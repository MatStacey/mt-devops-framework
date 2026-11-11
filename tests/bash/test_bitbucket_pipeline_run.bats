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
  LISTS="$BATS_TEST_TMPDIR/lists"
  export SECRETS_MANAGER HTTP_LOG POLLS LISTS
  : > "$POLLS"
  : > "$LISTS"
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
    if [[ "$last" == */pipelines/%7Bp-1%7D && -n "${STUB_POLL_FAILS:-}" ]]; then
      local seen
      seen=$(wc -l < "$POLLS")
      if [ "$seen" -lt "$STUB_POLL_FAILS" ]; then
        echo poll >> "$POLLS"
        echo '{"error":{"message":"There was an error processing your request"}}' >&2
        return 4
      fi
    fi
    case "$last" in
      */pipelines/)
        if [[ "$*" == *" -d "* ]]; then
          echo '{"uuid":"{p-1}","build_number":61}'
        else
          local lists
          lists=$(wc -l < "$LISTS")
          echo list >> "$LISTS"
          if [ "$lists" -lt "${STUB_LIST_EMPTY_POLLS:-0}" ]; then
            echo '{"values":[{"uuid":"{p-0}","build_number":60,"target":{"commit":{"hash":"ffff000"}}}]}'
          else
            echo '{"values":[{"uuid":"{p-0}","build_number":60,"target":{"commit":{"hash":"ffff000"}}},{"uuid":"{p-1}","build_number":61,"target":{"commit":{"hash":"abc1234def"}}}]}'
          fi
        fi
        ;;
      */pipelines/42) echo '{"uuid":"{p-1}","build_number":42}' ;;
      */steps/\?*) echo '{"values":[{"name":"Build","state":{"name":"COMPLETED","result":{"name":"SUCCESSFUL"}},"duration_in_seconds":5,"uuid":"{s-1}"}]}' ;;
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

@test "--wait retries a transient failed status check and still reports the real result" {
  STUB_POLL_FAILS=2 STUB_STATES="COMPLETED/SUCCESSFUL" run bb-pipeline-run -r ws/r --branch main --wait --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status check failed (1/5)"* && "$output" == *"Status check failed (2/5)"* ]]
  [[ "$output" == *"#61 SUCCESSFUL"* ]]
}

@test "--wait never exits 0 when the state stays unknown: repeated failures return the API code" {
  STUB_POLL_FAILS=99 run bb-pipeline-run -r ws/r --branch main --wait --yes
  [ "$status" -eq 4 ]
  [[ "$output" == *"state of pipeline #61 is unknown"* ]]
  [[ "$output" != *SUCCESSFUL* ]]
}

@test "--wait times out with 124 when status checks keep failing within the allowed retries" {
  BITBUCKET_POLL_MAX_FAILURES=99999 STUB_POLL_FAILS=99999 run bb-pipeline-run -r ws/r --branch main --wait --timeout 1 --yes
  [ "$status" -eq 124 ]
}

@test "bb-pipelines --wait on a build number waits and prints the result and step table" {
  STUB_STATES="IN_PROGRESS COMPLETED/SUCCESSFUL" run bb-pipelines -r ws/r 42 --wait
  [ "$status" -eq 0 ]
  [[ "$output" == *"#42 SUCCESSFUL"* ]]
  [[ "$output" == *"Build"* ]]
}

@test "bb-pipelines --wait exits 1 for a failed run and still prints the step table" {
  STUB_STATES="COMPLETED/FAILED" run bb-pipelines -r ws/r 42 --wait
  [ "$status" -eq 1 ]
  [[ "$output" == *"#42 FAILED"* ]]
  [[ "$output" == *"Build"* ]]
}

@test "bb-pipelines --wait on an already completed run polls once" {
  STUB_STATES="COMPLETED/SUCCESSFUL" run bb-pipelines -r ws/r 42 --wait
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$POLLS")" -eq 1 ]
}

@test "bb-pipelines --wait times out with 124 and prints no step table" {
  STUB_STATES="IN_PROGRESS" run bb-pipelines -r ws/r 42 --wait --timeout 1
  [ "$status" -eq 124 ]
  [[ "$output" != *"Build"* ]]
  ! grep -q 'steps/' "$HTTP_LOG"
}

@test "bb-pipelines --wait passes through the API code when polls keep failing" {
  STUB_POLL_FAILS=99 STUB_STATES="IN_PROGRESS" run bb-pipelines -r ws/r 42 --wait
  [ "$status" -eq 4 ]
  [[ "$output" != *"Build"* ]]
}

@test "bb-pipelines --commit --wait waits for the run to appear, then reports it" {
  STUB_LIST_EMPTY_POLLS=1 STUB_STATES="COMPLETED/SUCCESSFUL" run bb-pipelines -r ws/r --commit abc1234 --wait
  [ "$status" -eq 0 ]
  [[ "$output" == *"Waiting for a pipeline on abc1234"* ]]
  [[ "$output" == *"#61 SUCCESSFUL"* ]]
  [[ "$output" == *"Build"* ]]
  [ "$(wc -l < "$LISTS")" -eq 2 ]
}

@test "bb-pipelines --commit --wait times out with 124 when no run appears" {
  STUB_LIST_EMPTY_POLLS=999 run bb-pipelines -r ws/r --commit abc1234 --wait --timeout 1
  [ "$status" -eq 124 ]
  [[ "$output" == *"No pipeline for abc1234 appeared within 1s"* ]]
}

@test "bb-pipelines --commit --wait returns the API code after repeated list failures" {
  STUB_FAIL=1 run bb-pipelines -r ws/r --commit abc1234 --wait
  [ "$status" -eq 4 ]
}

@test "bb-pipelines wait usage errors make no request" {
  local -a bad=(
    "--wait"
    "42 --commit abc1234 --wait"
    "--commit abc1234"
    "42 --wait --log 1"
    "42 --timeout 5"
    "--commit nothex --wait"
    "42 --wait --timeout 0"
  )
  local args
  for args in "${bad[@]}"; do
    : > "$HTTP_LOG"
    # shellcheck disable=SC2086
    run bb-pipelines -r ws/r $args
    [ "$status" -eq 1 ]
    [ ! -s "$HTTP_LOG" ]
  done
}
