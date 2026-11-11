#!/usr/bin/env bats
# ------------------------------------------
# Bats: git-publish-check in .bash.d/20-vcs/62-publish-check.sh
# ------------------------------------------
# gitleaks and gh are stubs on PATH that log their argv; the repo is real.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/62-publish-check.sh"
  CB_RED="" CB_GREEN="" CB_YELLOW="" CB_BLUE="" C_RESET=""
  # shellcheck disable=SC2317
  mt-help() { echo "help called"; }
  unset GIT_PUBLIC_EMAIL_REGEX GIT_AI_ATTRIBUTION_REGEX

  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  export GH_LOG
  cat > "$fake_bin/gitleaks" << 'STUB'
#!/usr/bin/env bash
echo "gitleaks $*" >> "$GH_LOG.gitleaks"
report=""
while [ "$#" -gt 0 ]; do
  [ "$1" = "--report-path" ] && report="$2"
  shift
done
case "${STUB_GITLEAKS_MODE:-clean}" in
  findings) echo '[{"RuleID":"aws-key","File":"app.env","Commit":"abcdef1234567","StartLine":3,"Secret":"TOPSECRET123","Match":"KEY=TOPSECRET123"}]' > "$report" ;;
  clean) echo '[]' > "$report" ;;
  fail) exit 2 ;;
esac
STUB
  cat > "$fake_bin/gh" << 'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$GH_LOG"
if [ "$1 $2" = "repo view" ]; then
  echo "{\"nameWithOwner\":\"me/app\",\"visibility\":\"${STUB_GH_VISIBILITY:-PRIVATE}\"}"
fi
STUB
  chmod +x "$fake_bin/gitleaks" "$fake_bin/gh"
  PATH="$fake_bin:$PATH"

  work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work"
  cd "$work" || return 1
  git init -q -b main
  commit_as() { # <email> <message>
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL="$1" GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL="$1" \
      git commit -q --allow-empty -m "$2"
  }
}

@test "a personal email is reported with its commit count; a noreply address is not" {
  commit_as me@personal.example one
  commit_as me@personal.example two
  commit_as 123+me@users.noreply.github.com three
  run git-publish-check
  [ "$status" -eq 1 ]
  [[ "$output" == *$'me@personal.example\t2'* ]]
  [[ "$output" != *"users.noreply.github.com"$'\t'* ]]
  [[ "$output" == *"git filter-repo --mailmap"* ]]
}

@test "AI attribution trailers are reported; ordinary commits are not" {
  commit_as 1+me@users.noreply.github.com "plain change"
  commit_as 1+me@users.noreply.github.com "feat: thing

Co-Authored-By: Claude <noreply@anthropic.com>"
  run git-publish-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"feat: thing"* ]]
  [[ "$output" != *"plain change"* ]]
  [[ "$output" == *"git filter-repo --message-callback"* ]]
}

@test "secret findings print rule, file, short commit and line but never the secret" {
  commit_as 1+me@users.noreply.github.com clean
  STUB_GITLEAKS_MODE=findings run git-publish-check
  [ "$status" -eq 1 ]
  [[ "$output" == *$'aws-key\tapp.env\tabcdef1\t3'* ]]
  [[ "$output" != *TOPSECRET123* ]]
  [[ "$output" == *"Rotate the secret first"* ]]
  grep -q -- '--redact' "$GH_LOG.gitleaks"
  grep -q -- 'detect' "$GH_LOG.gitleaks"
}

@test "a clean repo exits 0" {
  commit_as 1+me@users.noreply.github.com clean
  run git-publish-check
  [ "$status" -eq 0 ]
  [[ "$output" != *"SKIPPED"* ]]
}

@test "missing gitleaks is a blocking SKIPPED result" {
  commit_as 1+me@users.noreply.github.com clean
  rm "$fake_bin/gitleaks"
  PATH="$fake_bin:/usr/bin:/bin" run git-publish-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"SKIPPED"* ]]
}

@test "a gitleaks failure is blocking" {
  commit_as 1+me@users.noreply.github.com clean
  STUB_GITLEAKS_MODE=fail run git-publish-check
  [ "$status" -eq 1 ]
  [[ "$output" == *"gitleaks failed"* ]]
}

@test "the email and attribution regexes can be overridden" {
  commit_as me@corp.example "Assisted by Claude"
  GIT_PUBLIC_EMAIL_REGEX='@corp\.example$' GIT_AI_ATTRIBUTION_REGEX='assisted by' run git-publish-check
  [ "$status" -eq 1 ]
  [[ "$output" != *$'me@corp.example\t'* ]]
  [[ "$output" == *"Assisted by Claude"* ]]
}

@test "--make-public with findings exits 1 and never calls gh" {
  commit_as me@personal.example one
  run git-publish-check --make-public --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not changing visibility"* ]]
  [ ! -f "$GH_LOG" ]
}

@test "--make-public --yes on a clean repo calls gh repo edit" {
  commit_as 1+me@users.noreply.github.com clean
  run git-publish-check --make-public --yes
  [ "$status" -eq 0 ]
  grep -qF 'gh repo edit me/app --visibility public --accept-visibility-change-consequences' "$GH_LOG"
}

@test "--make-public without --yes and without a terminal refuses" {
  commit_as 1+me@users.noreply.github.com clean
  run git-publish-check --make-public
  [ "$status" -eq 1 ]
  [[ "$output" == *"--yes"* ]]
  ! grep -q 'repo edit' "$GH_LOG"
}

@test "--make-public on an already public repo does not edit it" {
  commit_as 1+me@users.noreply.github.com clean
  STUB_GH_VISIBILITY=PUBLIC run git-publish-check --make-public --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"already public"* ]]
  ! grep -q 'repo edit' "$GH_LOG"
}

@test "--make-public exits 1 when gh cannot read the repository" {
  commit_as 1+me@users.noreply.github.com clean
  printf '#!/usr/bin/env bash\nexit 1\n' > "$fake_bin/gh"
  run git-publish-check --make-public --yes
  [ "$status" -eq 1 ]
}

@test "fails outside a git repository and on bad usage" {
  cd "$BATS_TEST_TMPDIR" || return 1
  GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run git-publish-check
  [ "$status" -eq 1 ]
  run git-publish-check --bogus
  [ "$status" -eq 1 ]
}

@test "-h shows help" {
  run git-publish-check -h
  [ "$output" = "help called" ]
}
