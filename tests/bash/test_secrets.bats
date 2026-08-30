#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# ------------------------------------------
# Bats: __mt_write_secret / __mt_delete_secret in .bash.d/00-system/01-secrets.sh
# ------------------------------------------
# These two functions are the only place the framework ever writes to or
# mutates ~/secrets/secrets.sh -- every mt-add-*-key/secret command and
# the Secrets Manager's delete flow all funnel through them. Neither had
# any behavioral test coverage before this file (part of the product
# readiness review's P1). 01-secrets.sh has no top-level side effects,
# so it's sourced directly, same as 52-git-sync.sh.
#
# __mt_delete_secret's python3 unregister call is stubbed out with a
# fake SECRETS_MANAGER script that just records its own arguments --
# these tests are about the bash-side file/env mutation, not the real
# Python secrets registry.

setup() {
  load_target="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/.bash.d/00-system/01-secrets.sh"
  # shellcheck disable=SC1090
  source "$load_target"

  SECRETS_DIR="$BATS_TEST_TMPDIR/secrets"
  SECRETS_FILE="$SECRETS_DIR/secrets.sh"

  fake_manager_calls="$BATS_TEST_TMPDIR/fake_manager_calls.log"
  SECRETS_MANAGER="$BATS_TEST_TMPDIR/fake_secrets_manager.py"
  cat > "$SECRETS_MANAGER" << PYEOF
import sys
with open("$fake_manager_calls", "a") as f:
    f.write(" ".join(sys.argv[1:]) + "\n")
PYEOF
}

# ---------- __mt_write_secret ----------

@test "write_secret creates SECRETS_DIR/SECRETS_FILE with correct permissions on first write" {
  __mt_write_secret "MY_TOKEN" "abc123"

  [ -d "$SECRETS_DIR" ]
  [ -f "$SECRETS_FILE" ]
  [ "$(stat -c '%a' "$SECRETS_DIR")" = "700" ]
  [ "$(stat -c '%a' "$SECRETS_FILE")" = "600" ]
  grep -qF 'export MY_TOKEN=abc123' "$SECRETS_FILE"
}

@test "write_secret appends a new variable without disturbing existing ones" {
  __mt_write_secret "FIRST_TOKEN" "one"
  __mt_write_secret "SECOND_TOKEN" "two"

  grep -qF 'export FIRST_TOKEN=one' "$SECRETS_FILE"
  grep -qF 'export SECOND_TOKEN=two' "$SECRETS_FILE"
  [ "$(grep -c '^export ' "$SECRETS_FILE")" -eq 2 ]
}

@test "write_secret updates an existing variable in place instead of duplicating it" {
  __mt_write_secret "MY_TOKEN" "old-value"
  __mt_write_secret "OTHER_TOKEN" "unrelated"
  __mt_write_secret "MY_TOKEN" "new-value"

  [ "$(grep -c '^export MY_TOKEN=' "$SECRETS_FILE")" -eq 1 ]
  grep -qF 'export MY_TOKEN=new-value' "$SECRETS_FILE"
  run ! grep -qF 'old-value' "$SECRETS_FILE"
  # Updating in place must not disturb the other variable's line.
  grep -qF 'export OTHER_TOKEN=unrelated' "$SECRETS_FILE"
}

@test "write_secret re-writing the same value is idempotent" {
  __mt_write_secret "MY_TOKEN" "same-value"
  __mt_write_secret "MY_TOKEN" "same-value"

  [ "$(grep -c '^export MY_TOKEN=' "$SECRETS_FILE")" -eq 1 ]
  grep -qF 'export MY_TOKEN=same-value' "$SECRETS_FILE"
}

@test "write_secret does not corrupt the previous line when the file is missing a trailing newline" {
  mkdir -p "$SECRETS_DIR"
  printf 'export EXISTING_TOKEN=untouched' > "$SECRETS_FILE"

  __mt_write_secret "NEW_TOKEN" "added"

  # The historical bug this guards against: appending directly onto a
  # file with no trailing newline would concatenate the two exports
  # onto one physical line, silently corrupting EXISTING_TOKEN's value.
  grep -qxF 'export EXISTING_TOKEN=untouched' "$SECRETS_FILE"
  grep -qxF 'export NEW_TOKEN=added' "$SECRETS_FILE"
  [ "$(wc -l < "$SECRETS_FILE")" -ge 2 ]
}

@test "write_secret shell-escapes a value containing special characters" {
  __mt_write_secret "TRICKY_TOKEN" 'value with $pace & "quotes"'

  # shellcheck disable=SC1090
  (source "$SECRETS_FILE" && [ "$TRICKY_TOKEN" = 'value with $pace & "quotes"' ])
}

# ---------- __mt_delete_secret ----------

@test "delete_secret removes only the named export line from SECRETS_FILE" {
  __mt_write_secret "KEEP_TOKEN" "keep-me"
  __mt_write_secret "DELETE_TOKEN" "delete-me"

  __mt_delete_secret "DELETE_TOKEN" ""

  grep -qF 'export KEEP_TOKEN=keep-me' "$SECRETS_FILE"
  run ! grep -qF 'DELETE_TOKEN' "$SECRETS_FILE"
}

@test "delete_secret removes both the named and paired export lines" {
  __mt_write_secret "BITBUCKET_EMAIL" "me@example.com"
  __mt_write_secret "BITBUCKET_API_KEY" "token-value"

  __mt_delete_secret "BITBUCKET_API_KEY" "BITBUCKET_EMAIL"

  run ! grep -qF 'BITBUCKET_API_KEY' "$SECRETS_FILE"
  run ! grep -qF 'BITBUCKET_EMAIL' "$SECRETS_FILE"
}

@test "delete_secret unsets the variable(s) from the current shell" {
  __mt_write_secret "DELETE_TOKEN" "delete-me"
  export DELETE_TOKEN="delete-me"

  __mt_delete_secret "DELETE_TOKEN" ""

  [ -z "${DELETE_TOKEN+x}" ]
}

@test "delete_secret calls the secrets manager to unregister the deleted secret" {
  __mt_write_secret "DELETE_TOKEN" "delete-me"

  __mt_delete_secret "DELETE_TOKEN" ""

  grep -qF 'unregister DELETE_TOKEN' "$fake_manager_calls"
}

@test "delete_secret on a non-existent SECRETS_FILE does not error and still unregisters" {
  rm -f "$SECRETS_FILE"

  run __mt_delete_secret "NEVER_EXISTED" ""

  [ "$status" -eq 0 ]
  grep -qF 'unregister NEVER_EXISTED' "$fake_manager_calls"
}
