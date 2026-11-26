#!/usr/bin/env bats
# ------------------------------------------
# Bats: git-raise-pr prompts without a controlling terminal
# ------------------------------------------
# Each case runs under `setsid -w ... < /dev/null`, so there is no
# controlling terminal and /dev/tty cannot be opened. gh, git and
# __open_url are stubbed and log their arguments.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  CALL_LOG="$BATS_TEST_TMPDIR/calls.log"
  DRIVER="$BATS_TEST_TMPDIR/driver.sh"
  export repo_root CALL_LOG
  cat > "$DRIVER" << 'EOF'
source "$repo_root/.bash.d/02-utilities/99-utils.sh"
source "$repo_root/.bash.d/20-vcs/50-git.sh"
gh() {
  echo "gh $*" >> "$CALL_LOG"
  echo "${STUB_PR_STATE:-MERGED}"
}
git() {
  echo "git $*" >> "$CALL_LOG"
  [ "$*" = "config --get remote.origin.url" ] && echo "git@github.com:me/repo.git"
  return 0
}
__open_url() { echo "open $*" >> "$CALL_LOG"; }
eval "$1"
EOF
}

# Runs a snippet in the driver with no controlling terminal.
run_without_tty() {
  run setsid -w bash "$DRIVER" "$1" < /dev/null
}

@test "__mt_has_tty fails without a controlling terminal" {
  run_without_tty '__mt_has_tty; echo "rc=$?"'
  [ "$output" = "rc=1" ]
}

@test "__mt_has_tty succeeds inside a pseudo-terminal" {
  run script -qec "bash -c 'source \"$repo_root/.bash.d/02-utilities/99-utils.sh\"; __mt_has_tty'" /dev/null
  [ "$status" -eq 0 ]
}

@test "the browser prompt returns 1 silently and opens nothing without a terminal" {
  run setsid -w bash -c 'bash "$1" "__git_raise_pr_confirm_open_browser && __open_url https://x; echo \"rc=\$?\"" 2> "$2"' _ "$DRIVER" "$BATS_TEST_TMPDIR/stderr" < /dev/null
  [ "$output" = "rc=1" ]
  [ ! -s "$BATS_TEST_TMPDIR/stderr" ]
  [ ! -f "$CALL_LOG" ] || ! grep -q '^open' "$CALL_LOG"
}

@test "a merged PR without a terminal stops with a warning and deletes nothing" {
  run_without_tty 'current_branch=feat; target_branch=main; __git_raise_pr_handle_dead_pr; echo "action=$__git_raise_pr_dead_pr_action"'
  [[ "$output" == *"This branch has a MERGED PR. Run git-raise-pr from a terminal to recycle it, or check out a new branch."* ]]
  [[ "$output" == *"action=error" ]]
  [[ "$output" != *"/dev/tty"* ]]
  grep -q '^gh pr view feat' "$CALL_LOG"
  ! grep -q -- '--delete' "$CALL_LOG"
  ! grep -qE '^git (checkout|branch)' "$CALL_LOG"
}

@test "a closed PR without a terminal stops the same way" {
  STUB_PR_STATE=CLOSED run_without_tty 'current_branch=feat; __git_raise_pr_handle_dead_pr; echo "action=$__git_raise_pr_dead_pr_action"'
  [[ "$output" == *"This branch has a CLOSED PR."* ]]
  [[ "$output" == *"action=error" ]]
  [[ "$output" != *"/dev/tty"* ]]
}

@test "an open PR without a terminal still pushes" {
  STUB_PR_STATE=OPEN run_without_tty 'current_branch=feat; __git_raise_pr_handle_dead_pr; echo "action=$__git_raise_pr_dead_pr_action"'
  [[ "$output" == *"action=done" ]]
  grep -q '^git push origin feat$' "$CALL_LOG"
}

@test "each prompt helper has exactly one docstring block directly above it" {
  local fn
  for fn in __git_raise_pr_confirm_open_browser __git_raise_pr_create_or_open __mt_has_tty; do
    run awk -v fn="$fn" -f "$BATS_TEST_DIRNAME/fixtures/git_raise_pr/docstring_blocks.awk" \
      "$repo_root/.bash.d/20-vcs/50-git.sh" "$repo_root/.bash.d/02-utilities/99-utils.sh"
    [ "$output" = "1" ]
  done
}
