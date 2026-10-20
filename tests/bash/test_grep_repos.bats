#!/usr/bin/env bats
# ------------------------------------------
# Bats: mt-grep-repos in .bash.d/20-vcs/50-git.sh
# ------------------------------------------
# Runs against a fake VCS_ROOT holding two work-scope repos and one personal repo.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/50-git.sh"
  CB_RED="" CB_GREEN="" CB_YELLOW="" CB_BLUE="" CB_CYAN="" C_RESET=""

  VCS_ROOT="$BATS_TEST_TMPDIR/vcs"
  work_repo="$VCS_ROOT/work/bitbucket/acme/proj/svc-a"
  other_repo="$VCS_ROOT/work/bitbucket/acme/proj/svc-b"
  personal_repo="$VCS_ROOT/personal/dotfiles"
  mkdir -p "$work_repo/.git" "$other_repo/.git" "$personal_repo/.git" "$work_repo/node_modules"
  echo 'redis_host = "10.0.0.1"' > "$work_repo/main.tf"
  echo 'redis_host: 10.0.0.2' > "$other_repo/values.yaml"
  echo 'redis_host=localhost' > "$personal_repo/env.sh"
  echo 'redis_host = "ignored"' > "$work_repo/node_modules/dep.tf"
  echo 'redis_host = "in-git"' > "$work_repo/.git/config"
}

@test "finds matches across all repos with line numbers" {
  run mt-grep-repos redis_host
  [ "$status" -eq 0 ]
  [[ "$output" == *"svc-a/main.tf:1:"* ]]
  [[ "$output" == *"svc-b/values.yaml:1:"* ]]
  [[ "$output" == *"dotfiles/env.sh:1:"* ]]
}

@test "skips .git and node_modules" {
  run mt-grep-repos redis_host
  [[ "$output" != *"node_modules"* ]]
  [[ "$output" != *".git/config"* ]]
}

@test "--scope personal limits the search" {
  run mt-grep-repos -s personal redis_host
  [[ "$output" == *"dotfiles/env.sh"* ]]
  [[ "$output" != *"svc-a"* ]]
}

@test "--glob restricts by file name" {
  run mt-grep-repos -g '*.tf' redis_host
  [[ "$output" == *"main.tf"* ]]
  [[ "$output" != *"values.yaml"* ]]
}

@test "--files-only prints paths without line content" {
  run mt-grep-repos -l -s personal redis_host
  [ "$output" = "$personal_repo/env.sh" ]
}

@test "--name lists files by name without a pattern" {
  run mt-grep-repos -N '*.yaml'
  [ "$status" -eq 0 ]
  [ "$output" = "$other_repo/values.yaml" ]
}

@test "returns 1 when nothing matches" {
  run mt-grep-repos no_such_string_anywhere
  [ "$status" -eq 1 ]
}

@test "returns 1 with usage when no pattern or name given" {
  run mt-grep-repos -s work
  [ "$status" -eq 1 ]
}

@test "rejects an invalid scope" {
  run mt-grep-repos -s bogus x
  [ "$status" -eq 1 ]
}
