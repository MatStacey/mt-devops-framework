#!/usr/bin/env bats
# ------------------------------------------
# Bats: git-review-prs in .bash.d/20-vcs/50-git.sh
# ------------------------------------------
# gh is stubbed; the base-branch diff runs against a real temp repo.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/50-git.sh"
  CB_RED="" CB_BLUE="" C_RESET=""
  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  PATH="$fake_bin:$PATH"
  printf '#!/usr/bin/env bash\necho "gh $*"\n' > "$fake_bin/gh"
  chmod +x "$fake_bin/gh"

  work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work"
  cd "$work" || return 1
  git init -q -b main
  git config user.email t@t
  git config user.name t
  echo one > f.txt
  git add f.txt
  git commit -q -m base
  git checkout -q -b feature
  echo two >> f.txt
  git commit -q -am change
}

@test "lists open pull requests by default" {
  run git-review-prs
  [ "$status" -eq 0 ]
  [[ "$output" == *"gh pr list"* ]]
}

@test "--pr shows that pull request's diff" {
  run git-review-prs -n 42
  [[ "$output" == *"gh pr diff 42"* ]]
}

@test "--pr with --stat lists changed files" {
  run git-review-prs -n 42 -s
  [[ "$output" == *"gh pr diff 42 --name-only"* ]]
}

@test "--base diffs HEAD against the named branch" {
  run git-review-prs -b main
  [ "$status" -eq 0 ]
  [[ "$output" == *"+two"* ]]
}

@test "--base --stat shows a diffstat" {
  run git-review-prs -b main -s
  [[ "$output" == *"f.txt | 1 +"* ]]
}

@test "fails outside a git repository" {
  cd "$BATS_TEST_TMPDIR" || return 1
  GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run git-review-prs
  [ "$status" -eq 1 ]
}

@test "rejects unknown options" {
  run git-review-prs --bogus
  [ "$status" -eq 1 ]
}
