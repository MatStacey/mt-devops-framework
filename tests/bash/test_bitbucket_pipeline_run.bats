#!/usr/bin/env bats
# ------------------------------------------
# Bats: bb-pipeline-run in .bash.d/25-atlassian/11-bitbucket-ci.sh
# ------------------------------------------
# mt-http is replaced by a function that logs its arguments and any -d @file
# body, and serves the trigger response and a scripted sequence of pipeline
# states (STUB_STATES, space-separated "STATE[/RESULT]", last one repeats).

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
  POLLS="$BATS_TEST_TMPDIR/polls"
  export SECRETS_MANAGER HTTP_LOG POLLS
  : > "$POLLS"
  BITBUCKET_PIPELINE_POLL_SECONDS=0
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""

  # shellcheck disable=SC2317
  mt-http() {
    local last="${*: -1}" arg prev=""
    echo "$*" >> "$HTTP_LOG"
    for arg in "$@"; do
      [[ "$prev" == "-d" && "$arg" == @* ]] && cat "${arg#@}" >> "$HTTP_LOG" && echo >> "$HTTP_LOG"
      prev="$arg"
    done
    [ -n "${STUB_FAIL:-}" ] && return 4
    case "$last" in
      */pipelines/) echo '{"uuid":"{p-1}","build_number":61}' ;;
      */pipelines/%7Bp-1%7D)
        local -a states=(${STUB_STATES:-COMPLETED/SUCCESSFUL})
        local n
        n=$(wc -l < "$POLLS")
        echo poll >> "$POLLS"
        local current="${states[$((n < ${#states[@]} ? n : ${#states[@]} - 1))]}"
        jq -nc --arg s "${current%%/*}" --arg r "${current#*/}" '{state: ({name: $s} + (if $r != $s then {result: {name: $r}} else {} end))}'
        ;;
    esac
  }
  # shellcheck disable=SC2317
  mt-help() { echo "help called"; }
}

@test "a branch run posts a ref target with a custom selector" {
  run bb-pipeline-run -r ws/r --branch feat/x --pattern deploy-stage --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Triggered pipeline #61 {p-1}"* ]]
  grep -qF '"target":{"type":"pipeline_ref_target","ref_type":"branch","ref_name":"feat/x","selector":{"type":"custom","pattern":"deploy-stage"}}' "$HTTP_LOG"
  grep -q 'repositories/ws/r/pipelines/$' "$HTTP_LOG"
  ! grep -qF '"variables"' "$HTTP_LOG"
}

@test "a commit run posts a commit target without a selector" {
  run bb-pipeline-run -r ws/r --commit abc1234 --yes
  [ "$status" -eq 0 ]
  grep -qF '"target":{"type":"pipeline_commit_target","commit":{"type":"commit","hash":"abc1234"}}' "$HTTP_LOG"
  ! grep -qF 'selector' "$HTTP_LOG"
}

@test "variables are sent, and a secured one is read from the environment, not the command line" {
  DEPLOY_TOKEN="s3cr3t-value" run bb-pipeline-run -r ws/r --branch main --var ENV=stage --secured-var DEPLOY_TOKEN --yes
  [ "$status" -eq 0 ]
  grep -qF '{"key":"ENV","value":"stage","secured":false}' "$HTTP_LOG"
  grep -qF '{"key":"DEPLOY_TOKEN","value":"s3cr3t-value","secured":true}' "$HTTP_LOG"
  [[ "$output" != *s3cr3t-value* ]]
  ! grep -F 's3cr3t-value' "$HTTP_LOG" | grep -vq '^{'
}

@test "without --yes and without a terminal it refuses and makes no request" {
  run bb-pipeline-run -r ws/r --branch main < /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"--yes"* ]]
  [ ! -s "$HTTP_LOG" ]
}

@test "--wait polls through the states and exits 0 when the pipeline succeeds" {
  STUB_STATES="PENDING IN_PROGRESS COMPLETED/SUCCESSFUL" run bb-pipeline-run -r ws/r --branch main --wait --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"PENDING"*"IN_PROGRESS"*"COMPLETED"* || "$output" == *"#61 SUCCESSFUL"* ]]
  [[ "$output" == *"#61 SUCCESSFUL"* ]]
  [ "$(wc -l < "$POLLS")" -eq 3 ]
}

@test "--wait exits 1 when the pipeline fails" {
  STUB_STATES="IN_PROGRESS COMPLETED/FAILED" run bb-pipeline-run -r ws/r --branch main --wait --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"#61 FAILED"* ]]
}

@test "--wait gives up with 124 at the timeout" {
  STUB_STATES="IN_PROGRESS" run bb-pipeline-run -r ws/r --branch main --wait --timeout 1 --yes
  [ "$status" -eq 124 ]
  [[ "$output" == *"Gave up waiting"* ]]
}

@test "a trigger API failure returns the mt-http code" {
  STUB_FAIL=1 run bb-pipeline-run -r ws/r --branch main --yes
  [ "$status" -eq 4 ]
}

@test "usage errors make no request" {
  run bb-pipeline-run -r ws/r --yes
  [ "$status" -eq 1 ]
  run bb-pipeline-run -r ws/r --branch a --commit abc1234 --yes
  [ "$status" -eq 1 ]
  run bb-pipeline-run -r ws/r --branch 'a b' --yes
  [ "$status" -eq 1 ]
  run bb-pipeline-run -r ws/r --commit nothex --yes
  [ "$status" -eq 1 ]
  run bb-pipeline-run -r ws/r --branch a --var NOEQUALS --yes
  [ "$status" -eq 1 ]
  run bb-pipeline-run -r ws/r --branch a --var 'bad key=1' --yes
  [ "$status" -eq 1 ]
  run bb-pipeline-run -r ws/r --branch a --secured-var UNSET_VARIABLE --yes
  [ "$status" -eq 1 ]
  run bb-pipeline-run -r ws/r --branch a --timeout 0 --yes
  [ "$status" -eq 1 ]
  run bb-pipeline-run -r ws/r --branch a --bogus
  [ "$status" -eq 1 ]
  [ ! -s "$HTTP_LOG" ]
}

@test "-h shows help" {
  run bb-pipeline-run -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}

@test "a secured value never appears in the argv of jq" {
  mkdir -p "$BATS_TEST_TMPDIR/shim"
  printf '#!/usr/bin/env bash\necho "$*" >> "%s/jq_argv"\nexec %s "$@"\n' "$BATS_TEST_TMPDIR" "$(command -v jq)" > "$BATS_TEST_TMPDIR/shim/jq"
  chmod +x "$BATS_TEST_TMPDIR/shim/jq"
  PATH="$BATS_TEST_TMPDIR/shim:$PATH" DEPLOY_TOKEN="s3cr3t-value" run bb-pipeline-run -r ws/r --branch main --secured-var DEPLOY_TOKEN --yes
  [ "$status" -eq 0 ]
  [ -s "$BATS_TEST_TMPDIR/jq_argv" ]
  ! grep -q 's3cr3t-value' "$BATS_TEST_TMPDIR/jq_argv"
  grep -qF '"value":"s3cr3t-value","secured":true' "$HTTP_LOG"
}
