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

# --- remote-tracking branch search (-b / -B / -u), against real temp repos ---

make_ref_repo() {
  ref_repo="$VCS_ROOT/personal/refs-repo"
  mkdir -p "$ref_repo"
  git -C "$ref_repo" init -q -b main
  git -C "$ref_repo" config user.email "t@example.test"
  git -C "$ref_repo" config user.name "T"
  echo 'shared_line = 1' > "$ref_repo/app.tf"
  git -C "$ref_repo" add app.tf
  git -C "$ref_repo" commit -q -m base
  base_sha=$(git -C "$ref_repo" rev-parse HEAD)
  echo 'only_on_feature = 1' > "$ref_repo/feature.txt"
  echo 'only_on_feature = 1' > "$ref_repo/feature.tf"
  git -C "$ref_repo" add feature.txt feature.tf
  git -C "$ref_repo" commit -q -m feature
  feature_sha=$(git -C "$ref_repo" rev-parse HEAD)
  git -C "$ref_repo" update-ref refs/remotes/origin/main "$base_sha"
  git -C "$ref_repo" update-ref refs/remotes/origin/feature-x "$feature_sha"
  git -C "$ref_repo" update-ref refs/remotes/origin/release/1.0 "$feature_sha"
  git -C "$ref_repo" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  git -C "$ref_repo" reset -q --hard "$base_sha"
}

@test "-B finds a match that exists only on a remote branch; without it the match is missed" {
  make_ref_repo
  run mt-grep-repos only_on_feature
  [ "$status" -eq 1 ]
  run mt-grep-repos -B only_on_feature
  [ "$status" -eq 0 ]
  [[ "$output" == *"personal/refs-repo/origin/feature-x:feature.txt:1:only_on_feature = 1"* ]]
}

@test "-b limits the search to the matching refs" {
  make_ref_repo
  run mt-grep-repos -b 'origin/release/*' only_on_feature
  [ "$status" -eq 0 ]
  [[ "$output" == *"personal/refs-repo/origin/release/1.0:feature.txt"* ]]
  [[ "$output" != *"origin/feature-x"* ]]
}

@test "origin/HEAD is not searched as a separate ref" {
  make_ref_repo
  run mt-grep-repos -B shared_line
  [[ "$output" != *"origin/HEAD"* ]]
  [[ "$output" == *"origin/main:app.tf:1:"* ]]
}

@test "--unique merges identical hits across refs into one line" {
  make_ref_repo
  run mt-grep-repos -B -u only_on_feature
  [ "$status" -eq 0 ]
  [[ "$output" == *"personal/refs-repo/origin/feature-x,origin/release/1.0:feature.txt:1:only_on_feature = 1"* ]]
  [ "$(grep -c 'feature.txt' <<< "$output")" -eq 1 ]
}

@test "-B honours --glob and --files-only" {
  make_ref_repo
  run mt-grep-repos -B -g '*.tf' -l only_on_feature
  [ "$status" -eq 0 ]
  [[ "$output" == *"origin/feature-x:feature.tf"* ]]
  [[ "$output" != *"feature.txt"* ]]
}

@test "-N combined with -B is a usage error" {
  run mt-grep-repos -B -N '*.tf'
  [ "$status" -eq 1 ]
  [[ "$output" == *"-N is not supported"* ]]
}

@test "--unique without -b or -B is a usage error" {
  run mt-grep-repos -u redis_host
  [ "$status" -eq 1 ]
}

@test "-B on repos without remote refs finds nothing and does not fail the run" {
  run mt-grep-repos -B redis_host
  [ "$status" -eq 1 ]
}
