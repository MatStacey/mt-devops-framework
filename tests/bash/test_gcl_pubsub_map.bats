#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-pubsub-map in .bash.d/10-infra/32-gcp-survey.sh
# ------------------------------------------
# gcloud is replaced by a stub serving per-project subscriptions and topics;
# STUB_DENY_PROJECT makes one project fail with a permission error.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "auth list") echo "me@example.test"; exit 0 ;;
  "auth print-access-token") echo tok; exit 0 ;;
esac
project=""
for arg in "$@"; do
  case "$arg" in --project=*) project="${arg#--project=}" ;; esac
done
if [ "$project" = "${STUB_DENY_PROJECT:-}" ]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'pubsub.subscriptions.list' denied" >&2
  exit 1
fi
case "$2 $project" in
  "subscriptions proj-a")
    echo '[{"name":"projects/proj-a/subscriptions/sub-y","topic":"projects/proj-a/topics/t1","bigqueryConfig":{"table":"p.d.t"}}]' ;;
  "subscriptions proj-b")
    echo '[{"name":"projects/proj-b/subscriptions/sub-x","topic":"projects/proj-a/topics/t1","pushConfig":{"pushEndpoint":"https://user:pw@host.example.test/path?token=SECRET"},"filter":"attributes.type=\"x\"","deadLetterPolicy":{"deadLetterTopic":"projects/proj-a/topics/dlq"},"state":"RESOURCE_ERROR"},{"name":"projects/proj-b/subscriptions/sub-z","topic":"projects/proj-b/topics/t2","cloudStorageConfig":{"bucket":"bkt"}},{"name":"projects/proj-b/subscriptions/sub-p","topic":"projects/proj-b/topics/t2"}]' ;;
  "topics proj-a")
    echo '[{"name":"projects/proj-a/topics/t1"},{"name":"projects/proj-a/topics/dlq"},{"name":"projects/proj-a/topics/empty"}]' ;;
  "topics proj-b")
    echo '[{"name":"projects/proj-b/topics/t2"}]' ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/32-gcp-survey.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  mt-help() { echo "help called"; }
  gcl-get-project() { echo "proj-a"; }
  gcl-get-user() { echo "me@example.test"; }
  gcl-auth-check() { return 0; }
}

@test "a subscription in another project appears under the topic it consumes" {
  run gcl-pubsub-map -p proj-a -p proj-b
  [ "$status" -eq 0 ]
  [[ "$output" == *"projects/proj-a/topics/t1"$'\n'"  ├─ sub-x  (projects/proj-b)  push → https://host.example.test/path"* ]]
  [[ "$output" == *"  └─ sub-y  (projects/proj-a)  bigquery → p.d.t"* ]]
}

@test "filter, dead-letter topic and a non-active state are shown" {
  run gcl-pubsub-map -p proj-a -p proj-b
  [[ "$output" == *'filter: attributes.type="x"   dlq: projects/proj-a/topics/dlq   state: RESOURCE_ERROR'* ]]
}

@test "the push URL loses its query string and userinfo" {
  run gcl-pubsub-map -p proj-a -p proj-b
  [[ "$output" != *SECRET* && "$output" != *"pw@"* && "$output" != *"token="* ]]
}

@test "a topic with no subscriptions is listed, and gcs and pull delivery are labelled" {
  run gcl-pubsub-map -p proj-a -p proj-b
  [[ "$output" == *"projects/proj-a/topics/empty"* ]]
  [[ "$output" == *"sub-p  (projects/proj-b)  pull"* ]]
  [[ "$output" == *"sub-z  (projects/proj-b)  gcs → bkt"* ]]
}

@test "-t filters by topic path" {
  run gcl-pubsub-map -p proj-a -p proj-b -t t2
  [ "$status" -eq 0 ]
  [[ "$output" == *"projects/proj-b/topics/t2"* ]]
  [[ "$output" != *"t1"* ]]
}

@test "--json prints the grouped structure" {
  run gcl-pubsub-map -p proj-a -p proj-b --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[] | select(.topic == "projects/proj-a/topics/t1") | .subscriptions | map(.name) | join(",")' <<< "$output")" = "sub-x,sub-y" ]
}

@test "a denied project is reported, the others still render, and the exit is 5" {
  STUB_DENY_PROJECT=proj-b run gcl-pubsub-map -p proj-a -p proj-b
  [ "$status" -eq 5 ]
  [[ "$output" == *"pubsub.subscriptions.list"* ]]
  [[ "$output" == *"sub-y  (projects/proj-a)"* ]]
}

@test "bad usage exits 1" {
  run gcl-pubsub-map --bogus
  [ "$status" -eq 1 ]
  run gcl-pubsub-map -p 'bad;proj'
  [ "$status" -eq 1 ]
}

@test "-h shows help" {
  run gcl-pubsub-map -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}
