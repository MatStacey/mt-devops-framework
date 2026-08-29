# shellcheck shell=bash
# ------------------------------------------
# System Uninstaller ("mt-uninstall")
# ------------------------------------------
# ~/.bash.d/00-system/05-uninstall.sh

#######################################
# System: Back up ~/.bash.d and ~/.bashrc to a timestamped directory
# under BACKUP_DIR before mt-uninstall removes them, mirroring the same
# backup-before-destroy pattern mt-push-update and mt-get-update already
# use elsewhere in the framework. Uses 'cp -aL' rather than 'cp -a' so
# that on a machine migrated via mt-migrate-symlink -- where ~/.bash.d
# is itself a symlink -- the backup captures the real files it points
# to instead of just a copy of the symlink (which 'cp -a' alone would
# leave dangling the moment the target is ever removed).
# Globals:
#   BACKUP_DIR
# Outputs:
#   Prints the backup directory path to stdout
#######################################
__mt_uninstall_backup() {
  local backup_dir
  backup_dir="${BACKUP_DIR:-$HOME/backups}/uninstall/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup_dir"

  [ -d "$HOME/.bash.d" ] && cp -aL "$HOME/.bash.d" "$backup_dir/.bash.d"
  [ -f "$HOME/.bashrc" ] && cp -p "$HOME/.bashrc" "$backup_dir/.bashrc"

  echo "$backup_dir"
}

#######################################
# System: Decide whether ~/.bashrc.bak actually looks like the user's
# genuine pre-framework bashrc, rather than a stale copy of the
# framework's own .bashrc from a past update -- a real bug in install.sh
# (fixed alongside this) meant every mt-get-update re-backed-up
# unconditionally, so on any machine that updated even once before the
# fix, .bashrc.bak silently stopped holding the true original. Detects
# the corrupted case by comparing against the user's own repo checkout's
# .bashrc; if that checkout isn't available to compare against, gives
# the backup the benefit of the doubt rather than distrusting it blind.
# Arguments:
#   $1 - Path to the user's repo checkout (DOTFILES_DIR/SYNC_REPO_DIR)
# Returns:
#   0 if ~/.bashrc.bak exists and looks trustworthy, 1 otherwise
#######################################
__mt_uninstall_bashrc_backup_trustworthy() {
  local repo_dir="$1"
  [ -f "$HOME/.bashrc.bak" ] || return 1
  [ -n "$repo_dir" ] && [ -f "$repo_dir/.bashrc" ] || return 0
  ! diff -q "$HOME/.bashrc.bak" "$repo_dir/.bashrc" > /dev/null 2>&1
}

#######################################
# System: Preserve config.yaml, secrets_metadata.yaml, and .vcs_hub.json
# to a single stable (non-timestamped) location outside ~/.bash.d before
# it's deleted -- a plain reinstall re-scaffolds a bare default
# config.yaml and has no source to regenerate the other two from, so
# without this a reinstalled framework silently comes back de-configured
# even though the full backup technically still has them buried in a
# timestamped folder. Re-running this overwrites the previous save with
# the latest, matching .bashrc.bak's own single-most-recent-copy model.
# Globals:
#   BACKUP_DIR, CONFIG_FILE, CONFIG_DIR, CACHE_DIR
# Outputs:
#   Prints the directory the files were saved to
#######################################
__mt_uninstall_preserve_state() {
  local save_dir="${BACKUP_DIR:-$HOME/backups}/uninstall-preserved-config"
  mkdir -p "$save_dir"

  [ -f "$CONFIG_FILE" ] && cp -p "$CONFIG_FILE" "$save_dir/"
  [ -f "$CONFIG_DIR/secrets_metadata.yaml" ] && cp -p "$CONFIG_DIR/secrets_metadata.yaml" "$save_dir/"
  [ -f "$CACHE_DIR/.vcs_hub.json" ] && cp -p "$CACHE_DIR/.vcs_hub.json" "$save_dir/"

  echo "$save_dir"
}

#######################################
# System: Check whether the repo checkout at $1 is safe to delete outright
# -- clean working tree (no uncommitted or untracked changes) and every
# local commit already pushed to its upstream. Refusing otherwise means
# mt-uninstall can never silently destroy real git history or work that
# exists nowhere else, even when the user opts in to wiping it.
# Arguments:
#   $1 - Repo checkout path
# Returns:
#   0 if safe to delete, 1 otherwise
#######################################
__mt_uninstall_repo_safe_to_delete() {
  local repo_dir="$1"
  [ -d "$repo_dir/.git" ] || return 0

  git -C "$repo_dir" diff --quiet 2> /dev/null || return 1
  git -C "$repo_dir" diff --staged --quiet 2> /dev/null || return 1
  [ -z "$(git -C "$repo_dir" ls-files --others --exclude-standard 2> /dev/null)" ] || return 1

  local upstream
  upstream=$(git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2> /dev/null)
  [ -n "$upstream" ] || return 1

  local ahead
  ahead=$(git -C "$repo_dir" rev-list --count "${upstream}..HEAD" 2> /dev/null)
  [ "${ahead:-0}" -eq 0 ]
}

#######################################
# System: Ask a single Y/n question and report whether the user accepted.
# Arguments:
#   $1 - Prompt text (without the [Y/n] or [y/N] suffix)
#   $2 - Default: "y" or "n"
# Returns:
#   0 if accepted, 1 if declined
#######################################
__mt_uninstall_confirm() {
  local prompt="$1" default="$2"
  local suffix="[y/N]"
  [ "$default" = "y" ] && suffix="[Y/n]"

  local reply
  read -r -p "${prompt} ${suffix} " -n 1 reply < /dev/tty
  echo
  [ -z "$reply" ] && reply="$default"
  [[ "$reply" =~ ^[Yy]$ ]]
}

#######################################
# System: Completely remove the MT DevOps Framework from this machine --
# deletes ~/.bash.d and restores or removes ~/.bashrc, after a full
# backup and a typed "yes" confirmation (case-insensitive). Along the
# way, offers two independent choices: whether to preserve config.yaml/
# secrets_metadata.yaml/.vcs_hub.json outside ~/.bash.d (default: yes --
# see __mt_uninstall_preserve_state), and whether to also delete
# ~/secrets/secrets.sh and the git repo checkout at DOTFILES_DIR/
# SYNC_REPO_DIR (default: no -- these are API keys and the user's own
# git history, not installer state, and the repo checkout is only ever
# actually deleted if __mt_uninstall_repo_safe_to_delete confirms nothing
# would be lost). BACKUP_DIR itself is never touched -- it's where every
# backup this framework has ever made lives, including this command's
# own. System packages installed via bootstrap (jq, fzf, shfmt, ...) are
# never touched either -- removing tools other software may also depend
# on is out of scope for uninstalling this framework alone.
# Usage: mt-uninstall
# Globals:
#   DOTFILES_DIR, SYNC_REPO_DIR, BACKUP_DIR
#######################################
mt-uninstall() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  local restore_bashrc=false
  __mt_uninstall_bashrc_backup_trustworthy "$repo_dir" && restore_bashrc=true

  local bashd_is_symlink=false
  [ -L "$HOME/.bash.d" ] && bashd_is_symlink=true

  echo -e "${CB_RED}==========================================================${C_RESET}"
  echo -e "${CB_RED}            MT DEVOPS FRAMEWORK - UNINSTALL                ${C_RESET}"
  echo -e "${CB_RED}==========================================================${C_RESET}\n"

  echo -e "${CB_CYAN}config.yaml, secrets_metadata.yaml, and .vcs_hub.json won't survive a plain reinstall otherwise.${C_RESET}"
  local preserve_state=false
  __mt_uninstall_confirm "Keep your settings for next time?" "y" && preserve_state=true
  echo

  local wipe_extras=false
  local wipe_repo=false
  if [ -n "$repo_dir" ] || [ -f "$HOME/secrets/secrets.sh" ]; then
    echo -e "${CB_CYAN}By default, ~/secrets/secrets.sh and your git repo checkout are left alone -- they're your API keys and your own git history, not installer state.${C_RESET}"
    __mt_uninstall_confirm "Also delete these?" "n" && wipe_extras=true
    echo

    if [ "$wipe_extras" = true ] && [ -n "$repo_dir" ] && [ -d "$repo_dir" ]; then
      if __mt_uninstall_repo_safe_to_delete "$repo_dir"; then
        wipe_repo=true
      else
        echo -e "${CB_YELLOW}⚠️  ${repo_dir} has uncommitted changes or commits not yet pushed -- leaving it in place rather than risk losing work that exists nowhere else.${C_RESET}\n"
      fi
    fi
  fi

  echo -e "${CB_YELLOW}This will:${C_RESET}"
  if [ "$bashd_is_symlink" = true ]; then
    echo -e "  ${CB_YELLOW}🔗 Remove${C_RESET}  the ~/.bash.d symlink (the framework's actual code lives in ${repo_dir}, not deleted here)"
  else
    echo -e "  ${CB_RED}🗑️  Delete${C_RESET}  ~/.bash.d (the entire framework)"
  fi
  if [ "$restore_bashrc" = true ]; then
    echo -e "  ${CB_YELLOW}♻️  Restore${C_RESET} ~/.bashrc from ~/.bashrc.bak (your pre-install bashrc)"
  else
    echo -e "  ${CB_RED}🗑️  Delete${C_RESET}  ~/.bashrc (no trustworthy pre-install backup was found to restore)"
  fi
  if [ "$preserve_state" = true ]; then
    echo -e "  ${CB_GREEN}💾 Preserve${C_RESET} config.yaml, secrets_metadata.yaml, .vcs_hub.json outside ~/.bash.d"
  fi
  [ "$wipe_extras" = true ] && [ -f "$HOME/secrets/secrets.sh" ] && echo -e "  ${CB_RED}🗑️  Delete${C_RESET}  ~/secrets/secrets.sh (your API keys)"
  [ "$wipe_repo" = true ] && echo -e "  ${CB_RED}🗑️  Delete${C_RESET}  ${repo_dir} (your git repo checkout -- confirmed clean and fully pushed)"

  echo -e "\n${CB_CYAN}This will NOT touch:${C_RESET}"
  if [ "$wipe_extras" = false ] || [ ! -f "$HOME/secrets/secrets.sh" ]; then
    echo -e "  ${CB_GREEN}✅${C_RESET} ~/secrets/secrets.sh (your API keys)"
  fi
  if [ -n "$repo_dir" ] && [ "$wipe_repo" = false ]; then
    echo -e "  ${CB_GREEN}✅${C_RESET} ${repo_dir} (your git repo checkout)"
  fi
  echo -e "  ${CB_GREEN}✅${C_RESET} ${BACKUP_DIR:-$HOME/backups} (existing backups, including the one this command is about to make)"
  echo -e "  ${CB_GREEN}✅${C_RESET} System packages installed via bootstrap (jq, fzf, shellcheck, ...)"
  echo

  local reply
  read -r -p 'Type "yes" to confirm: ' reply < /dev/tty
  if [ "${reply,,}" != "yes" ]; then
    echo -e "${CB_YELLOW}🛑 Uninstall cancelled.${C_RESET}"
    return 0
  fi

  local backup_dir
  backup_dir=$(__mt_uninstall_backup)
  echo -e "${CB_CYAN}📦 Backed up ~/.bash.d and ~/.bashrc to ${backup_dir} before removing anything.${C_RESET}"

  local preserved_dir=""
  if [ "$preserve_state" = true ]; then
    preserved_dir=$(__mt_uninstall_preserve_state)
    echo -e "${CB_GREEN}💾 Preserved your settings to ${preserved_dir}.${C_RESET}"
  fi

  rm -rf "$HOME/.bash.d"

  if [ "$restore_bashrc" = true ]; then
    mv "$HOME/.bashrc.bak" "$HOME/.bashrc"
    echo -e "${CB_GREEN}✅ Restored your original ~/.bashrc.${C_RESET}"
  else
    rm -f "$HOME/.bashrc"
    echo -e "${CB_GREEN}✅ Removed ~/.bashrc.${C_RESET}"
  fi

  if [ "$wipe_extras" = true ] && [ -f "$HOME/secrets/secrets.sh" ]; then
    rm -f "$HOME/secrets/secrets.sh"
    echo -e "${CB_GREEN}✅ Removed ~/secrets/secrets.sh.${C_RESET}"
  fi

  if [ "$wipe_repo" = true ]; then
    rm -rf "$repo_dir"
    echo -e "${CB_GREEN}✅ Removed ${repo_dir}.${C_RESET}"
  fi

  echo -e "\n${CB_GREEN}✅ MT DevOps Framework uninstalled.${C_RESET}"
  echo -e "${C_DIM}This terminal session still has its functions loaded in memory -- open a new terminal (or close this one) to finish.${C_RESET}"
  echo -e "${C_DIM}Backup saved to: ${backup_dir}${C_RESET}"
  [ -n "$preserved_dir" ] && echo -e "${C_DIM}Settings preserved at: ${preserved_dir} -- a fresh reinstall creates new defaults at \${XDG_CONFIG_HOME:-~/.config}/mt-devops-framework/, so copy these back in over top of them afterward.${C_RESET}"
}
