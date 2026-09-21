#!/usr/bin/env bats
# ------------------------------------------
# Bats: docker-health in .bash.d/02-utilities/30-docker.sh
# ------------------------------------------
# docker is stubbed with fixed `docker inspect` payloads -- no daemon needed.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  ln -s "$repo_root/.bash.d" "$HOME/.bash.d"
  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  PATH="$fake_bin:$PATH"

  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/30-docker.sh"
  __docker_ensure_running() { return 0; }
  CB_RED="" CB_GREEN="" CB_YELLOW="" CB_BLUE="" CB_CYAN="" C_RESET=""

  FIXTURE_DIR="$BATS_TEST_TMPDIR"
  export FIXTURE_DIR

  cat > "$fake_bin/docker" << 'STUB'
#!/usr/bin/env bash
case "$1" in
  ps) echo "slow-app" ;;
  inspect)
    case "$2" in
      slow-app) cat "$FIXTURE_DIR/slow.json" ;;
      plain-app) cat "$FIXTURE_DIR/plain.json" ;;
      *) exit 1 ;;
    esac ;;
esac
STUB
  chmod +x "$fake_bin/docker"

  cat > "$FIXTURE_DIR/slow.json" << 'JSON'
[{"Name":"/slow-app","Config":{"Healthcheck":{"Test":["CMD-SHELL","curl -f localhost/health"],"Interval":30000000000,"Timeout":15000000000,"Retries":3}},
 "State":{"Health":{"Status":"unhealthy","FailingStreak":4,"Log":[
  {"Start":"2026-09-21T02:00:00.000000000+01:00","End":"2026-09-21T02:00:15.500000000+01:00","ExitCode":-1,"Output":"Health check exceeded timeout (15s)\n"},
  {"Start":"2026-09-21T02:00:45.000000000+01:00","End":"2026-09-21T02:00:45.200000000+01:00","ExitCode":0,"Output":""}]}}}]
JSON
  cat > "$FIXTURE_DIR/plain.json" << 'JSON'
[{"Name":"/plain-app","Config":{},"State":{}}]
JSON
}

@test "docker-health --json reports status, streak, config and probe durations" {
  run docker-health -j slow-app
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].status' <<< "$output")" = "unhealthy" ]
  [ "$(jq -r '.[0].failing_streak' <<< "$output")" = "4" ]
  [ "$(jq -r '.[0].config.timeout_sec' <<< "$output")" = "15" ]
  [ "$(jq -r '.[0].probes[0].duration_sec' <<< "$output")" = "15.5" ]
  [ "$(jq -r '.[0].probes[0].near_timeout' <<< "$output")" = "true" ]
  [ "$(jq -r '.[0].probes[1].near_timeout' <<< "$output")" = "false" ]
}

@test "docker-health --lines keeps only the most recent probes" {
  run docker-health -j -n 1 slow-app
  [ "$(jq -r '.[0].probes | length' <<< "$output")" = "1" ]
  [ "$(jq -r '.[0].probes[0].exit_code' <<< "$output")" = "0" ]
}

@test "docker-health report flags a probe near the timeout" {
  run docker-health slow-app
  [[ "$output" == *"failing streak: 4"* ]]
  [[ "$output" == *"Health check exceeded timeout (15s)"* ]]
  [[ "$output" == *"raise the healthcheck timeout"* ]]
}

@test "docker-health with no argument diagnoses unhealthy containers" {
  run docker-health
  [[ "$output" == *"slow-app"* ]]
}

@test "docker-health says so when a container has no healthcheck" {
  run docker-health plain-app
  [ "$status" -eq 0 ]
  [[ "$output" == *"no healthcheck configured"* ]]
}

@test "docker-health fails for an unknown container and a bad --lines" {
  run docker-health nosuch
  [ "$status" -eq 1 ]
  run docker-health -n abc slow-app
  [ "$status" -eq 1 ]
}
