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
  export HTTP_LOG

  # shellcheck disable=SC2317
  mt-http() {
    local last="${*: -1}"
    echo "$*" >> "$HTTP_LOG"
    [ -n "${STUB_FAIL:-}" ] && return 4
    case "$last" in
      */diff) printf 'diff --git a/f b/f\n+\033]0;pwned\007evil\r\n' ;;
      */diffstat*) echo '{"values":[{"status":"modified","lines_added":3,"lines_removed":1,"new":{"path":"src/a.py"}}]}' ;;
      */comments*page=2*) echo '{"values":[{"id":2,"deleted":false,"user":{"display_name":"Bo"},"content":{"raw":"second"},"created_on":"t2"}]}' ;;
      */comments*) echo '{"values":[{"id":1,"deleted":false,"user":{"display_name":"Al"},"inline":{"path":"src/a.py","to":7},"content":{"raw":"first"},"created_on":"t1"}],"next":"https://api.bitbucket.org/2.0/repositories/ws/r/pullrequests/9/comments?page=2"}' ;;
      *) echo '{"id":9,"title":"Add thing","state":"OPEN","author":{"display_name":"Al"},"source":{"branch":{"name":"feat"}},"destination":{"branch":{"name":"main"}},"created_on":"c","updated_on":"u","participants":[{"role":"REVIEWER","approved":true,"user":{"display_name":"Bo"}}],"links":{"html":{"href":"https://bitbucket.org/ws/r/pull-requests/9"}},"description":"Body text"}' ;;
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
