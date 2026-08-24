# shellcheck shell=bash
# ------------------------------------------
# System Diagnostics ("mt-doctor")
# ------------------------------------------
# ~/.bash.d/00-system/03-doctor.sh

#######################################
# System: Print one mt-doctor report line with a status prefix, and
# track whether anything worth acting on was found. Internal to this
# file -- never called directly.
# Arguments:
#   $1 - Status: OK, WARN, FAIL, or SKIP
#   $2 - Message
# Globals (written):
#   __mt_doctor_issues -- incremented on WARN/FAIL
#######################################
__mt_doctor_line() {
  local status="$1" msg="$2"
  case "$status" in
    OK) echo -e "  ${CB_GREEN}✅ ${msg}${C_RESET}" ;;
    WARN)
      echo -e "  ${CB_YELLOW}⚠️  ${msg}${C_RESET}"
      __mt_doctor_issues=$((__mt_doctor_issues + 1))
      ;;
    FAIL)
      echo -e "  ${CB_RED}🚨 ${msg}${C_RESET}"
      __mt_doctor_issues=$((__mt_doctor_issues + 1))
      ;;
    SKIP) echo -e "  ${C_DIM}⏭️  ${msg}${C_RESET}" ;;
  esac
}

#######################################
# System: Report installed vs latest-known framework version, reusing
# the periodic background check's own cache file instead of making a
# fresh network call on every mt-doctor run.
# Globals:
#   __mt_doctor_issues (written, via __mt_doctor_line)
#######################################
__mt_doctor_check_version() {
  echo -e "${CB_BLUE}📦 Version${C_RESET}"

  local installed="Local"
  [ -f "$HOME/.bash.d/data/.current_version" ] && installed=$(command cat "$HOME/.bash.d/data/.current_version")

  local pending_file="$HOME/.bash.d/data/cache/.profile_update_pending"
  if [ -f "$pending_file" ]; then
    local latest
    latest=$(command cat "$pending_file")
    __mt_doctor_line WARN "Update available: ${installed} -> ${latest}. Run 'mt-get-update'."
  else
    __mt_doctor_line OK "Running ${installed} (as of the last periodic check)."
  fi
}

#######################################
# System: Verify SYNC_REPO_URL is configured, the GitHub CLI is
# authenticated, and the local sync repo checkout actually points at
# that URL -- the class of gap that left mt-become-collaborator's first
# users stuck before that wizard existed.
# Globals:
#   SYNC_REPO_URL, DOTFILES_DIR, SYNC_REPO_DIR
#   __mt_doctor_issues (written, via __mt_doctor_line)
#######################################
__mt_doctor_check_sync_config() {
  echo -e "${CB_BLUE}🔗 Sync Configuration${C_RESET}"

  if [ -z "${SYNC_REPO_URL:-}" ] || [ "$SYNC_REPO_URL" = "YOUR_SYNC_REPO_URL" ] || [ "$SYNC_REPO_URL" = "null" ]; then
    __mt_doctor_line WARN "SYNC_REPO_URL not configured. Run 'mt-become-collaborator' (or 'mt-add-sync-url' if you have direct write access)."
    return
  fi
  __mt_doctor_line OK "SYNC_REPO_URL set to ${SYNC_REPO_URL}"

  if command -v gh > /dev/null 2>&1; then
    if gh auth status > /dev/null 2>&1; then
      __mt_doctor_line OK "GitHub CLI authenticated."
    else
      __mt_doctor_line WARN "GitHub CLI installed but not authenticated. Run 'gh auth login'."
    fi
  else
    __mt_doctor_line SKIP "GitHub CLI not installed -- PR checks below are skipped."
  fi

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  if [ ! -d "$repo_dir/.git" ]; then
    __mt_doctor_line WARN "${repo_dir} has no git checkout yet. It will be cloned on the next 'mt-push-update'."
    return
  fi

  local actual_origin
  actual_origin=$(git -C "$repo_dir" remote get-url origin 2> /dev/null)
  if [ "$actual_origin" != "$SYNC_REPO_URL" ]; then
    __mt_doctor_line WARN "${repo_dir}'s origin (${actual_origin:-none}) doesn't match SYNC_REPO_URL -- it will be re-pointed on the next 'mt-push-update'."
  else
    __mt_doctor_line OK "${repo_dir} is cloned and its origin matches SYNC_REPO_URL."
  fi
}

#######################################
# System: Inspect the sync repo's git state for the class of problem
# that strands 'mt-push-update' -- a leftover non-default branch
# (especially one with a still-open PR that a fast-moving default
# branch can conflict against as it drifts further ahead), an
# in-progress merge, or uncommitted changes sitting in the checkout.
# Globals:
#   DOTFILES_DIR, SYNC_REPO_DIR
#   __mt_doctor_issues (written, via __mt_doctor_line)
#######################################
__mt_doctor_check_sync_repo_state() {
  echo -e "${CB_BLUE}🌿 Sync Repo Git State${C_RESET}"

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  if [ ! -d "$repo_dir/.git" ]; then
    __mt_doctor_line SKIP "No sync repo checkout yet -- nothing to inspect."
    return
  fi

  if [ -f "$repo_dir/.git/MERGE_HEAD" ]; then
    __mt_doctor_line FAIL "A merge is in progress in ${repo_dir}. Resolve conflicts, commit, then re-run 'mt-push-update'."
  fi

  local default_branch
  default_branch=$(git -C "$repo_dir" remote show origin 2> /dev/null | awk '/HEAD branch/ {print $NF}')
  default_branch="${default_branch:-main}"

  local current_branch
  current_branch=$(git -C "$repo_dir" branch --show-current)

  if [ "$current_branch" = "$default_branch" ]; then
    __mt_doctor_line OK "On ${default_branch}, ready to sync."
  elif command -v gh > /dev/null 2>&1; then
    local pr_json pr_state pr_url
    pr_json=$(cd "$repo_dir" && gh pr view "$current_branch" --json state,url 2> /dev/null)
    pr_state=$(echo "$pr_json" | jq -r ".state // empty" 2> /dev/null)
    pr_url=$(echo "$pr_json" | jq -r ".url // empty" 2> /dev/null)
    case "$pr_state" in
      OPEN)
        __mt_doctor_line WARN "On '${current_branch}' with an open PR (${pr_url}). 'mt-push-update' will try to merge ${default_branch} into it, which can conflict the longer it sits unmerged."
        ;;
      MERGED | CLOSED)
        __mt_doctor_line WARN "On '${current_branch}', whose PR is already ${pr_state,,} -- this branch is stale. The next 'mt-push-update' will offer to clean it up."
        ;;
      *)
        __mt_doctor_line WARN "On '${current_branch}' with no PR found for it -- it may be abandoned. Consider 'git checkout ${default_branch}' and deleting it."
        ;;
    esac
  else
    __mt_doctor_line WARN "On '${current_branch}', not '${default_branch}', and GitHub CLI isn't installed so its PR status can't be checked."
  fi

  local dirty
  dirty=$(git -C "$repo_dir" status --porcelain 2> /dev/null)
  if [ -n "$dirty" ]; then
    local dirty_count
    dirty_count=$(echo "$dirty" | wc -l)
    __mt_doctor_line WARN "${dirty_count} uncommitted change(s) sitting in ${repo_dir}."
  else
    __mt_doctor_line OK "No uncommitted changes in the sync repo checkout."
  fi

  local unpushed
  unpushed=$(git -C "$repo_dir" log --branches --not --remotes --oneline 2> /dev/null | wc -l)
  [ "$unpushed" -gt 0 ] && __mt_doctor_line WARN "${unpushed} local commit(s) not yet pushed to any remote branch."
}

#######################################
# System: Report legacy config.yaml keys pending migration, via
# config_manager.py's read-only 'check-config' subcommand -- never
# mutates config.yaml as a side effect of a report command.
# Globals:
#   CONFIG_MANAGER
#   __mt_doctor_issues (written, via __mt_doctor_line)
#######################################
__mt_doctor_check_config_schema() {
  echo -e "${CB_BLUE}⚙️  Config Schema${C_RESET}"

  if [ ! -f "$CONFIG_MANAGER" ]; then
    __mt_doctor_line FAIL "config_manager.py not found."
    return
  fi

  local output first_line
  output=$(python3 "$CONFIG_MANAGER" check-config)
  first_line=$(echo "$output" | head -1)

  case "$first_line" in
    OK:*) __mt_doctor_line OK "${first_line#OK: }" ;;
    SKIP:*) __mt_doctor_line SKIP "${first_line#SKIP: }" ;;
    WARN:*)
      __mt_doctor_line WARN "${first_line#WARN: }"
      echo "$output" | tail -n +2 | while IFS= read -r line; do
        echo -e "      ${C_DIM}${line}${C_RESET}"
      done
      ;;
    *) __mt_doctor_line FAIL "Unexpected output from 'config_manager.py check-config'." ;;
  esac
}

#######################################
# System: Diagnostic health-check for the framework's environment --
# framework version, sync configuration (SYNC_REPO_URL, gh auth, clone
# state), the sync repo's git state (stuck branches, open/stale PRs, an
# in-progress merge, uncommitted changes), and config.yaml schema
# drift. Report-only: never modifies anything, just names the command
# that would fix each issue found (mt-get-update, mt-push-update,
# mt-migrate-config, gh auth login, ...).
# Usage: mt-doctor
# Returns:
#   0 if every check passed, 1 if any WARN/FAIL was reported
# Globals:
#   CONFIG_MANAGER, SYNC_REPO_URL, DOTFILES_DIR, SYNC_REPO_DIR
#######################################
mt-doctor() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}              MT DEVOPS FRAMEWORK - DOCTOR                 ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}\n"

  local __mt_doctor_issues=0

  __mt_doctor_check_version
  echo
  __mt_doctor_check_sync_config
  echo
  __mt_doctor_check_sync_repo_state
  echo
  __mt_doctor_check_config_schema

  echo -e "\n${CB_BLUE}==========================================================${C_RESET}"
  if [ "$__mt_doctor_issues" -eq 0 ]; then
    echo -e "${CB_GREEN}✅ No issues found.${C_RESET}"
  else
    echo -e "${CB_YELLOW}⚠️  ${__mt_doctor_issues} issue(s) found -- see above for the command to fix each.${C_RESET}"
  fi
  echo -e "${CB_BLUE}==========================================================${C_RESET}"

  [ "$__mt_doctor_issues" -eq 0 ]
}
