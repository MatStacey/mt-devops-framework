# shellcheck shell=bash
# ------------------------------------------
# System Diagnostics ("mt-doctor")
# ------------------------------------------
# ~/.bash.d/00-system/03-doctor.sh

#######################################
# System: Print one mt-doctor report line with a status prefix, and
# track whether anything worth acting on was found. Internal to this
# file -- never called directly. In JSON mode (__mt_doctor_json=true,
# set by mt-doctor), appends a {section,status,message} object to
# __mt_doctor_results instead of printing colorized text.
# Arguments:
#   $1 - Status: OK, WARN, FAIL, or SKIP
#   $2 - Message
# Globals (read):
#   __mt_doctor_json, __mt_doctor_section
# Globals (written):
#   __mt_doctor_issues -- incremented on WARN/FAIL
#   __mt_doctor_results -- appended to in JSON mode
#######################################
__mt_doctor_line() {
  local status="$1" msg="$2"

  if [ "$status" = "WARN" ] || [ "$status" = "FAIL" ]; then
    __mt_doctor_issues=$((__mt_doctor_issues + 1))
  fi

  if [ "${__mt_doctor_json:-false}" = "true" ]; then
    __mt_doctor_results+=("$(jq -nc --arg section "$__mt_doctor_section" --arg status "$status" --arg message "$msg" '{section: $section, status: $status, message: $message}')")
    return
  fi

  case "$status" in
    OK) echo -e "  ${CB_GREEN}✅ ${msg}${C_RESET}" ;;
    WARN) echo -e "  ${CB_YELLOW}⚠️  ${msg}${C_RESET}" ;;
    FAIL) echo -e "  ${CB_RED}🚨 ${msg}${C_RESET}" ;;
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
  __mt_doctor_section="version"
  [ "${__mt_doctor_json:-false}" = "true" ] || echo -e "${CB_BLUE}📦 Version${C_RESET}"

  local installed="Local"
  [ -f "$VERSION_FILE" ] && installed=$(command cat "$VERSION_FILE")

  local pending_file="$CACHE_DIR/.profile_update_pending"
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
  __mt_doctor_section="sync_config"
  [ "${__mt_doctor_json:-false}" = "true" ] || echo -e "${CB_BLUE}🔗 Sync Configuration${C_RESET}"

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
  __mt_doctor_section="sync_repo_state"
  [ "${__mt_doctor_json:-false}" = "true" ] || echo -e "${CB_BLUE}🌿 Sync Repo Git State${C_RESET}"

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  if [ ! -d "$repo_dir/.git" ]; then
    __mt_doctor_line SKIP "No sync repo checkout yet -- nothing to inspect."
    return
  fi

  if [ -f "$repo_dir/.git/MERGE_HEAD" ]; then
    __mt_doctor_line FAIL "A merge is in progress in ${repo_dir}. Resolve conflicts, commit, then re-run 'mt-push-update'."
  fi

  local default_branch
  default_branch=$(__mt_git_default_branch "$repo_dir")
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

  local upstream
  upstream=$(cd "$repo_dir" && git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2> /dev/null)
  if [ -z "$upstream" ]; then
    __mt_doctor_line WARN "'${current_branch}' has no upstream tracking branch configured."
  else
    local ahead
    ahead=$(git -C "$repo_dir" rev-list --count "${upstream}..HEAD" 2> /dev/null)
    [ "${ahead:-0}" -gt 0 ] && __mt_doctor_line WARN "${ahead} commit(s) on '${current_branch}' not yet pushed to ${upstream}."
  fi
}

#######################################
# System: Report whether the active AI provider's configured model was
# last confirmed present in that provider's live catalog, reusing the
# periodic background check's own pending-marker file instead of making
# a fresh network call on every mt-doctor run (same pattern as
# __mt_doctor_check_version).
# Globals:
#   CACHE_DIR, AI_ENABLED, DEFAULT_AI
#   __mt_doctor_issues (written, via __mt_doctor_line)
#######################################
__mt_doctor_check_ai_model() {
  __mt_doctor_section="ai_model"
  [ "${__mt_doctor_json:-false}" = "true" ] || echo -e "${CB_BLUE}🤖 AI Model${C_RESET}"

  if [ "${AI_ENABLED:-true}" != "true" ]; then
    __mt_doctor_line SKIP "AI integration is disabled ('mt-toggle-ai' to enable)."
    return
  fi

  local provider="${DEFAULT_AI:-gemini}"
  if [ "$provider" = "local" ]; then
    __mt_doctor_line SKIP "Active provider is 'local' -- no cloud catalog to check."
    return
  elif [ "$provider" = "claude-code" ]; then
    __mt_doctor_line SKIP "Active provider is 'claude-code' -- it resolves its own model aliases, no catalog to check here."
    return
  fi

  local pending_file="$CACHE_DIR/.ai_model_stale_pending"
  if [ -f "$pending_file" ]; then
    local stale_model
    stale_model=$(jq -r '.model' "$pending_file" 2> /dev/null)
    __mt_doctor_line WARN "${provider^} model '${stale_model}' is no longer listed by its provider's API. Run 'mt-set-${provider}-model'."
  else
    __mt_doctor_line OK "${provider^} model confirmed present as of the last periodic check (or not yet checked -- run 'mt-ai-models -r' to check now)."
  fi
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
  __mt_doctor_section="config_schema"
  [ "${__mt_doctor_json:-false}" = "true" ] || echo -e "${CB_BLUE}⚙️  Config Schema${C_RESET}"

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
      if [ "${__mt_doctor_json:-false}" != "true" ]; then
        echo "$output" | tail -n +2 | while IFS= read -r line; do
          echo -e "      ${C_DIM}${line}${C_RESET}"
        done
      fi
      ;;
    *) __mt_doctor_line FAIL "Unexpected output from 'config_manager.py check-config'." ;;
  esac
}

#######################################
# System: Diagnostic health-check for the framework's environment --
# framework version, sync configuration (SYNC_REPO_URL, gh auth, clone
# state), the sync repo's git state (stuck branches, open/stale PRs, an
# in-progress merge, uncommitted changes), config.yaml schema drift, and
# whether the active AI provider's configured model is still listed by
# that provider's API. Report-only: never modifies anything, just names
# the command that would fix each issue found (mt-get-update,
# mt-push-update, mt-migrate-config, gh auth login, mt-set-claude-model /
# mt-set-gemini-model, ...).
# Usage: mt-doctor [-j|--json]
# Options:
#   -j, --json   Print every check as one JSON object ({issues, checks:
#                [{section, status, message}, ...]}) instead of the
#                colorized report (for scripts/editor integrations)
#   -h, --help   Show this help menu
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
  local __mt_doctor_json=false
  [[ "$1" == "-j" || "$1" == "--json" ]] && __mt_doctor_json=true

  if [ "$__mt_doctor_json" != "true" ]; then
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e "${CB_BLUE}              MT DEVOPS FRAMEWORK - DOCTOR                 ${C_RESET}"
    echo -e "${CB_BLUE}==========================================================${C_RESET}\n"
  fi

  local __mt_doctor_issues=0
  local __mt_doctor_section=""
  local -a __mt_doctor_results=()

  __mt_doctor_check_version
  [ "$__mt_doctor_json" = "true" ] || echo
  __mt_doctor_check_sync_config
  [ "$__mt_doctor_json" = "true" ] || echo
  __mt_doctor_check_sync_repo_state
  [ "$__mt_doctor_json" = "true" ] || echo
  __mt_doctor_check_config_schema
  [ "$__mt_doctor_json" = "true" ] || echo
  __mt_doctor_check_ai_model

  if [ "$__mt_doctor_json" = "true" ]; then
    printf '%s\n' "${__mt_doctor_results[@]}" | jq -s --argjson issues "$__mt_doctor_issues" '{issues: $issues, checks: .}'
    [ "$__mt_doctor_issues" -eq 0 ]
    return
  fi

  echo -e "\n${CB_BLUE}==========================================================${C_RESET}"
  if [ "$__mt_doctor_issues" -eq 0 ]; then
    echo -e "${CB_GREEN}✅ No issues found.${C_RESET}"
  else
    echo -e "${CB_YELLOW}⚠️  ${__mt_doctor_issues} issue(s) found -- see above for the command to fix each.${C_RESET}"
  fi
  echo -e "${CB_BLUE}==========================================================${C_RESET}"

  [ "$__mt_doctor_issues" -eq 0 ]
}
