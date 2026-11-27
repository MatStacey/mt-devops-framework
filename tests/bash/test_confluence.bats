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
  PUT_REQUEST="$BATS_TEST_TMPDIR/put_request.json"
  BODY_FILE="$BATS_TEST_TMPDIR/body.xhtml"
  printf '<p>marker-body-7f3a</p>' > "$BODY_FILE"
  export SECRETS_MANAGER HTTP_LOG PUT_REQUEST BODY_FILE

  # shellcheck disable=SC2317
  mt-http() {
    local last="${*: -1}"
    echo "$*" >> "$HTTP_LOG"
    [ -n "${STUB_FAIL:-}" ] && [[ "$last" != *tenant_info ]] && return 4
    case "$last" in
      *tenant_info) echo '{"cloudId":"cloud-abc"}' ;;
      */pages/*)
        if [[ "$*" == *"-X PUT"* ]]; then
          local arg prev=""
          for arg in "$@"; do
            [ "$prev" = "-d" ] && cp "${arg#@}" "$PUT_REQUEST"
            prev="$arg"
          done
          if [ -n "${STUB_PUT_STATUS:-}" ]; then
            echo "🚨 HTTP ${STUB_PUT_STATUS}" >&2
            return 4
          fi
          echo '{"version":{"number":5},"_links":{"base":"https://acme.atlassian.net/wiki","webui":"/spaces/ENG/pages/12345/Networking"}}'
        elif [[ "$*" == *body-format=view* ]]; then
          printf '{"body":{"view":{"value":"<p>ok</p>%s"}}}' "${STUB_VIEW_EXTRA:-}"
        else
          printf '{"title":"Networking","status":"%s","version":{"number":4,"createdAt":"2026-11-01T09:00:00Z","authorId":"acct-1"},"body":{"storage":{"value":"<h2>Overview</h2><p>Redis &amp; VPC\\u001b[31m</p><ul><li>one</li><li>two</li></ul>"}}}' "${STUB_PAGE_STATUS:-current}"
        fi
        ;;
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
  [[ "$output" == *"# Networking (version 4)"* ]]
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

# Runs a command in a fresh bash with the real module, __mt_has_tty and this
# file's mt-http stub, for cases that need no terminal or a terminal stdin.
write_driver() {
  declare -f mt-http > "$BATS_TEST_TMPDIR/stub.bash"
  DRIVER="$BATS_TEST_TMPDIR/driver.bash"
  {
    echo "source '$repo_root/.bash.d/02-utilities/39-http-client.sh'"
    echo "source '$repo_root/.bash.d/02-utilities/99-utils.sh'"
    echo "source '$repo_root/.bash.d/25-atlassian/20-confluence.sh'"
    echo "source '$BATS_TEST_TMPDIR/stub.bash'"
    echo 'eval "$1"'
  } > "$DRIVER"
}

put_requests() {
  grep -c -- "-X PUT" "$HTTP_LOG" 2> /dev/null || true
}

@test "conf-put --yes sends version n+1 with the message, title and file body" {
  run conf-put 12345 "@$BODY_FILE" -m "Sync from repo" --yes
  [ "$status" -eq 0 ]
  [ "$(jq -r '.version.number' "$PUT_REQUEST")" = "5" ]
  [ "$(jq -r '.version.message' "$PUT_REQUEST")" = "Sync from repo" ]
  [ "$(jq -r '.title' "$PUT_REQUEST")" = "Networking" ]
  [ "$(jq -r '.status' "$PUT_REQUEST")" = "current" ]
  [ "$(jq -r '.body.representation' "$PUT_REQUEST")" = "storage" ]
  [ "$(jq -r '.body.value' "$PUT_REQUEST")" = "<p>marker-body-7f3a</p>" ]
  [[ "$output" == *$'https://acme.atlassian.net/wiki/spaces/ENG/pages/12345/Networking\t5'* ]]
  [[ "$output" == *'Update "Networking" v4 → v5'* ]]
}

@test "conf-put never puts the page body on a command line" {
  run conf-put 12345 "@$BODY_FILE" --yes
  [ "$status" -eq 0 ]
  [ "$(grep -c "marker-body-7f3a" "$HTTP_LOG")" -eq 0 ]
  grep -q -- "-X PUT -H Content-Type: application/json -d @" "$HTTP_LOG"
}

@test "conf-put uses the default version message" {
  run conf-put 12345 "@$BODY_FILE" --yes
  [ "$(jq -r '.version.message' "$PUT_REQUEST")" = "Updated with conf-put" ]
}

@test "conf-put --title changes the title" {
  run conf-put 12345 "@$BODY_FILE" --title "New" --yes
  [ "$status" -eq 0 ]
  [ "$(jq -r '.title' "$PUT_REQUEST")" = "New" ]
}

@test "conf-put reads the body from piped stdin" {
  write_driver
  run bash "$DRIVER" 'echo "<p>piped</p>" | conf-put 12345 - --yes'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.body.value' "$PUT_REQUEST")" = "<p>piped</p>" ]
}

@test "conf-put --expect-version that no longer matches exits 6 without a PUT" {
  run conf-put 12345 "@$BODY_FILE" --expect-version 3 --yes
  [ "$status" -eq 6 ]
  [[ "$output" == *"version 4"* ]]
  [[ "$output" == *"2026-11-01T09:00:00Z"* ]]
  [[ "$output" == *"acct-1"* ]]
  [ "$(put_requests)" -eq 0 ]
}

@test "conf-put --expect-version that matches goes ahead" {
  run conf-put 12345 "@$BODY_FILE" --expect-version 4 --yes
  [ "$status" -eq 0 ]
  [ "$(put_requests)" -eq 1 ]
}

@test "conf-put maps a 409 on the PUT to exit 6" {
  STUB_PUT_STATUS=409 run conf-put 12345 "@$BODY_FILE" --yes
  [ "$status" -eq 6 ]
  [[ "$output" == *"Someone else saved the page first"* ]]
}

@test "conf-put adds the scope hint to a 403" {
  STUB_PUT_STATUS=403 run conf-put 12345 "@$BODY_FILE" --yes
  [ "$status" -eq 4 ]
  [[ "$output" == *"write:page:confluence"* ]]
}

@test "conf-put rejects bad input before any request" {
  printf '' > "$BATS_TEST_TMPDIR/empty.xhtml"
  local args
  for args in "12345 @$BATS_TEST_TMPDIR/missing.xhtml" "12345 @$BATS_TEST_TMPDIR/empty.xhtml" \
    "12345 <p>literal</p>" "12345 @$BODY_FILE --expect-version abc" "12345 @$BODY_FILE --expect-version 0" \
    "12345" "12345 @$BODY_FILE extra" "12345 @$BODY_FILE --bogus"; do
    # shellcheck disable=SC2086
    run conf-put $args --yes
    [ "$status" -eq 1 ] || {
      echo "args: $args -> $status"
      return 1
    }
  done
  run conf-put 12345 "@$BODY_FILE" --yes -m
  [ "$status" -eq 1 ]
  [ ! -f "$HTTP_LOG" ]
}

@test "conf-put names the accepted body forms when given literal text" {
  run conf-put 12345 "<p>literal</p>" --yes
  [[ "$output" == *"@<file> or - (stdin)"* ]]
}

@test "conf-put refuses - when stdin is a terminal" {
  write_driver
  run script -qec "bash '$DRIVER' 'conf-put 12345 - --yes; echo rc=\$?'" /dev/null
  [[ "$output" == *"Pipe the page body in"* ]]
  [[ "$output" == *"rc=1"* ]]
  [ ! -f "$HTTP_LOG" ]
}

@test "conf-put without a terminal and without --yes exits 1 with no PUT" {
  write_driver
  run setsid -w bash "$DRIVER" "conf-put 12345 @$BODY_FILE" < /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"pass --yes"* ]]
  [ "$(put_requests)" -eq 0 ]
}

@test "conf-put refuses a page that is not current" {
  STUB_PAGE_STATUS=draft run conf-put 12345 "@$BODY_FILE" --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"draft"* ]]
  [ "$(put_requests)" -eq 0 ]
}

@test "conf-put exits 7 when the updated page renders with macro errors" {
  STUB_VIEW_EXTRA='<img class=\"wysiwyg-unknown-macro\" src=\"x\" />' run conf-put 12345 "@$BODY_FILE" --yes
  [ "$status" -eq 7 ]
  [[ "$output" == *"renders with macro errors"* ]]
  [ "$(put_requests)" -eq 1 ]
}

@test "conf-put maps a 409 from the real mt-http to exit 6" {
  unset -f mt-http
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/curl" << 'STUB'
#!/usr/bin/env bash
cat > /dev/null
out="" status=200 body='{"title":"T","status":"current","version":{"number":4},"body":{"storage":{"value":"<p>a</p>"}}}'
for arg in "$@"; do
  [ "$prev" = "--output" ] && out="$arg"
  [ "$arg" = "PUT" ] && status=409 body='{"errors":[{"status":409,"code":"CONFLICT"}]}'
  prev="$arg"
done
printf '%s' "$body" > "$out"
printf '%s' "$status"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  __MT_CONFLUENCE_GATEWAY_URL="https://gateway.example.test"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run conf-put 12345 "@$BODY_FILE" --yes
  [ "$status" -eq 6 ]
  [[ "$output" == *"Someone else saved the page first"* ]]
}
