#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-scheduler in .bash.d/10-infra/32-gcp-survey.sh
# ------------------------------------------
# gcloud is replaced by a stub that logs its argv and serves per-project,
# per-location scheduler jobs; STUB_DENY_ACTION makes pause/resume fail with
# a permission error.

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
  "scheduler locations") printf 'europe-west1\nus-central1\n'; exit 0 ;;
esac
project="" location=""
for arg in "$@"; do
  case "$arg" in
    --project=*) project="${arg#--project=}" ;;
    --location=*) location="${arg#--location=}" ;;
  esac
done
if [ "$2 $3" = "jobs pause" ] || [ "$2 $3" = "jobs resume" ]; then
  if [ -n "${STUB_DENY_ACTION:-}" ]; then
    echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'cloudscheduler.jobs.pause' denied" >&2
    exit 1
  fi
  exit 0
fi
job_json() {
  printf '{"name":"projects/%s/locations/%s/jobs/%s","state":"ENABLED","schedule":"0 * * * *","timeZone":"UTC","httpTarget":{"httpMethod":"POST","uri":"https://svc.example.test/run?key=secret","headers":{"X-Api-Key":"hunter2"},"body":"c2VjcmV0"},"lastAttemptTime":"2026-10-05T00:00:00Z","status":{"code":2}}' "$1" "$2" "$3"
}
case "$3" in
  list)
    if [[ "$*" == *"value(name)"* ]]; then
      case "$project/$location" in
        proj-a/europe-west1) echo "projects/proj-a/locations/europe-west1/jobs/nightly" ;;
        proj-a/europe-west2) echo "projects/proj-a/locations/europe-west2/jobs/other" ;;
        proj-b/europe-west1 | proj-b/europe-west2) echo "projects/$project/locations/$location/jobs/dup" ;;
      esac
      exit 0
    fi
    case "$project/$location" in
      proj-a/europe-west1) printf '[%s]' "$(job_json proj-a europe-west1 nightly)" ;;
      proj-b/europe-west2) printf '[%s]' "$(job_json proj-b europe-west2 hourly)" ;;
      *) printf '[]' ;;
    esac ;;
  describe)
    job_json "$project" "$location" "$4" ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/32-gcp-survey.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  GCP_SCAN_REGIONS="europe-west1 europe-west2"
  mt-help() { echo "help called"; }
  gcl-get-project() { echo "proj-a"; }
  gcl-get-user() { echo "me@example.test"; }
  gcl-auth-check() { return 0; }
}

@test "list covers two projects and two regions with a normalised row" {
  run gcl-scheduler list -p proj-a -p proj-b
  [ "$status" -eq 0 ]
  [ "$(wc -l <<< "$output")" -eq 2 ]
  [[ "$output" == *$'proj-a\teurope-west1\tnightly\tENABLED\t0 * * * *\tUTC\tPOST https://svc.example.test/run\t2026-10-05T00:00:00Z\t2'* ]]
  [[ "$output" == *$'proj-b\teurope-west2\thourly\t'* ]]
  [[ "$output" != *secret* ]]
}

@test "list uses -l over the configured regions, and --all-locations asks the project" {
  run gcl-scheduler list -p proj-a -l us-central1
  [ "$status" -eq 0 ]
  grep -q -- '--location=us-central1' "$CALLS"
  ! grep -q -- '--location=europe-west1' "$CALLS"
  : > "$CALLS"
  run gcl-scheduler list -p proj-a --all-locations
  grep -q 'scheduler locations list --project=proj-a' "$CALLS"
  grep -q -- '--location=us-central1' "$CALLS"
}

@test "describe finds the location by itself and hides bodies, header values and query strings" {
  run gcl-scheduler describe nightly -p proj-a
  [ "$status" -eq 0 ]
  [ "$(jq -r '.name' <<< "$output")" = "projects/proj-a/locations/europe-west1/jobs/nightly" ]
  [ "$(jq -r '.httpTarget.headers["X-Api-Key"]' <<< "$output")" = "<redacted>" ]
  [ "$(jq -r '.httpTarget.uri' <<< "$output")" = "https://svc.example.test/run" ]
  [ "$(jq -r '.httpTarget.body' <<< "$output")" = "null" ]
}

@test "an unknown job and an ambiguous job are errors that say where they looked" {
  run gcl-scheduler describe missing -p proj-a
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"*"europe-west1 europe-west2"* ]]
  run gcl-scheduler describe dup -p proj-b
  [ "$status" -eq 1 ]
  [[ "$output" == *"several locations"* ]]
  run gcl-scheduler describe dup -p proj-b -l europe-west2
  [ "$status" -eq 0 ]
}

@test "pause without --yes and without a terminal refuses and makes no gcloud call" {
  run gcl-scheduler pause nightly -p proj-a < /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"--yes"* ]]
  [ ! -s "$CALLS" ]
}

@test "pause --yes pauses the job in the location it found; resume likewise" {
  run gcl-scheduler pause nightly -p proj-a --yes
  [ "$status" -eq 0 ]
  grep -q 'scheduler jobs pause nightly --location=europe-west1 --project=proj-a' "$CALLS"
  run gcl-scheduler resume nightly -p proj-a --yes
  [ "$status" -eq 0 ]
  grep -q 'scheduler jobs resume nightly --location=europe-west1 --project=proj-a' "$CALLS"
}

@test "a denied pause exits 5 and names the permission" {
  STUB_DENY_ACTION=1 run gcl-scheduler pause nightly -p proj-a --yes
  [ "$status" -eq 5 ]
  [[ "$output" == *cloudscheduler.jobs.pause* ]]
}

@test "bad usage exits 1 without calling gcloud" {
  run gcl-scheduler
  [ "$status" -eq 1 ]
  run gcl-scheduler frobnicate
  [ "$status" -eq 1 ]
  run gcl-scheduler describe
  [ "$status" -eq 1 ]
  run gcl-scheduler describe 'bad job'
  [ "$status" -eq 1 ]
  run gcl-scheduler describe nightly -p proj-a -p proj-b
  [ "$status" -eq 1 ]
  run gcl-scheduler list -l 'EU West'
  [ "$status" -eq 1 ]
  [ ! -s "$CALLS" ]
}

@test "-h shows help" {
  run gcl-scheduler -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}
