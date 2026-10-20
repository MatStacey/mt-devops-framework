#!/usr/bin/env bats
# ------------------------------------------
# Bats: Confluence helpers in .bash.d/25-atlassian/20-confluence.sh
# ------------------------------------------
# mt-http is replaced by a function that logs its arguments and serves
# fixtures chosen by URL, so no network or real credentials are used.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/25-atlassian/20-confluence.sh"
  export CONFLUENCE_EMAIL="me@example.test" CONFLUENCE_API_TOKEN="tok-123" CONFLUENCE_SITE="acme.atlassian.net"
  SECRETS_MANAGER="$BATS_TEST_TMPDIR/secrets_stub.py"
  printf 'import sys\nopen(sys.argv[0] + ".called", "w").write(" ".join(sys.argv[1:]))\n' > "$SECRETS_MANAGER"
  HTTP_LOG="$BATS_TEST_TMPDIR/http.log"
  export SECRETS_MANAGER HTTP_LOG

  # shellcheck disable=SC2317
  mt-http() {
    local last="${*: -1}"
    echo "$*" >> "$HTTP_LOG"
    [ -n "${STUB_FAIL:-}" ] && [[ "$last" != *tenant_info ]] && return 4
    case "$last" in
      *tenant_info) echo '{"cloudId":"cloud-abc"}' ;;
      */pages/*) printf '{"title":"Networking","body":{"storage":{"value":"<h2>Overview</h2><p>Redis &amp; VPC\\u001b[31m</p><ul><li>one</li><li>two</li></ul>"}}}' ;;
      */direct-children*cursor=2*) echo '{"results":[{"type":"page","id":"3","title":"Third"}]}' ;;
      */direct-children*) echo '{"results":[{"type":"page","id":"1","title":"First"},{"type":"folder","id":"2","title":"Sub"}],"_links":{"next":"/wiki/api/v2/folders/99/direct-children?cursor=2"}}' ;;
      */search) echo '{"results":[{"content":{"type":"page","id":"7"},"title":"Hit","resultGlobalContainer":{"title":"Docs"}}]}' ;;
    esac
  }
  # shellcheck disable=SC2317
  mt-help() { :; }
}

@test "page ID is taken from a Confluence URL" {
  run __mt_conf_extract_id "https://acme.atlassian.net/wiki/spaces/ENG/pages/12345/Networking"
  [ "$output" = "12345" ]
}

@test "garbage is rejected as an ID" {
  run __mt_conf_extract_id "not-an-id"
  [ "$status" -eq 1 ]
}

@test "missing credentials stop before any request" {
  unset CONFLUENCE_API_TOKEN
  run conf-get 1
  [ "$status" -eq 1 ]
  [[ "$output" == *CONFLUENCE_API_TOKEN* ]]
  [ ! -f "$HTTP_LOG" ]
}

@test "missing CONFLUENCE_SITE is reported" {
  unset CONFLUENCE_SITE
  run conf-get 1
  [ "$status" -eq 1 ]
  [[ "$output" == *CONFLUENCE_SITE* ]]
}

@test "conf-get prints the title and converted text" {
  run conf-get 12345
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Networking"* ]]
  [[ "$output" == *"## Overview"* ]]
  [[ "$output" == *"Redis & VPC"* ]]
  [[ "$output" == *"- one"* ]]
}

@test "requests go through the gateway with basic auth" {
  run conf-get 12345
  grep -q "https://api.atlassian.com/ex/confluence/cloud-abc/wiki/api/v2/pages/12345" "$HTTP_LOG"
  grep -q -- "-u me@example.test:tok-123" "$HTTP_LOG"
}

@test "terminal control characters are stripped from page text" {
  run conf-get 12345
  [[ "$output" != *$'\033'* ]]
}

@test "--storage prints the raw body" {
  run conf-get --storage 12345
  [[ "$output" == *"<h2>Overview</h2>"* ]]
}

@test "the secret is recorded as used after success" {
  run conf-get 12345
  [ "$(cat "$SECRETS_MANAGER.called")" = "touch CONFLUENCE_API_TOKEN" ]
}

@test "the cloud ID is looked up once, not on every request" {
  conf-get 12345 > /dev/null
  conf-get 12345 > /dev/null
  conf-get 12345 > /dev/null
  [ "$(grep -c tenant_info "$HTTP_LOG")" -eq 1 ]
}

@test "conf-folder follows pagination" {
  run conf-folder 99
  [[ "$output" == *$'page\t1\tFirst'* ]]
  [[ "$output" == *$'folder\t2\tSub'* ]]
  [[ "$output" == *$'page\t3\tThird'* ]]
}

@test "conf-search wraps text in a CQL text query within a space" {
  run conf-search -s ENG 'redis "cache"'
  grep -qF 'cql=space = "ENG" AND text ~ "redis \"cache\""' "$HTTP_LOG"
  [[ "$output" == *$'page\t7\tHit\tDocs'* ]]
}

@test "conf-search --cql passes the query through unchanged" {
  run conf-search --cql 'type = page AND label = "x"'
  grep -qF 'cql=type = page AND label = "x"' "$HTTP_LOG"
}

@test "an API failure returns non-zero and does not record the secret" {
  STUB_FAIL=1 run conf-get 12345
  [ "$status" -eq 4 ]
  [ ! -f "$SECRETS_MANAGER.called" ]
}
