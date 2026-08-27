# shellcheck shell=bash
# ------------------------------------------
# System Uninstaller ("mt-uninstall")
# ------------------------------------------
# ~/.bash.d/00-system/05-uninstall.sh

#######################################
# System: Back up ~/.bash.d and ~/.bashrc to a timestamped directory
# under BACKUP_DIR before mt-uninstall removes them, mirroring the same
# backup-before-destroy pattern mt-push-update and mt-get-update already
# use elsewhere in the framework.
# Globals:
#   BACKUP_DIR
# Outputs:
#   Prints the backup directory path to stdout
#######################################
__mt_uninstall_backup() {
  local backup_dir
  backup_dir="${BACKUP_DIR:-$HOME/backups}/uninstall/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup_dir"

  [ -d "$HOME/.bash.d" ] && cp -a "$HOME/.bash.d" "$backup_dir/.bash.d"
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
# System: Completely remove the MT DevOps Framework from this machine --
# deletes ~/.bash.d and restores or removes ~/.bashrc, after a full
# backup and a typed "yes" confirmation (case-insensitive). Deliberately
# leaves untouched: the git repo checkout at DOTFILES_DIR/SYNC_REPO_DIR
# (the user's own git history, not installer state), ~/secrets/secrets.sh
# (API keys, not framework code), and BACKUP_DIR itself (where this
# command's own safety backup, and every other backup this framework has
# ever made, lives). System packages installed via bootstrap (jq, fzf,
# shfmt, ...) are never touched -- removing tools other software may also
# depend on is out of scope for uninstalling this framework alone.
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

  echo -e "${CB_RED}==========================================================${C_RESET}"
  echo -e "${CB_RED}            MT DEVOPS FRAMEWORK - UNINSTALL                ${C_RESET}"
  echo -e "${CB_RED}==========================================================${C_RESET}\n"
  echo -e "${CB_YELLOW}This will:${C_RESET}"
  echo -e "  ${CB_RED}🗑️  Delete${C_RESET}  ~/.bash.d (the entire framework)"
  if [ "$restore_bashrc" = true ]; then
    echo -e "  ${CB_YELLOW}♻️  Restore${C_RESET} ~/.bashrc from ~/.bashrc.bak (your pre-install bashrc)"
  else
    echo -e "  ${CB_RED}🗑️  Delete${C_RESET}  ~/.bashrc (no trustworthy pre-install backup was found to restore)"
  fi
  echo -e "\n${CB_CYAN}This will NOT touch:${C_RESET}"
  echo -e "  ${CB_GREEN}✅${C_RESET} ~/secrets/secrets.sh (your API keys)"
  [ -n "$repo_dir" ] && echo -e "  ${CB_GREEN}✅${C_RESET} ${repo_dir} (your git repo checkout)"
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

  rm -rf "$HOME/.bash.d"

  if [ "$restore_bashrc" = true ]; then
    mv "$HOME/.bashrc.bak" "$HOME/.bashrc"
    echo -e "${CB_GREEN}✅ Restored your original ~/.bashrc.${C_RESET}"
  else
    rm -f "$HOME/.bashrc"
    echo -e "${CB_GREEN}✅ Removed ~/.bashrc.${C_RESET}"
  fi

  echo -e "\n${CB_GREEN}✅ MT DevOps Framework uninstalled.${C_RESET}"
  echo -e "${C_DIM}This terminal session still has its functions loaded in memory -- open a new terminal (or close this one) to finish.${C_RESET}"
  echo -e "${C_DIM}Backup saved to: ${backup_dir}${C_RESET}"
}
