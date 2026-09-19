#!/usr/bin/env bats
# ------------------------------------------
# Bats: mt-alias --private in .bash.d/02-utilities/99-utils.sh
# ------------------------------------------
# A private alias must land in 40-private/10-aliases.sh (never synced),
# leave the public 20-aliases.sh untouched, and be updatable via -u.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  CACHE_DIR="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$HOME/.bash.d/02-utilities" "$CACHE_DIR"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  printf "alias pub='echo public'\n" > "$HOME/.bash.d/02-utilities/20-aliases.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/99-utils.sh"
  mt-refresh-caches() { :; }
  private_file="$HOME/.bash.d/40-private/10-aliases.sh"
}

@test "mt-alias -p creates the alias in 40-private/10-aliases.sh" {
  printf 'pa\necho hi\nTest\nDesc\n' | mt-alias -p > /dev/null
  grep -qF "alias pa='echo hi'" "$private_file"
  ! grep -q "alias pa=" "$HOME/.bash.d/02-utilities/20-aliases.sh"
}

@test "mt-alias -p rejects a name that already exists publicly" {
  run bash -c 'source "'"$repo_root"'/.bash.d/02-utilities/99-utils.sh"; printf "pub\n" | mt-alias --private'
  [ "$status" -ne 0 ]
  [ ! -f "$private_file" ]
}

@test "mt-alias -u finds and rewrites a private alias in place" {
  printf 'pa\necho hi\nTest\nDesc\n' | mt-alias -p > /dev/null
  printf 'echo bye\nTest\nDesc\n' | mt-alias -u pa > /dev/null
  grep -qF "alias pa='echo bye'" "$private_file"
  ! grep -qF "echo hi" "$private_file"
}
