# shellcheck shell=bash
# ------------------------------------------
# System Update Check
# ------------------------------------------
# ~/.bash.d/00-system/02-update-check.sh

#######################################
# System: Check asynchronously for pending system package updates
#######################################
__check_updates() {
  if [[ $- != *i* ]]; then return; fi

  local pending_file="$CACHE_DIR/.update_pending"
  local cache_file="$CACHE_DIR/.update_check_cache"
  local current_time
  current_time=$(date +%s)
  mkdir -p "$CACHE_DIR" 2> /dev/null

  if [ -f "$pending_file" ]; then
    local updates_count
    updates_count=$(command cat "$pending_file")
    echo -e "\n${C_YELLOW}📦 $updates_count system package(s) can be upgraded. Run ${C_BOLD}sys-install${C_RESET}${C_YELLOW} to install them.${C_RESET}"
    return
  fi

  local last_check=0
  if [ -f "$cache_file" ]; then
    last_check=$(command cat "$cache_file")
  fi

  local ttl="${UPDATE_CHECK_TTL_SEC:-43200}"

  if ((current_time - last_check >= ttl)); then
    (
      local count
      if [ "$OS_FAMILY" = "macos" ]; then
        if command -v brew > /dev/null 2>&1; then
          count=$(brew outdated 2> /dev/null | grep -c .)
        else
          count=0
        fi
      else
        count=$(apt list --upgradable 2> /dev/null | grep -c -v 'Listing...')
      fi

      if [ "$count" -gt 0 ]; then
        echo "$count" > "$pending_file"
      else
        date +%s > "$cache_file"
      fi
    ) &
    disown
  fi
}

__check_updates

#######################################
# System: Asynchronously check for profile updates from remote Git repository
#######################################
__check_profile_updates() {
  if [[ $- != *i* ]]; then return; fi

  local pending_file="$CACHE_DIR/.profile_update_pending"
  local cache_file="$CACHE_DIR/.profile_update_cache"
  local current_time
  current_time=$(date +%s)
  mkdir -p "$CACHE_DIR" 2> /dev/null

  if [ -f "$pending_file" ]; then
    local new_version
    new_version=$(command cat "$pending_file")
    local current_version="Local"
    local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
    if [ -f "$VERSION_FILE" ]; then
      current_version=$(command cat "$VERSION_FILE")
    elif [ -n "$repo_dir" ] && [ -d "$repo_dir/.git" ] && command -v git > /dev/null 2>&1; then
      current_version=$(git -C "$repo_dir" describe --tags --abbrev=0 2> /dev/null || echo "Local")
    fi

    echo -e "\n${C_YELLOW}🚀 Terminal profile update available! (${C_BOLD}${current_version}${C_UNBOLD} -> ${C_BOLD}${new_version}${C_UNBOLD})${C_RESET}"
    echo -e "${C_YELLOW}   Run ${C_BOLD}mt-get-update${C_UNBOLD} to apply the latest changes.${C_RESET}\n"
    return
  fi

  local last_check=0
  if [ -f "$cache_file" ]; then
    last_check=$(command cat "$cache_file")
  fi

  local ttl="${UPDATE_CHECK_TTL_SEC:-43200}"

  if ((current_time - last_check >= ttl)); then
    (
      local repo_path="MatStacey/mt-devops-framework"
      if [[ "${SYNC_REPO_URL:-}" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)? ]]; then
        repo_path="${BASH_REMATCH[1]}"
      fi

      local remote_version
      remote_version=$(curl -s "https://api.github.com/repos/${repo_path}/releases/latest" | jq -r ".tag_name // empty")

      local current_version=""
      local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
      if [ -f "$VERSION_FILE" ]; then
        current_version=$(command cat "$VERSION_FILE")
      elif [ -n "$repo_dir" ] && [ -d "$repo_dir/.git" ] && command -v git > /dev/null 2>&1; then
        current_version=$(git -C "$repo_dir" describe --tags --abbrev=0 2> /dev/null || echo "")
      fi

      # A plain != flags "update available" whenever the tags merely
      # differ, not when remote is actually newer -- on a symlinked
      # machine (pulling straight from main via git) that's wrong the
      # moment local is AHEAD of GitHub's own "latest Release" listing,
      # which publishes asynchronously after a push and can briefly lag
      # behind a tag/commit that's already pullable. sort -V settles
      # which of the two actually comes last; an unknown local version
      # (no VERSION_FILE, no git checkout) always counts as needing the
      # update, same as before this fix.
      local should_update=false
      if [ -n "$remote_version" ]; then
        if [ -z "$current_version" ]; then
          should_update=true
        elif [ "$current_version" != "$remote_version" ]; then
          local newest
          newest=$(printf '%s\n%s\n' "$current_version" "$remote_version" | sort -V | tail -n1)
          [ "$newest" = "$remote_version" ] && should_update=true
        fi
      fi

      if [ "$should_update" = true ]; then
        echo "$remote_version" > "$pending_file"
      else
        date +%s > "$cache_file"
      fi
    ) &
    disown
  fi
}

__check_profile_updates
