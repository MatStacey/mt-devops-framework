#!/usr/bin/env bats
# ------------------------------------------
# Bats: install.sh -- the fresh-install AND update-in-place code path
# ------------------------------------------
# install.sh runs on every fresh install *and* every mt-get-update (it's
# the script that re-syncs ~/.bash.d from the repo). CI's existing
# "Smoke-Test Packaged Release Install" step only exercises a single
# fresh install against an empty $TEST_HOME, so it can't catch
# regressions that only show up on a *second* run over an
# already-installed tree: the .bashrc.bak guard, and rsync --delete
# preserving local-only files (config.yaml, secrets_metadata.yaml,
# *_token.sh, 40-private/, lib/private/) instead of deleting them.
# These tests cover exactly that second-run behavior, plus the
# config-scaffolding path rebind, directly against the real install.sh.
#
# MT_INSTALL_WIZARD=1 is set on every run so the interactive
# "run bootstrap now? [Y/n]" dependency prompt is skipped entirely --
# these tests are about file sync, not system package installation
# (matches the intent of install-wizard.sh's own reuse of this script).

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  fake_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$fake_home"
}

run_install() {
  HOME="$fake_home" MT_INSTALL_WIZARD=1 bash "$repo_root/install.sh"
}

@test "fresh install backs up a real pre-existing .bashrc to .bashrc.bak" {
  printf '# my own original bashrc\n' > "$fake_home/.bashrc"

  run_install

  [ -f "$fake_home/.bashrc.bak" ]
  grep -qF 'my own original bashrc' "$fake_home/.bashrc.bak"
}

@test "second install run does not overwrite .bashrc.bak with the framework's own .bashrc" {
  printf '# my own original bashrc\n' > "$fake_home/.bashrc"
  run_install
  [ -f "$fake_home/.bashrc.bak" ]

  # Second pass, simulating mt-get-update: .bashrc is now the framework's
  # own file from the first pass, not the user's original.
  run_install

  grep -qF 'my own original bashrc' "$fake_home/.bashrc.bak"
  ! grep -qF 'my own original bashrc' "$fake_home/.bashrc"
}

@test "backup is skipped entirely when ~/.bashrc is already a symlink" {
  ln -s "$repo_root/.bashrc" "$fake_home/.bashrc"

  run_install

  [ ! -f "$fake_home/.bashrc.bak" ]
}

@test "second install run preserves pre-existing local-only files instead of deleting them" {
  run_install

  # config.yaml/secrets_metadata.yaml have their own dedicated migration
  # coverage in test_path_resolution.bats; this test sticks to the
  # local-only file classes install.sh's rsync excludes handle directly.
  local_config="$fake_home/.bash.d/config"
  mkdir -p "$local_config" "$fake_home/.bash.d/40-private" "$fake_home/.bash.d/lib/private"
  printf 'export MY_API_TOKEN=abc123\n' > "$local_config/my_service_token.sh"
  printf 'echo "private alias"\n' > "$fake_home/.bash.d/40-private/custom.sh"
  printf 'echo "private lib"\n' > "$fake_home/.bash.d/lib/private/helper.sh"

  run_install

  grep -qF 'MY_API_TOKEN' "$local_config/my_service_token.sh"
  grep -qF 'private alias' "$fake_home/.bash.d/40-private/custom.sh"
  grep -qF 'private lib' "$fake_home/.bash.d/lib/private/helper.sh"
}

@test "config-scaffolding rebinds paths.dotfiles_dir and paths.sync_repo_dir to the install's own repo dir" {
  run_install

  # config.yaml now scaffolds at the XDG location (~/.config/mt-devops-framework),
  # not under .bash.d/config -- see the config.yaml XDG migration.
  config_file="$fake_home/.config/mt-devops-framework/config.yaml"
  [ -f "$config_file" ]
  grep -qF "dotfiles_dir: $repo_root" "$config_file"
  grep -qF "sync_repo_dir: $repo_root" "$config_file"
  ! grep -qF '~/vcs/personal/mt-devops-framework' "$config_file"
}

@test "second install run does not re-scaffold or overwrite an already-configured config.yaml" {
  run_install
  config_file="$fake_home/.config/mt-devops-framework/config.yaml"
  printf '\n# a user edit that must survive updates\n' >> "$config_file"

  run_install

  grep -qF 'a user edit that must survive updates' "$config_file"
}
