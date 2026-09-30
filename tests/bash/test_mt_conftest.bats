#!/usr/bin/env bats
# ------------------------------------------
# Bats: mt-conftest in .bash.d/10-infra/46-conftest.sh
# ------------------------------------------
# conftest is stubbed to record its arguments.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/46-conftest.sh"
  CB_RED="" C_RESET=""
  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  PATH="$fake_bin:$PATH"
  printf '#!/usr/bin/env bash\necho "$@" > "$BATS_TEST_TMPDIR/args"\n' > "$fake_bin/conftest"
  chmod +x "$fake_bin/conftest"
  cd "$BATS_TEST_TMPDIR" || return 1
  mkdir policy custom
}

@test "tests files against the default policy directory" {
  run mt-conftest a.yaml b.yaml
  [ "$status" -eq 0 ]
  [ "$(cat args)" = "test --policy policy a.yaml b.yaml" ]
}

@test "passes a custom policy directory and namespace" {
  run mt-conftest -p custom -n main a.yaml
  [ "$(cat args)" = "test --policy custom --namespace main a.yaml" ]
}

@test "--verify runs conftest verify" {
  run mt-conftest -v -p custom
  [ "$(cat args)" = "verify --policy custom" ]
}

@test "fails when the policy directory is missing" {
  run mt-conftest -p nope a.yaml
  [ "$status" -eq 1 ]
}

@test "fails with usage when no files are given" {
  run mt-conftest
  [ "$status" -eq 1 ]
}

@test "fails when conftest is not installed" {
  rm "$fake_bin/conftest"
  PATH="/usr/bin:/bin" run mt-conftest a.yaml
  [ "$status" -eq 1 ]
}
