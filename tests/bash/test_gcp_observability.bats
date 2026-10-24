#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-audit-changes in .bash.d/10-infra/34-gcp-observability.sh
# and the shared helpers in 33-gcp-read-only.sh
# ------------------------------------------
# gcloud is replaced by a stub that logs its argv and serves audit-log
# fixtures per project; STUB_DENY_PROJECT makes one project fail with a
# permission error; STUB_FULL makes every project return limit entries.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  mkdir -p "$HOME/.config/gcloud/configurations"
  printf 'project = proj-1\naccount = me@example.test\n' > "$HOME/.config/gcloud/configurations/config_default"
  CALLS="$BATS_TEST_TMPDIR/calls"
  export CALLS
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
echo "gcloud $*" >> "$CALLS"
case "$1 $2" in
  "auth list") echo "me@example.test"; exit 0 ;;
  "auth print-access-token") echo tok; exit 0 ;;
  "config get-value") echo "proj-1"; exit 0 ;;
esac
project=""
for arg in "$@"; do
  case "$arg" in --project=*) project="${arg#--project=}" ;; esac
done
if [ -n "${STUB_DENY_PROJECT:-}" ] && [ "$project" = "$STUB_DENY_PROJECT" ]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'logging.logEntries.list' denied" >&2
  exit 1
fi
entry() {
  printf '{"timestamp":"%s","protoPayload":{"serviceName":"run.googleapis.com","methodName":"v1.UpdateService","resourceName":"projects/p/locations/eu/services/svc","status":{},"authenticationInfo":{"principalEmail":"%s"}}}' "$1" "$2"
}
if [ -n "${STUB_FULL:-}" ]; then
  printf '[%s,%s]' "$(entry 2026-10-05T01:00:00Z a@example.test)" "$(entry 2026-10-05T02:00:00Z a@example.test)"
  exit 0
fi
case "$project" in
  proj-a) printf '[%s,%s]' "$(entry 2026-10-05T03:00:00Z a@example.test)" "$(entry 2026-10-05T01:00:00Z b@example.test)" ;;
  proj-b) printf '[%s]' "$(entry 2026-10-05T02:00:00Z c@example.test)" ;;
  *) printf '[]' ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/30-gcp-config.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/34-gcp-observability.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  mt-help() { echo "help called"; }
}

read_call() {
  grep 'logging read' "$CALLS" | head -1
}

@test "duration helper converts s, m, h and d and rejects anything else" {
  [ "$(__mt_gcl_duration_seconds 90s)" = "90" ]
  [ "$(__mt_gcl_duration_seconds 30m)" = "1800" ]
  [ "$(__mt_gcl_duration_seconds 6h)" = "21600" ]
  [ "$(__mt_gcl_duration_seconds 2d)" = "172800" ]
  run __mt_gcl_duration_seconds 2w
  [ "$status" -eq 1 ]
  run __mt_gcl_duration_seconds ""
  [ "$status" -eq 1 ]
}

@test "rfc3339 helper prints a UTC timestamp" {
  [ "$(__mt_gcl_rfc3339 0)" = "1970-01-01T00:00:00Z" ]
}

@test "absolute window puts both bounds, ascending order and the limit in the gcloud call" {
  run gcl-audit-changes -p proj-a --start 2026-10-05T00:00:00Z --end 2026-10-05T12:00:00Z --service run.googleapis.com --limit 50
  [ "$status" -eq 0 ]
  local call
  call="$(read_call)"
  [[ "$call" == *'timestamp>="2026-10-05T00:00:00Z" AND timestamp<="2026-10-05T12:00:00Z"'* ]]
  [[ "$call" == *'logName="projects/proj-a/logs/cloudaudit.googleapis.com%2Factivity"'* ]]
  [[ "$call" == *'protoPayload.serviceName="run.googleapis.com"'* ]]
  [[ "$call" == *"--order=asc"* ]]
  [[ "$call" == *"--limit=50"* ]]
  [[ "$call" != *"system_event"* ]]
}

@test "relative window builds an explicit timestamp filter, never --freshness" {
  run gcl-audit-changes -p proj-a --since 6h
  [ "$status" -eq 0 ]
  local call
  call="$(read_call)"
  [[ "$call" == *'timestamp>="'* ]]
  [[ "$call" != *"--freshness"* ]]
}

@test "--system adds the system_event log and --principal filters by principal" {
  run gcl-audit-changes -p proj-a --system --principal a@example.test
  [ "$status" -eq 0 ]
  local call
  call="$(read_call)"
  [[ "$call" == *"cloudaudit.googleapis.com%2Fsystem_event"* ]]
  [[ "$call" == *'protoPayload.authenticationInfo.principalEmail="a@example.test"'* ]]
}

@test "output from several projects is merged and sorted by time" {
  run gcl-audit-changes -p proj-a -p proj-b
  [ "$status" -eq 0 ]
  [ "$(wc -l <<< "$output")" -eq 3 ]
  [ "$(cut -f1 <<< "$output" | tr '\n' ' ')" = "2026-10-05T01:00:00Z 2026-10-05T02:00:00Z 2026-10-05T03:00:00Z " ]
  [ "$(sed -n 1p <<< "$output" | cut -f2-7)" = "$(printf 'proj-a\tb@example.test\trun.googleapis.com\tv1.UpdateService\teu/services/svc\t0')" ]
}

@test "a denied project is named, the others are still shown, and the exit is non-zero" {
  STUB_DENY_PROJECT=proj-b run gcl-audit-changes -p proj-a -p proj-b
  [ "$status" -eq 5 ]
  [[ "$output" == *"Permission denied"* ]]
  [[ "$output" == *"logging.logEntries.list"* ]]
  [[ "$output" == *"proj-a"* ]]
}

@test "the limit warning fires when a project returns exactly the limit" {
  STUB_FULL=1 run gcl-audit-changes -p proj-a --limit 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"reached the 2-entry limit"* ]]
}

@test "no limit warning below the limit" {
  run gcl-audit-changes -p proj-a --limit 100
  [ "$status" -eq 0 ]
  [[ "$output" != *"reached"* ]]
}

@test "invalid durations, timestamps, limits and filter values exit 1 without calling gcloud logging" {
  run gcl-audit-changes -p proj-a --since 2w
  [ "$status" -eq 1 ]
  run gcl-audit-changes -p proj-a --start yesterday
  [ "$status" -eq 1 ]
  run gcl-audit-changes -p proj-a --limit 0
  [ "$status" -eq 1 ]
  run gcl-audit-changes -p 'proj" OR 1=1'
  [ "$status" -eq 1 ]
  run gcl-audit-changes -p proj-a --service 'x" OR "y'
  [ "$status" -eq 1 ]
  run gcl-audit-changes --bogus
  [ "$status" -eq 1 ]
  ! grep -q 'logging read' "$CALLS" 2> /dev/null
}

@test "gcl-audit-changes -h shows help" {
  run gcl-audit-changes -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}
