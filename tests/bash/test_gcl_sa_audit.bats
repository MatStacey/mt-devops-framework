#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-sa-audit in .bash.d/10-infra/37-gcp-sa-audit.sh
# ------------------------------------------
# gcloud is replaced by a stub on PATH that logs its argv and serves the
# fixtures in fixtures/gcl_sa_audit/ by command and resource; proj-denied
# fails with a permission error and an unknown pool with NOT_FOUND.

# shellcheck disable=SC2154  # $stderr is set by `run --separate-stderr`
bats_require_minimum_version 1.5.0

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  export FIXTURES="$BATS_TEST_DIRNAME/fixtures/gcl_sa_audit" GCLOUD_LOG="$BATS_TEST_TMPDIR/gcloud.log"
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GCLOUD_LOG"
project="" pool=""
for arg in "$@"; do
  case "$arg" in
    --project=*) project="${arg#--project=}" ;;
    --workload-identity-pool=*) pool="${arg#--workload-identity-pool=}" ;;
  esac
done
if [ "$project" = "proj-denied" ] || [ "$4" = "proj-denied" ]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'iam.serviceAccounts.list' denied" >&2
  exit 1
fi
serve() {
  [ -f "$FIXTURES/$1" ] && cat "$FIXTURES/$1" && exit 0
  echo "ERROR: (gcloud) NOT_FOUND: Requested entity was not found." >&2
  exit 1
}
case "$1 $2 $3" in
  "iam service-accounts list") serve "sa_list_${project}.json" ;;
  "projects get-iam-policy "*) serve "project_policy_$3.json" ;;
  "iam service-accounts get-iam-policy") serve "sa_policy_${4%%@*}.json" ;;
  "iam workload-identity-pools describe") serve "pool_$4.json" ;;
  "iam workload-identity-pools providers") serve "providers_${pool}.json" ;;
esac
exit 1
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/37-gcp-sa-audit.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  unset GCP_WIF_BROAD_CLAIMS
  mt-help() { echo "help called"; }
  gcl-get-project() { echo "proj-b"; }
  gcl-get-user() { echo "me@example.test"; }
  gcl-auth-check() { return 0; }
}

# Prints "<service account local part> <finding>" for each row on stdout.
findings_of() {
  awk -F'\t' '{ split($3, sa, "@"); print sa[1], $6 }' <<< "$1" | sort
}

@test "each finding code is raised by the fixture built for it" {
  run --separate-stderr gcl-sa-audit -p proj-a
  [ "$status" -eq 0 ]
  [ "$(findings_of "$output")" = "builder NO_CONDITION
builder POOL_MISSING
builder POOL_MISSING
deployer BROAD_ATTRIBUTE+SECRETS
deployer PLACEHOLDER_SUBJECT+SECRETS
deployer WILDCARD_POOL+SECRETS" ]
}

@test "rows use the shared six-column schema with the wif detail" {
  run --separate-stderr gcl-sa-audit -p proj-a
  [[ "$output" == *$'wif\tproj-a\tdeployer@proj-a.iam.gserviceaccount.com\tprincipalSet://iam.googleapis.com/projects/111/locations/global/workloadIdentityPools/ci-pool/attribute.repository_owner/acme\tpool=ci-pool attr=repository_owner<-assertion.repository_owner condition=set\tBROAD_ATTRIBUTE+SECRETS'* ]]
  [[ "$output" == *$'\tpool=loose-pool attr=- condition=none\tNO_CONDITION'* ]]
  [[ "$output" == *$'\tpool=ci-pools attr=- condition=-\tPOOL_MISSING'* ]]
  [ "$(awk -F'\t' '{ print NF }' <<< "$output" | sort -u)" = "6" ]
}

@test "+SECRETS is appended only for a service account with a project-level secretmanager role" {
  run --separate-stderr gcl-sa-audit -p proj-a
  [ "$(grep -c '^wif.proj-a.deployer@.*+SECRETS$' <<< "$output")" -eq 3 ]
  [ "$(grep -c '^wif.proj-a.builder@.*+SECRETS$' <<< "$output")" -eq 0 ]
}

@test "members of other roles and non-WIF members are ignored" {
  run --separate-stderr gcl-sa-audit -p proj-a
  [ "$(grep -c "WILDCARD_POOL" <<< "$output")" -eq 1 ]
  [[ "$output" != *"svc.id.goog"* ]]
  [[ "$output" != *"clean@"* ]]
}

@test "a clean project prints no rows, says so and exits 0" {
  run --separate-stderr gcl-sa-audit
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" == *"✅ No findings."* ]]
}

@test "the summary counts findings, service accounts and projects" {
  run --separate-stderr gcl-sa-audit -p proj-a -p proj-b
  [[ "$stderr" == *"6 findings across 4 service accounts in 2 projects"* ]]
}

@test "--expected-pool flags a plural pool name as both mismatched and missing" {
  run --separate-stderr gcl-sa-audit -p proj-a --expected-pool ci-pool
  [ "$status" -eq 0 ]
  [[ "$output" == *$'/ci-pools/subject/repo:acme/app\tpool=ci-pools attr=- condition=-\tPOOL_MISMATCH'* ]]
  [[ "$output" == *$'/ci-pools/subject/repo:acme/app\tpool=ci-pools attr=- condition=-\tPOOL_MISSING'* ]]
  [ "$(grep -c "POOL_MISMATCH" <<< "$output")" -eq 3 ]
}

@test "a denied project is reported, the other still prints, and the exit code is 5" {
  run --separate-stderr gcl-sa-audit -p proj-denied -p proj-a
  [ "$status" -eq 5 ]
  [[ "$stderr" == *"Permission denied for listing service accounts of proj-denied"* ]]
  [[ "$output" == *"deployer@proj-a"* ]]
}

@test "--json prints the same findings as an array" {
  run --separate-stderr gcl-sa-audit -p proj-a --json
  [ "$status" -eq 0 ]
  jq -e 'type == "array" and length == 6' <<< "$output"
  jq -e 'all(.[]; keys == ["check", "detail", "finding", "principal", "project", "resource"])' <<< "$output"
}

@test "--json with no findings prints an empty array" {
  run --separate-stderr gcl-sa-audit --json
  [ "$(jq -c . <<< "$output")" = "[]" ]
}

@test "each pool is described once, not once per member" {
  run --separate-stderr gcl-sa-audit -p proj-a -p proj-b
  [ "$(grep -c "workload-identity-pools describe ci-pool " "$GCLOUD_LOG")" -eq 1 ]
  [ "$(grep -c "providers list --workload-identity-pool=ci-pool " "$GCLOUD_LOG")" -eq 1 ]
}

@test "gcp.wif_broad_claims replaces the default claims" {
  GCP_WIF_BROAD_CLAIMS="assertion.sub" run --separate-stderr gcl-sa-audit -p proj-a
  [ "$(grep -c "BROAD_ATTRIBUTE" <<< "$output")" -eq 0 ]
}

@test "bad usage is rejected before any gcloud call" {
  local args
  for args in "--bogus" "-p" "--expected-pool" "-p BAD_PROJECT" "--expected-pool Bad_Pool" "--expected-pool abc"; do
    # shellcheck disable=SC2086
    run gcl-sa-audit $args
    [ "$status" -eq 1 ] || {
      echo "args: $args -> $status"
      return 1
    }
  done
  [ ! -f "$GCLOUD_LOG" ]
}

@test "terminal control characters in fixture values are stripped" {
  mkdir -p "$BATS_TEST_TMPDIR/fx"
  cp "$FIXTURES"/*.json "$BATS_TEST_TMPDIR/fx/"
  sed -i 's|subject/REPLACE_ME|subject/REPLACE_ME\\u001b[31m|' "$BATS_TEST_TMPDIR/fx/sa_policy_deployer.json"
  FIXTURES="$BATS_TEST_TMPDIR/fx" run --separate-stderr gcl-sa-audit -p proj-a
  [[ "$output" == *"PLACEHOLDER_SUBJECT"* ]]
  [[ "$output" != *$'\033'* ]]
}

@test "no findings with an unreadable project warns instead of giving the all-clear" {
  run --separate-stderr gcl-sa-audit -p proj-denied -p proj-b
  [ "$status" -eq 5 ]
  [ -z "$output" ]
  [[ "$stderr" != *"✅"* ]]
  [[ "$stderr" == *"⚠️  No findings in what could be read; some projects or policies were unreadable (see above)"* ]]
}
