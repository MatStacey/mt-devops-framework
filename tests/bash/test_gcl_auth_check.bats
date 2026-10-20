#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-auth-check in .bash.d/10-infra/30-gcp-config.sh
# ------------------------------------------
# gcloud is replaced with a stub on PATH driven by STUB_ACCOUNT,
# STUB_TOKEN_EXIT and STUB_TOKEN_ERR.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  stub_dir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/gcloud" << 'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "auth list") [ -n "${STUB_ACCOUNT:-}" ] && echo "$STUB_ACCOUNT" ;;
  "auth print-access-token")
    [ "${STUB_TOKEN_EXIT:-0}" -eq 0 ] && echo "ya29.token" || echo "${STUB_TOKEN_ERR:-}" >&2
    exit "${STUB_TOKEN_EXIT:-0}"
    ;;
esac
STUB
  chmod +x "$stub_dir/gcloud"
  PATH="$stub_dir:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/30-gcp-config.sh"
  mt-help() { :; }
}

@test "valid token returns 0" {
  STUB_ACCOUNT=me@example.com run gcl-auth-check
  [ "$status" -eq 0 ]
  [[ "$output" == *me@example.com* ]]
}

@test "token output is never printed" {
  STUB_ACCOUNT=me@example.com run gcl-auth-check
  [[ "$output" != *ya29* ]]
}

@test "no active account returns 1" {
  run gcl-auth-check
  [ "$status" -eq 1 ]
  [[ "$output" == *gcp-login* ]]
}

@test "reauthentication failure returns 2" {
  STUB_ACCOUNT=me@example.com STUB_TOKEN_EXIT=1 STUB_TOKEN_ERR="Reauthentication failed. cannot prompt during non-interactive execution." run gcl-auth-check
  [ "$status" -eq 2 ]
  [[ "$output" == *gcp-login* ]]
}

@test "other token failure returns 4 and shows the error" {
  STUB_ACCOUNT=me@example.com STUB_TOKEN_EXIT=1 STUB_TOKEN_ERR="network unreachable" run gcl-auth-check
  [ "$status" -eq 4 ]
  [[ "$output" == *"network unreachable"* ]]
}

@test "--quiet prints nothing" {
  STUB_ACCOUNT=me@example.com STUB_TOKEN_EXIT=1 STUB_TOKEN_ERR="Reauthentication failed" run gcl-auth-check --quiet
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "missing gcloud returns 3" {
  PATH="/usr/bin:/bin"
  rm -f "$stub_dir/gcloud"
  command -v gcloud && skip "system gcloud present"
  run gcl-auth-check --quiet
  [ "$status" -eq 3 ]
}
