#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-firestore in .bash.d/10-infra/35-gcp-firestore.sh
# ------------------------------------------
# mt-http is replaced by a function that logs its arguments and any -d @file
# body, and serves Firestore fixtures by URL; STUB_REST_DENY makes it fail
# with a permission error.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "auth list") echo "me@example.test" ;;
  "auth print-access-token") echo tok ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/35-gcp-firestore.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  mt-help() { echo "help called"; }
  gcl-get-project() { echo "proj-a"; }
  gcl-get-user() { echo "me@example.test"; }
  gcl-auth-check() { return 0; }

  HTTP_LOG="$BATS_TEST_TMPDIR/http.log"
  export HTTP_LOG
  # shellcheck disable=SC2317
  mt-http() {
    local arg prev=""
    echo "$*" >> "$HTTP_LOG"
    for arg in "$@"; do
      [[ "$prev" == "-d" && "$arg" == @* ]] && cat "${arg#@}" >> "$HTTP_LOG" && echo >> "$HTTP_LOG"
      prev="$arg"
    done
    if [ -n "${STUB_REST_DENY:-}" ]; then
      echo "HTTP 403: Missing or insufficient permissions: Permission datastore.entities.get denied" >&2
      return 4
    fi
    case "${*: -1}" in
      *:runAggregationQuery) echo '[{"result":{"aggregateFields":{"count":{"integerValue":"42"}}}}]' ;;
      *:runQuery) echo '[{"document":{"name":"projects/p/databases/(default)/documents/devices/d1","fields":{"n":{"integerValue":"5"}}}},{"readTime":"t"},{"document":{"name":"projects/p/databases/(default)/documents/devices/d2","fields":{"n":{"integerValue":"0"}}}}]' ;;
      *documents/users/abc)
        echo '{"name":"projects/p/databases/(default)/documents/users/abc","fields":{"name":{"stringValue":"Al"},"age":{"integerValue":"30"},"score":{"doubleValue":1.5},"ok":{"booleanValue":false},"gone":{"nullValue":null},"at":{"timestampValue":"2026-10-05T00:00:00Z"},"ref":{"referenceValue":"projects/p/databases/(default)/documents/x/y"},"geo":{"geoPointValue":{"latitude":1,"longitude":2}},"tags":{"arrayValue":{"values":[{"stringValue":"a"},{"integerValue":"2"}]}},"addr":{"mapValue":{"fields":{"city":{"stringValue":"X"},"zip":{"mapValue":{"fields":{"n":{"integerValue":"7"}}}}}}}}}'
        ;;
    esac
  }
}

docs="projects/proj-a/databases/(default)/documents"

@test "builder: integer where" {
  run __mt_gcl_firestore_query "$docs" devices "" "" "" 'n>=5'
  [ "$output" = '{"from":[{"collectionId":"devices"}],"where":{"fieldFilter":{"field":{"fieldPath":"n"},"op":"GREATER_THAN_OR_EQUAL","value":{"integerValue":"5"}}}}' ]
}

@test "builder: boolean, null and string values" {
  [ "$(__mt_gcl_firestore_query "$docs" c "" "" "" 'a==true' | jq -c '.where.fieldFilter.value')" = '{"booleanValue":true}' ]
  [ "$(__mt_gcl_firestore_query "$docs" c "" "" "" 'a==null' | jq -c '.where.fieldFilter.value')" = '{"nullValue":null}' ]
  [ "$(__mt_gcl_firestore_query "$docs" c "" "" "" 'a!=x y' | jq -c '.where.fieldFilter | [.op, .value]')" = '["NOT_EQUAL",{"stringValue":"x y"}]' ]
}

@test "builder: __name__ becomes a reference value under the collection" {
  run __mt_gcl_firestore_query "$docs" devices "" "" "" '__name__>=abc'
  [ "$(jq -c '.where.fieldFilter.value' <<< "$output")" = '{"referenceValue":"projects/proj-a/databases/(default)/documents/devices/abc"}' ]
}

@test "builder: several wheres combine into an AND composite with order, limit and descendants" {
  run __mt_gcl_firestore_query "$docs" devices "n:desc" 10 1 'n>1' 'n<9'
  [ "$(jq -c '.where.compositeFilter | [.op, (.filters | length)]' <<< "$output")" = '["AND",2]' ]
  [ "$(jq -c '.orderBy' <<< "$output")" = '[{"field":{"fieldPath":"n"},"direction":"DESCENDING"}]' ]
  [ "$(jq -c '.limit, .from[0].allDescendants' <<< "$output" | paste -sd' ')" = "10 true" ]
}

@test "get unwraps nested map, array, timestamp, reference, geopoint, double and null values" {
  run gcl-firestore get users/abc -p proj-a
  [ "$status" -eq 0 ]
  [ "$(jq -c '.' <<< "$output")" = '{"_id":"abc","name":"Al","age":30,"score":1.5,"ok":false,"gone":null,"at":"2026-10-05T00:00:00Z","ref":"projects/p/databases/(default)/documents/x/y","geo":{"latitude":1,"longitude":2},"tags":["a",2],"addr":{"city":"X","zip":{"n":7}}}' ]
}

@test "get sends one mask parameter per field to the documents URL" {
  run gcl-firestore get users/abc --fields name,addr.city -p proj-a
  [ "$status" -eq 0 ]
  local call
  call="$(head -1 "$HTTP_LOG")"
  [[ "$call" == *"-X GET"* ]]
  [[ "$call" == *"-q mask.fieldPaths=name -q mask.fieldPaths=addr.city"* ]]
  [[ "$call" == *"https://firestore.googleapis.com/v1/projects/proj-a/databases/(default)/documents/users/abc" ]]
}

@test "query posts the structured query, applies the default limit and prints one object per document" {
  run gcl-firestore query --collection devices --where 'n>=0' --order-by n -p proj-a
  [ "$status" -eq 0 ]
  [ "$(wc -l <<< "$output")" -eq 2 ]
  [ "$(sed -n 1p <<< "$output")" = '{"_id":"d1","n":5}' ]
  grep -q -- '-X POST' "$HTTP_LOG"
  grep -q 'documents:runQuery$' "$HTTP_LOG"
  grep -qF '"limit":100' "$HTTP_LOG"
}

@test "query under a parent document and with a raw --json query" {
  run gcl-firestore query --json '{"from":[{"collectionId":"orders"}]}' --parent users/abc -p proj-a -d other-db
  [ "$status" -eq 0 ]
  grep -q 'databases/other-db/documents/users/abc:runQuery$' "$HTTP_LOG"
  grep -qF '{"structuredQuery":{"from":[{"collectionId":"orders"}]}}' "$HTTP_LOG"
}

@test "count prints a bare integer and sends an aggregation with no default limit" {
  run gcl-firestore count --collection devices --where '__name__>=a' --where '__name__<b' -p proj-a
  [ "$status" -eq 0 ]
  [ "$output" = "42" ]
  grep -q 'documents:runAggregationQuery$' "$HTTP_LOG"
  grep -qF '"aggregations":[{"alias":"count","count":{}}]' "$HTTP_LOG"
  ! grep -qF '"limit"' "$HTTP_LOG"
}

@test "a denied read exits 5 and names the permission" {
  STUB_REST_DENY=1 run gcl-firestore get users/abc -p proj-a
  [ "$status" -eq 5 ]
  [[ "$output" == *datastore.entities.get* ]]
}

@test "bad usage exits 1 without any request" {
  run gcl-firestore
  [ "$status" -eq 1 ]
  run gcl-firestore get
  [ "$status" -eq 1 ]
  run gcl-firestore get '../x'
  [ "$status" -eq 1 ]
  run gcl-firestore query
  [ "$status" -eq 1 ]
  run gcl-firestore query --collection c --json '{}'
  [ "$status" -eq 1 ]
  run gcl-firestore query --collection c --where 'nonsense'
  [ "$status" -eq 1 ]
  run gcl-firestore query --collection c --limit 0
  [ "$status" -eq 1 ]
  run gcl-firestore query --json 'not json'
  [ "$status" -eq 1 ]
  run gcl-firestore get users/abc -d 'bad db'
  [ "$status" -eq 1 ]
  [ ! -s "$HTTP_LOG" ]
}

@test "-h shows help" {
  run gcl-firestore -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}
