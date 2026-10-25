#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-as-sa in .bash.d/10-infra/30-gcp-config.sh
# ------------------------------------------
# Runs against a fake $HOME holding an active gcloud configuration. gcloud is
# a stub that records its CLOUDSDK_CONFIG and argv; STUB_ACTIVATE_FAIL makes
# `auth activate-service-account` fail.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config/gcloud/configurations" "$BATS_TEST_TMPDIR/bin"
  printf 'default' > "$HOME/.config/gcloud/active_config"
  printf '[core]\nproject = proj-1\naccount = me@example.test\n' > "$HOME/.config/gcloud/configurations/config_default"
  unset CLOUDSDK_CONFIG CLOUDSDK_CORE_PROJECT CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT GOOGLE_APPLICATION_CREDENTIALS
  CALLS="$BATS_TEST_TMPDIR/calls"
  export CALLS
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
echo "gcloud config=${CLOUDSDK_CONFIG:-} $*" >> "$CALLS"
if [ "$1 $2" = "auth activate-service-account" ]; then
  [ -n "${STUB_ACTIVATE_FAIL:-}" ] && { echo "ERROR: bad key" >&2; exit 1; }
  mkdir -p "$CLOUDSDK_CONFIG" && echo activated > "$CLOUDSDK_CONFIG/credentials"
fi
exit 0
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/30-gcp-config.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  mt-help() { echo "help called"; }

  key_file="$BATS_TEST_TMPDIR/key.json"
  printf '{"type":"service_account","client_email":"ro@proj.iam.gserviceaccount.com","private_key":"FAKE-PRIVATE-MATERIAL"}' > "$key_file"
  chmod 600 "$key_file"
  config_before=$(cd "$HOME/.config/gcloud" && find . -type f -exec cksum {} + | sort)
}

config_unchanged() {
  [ "$(cd "$HOME/.config/gcloud" && find . -type f -exec cksum {} + | sort)" = "$config_before" ]
}

probe() {
  echo "config=${CLOUDSDK_CONFIG:-} project=${CLOUDSDK_CORE_PROJECT:-} imp=${CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT:-} adc=${GOOGLE_APPLICATION_CREDENTIALS:-}"
}

@test "--impersonate sets the environment for the command only" {
  run gcl-as-sa --impersonate ro@proj.iam.gserviceaccount.com -p proj-x -- probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running as ro@proj.iam.gserviceaccount.com"* ]]
  [[ "$output" == *"config= project=proj-x imp=ro@proj.iam.gserviceaccount.com adc="* ]]
  [ -z "${CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT:-}" ]
  [ -z "${CLOUDSDK_CORE_PROJECT:-}" ]
  config_unchanged
}

@test "--key-file activates in a temporary config that probe sees, then removes it" {
  run gcl-as-sa --key-file "$key_file" -- probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running as ro@proj.iam.gserviceaccount.com"* ]]
  local temp_config
  temp_config=$(grep -o 'config=[^ ]*' <<< "$output" | tail -1 | cut -d= -f2)
  [ -n "$temp_config" ]
  [ "$temp_config" != "$HOME/.config/gcloud" ]
  [ ! -e "$temp_config" ]
  [[ "$output" == *"adc=$key_file"* ]]
  grep -q "config=$temp_config auth activate-service-account --key-file=$key_file" "$CALLS"
  config_unchanged
}

@test "the key contents are never printed" {
  run gcl-as-sa --key-file "$key_file" -- probe
  [[ "$output" != *FAKE-PRIVATE-MATERIAL* ]]
  ! grep -q FAKE-PRIVATE-MATERIAL "$CALLS"
}

@test "the command's exit code is passed through and the temp config is removed on failure" {
  run gcl-as-sa --key-file "$key_file" -- bash -c 'echo "$CLOUDSDK_CONFIG" > "$0"; exit 7' "$BATS_TEST_TMPDIR/seen"
  [ "$status" -eq 7 ]
  [ ! -e "$(cat "$BATS_TEST_TMPDIR/seen")" ]
  config_unchanged
}

@test "a failed activation exits 1, shows the error, runs nothing and leaves no temp config" {
  STUB_ACTIVATE_FAIL=1 run gcl-as-sa --key-file "$key_file" -- bash -c 'echo ran > "$0"' "$BATS_TEST_TMPDIR/ran"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bad key"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/ran" ]
  config_unchanged
}

@test "an invalid or missing key file exits 1 before any gcloud call" {
  printf '{"type":"authorized_user"}' > "$BATS_TEST_TMPDIR/user.json"
  run gcl-as-sa --key-file "$BATS_TEST_TMPDIR/user.json" -- probe
  [ "$status" -eq 1 ]
  run gcl-as-sa --key-file "$BATS_TEST_TMPDIR/missing.json" -- probe
  [ "$status" -eq 1 ]
  [ ! -s "$CALLS" ]
}

@test "a key file readable by others triggers a warning" {
  chmod 644 "$key_file"
  run gcl-as-sa --key-file "$key_file" -- probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"readable by other users"* ]]
}

@test "usage errors: no command, both or neither identity, bad email or project" {
  run gcl-as-sa --impersonate ro@proj.iam.gserviceaccount.com
  [ "$status" -eq 1 ]
  run gcl-as-sa --impersonate ro@proj.iam.gserviceaccount.com --key-file "$key_file" -- probe
  [ "$status" -eq 1 ]
  run gcl-as-sa -- probe
  [ "$status" -eq 1 ]
  run gcl-as-sa --impersonate not-an-email -- probe
  [ "$status" -eq 1 ]
  run gcl-as-sa --impersonate ro@proj.iam.gserviceaccount.com -p 'bad;p' -- probe
  [ "$status" -eq 1 ]
  run gcl-as-sa --bogus
  [ "$status" -eq 1 ]
}

@test "a framework function passed as the command runs in the subshell" {
  run gcl-as-sa --impersonate ro@proj.iam.gserviceaccount.com -- probe
  [[ "$output" == *"imp=ro@proj.iam.gserviceaccount.com"* ]]
}

@test "-h shows help" {
  run gcl-as-sa -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}
