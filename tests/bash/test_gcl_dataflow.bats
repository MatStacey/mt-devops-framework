#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-dataflow-describe in .bash.d/10-infra/32-gcp-survey.sh
# ------------------------------------------
# gcloud is replaced by a stub that logs its argv and serves a describe
# result, job messages and a worker table; STUB_DENY makes the logging and
# compute reads fail with a permission error.

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
  "dataflow jobs") echo "DESCRIBED"; exit 0 ;;
esac
if [ -n "${STUB_DENY:-}" ]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'logging.logEntries.list' denied" >&2
  exit 1
fi
case "$1 $2" in
  "logging read")
    cat << 'JSON'
[
 {"timestamp":"2026-10-05T01:00:00Z","severity":"INFO","resource":{"labels":{"job_id":"job-1"}},"textPayload":"Starting workers\nsecond line"},
 {"timestamp":"2026-10-05T02:00:00Z","severity":"WARNING","resource":{"labels":{"job_id":"job-1"}},"jsonPayload":{"message":"Autoscaling up"}},
 {"timestamp":"2026-10-05T03:00:00Z","severity":"INFO","resource":{"labels":{"job_id":"job-2"}},"textPayload":"Job relaunched"}
]
JSON
    ;;
  "compute instances") printf 'NAME  ZONE  MACHINE_TYPE  STATUS  CREATION_TIMESTAMP\nworker-1  europe-west1-b  n1-standard-4  RUNNING  2026-10-05\n' ;;
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

@test "without the new flags it still runs dataflow jobs describe, unchanged" {
  run gcl-dataflow-describe job-1 -p proj-a --full
  [ "$status" -eq 0 ]
  [ "$output" = "DESCRIBED" ]
  [ "$(cat "$CALLS")" = "gcloud dataflow jobs describe job-1 --project=proj-a --full --quiet" ]
}

@test "--timeline filters on both name and ID, reads ascending, and skips jobs describe" {
  run gcl-dataflow-describe my-job -p proj-a --timeline
  [ "$status" -eq 0 ]
  local call
  call="$(grep 'logging read' "$CALLS")"
  [[ "$call" == *'resource.labels.job_name="my-job" OR resource.labels.job_id="my-job"'* ]]
  [[ "$call" == *'logName="projects/proj-a/logs/dataflow.googleapis.com%2Fjob-message"'* ]]
  [[ "$call" == *"--order=asc"* ]]
  ! grep -q 'dataflow jobs describe' "$CALLS"
}

@test "--timeline prints first lines only and marks a job_id change" {
  run gcl-dataflow-describe my-job -p proj-a --timeline
  [ "$(sed -n 1p <<< "$output")" = "$(printf '2026-10-05T01:00:00Z\tINFO\tjob-1\tStarting workers')" ]
  [ "$(sed -n 2p <<< "$output")" = "$(printf '2026-10-05T02:00:00Z\tWARNING\tjob-1\tAutoscaling up')" ]
  [ "$(sed -n 3p <<< "$output")" = "--- job_id changed: job-1 -> job-2 ---" ]
  [ "$(sed -n 4p <<< "$output")" = "$(printf '2026-10-05T03:00:00Z\tINFO\tjob-2\tJob relaunched')" ]
  [[ "$output" != *"second line"* ]]
}

@test "--timeline uses the --since window" {
  run gcl-dataflow-describe my-job -p proj-a --timeline --since 6h
  [ "$status" -eq 0 ]
  [[ "$(grep 'logging read' "$CALLS")" == *'timestamp>="'* ]]
  run gcl-dataflow-describe my-job -p proj-a --timeline --since 2w
  [ "$status" -eq 1 ]
}

@test "--workers lists the job's VMs by name or ID label without calling jobs describe" {
  run gcl-dataflow-describe my-job -p proj-a --workers
  [ "$status" -eq 0 ]
  [[ "$output" == *"worker-1"* ]]
  local call
  call="$(grep 'compute instances list' "$CALLS")"
  [[ "$call" == *"--filter=labels.dataflow_job_name=my-job OR labels.dataflow_job_id=my-job"* ]]
  ! grep -q 'dataflow jobs describe' "$CALLS"
}

@test "--timeline and --workers together print both" {
  run gcl-dataflow-describe my-job -p proj-a --timeline --workers
  [ "$status" -eq 0 ]
  [[ "$output" == *"Starting workers"* && "$output" == *"worker-1"* ]]
}

@test "a denied read exits 5 and names the permission" {
  STUB_DENY=1 run gcl-dataflow-describe my-job -p proj-a --timeline
  [ "$status" -eq 5 ]
  [[ "$output" == *logging.logEntries.list* ]]
}

@test "an injected job name is rejected before any request" {
  run gcl-dataflow-describe 'x" OR 1=1' -p proj-a --timeline
  [ "$status" -eq 1 ]
  run gcl-dataflow-describe 'x" OR 1=1' -p proj-a --workers
  [ "$status" -eq 1 ]
  ! grep -q 'logging read\|compute instances' "$CALLS" 2> /dev/null
}
