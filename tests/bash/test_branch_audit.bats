#!/usr/bin/env bats
# ------------------------------------------
# Bats: mt-branch-audit in .bash.d/20-vcs/61-branch-audit.sh
# ------------------------------------------
# Real git repos: a bare "remote" with main as HEAD, cloned into a temp VCS_ROOT.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/50-git.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/61-branch-audit.sh"
  CB_RED="" CB_YELLOW="" C_RESET=""
  # shellcheck disable=SC2317
  mt-help() { echo "help called"; }
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

  VCS_ROOT="$BATS_TEST_TMPDIR/vcs"
  export VCS_ROOT
  remote="$BATS_TEST_TMPDIR/remote.git"
  seed="$BATS_TEST_TMPDIR/seed"
  git init -q --bare -b main "$remote"
  git init -q -b main "$seed"
  git -C "$seed" remote add origin "$remote"
  echo base > "$seed/f"
  git -C "$seed" add f
  git -C "$seed" commit -q -m base
  git -C "$seed" push -q origin main
  git -C "$seed" branch staging
  git -C "$seed" branch feature/x
  git -C "$seed" checkout -q -b develop
  echo dev > "$seed/d"
  git -C "$seed" add d
  git -C "$seed" commit -q -m dev
  git -C "$seed" push -q origin develop staging feature/x
  git -C "$seed" checkout -q main

  mkdir -p "$VCS_ROOT/personal" "$VCS_ROOT/work"
  git clone -q "$remote" "$VCS_ROOT/personal/app"
  git init -q -b main "$BATS_TEST_TMPDIR/solo-remote"
  echo s > "$BATS_TEST_TMPDIR/solo-remote/s"
  git -C "$BATS_TEST_TMPDIR/solo-remote" add s
  git -C "$BATS_TEST_TMPDIR/solo-remote" commit -q -m s
  git clone -q "$BATS_TEST_TMPDIR/solo-remote" "$VCS_ROOT/personal/solo"
}

@test "an unmerged retired branch is UNSAFE, a merged one SAFE, others are ignored, a clean repo is CLEAN" {
  run mt-branch-audit
  [ "$status" -eq 0 ]
  [[ "$output" == *$'personal/app\tmain\tdevelop\t1\t'*$'\tUNSAFE'* ]]
  [[ "$output" == *$'personal/app\tmain\tstaging\t0\t'*$'\tSAFE'* ]]
  [[ "$output" != *"feature/x"* ]]
  [[ "$output" == *$'personal/solo\tmain\t-\t0\t-\tCLEAN'* ]]
}

@test "--pattern overrides the configured regex" {
  run mt-branch-audit --pattern '^feature/'
  [ "$status" -eq 0 ]
  [[ "$output" == *$'personal/app\tmain\tfeature/x\t0\t'*$'\tSAFE'* ]]
  [[ "$output" != *"develop"* ]]
}

@test "GIT_RETIRED_BRANCH_REGEX from config is used when no --pattern is given" {
  GIT_RETIRED_BRANCH_REGEX='^develop$' run mt-branch-audit
  [[ "$output" == *"develop"* ]]
  [[ "$output" != *"staging"* ]]
}

@test "an invalid regex exits 1 before touching any repo" {
  run mt-branch-audit --pattern '('
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid --pattern"* ]]
}

@test "a stale local origin/HEAD is warned about and the default column shows the live default" {
  git -C "$VCS_ROOT/personal/app" remote set-head origin develop
  run mt-branch-audit
  [ "$status" -eq 0 ]
  [[ "$output" == *"local origin/HEAD is develop but the remote default is main"* ]]
  [[ "$output" == *$'personal/app\tmain\t'* ]]
  [ "$(git -C "$VCS_ROOT/personal/app" symbolic-ref --short refs/remotes/origin/HEAD)" = "origin/develop" ]
}

@test "--no-fetch reports a live branch pushed after cloning as not fetched; fetching reports it" {
  git -C "$seed" push -q origin main:qa
  run mt-branch-audit --no-fetch
  [ "$status" -eq 1 ]
  [[ "$output" == *$'personal/app\tmain\tqa\t-\t-\tERROR (not fetched)'* ]]
  run mt-branch-audit
  [ "$status" -eq 0 ]
  [[ "$output" == *$'personal/app\tmain\tqa\t0\t'*$'\tSAFE'* ]]
}

@test "a branch deleted on the remote is no longer reported" {
  git -C "$seed" push -q origin :develop
  run mt-branch-audit --no-fetch
  [[ "$output" != *"develop"* ]]
}

@test "a single-branch clone still reports an unmerged retired branch" {
  rm -rf "$VCS_ROOT/personal/app"
  git clone -q --single-branch "$remote" "$VCS_ROOT/personal/app"
  run mt-branch-audit -pr app
  [ "$status" -eq 0 ]
  [[ "$output" == *$'personal/app\tmain\tdevelop\t1\t'*$'\tUNSAFE'* ]]
}

@test "a single-branch clone with --no-fetch reports develop as not fetched" {
  rm -rf "$VCS_ROOT/personal/app"
  git clone -q --single-branch "$remote" "$VCS_ROOT/personal/app"
  run mt-branch-audit -pr app --no-fetch
  [ "$status" -eq 1 ]
  [[ "$output" == *$'personal/app\tmain\tdevelop\t-\t-\tERROR (not fetched)'* ]]
}

@test "a shallow clone is an error" {
  rm -rf "$VCS_ROOT/personal/app"
  git clone -q --depth 1 "file://$remote" "$VCS_ROOT/personal/app"
  run mt-branch-audit -pr app
  [ "$status" -eq 1 ]
  [[ "$output" == *$'personal/app\t-\t-\t-\t-\tERROR (shallow clone)'* ]]
}

@test "a clone whose only fetched branch is not the remote default reports the default as not fetched" {
  rm -rf "$VCS_ROOT/personal/app"
  git clone -q --single-branch -b develop "$remote" "$VCS_ROOT/personal/app"
  run mt-branch-audit -pr app --no-fetch
  [ "$status" -eq 1 ]
  [[ "$output" == *$'personal/app\tmain\t-\t-\t-\tERROR (default branch not fetched)'* ]]
}

@test "an unreachable remote gives an ERROR row and exit 1 while other repos are still reported" {
  rm -rf "$remote"
  run mt-branch-audit
  [ "$status" -eq 1 ]
  [[ "$output" == *$'personal/app\t-\t-\t-\t-\tERROR (fetch failed)'* ]]
  [[ "$output" == *$'personal/solo\tmain\t-\t0\t-\tCLEAN'* ]]
}

@test "--no-fetch with an unreachable remote reports an ls-remote error" {
  rm -rf "$remote"
  run mt-branch-audit --no-fetch
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR (ls-remote failed)"* ]]
}

@test "a repo without an origin is skipped with a note" {
  git init -q -b main "$VCS_ROOT/personal/local-only"
  run mt-branch-audit
  [ "$status" -eq 0 ]
  [[ "$output" == *"local-only: no origin remote, skipped"* ]]
}

@test "-s work with no work repos warns and exits 0" {
  run mt-branch-audit -s work
  [ "$status" -eq 0 ]
  [[ "$output" == *"No repositories matched"* ]]
}

@test "-pr limits the audit to one personal repo" {
  run mt-branch-audit -pr solo
  [[ "$output" == *"personal/solo"* ]]
  [[ "$output" != *"personal/app"* ]]
}

@test "bad usage and a missing VCS root exit 1" {
  run mt-branch-audit --bogus
  [ "$status" -eq 1 ]
  run mt-branch-audit -s nowhere
  [ "$status" -eq 1 ]
  VCS_ROOT="$BATS_TEST_TMPDIR/missing" run mt-branch-audit
  [ "$status" -eq 1 ]
}

@test "the command never deletes a branch" {
  run mt-branch-audit
  git -C "$remote" rev-parse --verify -q refs/heads/develop
  git -C "$VCS_ROOT/personal/app" rev-parse --verify -q refs/remotes/origin/develop
}

@test "-h shows help" {
  run mt-branch-audit -h
  [ "$output" = "help called" ]
}
