#!/usr/bin/env bats
# ------------------------------------------
# Bats: uv-pytest in .bash.d/03-mytools/11-python-dev.sh
# ------------------------------------------
# uv is replaced with a stub on PATH that records its argv and fails the
# subcommand named in STUB_UV_FAIL.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  stub_dir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$stub_dir" "$BATS_TEST_TMPDIR/proj"
  cat > "$stub_dir/uv" << 'STUB'
#!/usr/bin/env bash
echo "$*" >> "$STUB_UV_LOG"
[ "$1" = "${STUB_UV_FAIL:-}" ] && exit 3
exit 0
STUB
  chmod +x "$stub_dir/uv"
  PATH="$stub_dir:$PATH"
  export STUB_UV_LOG="$BATS_TEST_TMPDIR/uv.log"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/03-mytools/11-python-dev.sh"
  cd "$BATS_TEST_TMPDIR/proj" || return 1
}

@test "fails clearly without a uv.lock and runs nothing" {
  run uv-pytest
  [ "$status" -eq 1 ]
  [[ "$output" == *uv.lock* ]]
  [ ! -f "$STUB_UV_LOG" ]
}

@test "syncs frozen then runs pytest with coverage" {
  touch uv.lock
  run uv-pytest
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$STUB_UV_LOG")" = "sync --frozen" ]
  [ "$(sed -n 2p "$STUB_UV_LOG")" = "run --frozen pytest --cov" ]
}

@test "extra arguments are passed through to pytest" {
  touch uv.lock
  run uv-pytest -k smoke -x
  [ "$(sed -n 2p "$STUB_UV_LOG")" = "run --frozen pytest --cov -k smoke -x" ]
}

@test "a failed sync stops before pytest" {
  touch uv.lock
  STUB_UV_FAIL=sync run uv-pytest
  [ "$status" -eq 1 ]
  [ "$(wc -l < "$STUB_UV_LOG")" -eq 1 ]
}

@test "pytest's exit code is returned" {
  touch uv.lock
  STUB_UV_FAIL=run run uv-pytest
  [ "$status" -eq 3 ]
}

@test "missing uv fails without searching other interpreters" {
  touch uv.lock
  run /bin/bash -c 'PATH=/nonexistent; source "$1"; uv-pytest' _ "$repo_root/.bash.d/03-mytools/11-python-dev.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"uv is not installed"* ]]
}
