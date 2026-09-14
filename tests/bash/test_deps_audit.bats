#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# ------------------------------------------
# Bats: mt-audit-deps / mt-deps-outdated / __mt_parse_maven_version_updates
# in .bash.d/20-vcs/56-audit.sh
# ------------------------------------------
# Covers the Maven support added alongside the pre-existing npm/pip
# branches: mt-audit-deps's OWASP dependency-check dispatch, the new
# mt-deps-outdated command (npm outdated / pip list --outdated / Maven
# Versions Plugin), and the awk-backed parser behind the Maven branch --
# including the two real formatting quirks confirmed against a live
# Spring Boot + GCP BOM project rather than assumed: a plugin-management
# section whose header collides with the plain dependency header's
# substring, and long name/version pairs wrapping onto a second physical
# [INFO] line with no dotted leader at all. All external tools (mvn, npm,
# pip) are stubbed on PATH -- no real network/registry calls.
#
# 56-audit.sh has no top-level side effects, so it's sourced directly,
# same as 01-secrets.sh in test_secrets.bats. mt-help is never exercised
# (no test passes -h), so it's left undefined rather than stubbed.
#
# __mt_parse_maven_version_updates locates its awk script via
# $HOME/.bash.d/lib/awk/... (the same convention every other lib/awk or
# lib/python reference in the framework uses), so HOME is pointed at a
# throwaway directory with just lib/ symlinked in -- same technique as
# test_path_resolution.bats's setup() -- rather than relying on the real
# $HOME/.bash.d, which only happens to resolve correctly on a machine
# already migrated via mt-migrate-symlink and would silently break in CI.

setup() {
  local repo_bashd
  repo_bashd="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/.bash.d"

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d"
  ln -s "$repo_bashd/lib" "$HOME/.bash.d/lib"

  # shellcheck disable=SC1091
  source "$repo_bashd/20-vcs/56-audit.sh"

  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  PATH="$fake_bin:$PATH"

  project_dir="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project_dir/target"
  cd "$project_dir" || return 1
}

# ---------- mt-audit-deps: Maven branch ----------

@test "mt-audit-deps reports tool-missing when pom.xml exists but mvn doesn't" {
  touch pom.xml

  # Prepending fake_bin (the other tests' approach) only shadows a real
  # mvn if one happens to sit later on PATH -- this dev machine has a
  # real one installed, so proving "not found" needs a PATH that excludes
  # it entirely, not just one that offers a preferred alternative first.
  # jq is still needed (for the JSON-mode output itself), so it's the
  # only real binary carried over. Restored after, not just for other
  # tests' sake (bats forks a process per test anyway) but because
  # bats-core's own per-test teardown bookkeeping runs real coreutils
  # (rm, etc.) after this test body returns, in this same process.
  local old_path="$PATH"
  ln -s "$(command -v jq)" "$fake_bin/jq"
  PATH="$fake_bin"

  run mt-audit-deps -j

  PATH="$old_path"

  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "tool-missing" ]
}

@test "mt-audit-deps reports severity counts from a successful OWASP dependency-check run" {
  touch pom.xml
  cat > "$fake_bin/mvn" << 'EOF'
#!/usr/bin/env bash
mkdir -p target
cat > target/dependency-check-report.json << 'JSON'
{"dependencies":[
  {"vulnerabilities":[{"severity":"CRITICAL"},{"severity":"HIGH"}]},
  {"vulnerabilities":[{"severity":"medium"}]},
  {"vulnerabilities":[]}
]}
JSON
exit 0
EOF
  chmod +x "$fake_bin/mvn"

  run mt-audit-deps -j
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "ok" ]
  [ "$(echo "$output" | jq -r '.vulnerabilities.critical')" = "1" ]
  [ "$(echo "$output" | jq -r '.vulnerabilities.high')" = "1" ]
  [ "$(echo "$output" | jq -r '.vulnerabilities.moderate')" = "1" ]
  [ "$(echo "$output" | jq -r '.vulnerabilities.total')" = "3" ]
  # The report is parsed then cleaned up, not left behind as a build artifact.
  [ ! -f target/dependency-check-report.json ]
}

@test "mt-audit-deps gives an actionable message when NVD blocks the CVE database build" {
  touch pom.xml
  cat > "$fake_bin/mvn" << 'EOF'
#!/usr/bin/env bash
echo "[ERROR] Consider using an NVD API Key" >&2
echo "[ERROR] NoDataException: No documents exist" >&2
exit 1
EOF
  chmod +x "$fake_bin/mvn"

  run mt-audit-deps -j
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "error" ]
  [[ "$(echo "$output" | jq -r '.message')" == *"mt-add-nvd-key"* ]]
}

@test "mt-audit-deps reports unsupported for a directory with no known manifest" {
  run mt-audit-deps -j
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "unsupported" ]
}

# ---------- mt-deps-outdated: npm / pip branches ----------

@test "mt-deps-outdated parses npm outdated --json into the common update shape" {
  echo '{}' > package.json
  cat > "$fake_bin/npm" << 'EOF'
#!/usr/bin/env bash
echo '{"lodash": {"current": "4.17.20", "wanted": "4.17.21", "latest": "4.17.21"}}'
exit 1
EOF
  chmod +x "$fake_bin/npm"

  run mt-deps-outdated -j
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "ok" ]
  [ "$(echo "$output" | jq -r '.updates | length')" = "1" ]
  [ "$(echo "$output" | jq -r '.updates[0].scope')" = "dependency" ]
  [ "$(echo "$output" | jq -r '.updates[0].artifact')" = "lodash" ]
  [ "$(echo "$output" | jq -r '.updates[0].latest')" = "4.17.21" ]
}

@test "mt-deps-outdated reports zero updates when npm outdated finds nothing" {
  echo '{}' > package.json
  cat > "$fake_bin/npm" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$fake_bin/npm"

  run mt-deps-outdated -j
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "ok" ]
  [ "$(echo "$output" | jq -r '.updates | length')" = "0" ]
}

@test "mt-deps-outdated parses pip list --outdated --format=json" {
  touch requirements.txt
  cat > "$fake_bin/pip" << 'EOF'
#!/usr/bin/env bash
echo '[{"name": "requests", "version": "2.28.0", "latest_version": "2.32.0", "latest_filetype": "wheel"}]'
EOF
  chmod +x "$fake_bin/pip"

  run mt-deps-outdated -j
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "ok" ]
  [ "$(echo "$output" | jq -r '.updates[0].artifact')" = "requests" ]
  [ "$(echo "$output" | jq -r '.updates[0].current')" = "2.28.0" ]
  [ "$(echo "$output" | jq -r '.updates[0].latest')" = "2.32.0" ]
}

# ---------- mt-deps-outdated: Maven branch ----------

@test "mt-deps-outdated runs the three versions-plugin goals and parses all scopes" {
  touch pom.xml
  cat > "$fake_bin/mvn" << 'EOF'
#!/usr/bin/env bash
cat << 'MVNOUT'
[INFO] The following dependencies in Dependencies have newer versions:
[INFO]   org.projectlombok:lombok .......................... 1.18.30 -> 1.18.48
[INFO] The following dependencies in pluginManagement of plugins have newer versions:
[INFO]   org.springframework.boot:spring-boot-maven-plugin ...
[INFO]                                                        3.0.6 -> 4.2.0-M1
[INFO] --- versions:2.16.2:display-property-updates (default-cli) @ x ---
[INFO] This project does not have any properties associated with versions.
[INFO] --- versions:2.16.2:display-parent-updates (default-cli) @ x ---
[INFO] The parent project has a newer version:
[INFO]   org.springframework.boot:spring-boot-starter-parent  3.0.6 -> 4.2.0-M1
MVNOUT
exit 0
EOF
  chmod +x "$fake_bin/mvn"

  run mt-deps-outdated -j
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "ok" ]
  [ "$(echo "$output" | jq -r '.updates | length')" = "3" ]
  [ "$(echo "$output" | jq -r '[.updates[] | select(.scope == "dependency")] | length')" = "1" ]
  [ "$(echo "$output" | jq -r '[.updates[] | select(.scope == "plugin")][0].artifact')" = "org.springframework.boot:spring-boot-maven-plugin" ]
  [ "$(echo "$output" | jq -r '[.updates[] | select(.scope == "parent")][0].artifact')" = "org.springframework.boot:spring-boot-starter-parent" ]
  [ "$(echo "$output" | jq -r '[.updates[] | select(.scope == "parent")][0].latest')" = "4.2.0-M1" ]
}

@test "mt-deps-outdated surfaces a Maven failure as an error, not a false empty result" {
  touch pom.xml
  cat > "$fake_bin/mvn" << 'EOF'
#!/usr/bin/env bash
echo "[ERROR] Could not resolve dependencies" >&2
exit 1
EOF
  chmod +x "$fake_bin/mvn"

  run mt-deps-outdated -j
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.status')" = "error" ]
}

# ---------- __mt_parse_maven_version_updates (direct, no mvn involved) ----------

@test "__mt_parse_maven_version_updates handles dotted, plain, and wrapped line formats together" {
  raw='[INFO] The following dependencies in Dependencies have newer versions:
[INFO]   com.example:short-name .............. 1.0.0 -> 2.0.0
[INFO]   org.example:a-very-long-artifact-name-that-wraps ...
[INFO]                                                        1.0.0 -> 1.5.0
[INFO] The following dependencies in pluginManagement of plugins have newer versions:
[INFO]   org.example:some-plugin .............. 1.0.0 -> 1.1.0
[INFO] --- versions:2.16.2:display-parent-updates (default-cli) @ x ---
[INFO] The parent project has a newer version:
[INFO]   org.example:parent-pom  1.0.0 -> 2.0.0'

  result="$(__mt_parse_maven_version_updates "$raw")"

  [ "$(echo "$result" | jq 'length')" = "4" ]
  [ "$(echo "$result" | jq -r '.[0].scope')" = "dependency" ]
  [ "$(echo "$result" | jq -r '.[0].artifact')" = "com.example:short-name" ]
  [ "$(echo "$result" | jq -r '.[1].artifact')" = "org.example:a-very-long-artifact-name-that-wraps" ]
  [ "$(echo "$result" | jq -r '.[1].current')" = "1.0.0" ]
  [ "$(echo "$result" | jq -r '.[1].latest')" = "1.5.0" ]
  [ "$(echo "$result" | jq -r '.[2].scope')" = "plugin" ]
  [ "$(echo "$result" | jq -r '.[3].scope')" = "parent" ]
  [ "$(echo "$result" | jq -r '.[3].artifact')" = "org.example:parent-pom" ]
}

@test "__mt_parse_maven_version_updates returns an empty array when nothing is outdated" {
  raw='[INFO] The following dependencies in Dependencies have newer versions:
[INFO] --- versions:2.16.2:display-property-updates (default-cli) @ x ---
[INFO] This project does not have any properties associated with versions.'

  result="$(__mt_parse_maven_version_updates "$raw")"
  [ "$(echo "$result" | jq 'length')" = "0" ]
}
