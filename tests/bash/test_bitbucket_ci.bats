#!/usr/bin/env bats
# ------------------------------------------
# Bats: bb-pipelines, bb-env, bb-var and Bitbucket PR creation in
# .bash.d/25-atlassian/11-bitbucket-ci.sh
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
    local last="${*: -1}" arg prev=""
    echo "$*" >> "$HTTP_LOG"
    for arg in "$@"; do
      [[ "$prev" == "-d" && "$arg" == @* ]] && cat "${arg#@}" >> "$HTTP_LOG" && echo >> "$HTTP_LOG"
      prev="$arg"
    done
    [ -n "${STUB_FAIL:-}" ] && return 4
    case "$last" in
      */pipelines/%7Bnosteps%7D/steps/\?*) echo '{"values":[]}' ;;
      */steps/%7Bs3%7D/log) printf 'report https://storage.googleapis.com/b/r.html?x-goog-credential=sa%%40p.example%%2Fx&x-goog-date=20261101T000000Z&x-goog-signature=f00dcafe\n' ;;
      */steps/*/log) printf 'line1\nDB_PASSWORD=hunter2\nAuthorization: Bearer abc.def\nline4\x1b[31m\nline5\nexport API_TOKEN="q1w2"\npassword: '"'"'p3p4'"'"'\n{"password": "j5j6"}\n' ;;
      */steps/\?*) echo '{"values":[{"uuid":"{s1}","name":"Build","state":{"result":{"name":"SUCCESSFUL"}},"duration_in_seconds":12,"started_on":"2026-10-05T10:00:00Z","completed_on":"2026-10-05T10:00:12Z"},{"uuid":"{s2}","name":"Deploy","state":{"result":{"name":"FAILED","error":{"message":"Undeclared output\tvariable"}}},"duration_in_seconds":30,"started_on":"2026-10-05T10:00:12Z","completed_on":"2026-10-05T10:00:42Z"},{"uuid":"{s3}","name":"Verify","state":{"name":"IN_PROGRESS"},"started_on":"2026-10-05T10:00:42Z","completed_on":null}]}' ;;
      */pipelines/42) echo '{"uuid":"{p1}","build_number":42,"trigger":{"name":"PUSH"},"target":{"ref_name":"main","commit":{"hash":"0123456789abcdef"},"selector":{"type":"branches","pattern":"main"}}}' ;;
      */pipelines/%7Bnosteps%7D) echo '{"uuid":"{nosteps}","build_number":43,"trigger":{"name":"MANUAL"},"target":{"ref_name":"main","commit":{"hash":"fedcba9876543210"},"selector":{"type":"custom","pattern":"deploy-prod"}},"state":{"name":"COMPLETED","result":{"name":"FAILED","error":{"message":"Step is empty"}}}}' ;;
      */pipelines/) echo '{"values":[{"uuid":"{p1}","build_number":42,"state":{"result":{"name":"FAILED"}},"target":{"ref_name":"main"},"creator":{"display_name":"Al"},"duration_in_seconds":95,"created_on":"t"}]}' ;;
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
  [[ "$output" == *$'#42\tFAILED\t95s\tmain\tAl'* ]]
  grep -q "pagelen=10" "$HTTP_LOG"
}

@test "bb-pipelines resolves a build number and lists numbered steps" {
  run bb-pipelines -r ws/r 42
  [[ "$output" == *$'1\tSUCCESSFUL\tBuild\t12s\t2026-10-05T10:00:00Z\t2026-10-05T10:00:12Z\t{s1}'* ]]
  [[ "$output" == *$'2\tFAILED\tDeploy\t30s\t2026-10-05T10:00:12Z\t2026-10-05T10:00:42Z\t{s2}'* ]]
  [[ "$output" == *$'3\tIN_PROGRESS\tVerify\t0s\t2026-10-05T10:00:42Z\t-\t{s3}'* ]]
  grep -q "pipelines/42" "$HTTP_LOG"
}

@test "pipeline and step UUID braces are URL-encoded" {
  run bb-pipelines -r ws/r 42 --log 2
  grep -q "pipelines/%7Bp1%7D/steps/%7Bs2%7D/log" "$HTTP_LOG"
}

@test "step logs are redacted, tailed and stripped of control characters" {
  run bb-pipelines -r ws/r 42 --log 2 --tail 7
  [[ "$output" != *hunter2* ]]
  [[ "$output" != *abc.def* ]]
  [[ "$output" != *line1* ]]
  [[ "$output" != *$'\033'* ]]
  [[ "$output" == *"DB_PASSWORD=***"* ]]
  [[ "$output" == *line5* ]]
}

@test "quoted and JSON-style secrets are redacted in step logs" {
  run bb-pipelines -r ws/r 42 --log 2 --tail 10
  [[ "$output" != *q1w2* ]]
  [[ "$output" != *p3p4* ]]
  [[ "$output" != *j5j6* ]]
  [[ "$output" == *'API_TOKEN="***"'* ]]
}

@test "signed URL credentials are redacted in step logs" {
  run bb-pipelines -r ws/r 42 --log 3
  [ "$status" -eq 0 ]
  [[ "$output" != *f00dcafe* ]]
  [[ "$output" != *p.example* ]]
  [[ "$output" == *"x-goog-credential=***&x-goog-date=20261101T000000Z&x-goog-signature=***"* ]]
}

@test "GCS V4 signed URL: signature and credential masked, path, date and expiry kept" {
  run sed -E -f "$BITBUCKET_REDACT_SED" <<< 'https://storage.googleapis.com/b/o.xml?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=sa%40p.example%2F20261101%2Fauto&X-Goog-Date=20261101T000000Z&X-Goog-Expires=600&X-Goog-SignedHeaders=host&X-Goog-Signature=abc123'
  [ "$output" = 'https://storage.googleapis.com/b/o.xml?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=***&X-Goog-Date=20261101T000000Z&X-Goog-Expires=600&X-Goog-SignedHeaders=host&X-Goog-Signature=***' ]
}

@test "GCS V4 signed URL in lowercase is masked the same way" {
  run sed -E -f "$BITBUCKET_REDACT_SED" <<< 'https://storage.googleapis.com/b/o.xml?x-goog-algorithm=GOOG4-RSA-SHA256&x-goog-credential=sa%40p.example%2Fx&x-goog-date=20261101T000000Z&x-goog-expires=600&x-goog-signedheaders=host&x-goog-signature=abc123'
  [ "$output" = 'https://storage.googleapis.com/b/o.xml?x-goog-algorithm=GOOG4-RSA-SHA256&x-goog-credential=***&x-goog-date=20261101T000000Z&x-goog-expires=600&x-goog-signedheaders=host&x-goog-signature=***' ]
}

@test "S3 presigned URL: credential, security token and signature masked" {
  run sed -E -f "$BITBUCKET_REDACT_SED" <<< 'https://bkt.s3.example/k?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIDEXAMPLE%2F20261101&X-Amz-Date=20261101T000000Z&X-Amz-Expires=600&X-Amz-Security-Token=FQoGtok&X-Amz-SignedHeaders=host&X-Amz-Signature=deadbeef'
  [[ "$output" != *AKIDEXAMPLE* ]]
  [[ "$output" != *FQoGtok* ]]
  [[ "$output" != *deadbeef* ]]
  [[ "$output" == *"X-Amz-Credential=***&X-Amz-Date=20261101T000000Z&X-Amz-Expires=600&"* ]]
}

@test "GCS V2 signed URL: access id and signature masked, expiry kept" {
  run sed -E -f "$BITBUCKET_REDACT_SED" <<< 'https://storage.googleapis.com/b/o?GoogleAccessId=sa@p.example&Expires=1700000000&Signature=c2ln%3D'
  [ "$output" = 'https://storage.googleapis.com/b/o?GoogleAccessId=***&Expires=1700000000&Signature=***' ]
}

@test "two signed URLs on one line are both masked" {
  run sed -E -f "$BITBUCKET_REDACT_SED" <<< 'a https://x/o?X-Goog-Signature=s1&X-Goog-Date=d1 b https://y/o?X-Goog-Signature=s2&X-Goog-Date=d2'
  [ "$output" = 'a https://x/o?X-Goog-Signature=***&X-Goog-Date=d1 b https://y/o?X-Goog-Signature=***&X-Goog-Date=d2' ]
}

@test "Signature= outside a query string is left alone" {
  run sed -E -f "$BITBUCKET_REDACT_SED" <<< 'Signature=abc is plain'
  [ "$output" = 'Signature=abc is plain' ]
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

@test "bb-var add keeps the value out of the argv of jq" {
  mkdir -p "$BATS_TEST_TMPDIR/shim"
  printf '#!/usr/bin/env bash\necho "$*" >> "%s/jq_argv"\nexec %s "$@"\n' "$BATS_TEST_TMPDIR" "$(command -v jq)" > "$BATS_TEST_TMPDIR/shim/jq"
  chmod +x "$BATS_TEST_TMPDIR/shim/jq"
  PATH="$BATS_TEST_TMPDIR/shim:$PATH" bb-var -r ws/r add --secured TOKEN <<< "s3cret-value"
  [ -s "$BATS_TEST_TMPDIR/jq_argv" ]
  ! grep -q 's3cret-value' "$BATS_TEST_TMPDIR/jq_argv"
  grep -qF '"value":"s3cret-value"' "$HTTP_LOG"
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

@test "PR creation closes the source branch on merge by default" {
  run __mt_bb_create_pull_request ws/r feat main "T" "B"
  [ "$status" -eq 0 ]
  grep -q '"close_source_branch":true' "$HTTP_LOG"
}

@test "PR creation with close_source false keeps the source branch" {
  run __mt_bb_create_pull_request ws/r feat main "T" "B" false
  [ "$status" -eq 0 ]
  grep -q '"close_source_branch":false' "$HTTP_LOG"
}

@test "PR creation rejects a close_source that is not true or false without a request" {
  run __mt_bb_create_pull_request ws/r feat main "T" "B" yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"close_source must be true or false"* ]]
  [ ! -f "$HTTP_LOG" ]
}

@test "an already-open PR is returned without a POST or a PUT" {
  STUB_EXISTING_PR=1 run __mt_bb_create_pull_request ws/r feat main "T" "B" false
  [ "$status" -eq 0 ]
  [ "$output" = "https://bitbucket.org/ws/r/pull-requests/5" ]
  run grep -qE -- '-d |-X PUT|close_source_branch' "$HTTP_LOG"
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

# Runs git-raise-pr end to end on a Bitbucket remote with every step before
# PR creation stubbed; the create helper logs the close_source it receives.
raise_pr_full_setup() {
  raise_pr_setup
  close_log="$BATS_TEST_TMPDIR/close_source"
  # shellcheck disable=SC2317
  __mt_git_default_branch() { echo main; }
  # shellcheck disable=SC2317
  git() {
    [ "$*" = "branch --show-current" ] && echo feat
    return 0
  }
  # shellcheck disable=SC2317
  __git_raise_pr_sync_with_target() { return 0; }
  # shellcheck disable=SC2317,SC2034
  __git_raise_pr_handle_dead_pr() { is_github=false origin_url="git@bitbucket.org:ws/r.git"; }
  # shellcheck disable=SC2317
  __git_raise_pr_push_branch() { return 0; }
  # shellcheck disable=SC2317
  __mt_bb_create_pull_request() {
    echo "$6" > "$close_log"
    echo "https://bitbucket.org/ws/r/pull-requests/6"
  }
}

@test "git-raise-pr closes the Bitbucket source branch by default" {
  raise_pr_full_setup
  run git-raise-pr -t T -m B
  [ "$status" -eq 0 ]
  [ "$(cat "$close_log")" = "true" ]
}

@test "git-raise-pr -k keeps the Bitbucket source branch" {
  raise_pr_full_setup
  run git-raise-pr -k -t T -m B
  [ "$status" -eq 0 ]
  [ "$(cat "$close_log")" = "false" ]
}

@test "git-raise-pr rejects an unknown option" {
  raise_pr_full_setup
  run git-raise-pr -z
  [ "$status" -eq 1 ]
  [[ "$output" == *"[-k]"* ]]
  [ ! -f "$close_log" ]
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

@test "the no-steps output starts with the run header" {
  run bb-pipelines -r ws/r '{nosteps}'
  [ "${lines[0]}" = "#43 MANUAL main fedcba987654 custom:deploy-prod" ]
  [[ "${lines[1]}" == "No steps ran."* ]]
  [ "$(grep -c 'pipelines/%7Bnosteps%7D$' "$HTTP_LOG")" -eq 1 ]
}

@test "a run's step table starts with a header line from one pipeline GET" {
  run bb-pipelines -r ws/r 42
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "#42 PUSH main 0123456789ab branches:main" ]
  [ "$(grep -c 'pipelines/42$' "$HTTP_LOG")" -eq 1 ]
}

@test "--log prints no header" {
  run bb-pipelines -r ws/r 42 --log 1
  [[ "$output" != *"#42 PUSH"* ]]
}

@test "a failed step's error message is the 8th column, - when there is none" {
  run bb-pipelines -r ws/r 42
  [[ "$output" == *$'\t{s2}\tUndeclared output variable'* ]]
  [[ "$output" == *$'\t{s1}\t-'* ]]
  [ "$(awk -F'\t' 'NR > 1 { print NF }' <<< "$output" | sort -u)" = "8" ]
}

# Serves the pipelines list from a fixture, regardless of query.
stub_run_list() {
  RUN_LIST_FIXTURE="$BATS_TEST_DIRNAME/fixtures/bb_pipelines/$1"
  export RUN_LIST_FIXTURE
  # shellcheck disable=SC2317
  mt-http() {
    echo "$*" >> "$HTTP_LOG"
    case "$*" in
      *page=2*) command cat "$BATS_TEST_DIRNAME/fixtures/bb_pipelines/scan_page2.json" ;;
      *) command cat "$RUN_LIST_FIXTURE" ;;
    esac
  }
}

@test "the run list shows each selector type in a 7th column" {
  stub_run_list runs_by_type.json
  run bb-pipelines -r ws/r
  [ "$status" -eq 0 ]
  [[ "$output" == *$'#10\tSUCCESSFUL\t60s\tmain\tAl\t2026-10-10T10:00:00Z\tcustom:deploy-prod'* ]]
  [[ "$output" == *$'\tbranches:main'* ]]
  [[ "$output" == *$'\ttags:v*'* ]]
  [[ "$output" == *$'\tpull-requests:**'* ]]
  [[ "$output" == *$'\tdefault'* ]]
  [[ "$output" == *$'\tbranches:release (imported: shared-build)'* ]]
  [[ "$output" == *$'#4\tCOMPLETED\t1s\tstaging\tAl\t2026-10-04T10:00:00Z\t-'* ]]
  [ "$(awk -F'\t' '{ print NF }' <<< "$output" | sort -u)" = "7" ]
}

@test "--selector filters on the server by selector pattern" {
  stub_run_list runs_by_type.json
  run bb-pipelines -r ws/r --selector deploy-prod
  [ "$status" -eq 0 ]
  grep -q -- '-q target.selector.pattern=deploy-prod' "$HTTP_LOG"
}

@test "--selector with an invalid value exits 1 without a request" {
  run bb-pipelines -r ws/r --selector 'bad;value'
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "--by-selector prints the newest run of each selector over two pages, stalest first" {
  stub_run_list scan_page1.json
  run bb-pipelines -r ws/r --by-selector -n 6
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[0]}" = $'-\t#2\tCOMPLETED\t2026-10-02T10:00:00Z' ]
  [ "${lines[1]}" = $'custom:nightly\t#3\tSUCCESSFUL\t2026-10-03T10:00:00Z' ]
  [ "${lines[2]}" = $'custom:deploy-prod\t#29\tFAILED\t2026-10-29T10:00:00Z' ]
  [ "${lines[3]}" = $'branches:main\t#30\tSUCCESSFUL\t2026-10-30T10:00:00Z' ]
  grep -q 'page=1' "$HTTP_LOG"
  grep -q 'page=2' "$HTTP_LOG"
}

@test "--by-selector warns when the scan stops before the oldest run" {
  stub_run_list scan_page1.json
  run --separate-stderr bb-pipelines -r ws/r --by-selector -n 2
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"older runs may exist"* ]]
  [ "$(grep -c 'pagelen=2' "$HTTP_LOG")" -eq 1 ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "--by-selector without -n scans the default 300 runs, 100 per page" {
  stub_run_list scan_page1.json
  run bb-pipelines -r ws/r --by-selector
  [ "$status" -eq 0 ]
  grep -q 'pagelen=100' "$HTTP_LOG"
}

@test "--by-selector cannot be combined with a build, --log or --wait" {
  run bb-pipelines -r ws/r --by-selector 42
  [ "$status" -eq 1 ]
  run bb-pipelines -r ws/r --by-selector 42 --wait
  [ "$status" -eq 1 ]
  run bb-pipelines -r ws/r --selector deploy-prod 42 --log 1
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "--by-selector rejects a scan size above the maximum" {
  run bb-pipelines -r ws/r --by-selector -n 2001
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "the header shows a pull-request run's source branch" {
  run jq -r -L "$HOME/.bash.d/lib/jq" -f "$HOME/.bash.d/lib/jq/bb_pipeline_header.jq" <<< '{"build_number":7,"trigger":{"name":"PULLREQUEST_CREATED"},"target":{"source":"feat/x","commit":{"hash":"abc"},"selector":{"type":"pull-requests","pattern":"**"}}}'
  [ "$output" = "#7 PULLREQUEST_CREATED feat/x abc pull-requests:**" ]
}
