#!/usr/bin/env bats
# ------------------------------------------
# Bats: XDG Base Directory path resolution + the pre-XDG config-file
# migration in .bash.d/00-system/00-config.sh
# ------------------------------------------
# Sources the real 00-config.sh (via symlinked 00-system/ and lib/
# dirs, so tests always run against current code, never a stale copy)
# against a throwaway $HOME per test. config/ is left as a real,
# writable directory under that throwaway $HOME -- never symlinked --
# so a test can safely drop a fake pre-XDG config.yaml there without
# ever touching this repo's own .bash.d/config/.
#
# Every test runs with ISOLATE_ENV as its baseline: unsetting every
# XDG/framework-path env var 00-config.sh reads or exports, regardless
# of whatever the ambient shell (a dev machine, a CI runner) happens
# to already have set for them. Without this, a test asserting against
# $TEST_HOME/.config/... can pass locally (nothing pre-set) yet fail on
# a runner that exports its own XDG_CONFIG_HOME -- 00-config.sh would
# then resolve CONFIG_FILE under *that* ambient path instead of the
# sandbox, and the migration would write somewhere the test never
# looks. A test then layers only the one var it actually wants to
# control on top of this baseline.

setup() {
  local repo_bashd
  repo_bashd="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/.bash.d"
  export TEST_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TEST_HOME/.bash.d"
  ln -s "$repo_bashd/00-system" "$TEST_HOME/.bash.d/00-system"
  ln -s "$repo_bashd/lib" "$TEST_HOME/.bash.d/lib"

  ISOLATE_ENV=(
    -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME
    -u CONFIG_FILE -u ENV_CACHE -u VERSION_FILE
    -u CACHE_DIR -u LOG_DIR -u CONFIG_DIR
  )
}

@test "CONFIG_FILE defaults to \${XDG_CONFIG_HOME:-~/.config}/mt-devops-framework/config.yaml" {
  run env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" bash -c '
    source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1
    printf %s "$CONFIG_FILE"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/.config/mt-devops-framework/config.yaml" ]
}

@test "CONFIG_FILE honors an absolute XDG_CONFIG_HOME override" {
  run env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/custom-config" bash -c '
    source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1
    printf %s "$CONFIG_FILE"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/custom-config/mt-devops-framework/config.yaml" ]
}

@test "CONFIG_FILE ignores a relative XDG_CONFIG_HOME (invalid per spec) and falls back to ~/.config" {
  run env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" XDG_CONFIG_HOME="relative/path" bash -c '
    source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1
    printf %s "$CONFIG_FILE"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/.config/mt-devops-framework/config.yaml" ]
}

@test "a pre-set CONFIG_FILE env var overrides the XDG default entirely" {
  run env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/custom-config" CONFIG_FILE="$TEST_HOME/explicit/config.yaml" bash -c '
    source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1
    printf %s "$CONFIG_FILE"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/explicit/config.yaml" ]
}

@test "ENV_CACHE defaults to \${XDG_CACHE_HOME:-~/.cache}/mt-devops-framework/.env.cache" {
  run env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" bash -c '
    source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1
    printf %s "$ENV_CACHE"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_HOME/.cache/mt-devops-framework/.env.cache" ]
}

@test "an old-style config.yaml at .bash.d/config/ is moved to the new XDG location on shell start" {
  mkdir -p "$TEST_HOME/.bash.d/config"
  echo "sync_repo_url: git@github.com:example/fork.git" > "$TEST_HOME/.bash.d/config/config.yaml"

  run env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" bash -c '
    source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1
    cat "$CONFIG_FILE"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "sync_repo_url: git@github.com:example/fork.git" ]
  [ ! -f "$TEST_HOME/.bash.d/config/config.yaml" ]
}

@test "migration also moves .syncignore and secrets_metadata.yaml alongside config.yaml" {
  mkdir -p "$TEST_HOME/.bash.d/config"
  echo "real syncignore" > "$TEST_HOME/.bash.d/config/.syncignore"
  echo "real secrets metadata" > "$TEST_HOME/.bash.d/config/secrets_metadata.yaml"
  echo "sync_repo_url: git@github.com:example/fork.git" > "$TEST_HOME/.bash.d/config/config.yaml"

  env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" bash -c 'source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1'

  [ "$(cat "$TEST_HOME/.config/mt-devops-framework/.syncignore")" = "real syncignore" ]
  [ "$(cat "$TEST_HOME/.config/mt-devops-framework/secrets_metadata.yaml")" = "real secrets metadata" ]
}

@test "the migration is idempotent -- a second shell start is a no-op, not an error" {
  mkdir -p "$TEST_HOME/.bash.d/config"
  echo "sync_repo_url: git@github.com:example/fork.git" > "$TEST_HOME/.bash.d/config/config.yaml"

  env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" bash -c 'source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1'

  run env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" bash -c '
    source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1
    cat "$CONFIG_FILE"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "sync_repo_url: git@github.com:example/fork.git" ]
}

@test "the migration never overwrites an existing file at the new location" {
  mkdir -p "$TEST_HOME/.bash.d/config" "$TEST_HOME/.config/mt-devops-framework"
  echo "STALE OLD" > "$TEST_HOME/.bash.d/config/config.yaml"
  echo "REAL CURRENT" > "$TEST_HOME/.config/mt-devops-framework/config.yaml"

  run env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" bash -c '
    source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1
  '
  [ "$status" -eq 0 ]
  [ "$(cat "$TEST_HOME/.config/mt-devops-framework/config.yaml")" = "REAL CURRENT" ]
  [ "$(cat "$TEST_HOME/.bash.d/config/config.yaml")" = "STALE OLD" ]
}

@test "no config.yaml anywhere -- a fresh shell scaffolds one from the template at the new location" {
  run env "${ISOLATE_ENV[@]}" HOME="$TEST_HOME" bash -c '
    source "$HOME/.bash.d/00-system/00-config.sh" > /dev/null 2>&1
    [ -s "$CONFIG_FILE" ] && echo "scaffolded"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "scaffolded" ]
}
