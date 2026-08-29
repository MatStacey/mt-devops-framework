#!/usr/bin/env bats
# ------------------------------------------
# Bats: the pure/near-pure helper functions in .bash.d/20-vcs/52-git-sync.sh
# ------------------------------------------
# 52-git-sync.sh drives mt-push-update/mt-get-update -- the mechanism
# that rewrites a user's ~/.bash.d and touches their git history on
# every update -- and had zero behavioral test coverage before this
# file. It has no top-level side effects (pure function definitions
# only), so it's sourced directly rather than through the symlinked-
# .bash.d skeleton test_path_resolution.bats needs for 00-config.sh.
#
# The three message/branch-naming functions here (trim/pr_title/
# branch_slug) were extracted from inline code specifically to make
# them testable, after a real live bug: grep/sed anchor ^/$ to every
# LINE, not the whole string, so feeding them a correctly multi-line
# commit message (once a separate xargs-flattening bug was fixed)
# produced a garbled, multi-line branch name and silently broke
# mt-push-update mid-run. These tests exist to make sure that
# specific failure mode can't come back unnoticed.

setup() {
  load_target="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/.bash.d/20-vcs/52-git-sync.sh"
  # shellcheck disable=SC1090
  source "$load_target"
}

# ---------- __mt_push_update_trim_message ----------

@test "trim_message strips leading/trailing whitespace, preserves embedded newlines" {
  result=$(__mt_push_update_trim_message "  fix: something

Body paragraph one.

Body paragraph two.  ")
  expected="fix: something

Body paragraph one.

Body paragraph two."
  [ "$result" = "$expected" ]
}

@test "trim_message on empty input returns empty" {
  result=$(__mt_push_update_trim_message "")
  [ -z "$result" ]
}

@test "trim_message on whitespace-only input returns empty" {
  result=$(__mt_push_update_trim_message "   ")
  [ -z "$result" ]
}

# ---------- __mt_push_update_derive_pr_title ----------

@test "derive_pr_title returns only the first line of a multi-paragraph message" {
  result=$(__mt_push_update_derive_pr_title "chore: add LICENSE

Closes the one genuinely blocking gap from the readiness review.")
  [ "$result" = "chore: add LICENSE" ]
}

@test "derive_pr_title on a single-line message returns it unchanged" {
  result=$(__mt_push_update_derive_pr_title "fix: a single line message")
  [ "$result" = "fix: a single line message" ]
}

@test "derive_pr_title on empty input returns empty" {
  result=$(__mt_push_update_derive_pr_title "")
  [ -z "$result" ]
}

# ---------- __mt_push_update_derive_branch_slug ----------

@test "derive_branch_slug produces type/slug from a conventional-commit title" {
  result=$(__mt_push_update_derive_branch_slug "chore: add LICENSE (MIT) and SECURITY.md")
  [ "$result" = "chore/add-license-mit-and-security-md" ]
}

@test "derive_branch_slug strips a scoped type's parenthetical" {
  result=$(__mt_push_update_derive_branch_slug "fix(config): Add Thing!")
  [ "$result" = "fix/add-thing" ]
}

@test "derive_branch_slug on empty input returns empty (caller supplies the timestamp fallback)" {
  result=$(__mt_push_update_derive_branch_slug "")
  [ -z "$result" ]
}

@test "derive_branch_slug caps the slug at 40 characters" {
  result=$(__mt_push_update_derive_branch_slug "feat: this is a very long commit subject line that definitely exceeds forty characters of slug")
  slug="${result#*/}"
  [ "${#slug}" -le 40 ]
}

@test "derive_branch_slug output is always exactly one line -- the exact regression this suite guards against" {
  # The historical bug: feeding a *multi-line* title (which should never
  # happen now that callers always pass the already-first-line-only
  # pr_title, but pin the single-line guarantee down directly) produced
  # a multi-line result that silently broke `git checkout -b`.
  result=$(__mt_push_update_derive_branch_slug "chore: add LICENSE (MIT) and SECURITY.md")
  line_count=$(printf '%s' "$result" | wc -l)
  [ "$line_count" -eq 0 ]
  git check-ref-format --branch "$result"
}

# ---------- __mt_reconcile_ignore_patterns ----------

@test "reconcile_ignore_patterns creates the target and appends all template lines when target is missing" {
  template="$BATS_TEST_TMPDIR/template"
  target="$BATS_TEST_TMPDIR/target"
  printf 'foo\nbar\n' > "$template"

  __mt_reconcile_ignore_patterns "$template" "$target"

  [ -f "$target" ]
  [ "$(cat "$target")" = "$(printf 'foo\nbar')" ]
}

@test "reconcile_ignore_patterns does not duplicate a pattern already present in target" {
  template="$BATS_TEST_TMPDIR/template"
  target="$BATS_TEST_TMPDIR/target"
  printf 'foo\nbar\n' > "$template"
  printf 'foo\n' > "$target"

  __mt_reconcile_ignore_patterns "$template" "$target"

  count=$(grep -c '^foo$' "$target")
  [ "$count" -eq 1 ]
  grep -qxF 'bar' "$target"
}

@test "reconcile_ignore_patterns skips blank lines and comments in the template" {
  template="$BATS_TEST_TMPDIR/template"
  target="$BATS_TEST_TMPDIR/target"
  printf '# a comment\n\nfoo\n' > "$template"
  : > "$target"

  __mt_reconcile_ignore_patterns "$template" "$target"

  ! grep -qF '# a comment' "$target"
  [ "$(cat "$target")" = "foo" ]
}

@test "reconcile_ignore_patterns is a no-op (returns 0, no error) when the template is missing" {
  target="$BATS_TEST_TMPDIR/target"
  run __mt_reconcile_ignore_patterns "$BATS_TEST_TMPDIR/does-not-exist" "$target"
  [ "$status" -eq 0 ]
  [ ! -f "$target" ]
}

# ---------- __mt_bashd_is_symlinked_into_repo ----------

@test "is_symlinked_into_repo is false when ~/.bash.d is a real directory" {
  fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home/.bash.d" "$fake_home/repo/.bash.d"
  run env HOME="$fake_home" bash -c "
    source '$load_target'
    __mt_bashd_is_symlinked_into_repo '$fake_home/repo'
  "
  [ "$status" -eq 1 ]
}

@test "is_symlinked_into_repo is true when ~/.bash.d symlinks to the given repo's .bash.d" {
  fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home/repo/.bash.d"
  ln -s "$fake_home/repo/.bash.d" "$fake_home/.bash.d"
  run env HOME="$fake_home" bash -c "
    source '$load_target'
    __mt_bashd_is_symlinked_into_repo '$fake_home/repo'
  "
  [ "$status" -eq 0 ]
}

@test "is_symlinked_into_repo is false when ~/.bash.d symlinks to a different repo" {
  fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home/repo-a/.bash.d" "$fake_home/repo-b/.bash.d"
  ln -s "$fake_home/repo-a/.bash.d" "$fake_home/.bash.d"
  run env HOME="$fake_home" bash -c "
    source '$load_target'
    __mt_bashd_is_symlinked_into_repo '$fake_home/repo-b'
  "
  [ "$status" -eq 1 ]
}
