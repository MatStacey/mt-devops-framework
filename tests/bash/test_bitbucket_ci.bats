#!/usr/bin/env bats
# ------------------------------------------
# Bats: bb-pipelines, bb-env, bb-var and Bitbucket PR creation in
# .bash.d/20-vcs/63-bitbucket-ci.sh
# ------------------------------------------
# mt-http is replaced by a function that logs its arguments (and any
# -d @file body) and serves fixtures chosen by URL.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/61-bitbucket.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/63-bitbucket-ci.sh"
  export BITBUCKET_EMAIL="me@example.test" BITBUCKET_API_KEY="key-123"
  SECRETS_MANAGER="$BATS_TEST_TMPDIR/secrets_stub.py"
  : > "$SECRETS_MANAGER"
  HTTP_LOG="$BATS_TEST_TMPDIR/http.log"
  export SECRETS_MANAGER HTTP_LOG
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
      */pipelines/%7Bnosteps%7D/steps/\?*) echo '{"values":[]}' ;;
      */steps/*/log) printf 'line1\nDB_PASSWORD=hunter2\nAuthorization: Bearer abc.def\nline4\x1b[31m\nline5\n' ;;
      */steps/\?*) echo '{"values":[{"uuid":"{s1}","name":"Build","state":{"result":{"name":"SUCCESSFUL"}},"duration_in_seconds":12},{"uuid":"{s2}","name":"Deploy","state":{"result":{"name":"FAILED"}},"duration_in_seconds":30}]}' ;;
      */pipelines/42) echo '{"uuid":"{p1}","build_number":42}' ;;
      */pipelines/%7Bnosteps%7D) echo '{"state":{"name":"COMPLETED","result":{"name":"FAILED","error":{"message":"Step is empty"}}}}' ;;
      */pipelines/) echo '{"values":[{"uuid":"{p1}","build_number":42,"state":{"result":{"name":"FAILED"}},"target":{"ref_name":"main"},"creator":{"display_name":"Al"},"created_on":"t"}]}' ;;
      */environments/\?*) echo '{"values":[{"uuid":"{e1}","name":"Staging","environment_type":{"name":"Staging"}}]}' ;;
      */variables\?*) echo '{"values":[{"uuid":"{v1}","key":"PLAIN","value":"visible","secured":false},{"uuid":"{v2}","key":"SECRET","secured":true}]}' ;;
      */pullrequests)
        if [ -n "${STUB_EXISTING_PR:-}" ]; then
          echo '{"values":[{"links":{"html":{"href":"https://bitbucket.org/ws/r/pull-requests/5"}}}]}'
        elif [[ "$*" == *"-d "* ]]; then
          echo '{"links":{"html":{"href":"https://bitbucket.org/ws/r/pull-requests/6"}}}'
        else
          echo '{"values":[]}'
        fi
        ;;
    esac
  }
  # shellcheck disable=SC2317
  mt-help() { :; }
}

@test "bb-pipelines lists recent runs" {
  run bb-pipelines -r ws/r
  [ "$status" -eq 0 ]
  [[ "$output" == *$'#42\tFAILED\tmain\tAl'* ]]
  grep -q "pagelen=10" "$HTTP_LOG"
}

@test "bb-pipelines resolves a build number and lists numbered steps" {
  run bb-pipelines -r ws/r 42
  [[ "$output" == *$'1\tSUCCESSFUL\tBuild\t12s\t{s1}'* ]]
  [[ "$output" == *$'2\tFAILED\tDeploy\t30s\t{s2}'* ]]
  grep -q "pipelines/42" "$HTTP_LOG"
}

@test "pipeline and step UUID braces are URL-encoded" {
  run bb-pipelines -r ws/r 42 --log 2
  grep -q "pipelines/%7Bp1%7D/steps/%7Bs2%7D/log" "$HTTP_LOG"
}

@test "step logs are redacted, tailed and stripped of control characters" {
  run bb-pipelines -r ws/r 42 --log 2 --tail 4
  [[ "$output" != *hunter2* ]]
  [[ "$output" != *abc.def* ]]
  [[ "$output" != *line1* ]]
  [[ "$output" != *$'\033'* ]]
  [[ "$output" == *"DB_PASSWORD=***"* ]]
  [[ "$output" == *line5* ]]
}

@test "an unknown step number is an error" {
  run bb-pipelines -r ws/r 42 --log 9
  [ "$status" -eq 1 ]
}

@test "--log without a pipeline is a usage error" {
  run bb-pipelines -r ws/r --log 1
  [ "$status" -eq 1 ]
}

@test "bb-env list shows name, type and uuid" {
  run bb-env -r ws/r list
  [[ "$output" == *$'Staging\tStaging\t{e1}'* ]]
}

@test "bb-env create posts the environment and type" {
  run bb-env -r ws/r create QA --type Staging
  [ "$status" -eq 0 ]
  grep -q '"name":"QA"' "$HTTP_LOG"
  grep -q '"name":"Staging"' "$HTTP_LOG"
}

@test "bb-env rejects an unknown type" {
  run bb-env -r ws/r create QA --type Bogus
  [ "$status" -eq 1 ]
}

@test "bb-var list hides secured values" {
  run bb-var -r ws/r list
  [[ "$output" == *$'PLAIN\tvisible'* ]]
  [[ "$output" == *$'SECRET\t(secured)'* ]]
}

@test "bb-var list -e resolves the environment to its variables endpoint" {
  run bb-var -r ws/r -e staging list
  grep -q "deployments_config/environments/%7Be1%7D/variables" "$HTTP_LOG"
}

@test "bb-var add reads the value from stdin and keeps it off the command line" {
  bb-var -r ws/r add --secured TOKEN <<< "s3cret-value"
  grep -q '"key":"TOKEN"' "$HTTP_LOG"
  grep -q '"secured":true' "$HTTP_LOG"
  # the value only ever appears in the logged request-body file, never in the argument line
  run grep -E '^[^{]*s3cret-value' "$HTTP_LOG"
  [ "$status" -eq 1 ]
}

@test "an unknown environment is an error" {
  run bb-var -r ws/r -e nope list
  [ "$status" -eq 1 ]
}

@test "missing credentials stop bb-env before any request" {
  unset BITBUCKET_API_KEY
  run bb-env -r ws/r list
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "PR creation posts the branches and returns the new URL" {
  git init -q "$BATS_TEST_TMPDIR/repo"
  cd "$BATS_TEST_TMPDIR/repo" || return 1
  run __mt_bb_create_pull_request ws/r feat main "My title" "My body"
  [ "$status" -eq 0 ]
  [ "$output" = "https://bitbucket.org/ws/r/pull-requests/6" ]
  grep -q '"title":"My title"' "$HTTP_LOG"
  grep -q '"name":"feat"' "$HTTP_LOG"
}

@test "an already-open PR is reused instead of creating a duplicate" {
  STUB_EXISTING_PR=1 run __mt_bb_create_pull_request ws/r feat main "T" "B"
  [ "$output" = "https://bitbucket.org/ws/r/pull-requests/5" ]
  run grep -q '"title"' "$HTTP_LOG"
  [ "$status" -eq 1 ]
}

@test "PR creation failure returns 1 so git-raise-pr can fall back" {
  STUB_FAIL=1 run __mt_bb_create_pull_request ws/r feat main "T" "B"
  [ "$status" -eq 1 ]
}

# git-raise-pr's Bitbucket branch: collaborators are stubbed, variables are
# the ones git-raise-pr sets for __git_raise_pr_create_or_open.
raise_pr_setup() {
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/50-git.sh"
  # shellcheck disable=SC2034
  is_github=false origin_url="git@bitbucket.org:ws/r.git" current_branch=feat target_branch=main pr_title="T" pr_body="B"
  opened_log="$BATS_TEST_TMPDIR/opened"
  # shellcheck disable=SC2317
  __git_raise_pr_confirm_open_browser() { return 0; }
  # shellcheck disable=SC2317
  __open_url() { echo "$1" >> "$opened_log"; }
  # shellcheck disable=SC2317
  __mt_bb_resolve_repo() { echo ws/r; }
}

@test "git-raise-pr creates the Bitbucket PR through the API" {
  raise_pr_setup
  # shellcheck disable=SC2317
  __mt_bb_create_pull_request() { echo "https://bitbucket.org/ws/r/pull-requests/6"; }
  run __git_raise_pr_create_or_open
  [ "$status" -eq 0 ]
  [[ "$output" == *"pull-requests/6"* ]]
  [ "$(cat "$opened_log")" = "https://bitbucket.org/ws/r/pull-requests/6" ]
}

@test "git-raise-pr falls back to the browser compare URL when the API fails" {
  raise_pr_setup
  # shellcheck disable=SC2317
  __mt_bb_create_pull_request() { return 1; }
  run __git_raise_pr_create_or_open
  [[ "$output" == *"API request failed"* ]]
  [[ "$(cat "$opened_log")" == *"bitbucket.org/ws/r/pull-requests/new?source=feat&dest=main"* ]]
}

@test "a pipeline with no steps reports its result and error instead of nothing" {
  run bb-pipelines -r ws/r '{nosteps}'
  [ "$status" -eq 0 ]
  [[ "$output" == *FAILED* ]]
  [[ "$output" == *"Step is empty"* ]]
}
