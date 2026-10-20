#!/usr/bin/env bats
# ------------------------------------------
# Bats: option parsers must not hang on a trailing flag with no value
# ------------------------------------------
# A bare `shift 2` fails without shifting when only the flag is left, so a
# `while [ "$#" -gt 0 ]` loop around it spins forever.

# shellcheck disable=SC2016
setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "no framework script uses a bare 'shift 2'" {
  run grep -rnE --include='*.sh' --exclude-dir=40-private '^[[:space:]]*shift 2$' "$repo_root/.bash.d"
  [ "$status" -eq 1 ]
}

@test "a trailing -p does not hang gcl-org-policies" {
  run timeout 5 bash -c 'source "$1"; gcl-get-project() { echo p; }; gcloud() { :; }; gcl-org-policies -p' _ "$repo_root/.bash.d/10-infra/30-gcp-config.sh"
  [ "$status" -ne 124 ]
}

@test "a trailing option does not hang a gcp-survey parser" {
  run timeout 5 bash -c 'source "$1"; gcl-get-project() { echo p; }; gcloud() { :; }; mt-help() { :; }; gcl-logging-read "f" -p' _ "$repo_root/.bash.d/10-infra/32-gcp-survey.sh"
  [ "$status" -ne 124 ]
}
