#!/usr/bin/env bats
# ------------------------------------------
# Bats: git-diff-all in .bash.d/20-vcs/50-git.sh
# ------------------------------------------
# Runs in a throwaway repo; the real index must be byte-identical after.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/50-git.sh"
  # shellcheck disable=SC2317
  mt-help() { :; }
  work="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$work"
  cd "$work" || return 1
  git init -q .
  git config user.email t@example.test
  git config user.name t
  echo one > tracked.txt
  echo keep > staged.txt
  git add . && git commit -q -m init
}

@test "shows unstaged, staged and untracked changes in one diff" {
  echo two >> tracked.txt
  echo more >> staged.txt && git add staged.txt
  echo fresh > untracked.txt
  run git-diff-all
  [ "$status" -eq 0 ]
  [[ "$output" == *"+two"* ]]
  [[ "$output" == *"+more"* ]]
  [[ "$output" == *"+++ b/untracked.txt"* ]]
  [[ "$output" == *"+fresh"* ]]
}

@test "does not modify the real index or status" {
  echo two >> tracked.txt
  echo fresh > untracked.txt
  git status --porcelain > "$BATS_TEST_TMPDIR/before"
  index_before=$(sha256sum .git/index)
  run git-diff-all
  git status --porcelain > "$BATS_TEST_TMPDIR/after"
  diff "$BATS_TEST_TMPDIR/before" "$BATS_TEST_TMPDIR/after"
  [ "$index_before" = "$(sha256sum .git/index)" ]
}

@test "ignored files are left out" {
  echo "*.log" > .gitignore
  git add .gitignore && git commit -q -m ignore
  echo noise > debug.log
  run git-diff-all
  [[ "$output" != *debug.log* ]]
}

@test "--stat prints a diffstat" {
  echo fresh > untracked.txt
  run git-diff-all --stat
  [[ "$output" == *"untracked.txt"* ]]
  [[ "$output" == *"changed"* ]]
}

@test "pathspec limits the output" {
  echo two >> tracked.txt
  echo fresh > untracked.txt
  run git-diff-all -- untracked.txt
  [[ "$output" == *untracked.txt* ]]
  [[ "$output" != *"+two"* ]]
}

@test "works in a repository with no commits" {
  rm -rf .git && git init -q .
  echo fresh > new.txt
  run git-diff-all
  [ "$status" -eq 0 ]
  [[ "$output" == *"+fresh"* ]]
}

@test "outside a repository returns 1" {
  cd "$BATS_TEST_TMPDIR" && mkdir plain && cd plain
  GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run git-diff-all
  [ "$status" -eq 1 ]
}
