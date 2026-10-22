#!/usr/bin/env bats
# ------------------------------------------
# Bats: mt-suggest in .bash.d/03-mytools/10-backlog.sh
# ------------------------------------------
# mt-suggest is the framework's backlog-capture command (see
# docs/TEAM_INTEGRATION.md): file a workflow-gap issue against the
# framework's own repo from wherever the gap was actually noticed.
# These tests cover only the fully-argument-given (non-interactive)
# path -- the prompt fallbacks need a real controlling terminal
# (`read ... < /dev/tty`), which CI runners don't have any more than
# this file's own sandbox does; that path was verified manually via a
# real pseudo-terminal during development instead (see memory).
#
# `gh` is stubbed with a fake script that records its own arguments,
# same technique test_secrets.bats uses to stub the Python secrets
# manager call.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/03-mytools/10-backlog.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/50-git.sh"

  VCS_ROOT="$BATS_TEST_TMPDIR/vcs"
  work_repo="$VCS_ROOT/work/bitbucket/acme-corp/secret-project/internal-svc"
  personal_repo="$VCS_ROOT/personal/my-private-repo"
  mkdir -p "$work_repo/src" "$personal_repo"

  # Consumed by mt-suggest itself (sourced above); shellcheck can't see
  # that from this file alone since the source path is dynamic.
  # shellcheck disable=SC2034
  UPSTREAM_REPO_PATH="TestOwner/test-repo"
  # shellcheck disable=SC2034
  VERSION_FILE="$BATS_TEST_TMPDIR/does-not-exist"

  gh_calls_dir="$BATS_TEST_TMPDIR/gh-calls"
  mkdir -p "$gh_calls_dir"
  gh_fixture="$BATS_TEST_TMPDIR/gh"
  cat > "$gh_fixture" << SHEOF
#!/usr/bin/env bash
i=0
while [ -e "$gh_calls_dir/\$i" ]; do i=\$((i + 1)); done
printf '%s\n' "\$@" > "$gh_calls_dir/\$i"
echo "https://github.com/TestOwner/test-repo/issues/42"
SHEOF
  chmod +x "$gh_fixture"
  PATH="$BATS_TEST_TMPDIR:$PATH"

  mt-help() { echo "help called"; }
}

last_gh_call() {
  cat "$gh_calls_dir/0"
}

@test "mt-suggest with full args files a bug-labeled issue with the given title" {
  run mt-suggest --bug --context "testing" "no bulk rotate command"
  [ "$status" -eq 0 ]

  local call
  call="$(last_gh_call)"
  grep -qxF -- "--repo" <<< "$call"
  grep -qxF -- "TestOwner/test-repo" <<< "$call"
  grep -qxF -- "[Workflow Gap] no bulk rotate command" <<< "$call"
  grep -qxF -- "bug" <<< "$call"
  grep -qxF -- "workflow-gap" <<< "$call"
}

@test "mt-suggest without --bug defaults to the enhancement label" {
  run mt-suggest --context "testing" "some idea"
  [ "$status" -eq 0 ]

  local call
  call="$(last_gh_call)"
  grep -qxF -- "enhancement" <<< "$call"
  run grep -qxF -- "bug" <<< "$call"
  [ "$status" -ne 0 ]
}

@test "mt-suggest's issue body includes the given context" {
  run mt-suggest --context "building the menu feature" "some idea"
  [ "$status" -eq 0 ]

  grep -qF -- "building the menu feature" <<< "$(last_gh_call)"
}

@test "mt-suggest from a work repo records only the scope, never the path" {
  cd "$work_repo/src"
  run mt-suggest --context "testing" "some idea"
  [ "$status" -eq 0 ]

  local call
  call="$(last_gh_call)"
  grep -qF -- "- Location: work repository" <<< "$call"
  run grep -qE -- "acme-corp|secret-project|internal-svc|$BATS_TEST_TMPDIR" <<< "$call"
  [ "$status" -ne 0 ]
}

@test "mt-suggest from a personal repo records only the scope, never the repo name" {
  cd "$personal_repo"
  run mt-suggest --context "testing" "some idea"
  [ "$status" -eq 0 ]

  local call
  call="$(last_gh_call)"
  grep -qF -- "- Location: personal repository" <<< "$call"
  run grep -qF -- "my-private-repo" <<< "$call"
  [ "$status" -ne 0 ]
}

@test "mt-suggest outside VCS_ROOT does not record the directory" {
  cd "$BATS_TEST_TMPDIR"
  run mt-suggest --context "testing" "some idea"
  [ "$status" -eq 0 ]

  local call
  call="$(last_gh_call)"
  grep -qF -- "- Location: outside the VCS root" <<< "$call"
  run grep -qF -- "$BATS_TEST_TMPDIR" <<< "$call"
  [ "$status" -ne 0 ]
}

@test "mt-suggest reports failure and returns non-zero when gh fails" {
  cat > "$gh_fixture" << 'SHEOF'
#!/usr/bin/env bash
echo "authentication error" >&2
exit 1
SHEOF
  chmod +x "$gh_fixture"

  run mt-suggest --context "testing" "some idea"
  [ "$status" -eq 1 ]
  grep -qF -- "Failed to file the issue" <<< "$output"
}

@test "mt-suggest accepts a multi-word unquoted description" {
  run mt-suggest --context "testing" no bulk rotate command
  [ "$status" -eq 0 ]

  local call
  call="$(last_gh_call)"
  grep -qxF -- "[Workflow Gap] no bulk rotate command" <<< "$call"
}
