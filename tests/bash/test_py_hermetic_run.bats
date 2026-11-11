#!/usr/bin/env bats
# ------------------------------------------
# Bats: py-hermetic-run in .bash.d/03-mytools/11-python-dev.sh
# ------------------------------------------
# Runs probe scripts from a throwaway project directory that has a .venv
# pointing at the system python. Network assertions are skipped where
# `unshare -rn` is unavailable.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/03-mytools/11-python-dev.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  mt-help() { echo "help called"; }

  project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project/.venv/bin"
  ln -s "$(command -v python3)" "$project/.venv/bin/python"
  cd "$project" || return 1
  cat > probe.py << 'PY'
import os
import socket
import sys

print("home=" + os.environ.get("HOME", ""))
print("adc=" + os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "<unset>"))
print("cloudsdk=" + os.environ.get("CLOUDSDK_CONFIG", ""))
print("secret=" + os.environ.get("SECRET_TOKEN", "<unset>"))
print("extra=" + os.environ.get("EXTRA_FLAG", "<unset>"))
print("args=" + ",".join(sys.argv[1:]))
try:
    socket.create_connection(("1.1.1.1", 443), timeout=2).close()
    print("network=reachable")
except OSError:
    print("network=blocked")
sys.exit(int(os.environ.get("PROBE_EXIT", "0")))
PY
  can_isolate=0
  if unshare -rn true 2> /dev/null; then
    can_isolate=1
  fi
}

@test "the environment is cleared: no credentials, an empty temp HOME and gcloud config, no inherited secrets" {
  SECRET_TOKEN="hunter2" GOOGLE_APPLICATION_CREDENTIALS="/real/key.json" run py-hermetic-run --allow-network probe.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"adc=<unset>"* ]]
  [[ "$output" == *"secret=<unset>"* ]]
  [[ "$output" != *hunter2* && "$output" != */real/key.json* ]]
  local home_dir
  home_dir=$(sed -n 's/^home=//p' <<< "$output")
  [[ "$home_dir" == /tmp/* || "$home_dir" == "${TMPDIR:-/tmp}"/* ]]
  [ "$home_dir" != "$HOME" ]
  [ ! -e "$home_dir" ]
  [[ "$output" == *"cloudsdk=/"* ]]
}

@test "the network is blocked unless --allow-network is given" {
  [ "$can_isolate" -eq 1 ] || skip "unshare -rn is unavailable on this runner"
  run py-hermetic-run probe.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"network=blocked"* ]]
}

@test "without isolation available it refuses unless --allow-network is passed" {
  unshare() { return 1; }
  run py-hermetic-run probe.py
  [ "$status" -eq 1 ]
  [[ "$output" == *"--allow-network"* ]]
  run py-hermetic-run --allow-network probe.py
  [ "$status" -eq 0 ]
}

@test "arguments reach the script and its exit code is passed through" {
  run py-hermetic-run --allow-network --env-file <(echo PROBE_EXIT=3) probe.py one two
  [ "$status" -eq 3 ]
  [[ "$output" == *"args=one,two"* ]]
}

@test "an env file adds KEY=VALUE lines, comments and blanks allowed" {
  printf '# stub values\n\nEXTRA_FLAG=on\n' > env.txt
  run py-hermetic-run --allow-network --env-file env.txt probe.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"extra=on"* ]]
}

@test "an env file rejects anything but KEY=VALUE and the protected keys" {
  printf 'export X=1\n' > bad1.txt
  run py-hermetic-run --allow-network --env-file bad1.txt probe.py
  [ "$status" -eq 1 ]
  printf 'GOOGLE_APPLICATION_CREDENTIALS=/real/key.json\n' > bad2.txt
  run py-hermetic-run --allow-network --env-file bad2.txt probe.py
  [ "$status" -eq 1 ]
  printf 'HOME=/root\n' > bad3.txt
  run py-hermetic-run --allow-network --env-file bad3.txt probe.py
  [ "$status" -eq 1 ]
  run py-hermetic-run --allow-network --env-file missing.txt probe.py
  [ "$status" -eq 1 ]
}

@test "-m runs a module" {
  mkdir pkg && : > pkg/__init__.py && echo 'print("module-ran")' > pkg/__main__.py
  run py-hermetic-run --allow-network -m pkg
  [ "$status" -eq 0 ]
  [[ "$output" == *module-ran* ]]
}

@test "without a venv it falls back to uv run --no-sync when uv.lock exists, and errors clearly otherwise" {
  rm -rf .venv
  run py-hermetic-run --allow-network probe.py
  [ "$status" -eq 1 ]
  [[ "$output" == *"No .venv/bin/python"* ]]
  : > uv.lock
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\necho "uv $*" > "%s/uv_args"\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/bin/uv"
  chmod +x "$BATS_TEST_TMPDIR/bin/uv"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run py-hermetic-run --allow-network probe.py a
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/uv_args")" = "uv run --no-sync python probe.py a" ]
}

@test "usage errors: nothing to run, a missing script, an unknown option" {
  run py-hermetic-run
  [ "$status" -eq 1 ]
  run py-hermetic-run --allow-network nothere.py
  [ "$status" -eq 1 ]
  run py-hermetic-run --bogus probe.py
  [ "$status" -eq 1 ]
}

@test "-h shows help" {
  run py-hermetic-run -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}

@test "on a host with WSL interop it warns that Windows programs are not network-isolated" {
  [ "$can_isolate" -eq 1 ] || skip "unshare -rn is unavailable on this runner"
  PY_WSL_INTEROP_FILE="$BATS_TEST_TMPDIR/interop"
  : > "$PY_WSL_INTEROP_FILE"
  run py-hermetic-run probe.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"WSL interop is enabled"* ]]
  PY_WSL_INTEROP_FILE="$BATS_TEST_TMPDIR/absent"
  run py-hermetic-run probe.py
  [[ "$output" != *"WSL interop"* ]]
}
