#!/usr/bin/env bats
# ------------------------------------------
# Bats: mt-dump private-path filtering in .bash.d/03-mytools/05-mytools.sh
# ------------------------------------------
# Commands defined under 40-private/ or lib/private/ must never appear in
# the generated reference, even though they are in the shared mytools index.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  CACHE_DIR="$BATS_TEST_TMPDIR/cache"
  export_dir="$BATS_TEST_TMPDIR/out"
  mkdir -p "$HOME/.bash.d/02-utilities" "$HOME/.bash.d/40-private" "$CACHE_DIR"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/03-mytools/05-mytools.sh"

  cat > "$HOME/.bash.d/02-utilities/10-pub.sh" << 'SRC'
#######################################
# Test: public command
#######################################
pub-cmd() { echo public; }
SRC
  cat > "$HOME/.bash.d/40-private/10-priv.sh" << 'SRC'
#######################################
# Test: secret command
#######################################
priv-secret-cmd() { echo hidden; }
__priv_internal_helper() { echo hidden; }
SRC
  printf 'alias priv-secret-alias=true\n' > "$HOME/.bash.d/40-private/20-aliases.sh"

  tsv="$CACHE_DIR/.mt_data.tsv"
  printf 'func\tTest\tpub-cmd\tpublic command\t%s\n' "$HOME/.bash.d/02-utilities/10-pub.sh" > "$tsv"
  printf 'func\tSecret\tpriv-secret-cmd\tsecret command\t%s\n' "$HOME/.bash.d/40-private/10-priv.sh" >> "$tsv"
  printf 'alias\tSecret\tpriv-secret-alias\tsecret alias\t%s\n' "$HOME/.bash.d/40-private/20-aliases.sh" >> "$tsv"
  # shellcheck disable=SC2317
  mytools() { :; }
  # shellcheck disable=SC2317
  __open_path_gui() { :; }
}

@test "mt-dump keeps public commands" {
  mt-dump -d "$export_dir" > /dev/null
  grep -q "pub-cmd" "$export_dir/TECHNICAL_REFERENCE.md"
}

@test "mt-dump omits private commands, aliases and categories" {
  mt-dump -d "$export_dir" > /dev/null
  run grep -q "priv-secret" "$export_dir/TECHNICAL_REFERENCE.md"
  [ "$status" -eq 1 ]
  run grep -q "Secret" "$export_dir/TECHNICAL_REFERENCE.md"
  [ "$status" -eq 1 ]
}

@test "mt-dump --internal omits private helpers" {
  mt-dump -d "$export_dir" --internal > /dev/null
  run grep -q "__priv_internal_helper" "$export_dir/TECHNICAL_REFERENCE.md"
  [ "$status" -eq 1 ]
}

@test "mt-dump --private still works as an alias for --internal" {
  run mt-dump -d "$export_dir" --private
  [ "$status" -eq 0 ]
}
