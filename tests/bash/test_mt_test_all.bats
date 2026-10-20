#!/usr/bin/env bats
# ------------------------------------------
# Bats: mt-test-all in .bash.d/02-utilities/37-test-runner.sh
# ------------------------------------------
# bats and python3 are stubbed -- these tests cover suite selection and
# exit-code aggregation, not the real suites.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  fake_repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$HOME" "$fake_repo/.bash.d" "$fake_repo/tests"
  git -C "$fake_repo" init -q
  ln -s "$fake_repo/.bash.d" "$HOME/.bash.d"
  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  PATH="$fake_bin:$PATH"
  CALLS="$BATS_TEST_TMPDIR/calls.log"
  export CALLS

  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/37-test-runner.sh"
  mt-log() { :; }
  CB_RED="" CB_GREEN="" CB_BLUE="" C_RESET=""

  printf '#!/usr/bin/env bash\necho bats >> "$CALLS"\nexit "${BATS_STUB_EXIT:-0}"\n' > "$fake_bin/bats"
  printf '#!/usr/bin/env bash\necho pytest >> "$CALLS"\nexit "${PYTEST_STUB_EXIT:-0}"\n' > "$fake_bin/python3"
  chmod +x "$fake_bin/bats" "$fake_bin/python3"
}

@test "runs both suites and succeeds when both pass" {
  run mt-test-all
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = $'bats\npytest' ]
}

@test "still runs pytest when bats fails, and returns 1" {
  BATS_STUB_EXIT=1 run mt-test-all
  [ "$status" -eq 1 ]
  [ "$(cat "$CALLS")" = $'bats\npytest' ]
}

@test "returns 1 when only pytest fails" {
  PYTEST_STUB_EXIT=1 run mt-test-all
  [ "$status" -eq 1 ]
}

@test "--bats-only skips pytest" {
  run mt-test-all --bats-only
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "bats" ]
}

@test "--pytest-only skips bats" {
  run mt-test-all -p
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "pytest" ]
}

@test "fails when no tests/ directory exists" {
  rmdir "$fake_repo/tests"
  run mt-test-all
  [ "$status" -eq 1 ]
}

@test "unknown option returns 1" {
  run mt-test-all --bogus
  [ "$status" -eq 1 ]
}
