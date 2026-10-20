#!/usr/bin/env bats
# ------------------------------------------
# Bats: ruff-check in .bash.d/03-mytools/07-formatting.sh
# ------------------------------------------
# ruff-check must report lint and format problems and never modify a file.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  command -v ruff > /dev/null || skip "ruff not installed"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/03-mytools/07-formatting.sh"
  # shellcheck disable=SC2317
  mt-help() { :; }
  work="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$work"
  cd "$work" || return 1
}

@test "clean file passes" {
  printf 'x = 1\n' > ok.py
  run ruff-check
  [ "$status" -eq 0 ]
}

@test "badly formatted file fails and is left byte-identical" {
  printf 'x   =   1\n' > bad.py
  before=$(sha256sum bad.py)
  run ruff-check
  [ "$status" -eq 1 ]
  [ "$before" = "$(sha256sum bad.py)" ]
}

@test "lint error fails and is left byte-identical" {
  printf 'import os\n' > lint.py
  before=$(sha256sum lint.py)
  run ruff-check lint.py
  [ "$status" -eq 1 ]
  [ "$before" = "$(sha256sum lint.py)" ]
}

@test "both checks run even when the first fails" {
  printf 'import os\nx   =   1\n' > both.py
  run ruff-check both.py
  [[ "$output" == *F401* || "$output" == *I001* ]]
  [[ "$output" == *"reformatted"* ]]
}

@test "missing ruff returns 127" {
  run /bin/bash -c 'PATH=/nonexistent; source "$1"; ruff-check' _ "$repo_root/.bash.d/03-mytools/07-formatting.sh"
  [ "$status" -eq 127 ]
}
