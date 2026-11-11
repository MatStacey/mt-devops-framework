#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-run-compare in .bash.d/10-infra/32-gcp-survey.sh and the
# diff_only/flag options of .bash.d/lib/awk/kv_matrix.awk
# ------------------------------------------
# gcloud is replaced by a stub serving one Cloud Run service JSON per
# project; STUB_ABSENT_PROJECT answers "cannot find service" for one project
# and STUB_DENY_PROJECT a permission error.

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
if [ "$project" = "${STUB_ABSENT_PROJECT:-}" ]; then
  echo "ERROR: (gcloud.run.services.describe) Cannot find service [svc]" >&2
  exit 1
fi
if [ "$project" = "${STUB_DENY_PROJECT:-}" ]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'run.services.get' denied" >&2
  exit 1
fi
if [ "$1 $2" = "artifacts docker" ]; then
  echo "gcloud $*" >> "${CALLS:-/dev/null}"
  echo "${STUB_DIGEST_TAGS:-latest}"
  exit 0
fi
service() {
  cat << JSON
{"metadata":{"annotations":{"run.googleapis.com/client-name":"gcloud","run.googleapis.com/ingress":"all"}},
 "status":{"latestReadyRevisionName":"svc-00001"},
 "spec":{"template":{
   "metadata":{"annotations":{"autoscaling.knative.dev/maxScale":"5","run.googleapis.com/vpc-access-connector":"conn"}},
   "spec":{"serviceAccountName":"$2","timeoutSeconds":300,"containerConcurrency":80,
     "containers":[{"image":"$1","resources":{"limits":{"cpu":"1","memory":"512Mi"}},
       "startupProbe":{"httpGet":{"path":"/ok","httpHeaders":[{"name":"X-Key","value":"probe-secret"}]}},
       "env":[{"name":"SHARED","value":"hunter2"},{"name":"$3","value":"literal-secret"},
              {"name":"DB_PASS","valueFrom":{"secretKeyRef":{"name":"db-pass","key":"$4"}}}]}],
     "volumes":[{"name":"cfg","secret":{"secretName":"cfg-secret"}}]}}}}
JSON
}
case "$project" in
  dev) service "${STUB_IMAGE_DEV:-img:1}" "sa-dev@x" "ONLY_DEV" "3" ;;
  *) service "${STUB_IMAGE_PROD:-img:2}" "sa-prod@x" "ONLY_PROD" "4" ;;
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
  CALLS="$BATS_TEST_TMPDIR/calls"
  export CALLS
  gcl-get-user() { echo "me@example.test"; }
  gcl-auth-check() { return 0; }
}

@test "only the rows that differ are shown, flagged, and identical rows are hidden" {
  run gcl-run-compare svc -r europe-west1 -p dev -p prod
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<< "$output")" = "$(printf 'KEY\tdev\tprod')" ]
  [[ "$output" == *$'⚠️ image\timg:1\timg:2'* ]]
  [[ "$output" == *$'⚠️ serviceAccount\tsa-dev@x\tsa-prod@x'* ]]
  [[ "$output" == *$'⚠️ env.ONLY_DEV\tset\t-'* ]]
  [[ "$output" == *$'⚠️ env.ONLY_PROD\t-\tset'* ]]
  [[ "$output" == *$'⚠️ env.DB_PASS\tsecret:db-pass:3\tsecret:db-pass:4'* ]]
  [[ "$output" != *"timeoutSeconds"* && "$output" != *"env.SHARED"* && "$output" != *"volume.cfg"* ]]
  [ "$(wc -l <<< "$output")" -eq 6 ]
}

@test "--all prints every row" {
  run gcl-run-compare svc -r europe-west1 -p dev -p prod --all
  [ "$status" -eq 0 ]
  [[ "$output" == *$'timeoutSeconds\t300\t300'* ]]
  [[ "$output" == *$'env.SHARED\tset\tset'* ]]
  [[ "$output" == *$'volume.cfg\tcfg-secret\tcfg-secret'* ]]
  [[ "$output" == *$'vpcConnector\tconn\tconn'* ]]
  [[ "$output" == *$'maxScale\t5\t5'* ]]
}

@test "literal environment values and probe headers never appear in the output" {
  run gcl-run-compare svc -r europe-west1 -p dev -p prod --all
  [ "$status" -eq 0 ]
  [[ "$output" != *hunter2* && "$output" != *literal-secret* && "$output" != *probe-secret* ]]
  [[ "$output" == *startupProbe* ]]
}

@test "a project without the service shows (absent)" {
  STUB_ABSENT_PROJECT=prod run gcl-run-compare svc -r europe-west1 -p dev -p prod
  [ "$status" -eq 0 ]
  [[ "$output" == *$'⚠️ service\t-\t(absent)'* ]]
}

@test "a denied project is named, the other columns are still shown, and the exit is 5" {
  STUB_DENY_PROJECT=prod run gcl-run-compare svc -r europe-west1 -p dev -p prod -p stage
  [ "$status" -eq 5 ]
  [[ "$output" == *"run.services.get"* ]]
  [[ "$output" == *$'KEY\tdev\tstage'* ]]
}

@test "bad usage exits 1 without calling gcloud" {
  run gcl-run-compare
  [ "$status" -eq 1 ]
  run gcl-run-compare svc -r europe-west1 -p dev
  [ "$status" -eq 1 ]
  run gcl-run-compare svc -p dev -p prod
  [ "$status" -eq 1 ]
  run gcl-run-compare 'bad svc' -r europe-west1 -p dev -p prod
  [ "$status" -eq 1 ]
  run gcl-run-compare svc -r europe-west1 -p dev -p 'bad;proj'
  [ "$status" -eq 1 ]
}

@test "-h shows help" {
  run gcl-run-compare -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}

@test "kv_matrix.awk diff_only hides identical rows and flags differing and missing ones" {
  run bash -c "printf 'a\tsame\tv\nb\tsame\tv\na\tdiff\tx\nb\tdiff\ty\na\tonly_a\t\n' | awk -v diff_only=1 -v flag='!' -v mark=X -f '$repo_root/.bash.d/lib/awk/kv_matrix.awk'"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'KEY\ta\tb\n! diff\tx\ty\n! only_a\tX\t-')" ]
}

make_repo() {
  repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email "t@example.test"
  git -C "$repo" config user.name "T"
  for n in 1 2 3; do
    echo "$n" > "$repo/f"
    git -C "$repo" add f
    git -C "$repo" commit -q -m "c$n"
  done
  head_sha=$(git -C "$repo" rev-parse HEAD)
  old_sha=$(git -C "$repo" rev-parse HEAD~2)
  git -C "$repo" update-ref refs/remotes/origin/main "$head_sha"
  git -C "$repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git -C "$repo" checkout -q -b side "$old_sha"
  echo side > "$repo/g"
  git -C "$repo" add g
  git -C "$repo" commit -q -m side
  side_sha=$(git -C "$repo" rev-parse HEAD)
}

@test "--repo reports how far an image tagged with a commit SHA is behind the branch" {
  make_repo
  STUB_IMAGE_DEV="gcr.example.test/app:${old_sha:0:10}" STUB_IMAGE_PROD="gcr.example.test/app:${head_sha}" run gcl-run-compare svc -r europe-west1 -p dev -p prod --repo "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'⚠️ behind origin/main\t2\t0'* ]]
  [[ "$output" == *$'⚠️ commit\t'"${old_sha:0:10}"$'\t'"${head_sha:0:12}"* ]]
}

@test "--repo reports a commit that is not on the branch" {
  make_repo
  STUB_IMAGE_DEV="gcr.example.test/app:${side_sha}" STUB_IMAGE_PROD="gcr.example.test/app:${head_sha}" run gcl-run-compare svc -r europe-west1 -p dev -p prod --repo "$repo"
  [[ "$output" == *$'behind origin/main\tnot on branch\t0'* ]]
}

@test "--repo reports unknown for a tag that is not a commit, and for a commit missing locally" {
  make_repo
  STUB_IMAGE_DEV="gcr.example.test/app:latest" STUB_IMAGE_PROD="gcr.example.test/app:deadbeefcafe" run gcl-run-compare svc -r europe-west1 -p dev -p prod --repo "$repo"
  [[ "$output" == *$'behind origin/main\tunknown (no SHA tag)\tunknown (not in local repo)'* ]]
}

@test "--repo finds the commit from a commit-sha tag listed for a digest-pinned image" {
  make_repo
  STUB_IMAGE_DEV="gcr.example.test/app@sha256:abc" STUB_DIGEST_TAGS="latest;${old_sha:0:10}" STUB_IMAGE_PROD="gcr.example.test/app:${head_sha}" run gcl-run-compare svc -r europe-west1 -p dev -p prod --repo "$repo"
  [[ "$output" == *$'behind origin/main\t2\t0'* ]]
  grep -q 'artifacts docker images list gcr.example.test/app .*--filter=version=sha256:abc' "$CALLS"
}

@test "--branch overrides the default branch" {
  make_repo
  git -C "$repo" update-ref refs/remotes/origin/side "$side_sha"
  STUB_IMAGE_DEV="gcr.example.test/app:${old_sha:0:10}" STUB_IMAGE_PROD="gcr.example.test/app:${side_sha}" run gcl-run-compare svc -r europe-west1 -p dev -p prod --repo "$repo" --branch side
  [[ "$output" == *"behind origin/side"* ]]
}

@test "without --repo the output has no commit rows" {
  run gcl-run-compare svc -r europe-west1 -p dev -p prod --all
  [[ "$output" != *"behind origin"* && "$output" != *$'commit\t'* ]]
}

@test "--repo errors: not a repository, and --branch without --repo" {
  run gcl-run-compare svc -r europe-west1 -p dev -p prod --repo "$BATS_TEST_TMPDIR"
  [ "$status" -eq 1 ]
  run gcl-run-compare svc -r europe-west1 -p dev -p prod --branch main
  [ "$status" -eq 1 ]
}
