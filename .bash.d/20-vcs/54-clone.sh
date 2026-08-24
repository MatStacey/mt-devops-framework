# shellcheck shell=bash
# ------------------------------------------
# Git: Bulk Repository Cloning (mt-clone)
# ------------------------------------------
# ~/.bash.d/20-vcs/54-clone.sh

CLONE_WIZARD="$HOME/.bash.d/lib/python/clone_wizard.py"

#######################################
# Git: Strip whitespace, hyphens, underscores, and path separators from
# a workspace/project name for use as a directory component, and
# lowercase it. Repo slugs are already filesystem-safe (Bitbucket
# normalizes them) and are used as-is, untouched by this.
# Arguments:
#   $1 - Raw name
# Outputs:
#   Prints the sanitized name to STDOUT
#######################################
__mt_clone_sanitize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' \t_/-'
}

#######################################
# Git: Guard against two different (workspace, project) inputs
# normalizing to the same sanitized directory -- writes/checks a small
# marker file recording the ORIGINAL, unsanitized names that populated
# a project directory, so a genuine collision is caught and confirmed
# instead of silently mixing repos from two different sources together.
# Arguments:
#   $1 - Project directory (parent of all its repo clones)
#   $2 - Raw workspace name
#   $3 - Raw project name
# Returns:
#   0 if safe to proceed, 1 if a collision was detected and declined
#######################################
__mt_clone_check_collision() {
  local project_dir="$1" raw_workspace="$2" raw_project="$3"
  local marker="$project_dir/.mt-clone-source"

  if [ -f "$marker" ]; then
    local prev_workspace prev_project
    IFS='|' read -r prev_workspace prev_project < "$marker"
    if [ "$prev_workspace" != "$raw_workspace" ] || [ "$prev_project" != "$raw_project" ]; then
      echo -e "${CB_RED}🚨 ${project_dir} was previously populated from a DIFFERENT source:${C_RESET}"
      echo -e "   Previously: workspace='${prev_workspace}' project='${prev_project}'"
      echo -e "   Now:        workspace='${raw_workspace}' project='${raw_project}'"
      echo -e "${CB_YELLOW}These normalize to the same directory but are not the same project.${C_RESET}"
      local reply
      read -r -p "Proceed anyway and mix repos into this directory? [y/N] " -n 1 reply < /dev/tty
      echo
      [[ ! $reply =~ ^[Yy]$ ]] && return 1
    fi
  fi

  mkdir -p "$project_dir"
  echo "${raw_workspace}|${raw_project}" > "$marker"
  return 0
}

#######################################
# Git: Clone one Bitbucket repo without ever writing the API token to
# disk -- the Authorization header is injected via GIT_CONFIG_KEY_n/
# GIT_CONFIG_VALUE_n env vars (git 2.31+), which git never persists
# into the resulting repo's .git/config, and which (unlike a `-c` CLI
# flag) never appears in `ps` output for other local users to see.
# Deliberately uses `command git` -- 50-git.sh's own `git()` override
# intercepts every `clone` call and redirects it into a flat $VCS_ROOT,
# which mt-clone doesn't want since it already computes its own,
# more specific target directory.
# Arguments:
#   $1 - HTTPS clone URL
#   $2 - Target directory
# Globals:
#   BITBUCKET_EMAIL, BITBUCKET_API_KEY
# Returns:
#   0 on success, git clone's own exit code otherwise
#######################################
__mt_clone_bitbucket_repo() {
  local clone_url="$1" target_dir="$2"
  local auth_header
  auth_header="Basic $(printf '%s:%s' "$BITBUCKET_EMAIL" "$BITBUCKET_API_KEY" | base64 | tr -d '\n')"

  GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0="http.extraHeader" \
    GIT_CONFIG_VALUE_0="Authorization: ${auth_header}" \
    command git clone --quiet "$clone_url" "$target_dir"
}

#######################################
# Git: Clone every repository in a source-control provider's project
# into config.paths.vcs_root_dir/<provider>/<workspace>/<project>/,
# skipping any that already exist locally. Shows a plan (repositories
# to clone vs already present) and asks for confirmation before
# cloning anything, unless --auto-approve is set. Currently supports
# Bitbucket only -- see clone_wizard.py's PROVIDERS registry to add
# another.
# Usage: mt-clone -p <provider> -w <workspace> -pr <project> [--auto-approve]
# Options:
#   -p, --provider <name>    Source-control provider (currently: bitbucket)
#   -w, --workspace <name>   Workspace name
#   -pr, --project <name>    Project name (or key)
#   --auto-approve           Skip the confirmation prompt
#   -h, --help                Show this help menu
# Globals:
#   VCS_ROOT, CLONE_WIZARD, SECRETS_MANAGER, BITBUCKET_API_KEY, BITBUCKET_EMAIL
#######################################
mt-clone() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local provider="" raw_workspace="" raw_project="" auto_approve=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --provider)
        provider="$2"
        shift 2
        ;;
      -w | --workspace)
        raw_workspace="$2"
        shift 2
        ;;
      -pr | --project)
        raw_project="$2"
        shift 2
        ;;
      --auto-approve)
        auto_approve=true
        shift
        ;;
      *)
        echo "Usage: mt-clone -p <provider> -w <workspace> -pr <project> [--auto-approve]" >&2
        return 1
        ;;
    esac
  done

  if [ -z "$provider" ] || [ -z "$raw_workspace" ] || [ -z "$raw_project" ]; then
    echo -e "${CB_RED}🚨 --provider, --workspace, and --project are all required.${C_RESET}"
    return 1
  fi

  if [ "$provider" = "bitbucket" ] && { [ -z "${BITBUCKET_API_KEY:-}" ] || [ -z "${BITBUCKET_EMAIL:-}" ]; }; then
    echo -e "${CB_RED}🚨 Bitbucket credentials are not configured. Run 'mt-add-bitbucket-secret' first.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}🔍 Fetching repositories for ${raw_workspace}/${raw_project} (${provider})...${C_RESET}"
  local repos_raw
  repos_raw=$(python3 "$CLONE_WIZARD" fetch "$provider" "$raw_workspace" "$raw_project") || return 1
  [ "$provider" = "bitbucket" ] && python3 "$SECRETS_MANAGER" touch "BITBUCKET_API_KEY" 2> /dev/null

  if [ -z "$repos_raw" ]; then
    echo -e "${CB_YELLOW}⚠️  No repositories found.${C_RESET}"
    return 0
  fi

  local sanitized_workspace sanitized_project
  sanitized_workspace=$(__mt_clone_sanitize_name "$raw_workspace")
  sanitized_project=$(__mt_clone_sanitize_name "$raw_project")
  local project_dir="${VCS_ROOT:-$HOME/vcs}/${provider}/${sanitized_workspace}/${sanitized_project}"

  __mt_clone_check_collision "$project_dir" "$raw_workspace" "$raw_project" || {
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 1
  }

  # Plan columns: slug|clone_url|size|language|updated_on|is_private|target_dir|exists
  local plan_file
  plan_file=$(mktemp)
  local slug clone_url size lang updated is_private
  while IFS='|' read -r slug clone_url size lang updated is_private; do
    local target_dir="${project_dir}/${slug}"
    local exists="false"
    [ -d "${target_dir}/.git" ] && exists="true"
    echo "${slug}|${clone_url}|${size}|${lang}|${updated}|${is_private}|${target_dir}|${exists}" >> "$plan_file"
  done <<< "$repos_raw"

  local total to_clone already_exist
  total=$(wc -l < "$plan_file")
  already_exist=$(awk -F'|' '$8=="true"' "$plan_file" | wc -l)
  to_clone=$((total - already_exist))

  echo -e "\n${CB_CYAN}📋 Plan for ${raw_workspace}/${raw_project}:${C_RESET}"
  echo -e "   Total repositories:        ${total}"
  echo -e "   Already cloned (skipped):  ${already_exist}"
  echo -e "   To be cloned:              ${to_clone}\n"

  if [ "$to_clone" -eq 0 ]; then
    echo -e "${CB_GREEN}✅ Nothing to do -- every repository already exists locally.${C_RESET}"
    rm -f "$plan_file"
    return 0
  fi

  awk -F'|' '$8=="false"{print "   • " $1}' "$plan_file"
  echo ""

  if [ "$auto_approve" != true ]; then
    local reply
    # No-tty read failures must default to declining, not to the [Y/n]
    # prompt's own default-yes-on-Enter behavior -- an unreadable
    # terminal is a different situation than a user actually pressing
    # Enter, and silently proceeding with a bulk clone in the former
    # case would be a real surprise.
    read -r -p "🚀 Proceed with cloning ${to_clone} repositories? [Y/n] " -n 1 reply < /dev/tty || reply="n"
    echo
    if [[ "$reply" =~ ^[Nn]$ ]]; then
      echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
      rm -f "$plan_file"
      return 0
    fi
  fi

  local cloned=0 failed=0
  local -a failed_repos=()
  while IFS='|' read -r slug clone_url size lang updated is_private target_dir exists; do
    [ "$exists" = "true" ] && continue

    echo -e "${CB_BLUE}📥 Cloning ${slug}...${C_RESET}"
    if [ "$provider" = "bitbucket" ] && __mt_clone_bitbucket_repo "$clone_url" "$target_dir"; then
      ((cloned++))
    else
      ((failed++))
      failed_repos+=("$slug")
    fi
  done < "$plan_file"

  rm -f "$plan_file"

  echo ""
  echo -e "${CB_GREEN}✅ Cloned ${cloned} repositories.${C_RESET}"
  if [ "$failed" -gt 0 ]; then
    echo -e "${CB_RED}🚨 ${failed} repositories failed to clone: ${failed_repos[*]}${C_RESET}"
    return 1
  fi
}
