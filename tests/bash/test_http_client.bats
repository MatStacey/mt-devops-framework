#!/usr/bin/env bats
# ------------------------------------------
# Bats: mt-http in .bash.d/02-utilities/39-http-client.sh
# ------------------------------------------
# curl is replaced with a stub on PATH that records argv and stdin, then
# emits the body/status/exit code requested through STUB_* variables.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  stub_dir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/curl" << 'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STUB_ARGV"
cat > "$STUB_STDIN"
out=""
while [ "$#" -gt 0 ]; do
  [ "$1" = "--output" ] && out="$2"
  shift
done
printf '%s' "${STUB_BODY:-}" > "$out"
printf '%s' "${STUB_ERR:-}" >&2
printf '%s' "${STUB_STATUS:-200}"
exit "${STUB_EXIT:-0}"
STUB
  chmod +x "$stub_dir/curl"
  PATH="$stub_dir:$PATH"
  export STUB_ARGV="$BATS_TEST_TMPDIR/argv" STUB_STDIN="$BATS_TEST_TMPDIR/stdin"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  mt-help() { :; }
}

@test "defaults to GET and prints the body" {
  STUB_BODY='plain text' run mt-http https://example.test/x
  [ "$status" -eq 0 ]
  [ "$output" = "plain text" ]
  grep -qx "GET" "$STUB_ARGV"
}

@test "a body switches the method to POST" {
  run mt-http -d '{"a":1}' https://example.test/x
  [ "$status" -eq 0 ]
  grep -qx "POST" "$STUB_ARGV"
  grep -qx '{"a":1}' "$STUB_ARGV"
}

@test "queries are URL-encoded by curl and sent as GET" {
  run mt-http -q 'q=a b' https://example.test/x
  grep -qx -- "--get" "$STUB_ARGV"
  grep -qx -- "q=a b" "$STUB_ARGV"
}

@test "basic auth goes to curl via stdin, never argv" {
  run mt-http -u 'me:hunter2' https://example.test/x
  grep -q 'user = "me:hunter2"' "$STUB_STDIN"
  run grep -q "hunter2" "$STUB_ARGV"
  [ "$status" -eq 1 ]
}

@test "bearer auth goes to curl via stdin, never argv" {
  run mt-http -b 'tok-123' https://example.test/x
  grep -q 'Authorization: Bearer tok-123' "$STUB_STDIN"
  run grep -q "tok-123" "$STUB_ARGV"
  [ "$status" -eq 1 ]
}

@test "a credential echoed in the response body is masked" {
  STUB_BODY='your token is tok-123' run mt-http -b 'tok-123' https://example.test/x
  [[ "$output" != *tok-123* ]]
  [[ "$output" == *"***"* ]]
}

@test "HTTP 4xx returns 4 and reports the status" {
  STUB_STATUS=403 STUB_BODY='denied' run mt-http https://example.test/x
  [ "$status" -eq 4 ]
  [[ "$output" == *"HTTP 403"* ]]
  [[ "$output" == *denied* ]]
}

@test "transport failure returns 3 and masks credentials in the error" {
  STUB_EXIT=6 STUB_ERR='could not resolve host tok-123' run mt-http -b 'tok-123' https://example.test/x
  [ "$status" -eq 3 ]
  [[ "$output" == *"curl exit 6"* ]]
  [[ "$output" != *tok-123* ]]
}

@test "verbose output masks URL userinfo and credentials" {
  run mt-http -v -u 'me:hunter2' https://me:hunter2@example.test/x
  [[ "$output" != *hunter2* ]]
}

@test "Atlassian 401 with basic auth suggests the gateway" {
  STUB_STATUS=401 run mt-http -u 'a@b.c:tok' https://x.atlassian.net/wiki/rest/api/content
  [[ "$output" == *api.atlassian.com* ]]
}

@test "JSON responses are pretty-printed unless --raw" {
  command -v jq > /dev/null || skip "jq not installed"
  STUB_BODY='{"a":1}' run mt-http https://example.test/x
  [[ "$output" == *'"a": 1'* ]]
  STUB_BODY='{"a":1}' run mt-http --raw https://example.test/x
  [ "$output" = '{"a":1}' ]
}

@test "usage errors return 2" {
  run mt-http
  [ "$status" -eq 2 ]
  run mt-http -u a:b -b t https://example.test/x
  [ "$status" -eq 2 ]
  run mt-http -d x -q a=b https://example.test/x
  [ "$status" -eq 2 ]
}
