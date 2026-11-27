#!/usr/bin/env bats
# ------------------------------------------
# Bats: Bitbucket helpers in .bash.d/25-atlassian/10-bitbucket.sh
# ------------------------------------------
# mt-http is replaced by a function that logs its arguments and serves a
# fixture file chosen by the URL, so no network or real credentials are used.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/25-atlassian/10-bitbucket.sh"
  export BITBUCKET_EMAIL="me@example.test" BITBUCKET_API_KEY="key-123"
  SECRETS_MANAGER="$BATS_TEST_TMPDIR/secrets_stub.py"
  printf 'import sys\nopen(sys.argv[0] + ".called", "w").write(" ".join(sys.argv[1:]))\n' > "$SECRETS_MANAGER"
  export SECRETS_MANAGER
  HTTP_LOG="$BATS_TEST_TMPDIR/http.log"
  BODY_FILE="$BATS_TEST_TMPDIR/body.json"
  export HTTP_LOG BODY_FILE

  # shellcheck disable=SC2317
  mt-http() {
    local last="${*: -1}" arg prev=""
    echo "$*" >> "$HTTP_LOG"
    for arg in "$@"; do
      if [[ "$prev" == "-d" && "$arg" == @* ]]; then
        cat "${arg#@}" >> "$HTTP_LOG"
        echo >> "$HTTP_LOG"
        cp "${arg#@}" "$BODY_FILE"
      fi
      prev="$arg"
    done
    [ -n "${STUB_FAIL:-}" ] && return 4
    case "$last" in
      */merge)
        [ -n "${STUB_MERGE_EMPTY:-}" ] || echo '{"state":"MERGED","merge_commit":{"hash":"abcdef1234567"}}'
        return 0
        ;;
      */statuses*)
        local statuses='[{"key":"b1","state":"SUCCESSFUL","name":"Build"}]'
        jq -nc --argjson values "${STUB_STATUSES:-$statuses}" '{values: $values}'
        return 0
        ;;
      *pullrequests?state=MERGED*) echo '{"values":[]}' ;;
      *pullrequests?state=*) echo '{"values":[{"id":7,"title":"Fix \u001b[31mbug","author":{"display_name":"Al"},"source":{"branch":{"name":"fix"}},"destination":{"branch":{"name":"main"}},"updated_on":"2026-10-01T10:00:00+00:00"}]}' ;;
      */diff) printf 'diff --git a/f b/f\n+\033]0;pwned\007evil\r\n' ;;
      */diffstat*) echo '{"values":[{"status":"modified","lines_added":3,"lines_removed":1,"new":{"path":"src/a.py"}}]}' ;;
      */comments*page=2*) echo '{"values":[{"id":2,"deleted":false,"user":{"display_name":"Bo"},"content":{"raw":"second"},"created_on":"t2"}]}' ;;
      */comments*) echo '{"values":[{"id":1,"deleted":false,"user":{"display_name":"Al"},"inline":{"path":"src/a.py","to":7},"content":{"raw":"first"},"created_on":"t1"}],"next":"https://api.bitbucket.org/2.0/repositories/ws/r/pullrequests/9/comments?page=2"}' ;;
      *)
        if [[ "$*" == *"-X PUT"* ]]; then
          echo '{"id":9,"links":{"html":{"href":"https://bitbucket.org/ws/r/pull-requests/9"}}}'
          return 0
        fi
        echo '{"id":9,"title":"Add thing","state":"'"${STUB_PR_STATE:-OPEN}"'","reviewers":[{"uuid":"{u-1}","display_name":"Bo"},{"uuid":"{u-2}","display_name":"Cy"}],"author":{"display_name":"Al"},"source":{"branch":{"name":"feat"}},"destination":{"branch":{"name":"main"}},"created_on":"c","updated_on":"u","participants":[{"role":"REVIEWER","approved":true,"user":{"display_name":"Bo"}}],"links":{"html":{"href":"https://bitbucket.org/ws/r/pull-requests/9"}},"description":"Body text"}'
        ;;
    esac
  }
  # shellcheck disable=SC2317
  mt-help() { :; }
  git init -q "$BATS_TEST_TMPDIR/repo"
  cd "$BATS_TEST_TMPDIR/repo" || return 1
}

@test "repo is parsed from an SSH remote" {
  git remote add origin git@bitbucket.org:ws/r.git
  run __mt_bb_resolve_repo
  [ "$output" = "ws/r" ]
}

@test "repo is parsed from an HTTPS remote with a user" {
  git remote add origin https://me@bitbucket.org/ws/r.git
  run __mt_bb_resolve_repo
  [ "$output" = "ws/r" ]
}

@test "a non-Bitbucket remote is rejected" {
  git remote add origin git@github.com:ws/r.git
  run __mt_bb_resolve_repo
  [ "$status" -eq 1 ]
}

@test "missing credentials stop before any request" {
  unset BITBUCKET_API_KEY
  run bb-pr -r ws/r 9
  [ "$status" -eq 1 ]
  [[ "$output" == *mt-add-bitbucket-secret* ]]
  [ ! -f "$HTTP_LOG" ]
}

@test "summary prints title, branches, reviewers and body" {
  run bb-pr -r ws/r 9
  [ "$status" -eq 0 ]
  [[ "$output" == *"#9 Add thing"* ]]
  [[ "$output" == *"feat -> main"* ]]
  [[ "$output" == *"Bo (approved)"* ]]
  [[ "$output" == *"Body text"* ]]
}

@test "credentials are passed to mt-http as basic auth" {
  run bb-pr -r ws/r 9
  grep -q -- "-u me@example.test:key-123" "$HTTP_LOG"
}

@test "the secret is recorded as used after success" {
  run bb-pr -r ws/r 9
  [ -f "$SECRETS_MANAGER.called" ]
  [ "$(cat "$SECRETS_MANAGER.called")" = "touch BITBUCKET_API_KEY" ]
}

@test "--diff prints the raw diff" {
  run bb-pr -r ws/r --diff 9
  [[ "$output" == *"diff --git"* ]]
}

@test "--diffstat prints one line per file" {
  run bb-pr -r ws/r --diffstat 9
  [[ "$output" == *$'modified\t+3\t-1\tsrc/a.py'* ]]
}

@test "--comments follows pagination and shows file and line" {
  run bb-pr -r ws/r --comments 9
  [[ "$output" == *"Al @ src/a.py:7"* ]]
  [[ "$output" == *first* ]]
  [[ "$output" == *"Bo @ general"* ]]
  [[ "$output" == *second* ]]
}

@test "pagination never follows a link to another host" {
  # shellcheck disable=SC2317
  mt-http() { echo '{"values":[{"id":1}],"next":"https://evil.example/steal"}'; }
  run __mt_bb_collect "repositories/ws/r/pullrequests/9/comments"
  [ "$status" -eq 1 ]
  [[ "$output" == *"outside"* ]]
}

@test "hitting the page cap warns that results are truncated" {
  # shellcheck disable=SC2034
  BITBUCKET_MAX_PAGES=2
  # shellcheck disable=SC2317
  mt-http() { echo '{"values":[{"id":1}],"next":"https://api.bitbucket.org/2.0/more"}'; }
  run __mt_bb_collect "repositories/ws/r/pullrequests/9/comments"
  [[ "$output" == *"truncated after 2 pages"* ]]
}

@test "an API failure returns non-zero and does not record the secret" {
  STUB_FAIL=1 run bb-pr -r ws/r 9
  [ "$status" -eq 4 ]
  [ ! -f "$SECRETS_MANAGER.called" ]
}

@test "a non-numeric PR number is a usage error" {
  run bb-pr -r ws/r abc
  [ "$status" -eq 1 ]
}

@test "terminal control characters are stripped from diffs" {
  run bb-pr -r ws/r --diff 9
  [[ "$output" != *$'\033'* ]]
  [[ "$output" != *$'\r'* ]]
  [[ "$output" == *"evil"* ]]
}

@test "--list requests OPEN pull requests and prints one row each" {
  run bb-pr -r ws/r --list
  [ "$status" -eq 0 ]
  grep -q 'pullrequests?state=OPEN' "$HTTP_LOG"
  [ "$output" = "$(printf '#7\tFix [31mbug\tfix -> main\tAl\t2026-10-01')" ]
}

@test "--list --state is case-insensitive" {
  run bb-pr -r ws/r --list --state merged
  [ "$status" -eq 0 ]
  grep -q 'state=MERGED' "$HTTP_LOG"
}

@test "--list requests the pull request page length, never the default" {
  run bb-pr -r ws/r --list
  [ "$status" -eq 0 ]
  grep -q 'pullrequests?state=OPEN&pagelen=50' "$HTTP_LOG"
  ! grep -q 'pagelen=100' "$HTTP_LOG"
}

@test "--list --state merged also requests the pull request page length" {
  run bb-pr -r ws/r --list --state merged
  [ "$status" -eq 0 ]
  grep -q 'state=MERGED&pagelen=50' "$HTTP_LOG"
  ! grep -q 'pagelen=100' "$HTTP_LOG"
}

@test "other collections keep the default page length" {
  run bb-pr -r ws/r --comments 9
  [ "$status" -eq 0 ]
  grep -q 'comments?pagelen=100' "$HTTP_LOG"
}

@test "an explicit page length overrides the default" {
  run __mt_bb_collect "repositories/ws/r/pullrequests/9/comments" 25
  [ "$status" -eq 0 ]
  grep -q 'comments?pagelen=25' "$HTTP_LOG"
  ! grep -q 'pagelen=100' "$HTTP_LOG"
}

@test "a page larger than the argument size limit is still collected" {
  # shellcheck disable=SC2317
  mt-http() { jq -nc '{values: [range(3) | {id: ., title: ("x" * 100000)}]}'; }
  run __mt_bb_collect "repositories/ws/r/pullrequests" 50
  [ "$status" -eq 0 ]
  [ "$(jq 'length' <<< "$output")" -eq 3 ]
}

@test "--list prints every row of a page larger than the argument size limit" {
  # shellcheck disable=SC2317
  mt-http() {
    echo "$*" >> "$HTTP_LOG"
    jq -nc '{values: [range(3) | {id: ., title: "t\(.)", description: ("x" * 100000), author: {display_name: "Al"}, source: {branch: {name: "fix"}}, destination: {branch: {name: "main"}}, updated_on: "2026-10-01T10:00:00+00:00"}]}'
  }
  run bb-pr -r ws/r --list
  [ "$status" -eq 0 ]
  [ "$(wc -l <<< "$output")" -eq 3 ]
  [[ "$output" == *"#0"$'\t'"t0"* ]]
  [[ "$output" == *"#2"$'\t'"t2"* ]]
  grep -q 'pagelen=50' "$HTTP_LOG"
}

@test "a page that is not JSON fails instead of printing nothing" {
  # shellcheck disable=SC2317
  mt-http() { echo 'not json'; }
  run __mt_bb_collect "repositories/ws/r/pullrequests" 50
  [ "$status" -ne 0 ]
}

@test "--list with an empty result reports it and exits 0" {
  run bb-pr -r ws/r --list --state MERGED
  [ "$status" -eq 0 ]
  [[ "$output" == *"No MERGED pull requests in ws/r."* ]]
}

@test "--list rejects an invalid state without a request" {
  run bb-pr -r ws/r --list --state bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"OPEN MERGED DECLINED SUPERSEDED"* ]]
  [ ! -f "$HTTP_LOG" ]
}

@test "--list with a PR number is a usage error" {
  run bb-pr -r ws/r --list 9
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: bb-pr"* ]]
  [ ! -f "$HTTP_LOG" ]
}

@test "--list with --diff is a usage error" {
  run bb-pr -r ws/r --list --diff
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "--state without --list is a usage error" {
  run bb-pr -r ws/r --state OPEN 9
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "--list surfaces an API failure" {
  STUB_FAIL=1 run bb-pr -r ws/r --list
  [ "$status" -eq 4 ]
}

@test "--list rejects a space-joined state without a request" {
  run bb-pr -r ws/r --list --state "OPEN MERGED"
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "--state with no value is a usage error" {
  run bb-pr -r ws/r --list --state
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: bb-pr"* ]]
  [ ! -f "$HTTP_LOG" ]
}

@test "--set-title sends a PUT with the title and the existing reviewers, no description" {
  run bb-pr -r ws/r 9 --set-title "New title"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated PR #9 (title)"* ]]
  grep -q -- '-X PUT' "$HTTP_LOG"
  [ "$(jq -c '.reviewers' "$BODY_FILE")" = '[{"uuid":"{u-1}"},{"uuid":"{u-2}"}]' ]
  [ "$(jq -r '.title' "$BODY_FILE")" = "New title" ]
  [ "$(jq 'has("description")' "$BODY_FILE")" = "false" ]
}

@test "--set-description @file keeps the markdown byte for byte" {
  local desc="$BATS_TEST_TMPDIR/desc.md"
  printf 'Uses `code` and $(id)\n\nSecond paragraph\n' > "$desc"
  run bb-pr -r ws/r 9 --set-description "@$desc"
  [ "$status" -eq 0 ]
  jq -j '.description' "$BODY_FILE" > "$BATS_TEST_TMPDIR/out.md"
  cmp "$desc" "$BATS_TEST_TMPDIR/out.md"
  [ "$(jq 'has("title")' "$BODY_FILE")" = "false" ]
}

@test "--set-description - reads stdin" {
  run bb-pr -r ws/r 9 --set-description - <<< 'from `stdin`'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.description' "$BODY_FILE")" = 'from `stdin`' ]
}

@test "--set-description rejects an empty file, a missing file and literal text without a PUT" {
  : > "$BATS_TEST_TMPDIR/empty.md"
  run bb-pr -r ws/r 9 --set-description "@$BATS_TEST_TMPDIR/empty.md"
  [ "$status" -eq 1 ]
  run bb-pr -r ws/r 9 --set-description "@$BATS_TEST_TMPDIR/missing.md"
  [ "$status" -eq 1 ]
  run bb-pr -r ws/r 9 --set-description "literal text"
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "--set-title longer than the maximum is rejected, not truncated" {
  run bb-pr -r ws/r 9 --set-title "$(printf 'x%.0s' $(seq 1 251))"
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "editing a merged PR is refused without a PUT" {
  STUB_PR_STATE=MERGED run bb-pr -r ws/r 9 --set-title "New"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PR #9 is MERGED"* ]]
  ! grep -q -- '-X PUT' "$HTTP_LOG"
}

@test "--merge posts close_source_branch true and no strategy by default" {
  run bb-pr -r ws/r --merge 9 --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Merged PR #9 (abcdef1)"* ]]
  [ "$(jq -c '.' "$BODY_FILE")" = '{"close_source_branch":true}' ]
}

@test "--merge --strategy squash --keep-branch sends both" {
  run bb-pr -r ws/r --merge 9 --strategy squash --keep-branch --yes
  [ "$status" -eq 0 ]
  [ "$(jq -c '.' "$BODY_FILE")" = '{"close_source_branch":false,"merge_strategy":"squash"}' ]
}

@test "--merge without --yes and without a terminal makes no request" {
  run bb-pr -r ws/r --merge 9
  [ "$status" -eq 1 ]
  [[ "$output" == *"pass --yes"* ]]
  [ ! -f "$HTTP_LOG" ]
}

@test "--merge refuses a PR that is not open" {
  STUB_PR_STATE=DECLINED run bb-pr -r ws/r --merge 9 --yes
  [ "$status" -eq 1 ]
  ! grep -q 'merge$' "$HTTP_LOG"
}

@test "--merge refuses when a build status is not successful and lists the statuses" {
  STUB_STATUSES='[{"key":"b1","state":"FAILED","name":"Build"},{"key":"b2","state":"SUCCESSFUL","name":"Lint"}]' run bb-pr -r ws/r --merge 9 --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"b1"*"FAILED"*"Build"* ]]
  [[ "$output" == *"not all successful"* ]]
  ! grep -q 'merge$' "$HTTP_LOG"
}

@test "--merge refuses while a build is in progress" {
  STUB_STATUSES='[{"key":"b1","state":"INPROGRESS","name":"Build"}]' run bb-pr -r ws/r --merge 9 --yes
  [ "$status" -eq 1 ]
  ! grep -q 'merge$' "$HTTP_LOG"
}

@test "--merge with no build statuses warns and merges" {
  STUB_STATUSES='[]' run bb-pr -r ws/r --merge 9 --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"has no build statuses"* ]]
  [[ "$output" == *"Merged PR #9"* ]]
}

@test "--merge with an empty 2xx response reports it is still running" {
  STUB_MERGE_EMPTY=1 run bb-pr -r ws/r --merge 9 --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"still running"* ]]
}

@test "--merge surfaces an API failure" {
  STUB_FAIL=1 run bb-pr -r ws/r --merge 9 --yes
  [ "$status" -eq 4 ]
}

@test "mode-rule violations are usage errors that make no request" {
  local -a bad=(
    "--merge 9 --set-title x"
    "--merge 9 --set-description @f"
    "--merge 9 --list"
    "--merge 9 --diff"
    "--merge 9 --diffstat"
    "--merge 9 --comments"
    "9 --set-title x --diff"
    "9 --set-title x --comments"
    "--list --set-title x"
    "9 --strategy squash"
    "9 --keep-branch"
    "9 --yes"
    "--merge 9 --strategy bogus --yes"
    "--merge"
    "--merge 9 --strategy"
    "9 --set-title"
  )
  local args
  for args in "${bad[@]}"; do
    rm -f "$HTTP_LOG"
    # shellcheck disable=SC2086
    run bb-pr -r ws/r $args
    [ "$status" -eq 1 ]
    [ ! -f "$HTTP_LOG" ]
  done
}

@test "an unknown strategy prints the allowed list" {
  run bb-pr -r ws/r --merge 9 --strategy bogus --yes
  [[ "$output" == *"merge_commit squash fast_forward"* ]]
}

@test "a failed edit removes the stdin description copy" {
  local scratch="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$scratch"
  TMPDIR="$scratch" STUB_FAIL=1 run bb-pr -r ws/r 9 --set-description - <<< "secret desc"
  [ "$status" -eq 4 ]
  [ -z "$(ls -A "$scratch")" ]
}

@test "an edit on a non-Bitbucket remote removes the stdin description copy" {
  local scratch="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$scratch"
  git remote add origin git@github.com:ws/r.git
  TMPDIR="$scratch" run bb-pr 9 --set-description - <<< "secret desc"
  [ "$status" -eq 1 ]
  [ -z "$(ls -A "$scratch")" ]
}

# Serves --checks data from fixtures: statuses, the PR (with a source
# commit), its reports and the annotations of report {r2}.
stub_checks() {
  CHECKS_DIR="$BATS_TEST_DIRNAME/fixtures/bb_pr_checks"
  export CHECKS_DIR
  # shellcheck disable=SC2317
  mt-http() {
    local last="${*: -1}"
    echo "$*" >> "$HTTP_LOG"
    case "$last" in
      */statuses*) command cat "${STUB_STATUSES_FILE:-$CHECKS_DIR/statuses.json}" ;;
      */reports/%7Br2%7D/annotations*) command cat "${STUB_ANNOTATIONS_FILE:-$CHECKS_DIR/annotations_r2.json}" ;;
      */commit/abc123def456/reports*) command cat "${STUB_REPORTS_FILE:-$CHECKS_DIR/reports.json}" ;;
      */pullrequests/9) echo '{"id":9,"source":{"commit":{"hash":"abc123def456"}}}' ;;
      *) return 4 ;;
    esac
  }
}

@test "--checks prints statuses, reports and the failed report's annotations by severity" {
  stub_checks
  run bb-pr -r ws/r --checks 9
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = $'status\tSUCCESSFUL\tBuild\tAll good\thttps://ci.example.test/build/1' ]
  [[ "${lines[1]}" == $'status\tFAILED\tLint\t2 errors '* ]]
  [ "${lines[2]}" = $'report\tPASSED\tUnit tests\tTEST\thttps://reports.example.test/r1' ]
  [ "${lines[3]}" = $'report\tFAILED\tStatic analysis\tBUG\thttps://reports.example.test/r2?id=7' ]
  [[ "${lines[4]}" == $'  CRITICAL\tsrc/b.py:10\tbad '* ]]
  [ "${lines[5]}" = $'  MEDIUM\tsrc/c.py:5\tmeh' ]
  [ "${lines[6]}" = $'  LOW\tsrc/a.py:3\tminor' ]
  [ "${#lines[@]}" -eq 7 ]
}

@test "--checks requests annotations only for failed reports" {
  stub_checks
  run bb-pr -r ws/r --checks 9
  grep -q 'reports/%7Br2%7D/annotations' "$HTTP_LOG"
  run grep -q '%7Br1%7D' "$HTTP_LOG"
  [ "$status" -eq 1 ]
}

@test "--checks strips URL userinfo and terminal escapes" {
  stub_checks
  run bb-pr -r ws/r --checks 9
  [[ "$output" != *s3cret* ]]
  [[ "$output" != *"user:pw"* ]]
  [[ "$output" == *"https://ci.example.test/lint/1"* ]]
  [[ "$output" != *$'\033'* ]]
  [[ "$output" != *$'\007'* ]]
}

@test "--checks caps annotations per report and says how many were left out" {
  stub_checks
  STUB_ANNOTATIONS_FILE="$BATS_TEST_TMPDIR/annotations_60.json"
  export STUB_ANNOTATIONS_FILE
  jq -n '{values: [range(60) | {severity: "HIGH", path: "f.py", line: ., summary: "s\(.)"}]}' > "$STUB_ANNOTATIONS_FILE"
  run bb-pr -r ws/r --checks 9
  [ "$status" -eq 0 ]
  [ "$(grep -c $'^  HIGH\t' <<< "$output")" -eq 50 ]
  [[ "${lines[-1]}" == "  … +10 more" ]]
}

@test "--checks with no statuses and no reports says so and exits 0" {
  stub_checks
  STUB_STATUSES_FILE="$BATS_TEST_TMPDIR/empty.json" STUB_REPORTS_FILE="$BATS_TEST_TMPDIR/empty.json"
  export STUB_STATUSES_FILE STUB_REPORTS_FILE
  echo '{"values":[]}' > "$BATS_TEST_TMPDIR/empty.json"
  run --separate-stderr bb-pr -r ws/r --checks 9
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$stderr" = "ℹ️  No build statuses or Code Insights reports on PR #9." ]
}

@test "--checks returns 0 even when a status failed" {
  stub_checks
  run bb-pr -r ws/r --checks 9
  [ "$status" -eq 0 ]
  [[ "$output" == *$'status\tFAILED'* ]]
}

@test "--checks surfaces an API failure" {
  stub_checks
  # shellcheck disable=SC2317
  mt-http() { return 4; }
  run bb-pr -r ws/r --checks 9
  [ "$status" -eq 4 ]
}

@test "--checks with --diff or --list is a usage error without a request" {
  run bb-pr -r ws/r --checks --diff 9
  [ "$status" -eq 1 ]
  run bb-pr -r ws/r --list --checks
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "two read modes together are a usage error" {
  run bb-pr -r ws/r --diff --diffstat 9
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: bb-pr"* ]]
  [ ! -f "$HTTP_LOG" ]
}
