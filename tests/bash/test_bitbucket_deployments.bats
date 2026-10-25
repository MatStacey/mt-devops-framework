#!/usr/bin/env bats
# ------------------------------------------
# Bats: bb-deployments in .bash.d/25-atlassian/11-bitbucket-ci.sh
# ------------------------------------------
# mt-http is replaced by a function that logs its arguments and serves
# fixtures chosen by URL (two environments, three deployments, two pipelines).

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/25-atlassian/10-bitbucket.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/25-atlassian/11-bitbucket-ci.sh"
  export BITBUCKET_EMAIL="me@example.test" BITBUCKET_API_KEY="key-123"
  SECRETS_MANAGER="$BATS_TEST_TMPDIR/secrets_stub.py"
  : > "$SECRETS_MANAGER"
  HTTP_LOG="$BATS_TEST_TMPDIR/http.log"
  export SECRETS_MANAGER HTTP_LOG
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""

  # shellcheck disable=SC2317
  mt-http() {
    local last="${*: -1}"
    echo "$*" >> "$HTTP_LOG"
    case "$last" in
      */environments/\?*) echo '{"values":[{"uuid":"{e-stg}","name":"Staging"},{"uuid":"{e-prod}","name":"Production"}]}' ;;
      */deployments/\?*)
        echo '{"values":[
          {"environment":{"uuid":"{e-prod}"},"state":{"name":"COMPLETED","status":{"name":"SUCCESSFUL"},"started_on":"2026-10-05T10:00:00Z"},"release":{"commit":{"hash":"aaaaaaaaaaaa1111"},"pipeline":{"uuid":"{p-new}"}}},
          {"environment":{"uuid":"{e-prod}"},"state":{"name":"COMPLETED","status":{"name":"FAILED"},"started_on":"2026-10-03T10:00:00Z"},"deployable":{"commit":{"hash":"bbbbbbbbbbbb2222"},"pipeline":{"uuid":"{p-old}"}}},
          {"environment":{"uuid":"{e-stg}"},"state":{"name":"IN_PROGRESS","started_on":"2026-10-06T09:00:00Z"},"release":{"commit":{"hash":"cccccccccccc3333"},"pipeline":{"uuid":"{p-new}"}}}]}'
        ;;
      */pipelines/%7Bp-new%7D) echo '{"build_number":57,"target":{"ref_name":"main"},"creator":{"display_name":"Al"}}' ;;
      */pipelines/%7Bp-old%7D) echo '{"build_number":50,"target":{"ref_name":"release/1"},"creator":{"display_name":"Bo"}}' ;;
    esac
  }
  # shellcheck disable=SC2317
  mt-help() { :; }
}

@test "without -e it shows the latest deployment of each environment, one row each" {
  run bb-deployments -r ws/r
  [ "$status" -eq 0 ]
  [ "$(wc -l <<< "$output")" -eq 2 ]
  [ "$(sed -n 1p <<< "$output")" = "$(printf 'Production\tCOMPLETED/SUCCESSFUL\t2026-10-05T10:00:00Z\taaaaaaaaaaaa\tmain\t#57\tAl')" ]
  [ "$(sed -n 2p <<< "$output")" = "$(printf 'Staging\tIN_PROGRESS\t2026-10-06T09:00:00Z\tcccccccccccc\tmain\t#57\tAl')" ]
}

@test "-e lists that environment's history newest first, case-insensitively, limited by -n" {
  run bb-deployments -r ws/r -e production
  [ "$status" -eq 0 ]
  [ "$(wc -l <<< "$output")" -eq 2 ]
  [[ "$(sed -n 1p <<< "$output")" == Production$'\t'COMPLETED/SUCCESSFUL* ]]
  [ "$(sed -n 2p <<< "$output")" = "$(printf 'Production\tCOMPLETED/FAILED\t2026-10-03T10:00:00Z\tbbbbbbbbbbbb\trelease/1\t#50\tBo')" ]
  run bb-deployments -r ws/r -e Production -n 1
  [ "$(wc -l <<< "$output")" -eq 1 ]
}

@test "pipelines are looked up only for the printed rows" {
  run bb-deployments -r ws/r -e production -n 1
  [ "$status" -eq 0 ]
  [ "$(grep -c 'pipelines/' "$HTTP_LOG")" -eq 1 ]
  grep -q 'pipelines/%7Bp-new%7D' "$HTTP_LOG"
  ! grep -q 'p-old' "$HTTP_LOG"
}

@test "an unknown environment exits 1 before any deployment request" {
  run bb-deployments -r ws/r -e nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"No environment named 'nope'"* ]]
  ! grep -q 'deployments/' "$HTTP_LOG"
}

@test "bad usage exits 1" {
  run bb-deployments -r ws/r --bogus
  [ "$status" -eq 1 ]
  run bb-deployments -r ws/r -e production -n zero
  [ "$status" -eq 1 ]
}

@test "an API failure returns the mt-http code" {
  mt-http() { return 4; }
  run bb-deployments -r ws/r
  [ "$status" -eq 4 ]
}
