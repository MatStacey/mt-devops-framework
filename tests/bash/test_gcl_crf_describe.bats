#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-crf-describe in .bash.d/10-infra/32-gcp-survey.sh
# ------------------------------------------
# gcloud is replaced by a stub serving one function JSON per project;
# STUB_ABSENT_PROJECT answers "not found" and STUB_DENY_PROJECT a permission error.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  CALLS="$BATS_TEST_TMPDIR/calls"
  export CALLS
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
echo "gcloud $*" >> "$CALLS"
case "$1 $2" in
  "auth list") echo "me@example.test"; exit 0 ;;
  "auth print-access-token") echo tok; exit 0 ;;
esac
project=""
for arg in "$@"; do
  case "$arg" in --project=*) project="${arg#--project=}" ;; esac
done
if [ "$project" = "${STUB_ABSENT_PROJECT:-}" ]; then
  echo "ERROR: (gcloud.functions.describe) NOT_FOUND: Function does not exist" >&2
  exit 1
fi
if [ "$project" = "${STUB_DENY_PROJECT:-}" ]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'cloudfunctions.functions.get' denied" >&2
  exit 1
fi
case "$project" in
  dev)
    echo '{"state":"ACTIVE","updateTime":"2026-10-01T00:00:00Z","labels":{"deployment-tool":"terraform","commit-sha":"abc1234"},"buildConfig":{"runtime":"python312","entryPoint":"handler","source":{"storageSource":{"bucket":"src","object":"fn.zip","generation":"77"}}},"serviceConfig":{"revision":"fn-00001","serviceAccountEmail":"sa-dev@x"},"eventTrigger":{"eventType":"google.cloud.pubsub.topic.v1.messagePublished","pubsubTopic":"projects/p/topics/t"}}' ;;
  *)
    echo '{"state":"ACTIVE","updateTime":"2026-10-02T00:00:00Z","buildConfig":{"runtime":"python312","entryPoint":"handler","source":{"repoSource":{"repoName":"repo","branchName":"main"}}},"serviceConfig":{"revision":"fn-00002","serviceAccountEmail":"sa-prod@x"}}' ;;
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
  gcl-get-project() { echo "dev"; }
  gcl-get-user() { echo "me@example.test"; }
  gcl-auth-check() { return 0; }
}

@test "two projects with different revisions give two correct rows" {
  run gcl-crf-describe fn -r europe-west1 -p dev -p prod
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<< "$output")" = "$(printf 'dev\tACTIVE\tpython312\thandler\tfn-00001\t2026-10-01T00:00:00Z\tgs://src/fn.zip#77\tgoogle.cloud.pubsub.topic.v1.messagePublished projects/p/topics/t\tsa-dev@x\tterraform\tabc1234')" ]
  [ "$(sed -n 2p <<< "$output")" = "$(printf 'prod\tACTIVE\tpython312\thandler\tfn-00002\t2026-10-02T00:00:00Z\trepo@main\thttps\tsa-prod@x\t-\t-')" ]
}

@test "the describe call uses --v2 and the region, project and name given" {
  run gcl-crf-describe fn -r europe-west1 -p dev
  grep -q 'gcloud functions describe fn --region=europe-west1 --project=dev --v2 --format=json' "$CALLS"
}

@test "the default project is used when none is given" {
  run gcl-crf-describe fn -r europe-west1
  [ "$status" -eq 0 ]
  [[ "$output" == dev$'\t'ACTIVE* ]]
}

@test "a function missing from one project shows (absent)" {
  STUB_ABSENT_PROJECT=prod run gcl-crf-describe fn -r europe-west1 -p dev -p prod
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p <<< "$output")" = "$(printf 'prod\t(absent)')" ]
}

@test "a denied project exits 5, names the permission, and the others still show" {
  STUB_DENY_PROJECT=prod run gcl-crf-describe fn -r europe-west1 -p dev -p prod
  [ "$status" -eq 5 ]
  [[ "$output" == *cloudfunctions.functions.get* ]]
  [[ "$output" == dev$'\t'ACTIVE* ]]
}

@test "--json prints one object per project" {
  run gcl-crf-describe fn -r europe-west1 -p dev -p prod --json
  [ "$status" -eq 0 ]
  [ "$(jq -s 'map(.project) | join(",")' <<< "$output")" = '"dev,prod"' ]
  [ "$(head -1 <<< "$output" | jq -r .revision)" = "fn-00001" ]
}

@test "bad usage exits 1 without calling gcloud" {
  run gcl-crf-describe
  [ "$status" -eq 1 ]
  run gcl-crf-describe fn
  [ "$status" -eq 1 ]
  run gcl-crf-describe 'bad fn' -r europe-west1
  [ "$status" -eq 1 ]
  run gcl-crf-describe fn -r europe-west1 -p 'bad;proj'
  [ "$status" -eq 1 ]
  run gcl-crf-describe fn -r europe-west1 --bogus
  [ "$status" -eq 1 ]
  [ ! -s "$CALLS" ]
}

@test "-h shows help" {
  run gcl-crf-describe -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}
