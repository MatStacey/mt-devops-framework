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
# Git: Convert a byte count into a human-readable string (B/KB/MB/GB/TB)
# Arguments:
#   $1 - Byte count
# Outputs:
#   Prints the formatted size to STDOUT
#######################################
__mt_clone_human_size() {
  awk -v b="$1" 'BEGIN {
    split("B KB MB GB TB", units, " ")
    i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf "%.1f %s", b, units[i]
  }'
}

#######################################
# Git: Print the bytes available on the filesystem containing the given
# path (creating it first if missing, since df can't stat a path that
# doesn't exist yet). Portable across GNU and BSD df (-P for POSIX
# output columns, -k for 1024-byte blocks).
# Arguments:
#   $1 - Path to check
# Outputs:
#   Prints the available byte count to STDOUT
#######################################
__mt_clone_available_bytes() {
  local path="$1"
  mkdir -p "$path"
  local available_kb
  available_kb=$(df -Pk "$path" | tail -n 1 | awk '{print $4}')
  echo $((available_kb * 1024))
}

#######################################
# Git: Sort the plan file (not-yet-cloned first, then newest-updated,
# largest-size, language, name -- matching the spec's requested table
# order) and print the full summary block + details table. The size
# estimate and disk-space check only ever count repositories that will
# actually be cloned, not ones already present, and apply a 1.5x safety
# margin since a provider's reported size is server-side git-object
# size, not the eventual on-disk footprint after checkout.
# Arguments:
#   $1 - Plan file path (slug|clone_url|size|language|updated_on|is_private|target_dir|exists)
#   $2 - Raw workspace name
#   $3 - Raw project name
#   $4 - Project directory (used for the disk-space check)
# Globals (written, expected pre-declared local by the caller):
#   MT_CLONE_TOTAL, MT_CLONE_TO_CLONE, MT_CLONE_ALREADY_EXIST
#######################################
__mt_clone_print_plan() {
  local plan_file="$1" raw_workspace="$2" raw_project="$3" project_dir="$4"

  local sorted_file
  sorted_file=$(mktemp)
  sort -t'|' -k8,8 -k5,5r -k3,3nr -k4,4 -k1,1 "$plan_file" > "$sorted_file"
  mv "$sorted_file" "$plan_file"

  MT_CLONE_TOTAL=$(wc -l < "$plan_file")
  MT_CLONE_ALREADY_EXIST=$(awk -F'|' '$8=="true"' "$plan_file" | wc -l)
  MT_CLONE_TO_CLONE=$((MT_CLONE_TOTAL - MT_CLONE_ALREADY_EXIST))

  local clone_size_bytes
  clone_size_bytes=$(awk -F'|' '$8=="false"{s+=$3} END{print s+0}' "$plan_file")
  local clone_size_human
  clone_size_human=$(__mt_clone_human_size "$clone_size_bytes")

  local available_bytes required_bytes size_color
  available_bytes=$(__mt_clone_available_bytes "$project_dir")
  required_bytes=$(awk -v s="$clone_size_bytes" 'BEGIN{printf "%d", s*1.5}')
  size_color="${CB_GREEN}"
  [ "$MT_CLONE_TO_CLONE" -gt 0 ] && [ "$available_bytes" -lt "$required_bytes" ] && size_color="${CB_RED}"

  echo -e "\n${CB_CYAN}📋 Clone Plan${C_RESET}"
  echo -e "   Workspace:                 ${raw_workspace}"
  echo -e "   Project:                   ${raw_project}"
  echo -e "   Total repositories:        ${MT_CLONE_TOTAL}"
  echo -e "   Already cloned (skipped):  ${MT_CLONE_ALREADY_EXIST}"
  echo -e "   To be cloned:              ${MT_CLONE_TO_CLONE}"
  echo -e "   Total size to clone:       ${size_color}${clone_size_human}${C_RESET}"
  if [ "$size_color" = "${CB_RED}" ]; then
    local available_human
    available_human=$(__mt_clone_human_size "$available_bytes")
    echo -e "   ${CB_RED}⚠️  Only ${available_human} available -- this may not be enough disk space.${C_RESET}"
  fi
  echo ""

  if [ "$MT_CLONE_TOTAL" -gt 0 ]; then
    printf "${CB_BLUE}%-30s %-12s %-10s %-8s %-15s${C_RESET}\n" "REPOSITORY" "UPDATED" "SIZE" "EXISTS" "LANGUAGE"
    echo -e "${CB_BLUE}--------------------------------------------------------------------------------${C_RESET}"

    local slug clone_url size lang updated is_private target_dir exists
    while IFS='|' read -r slug clone_url size lang updated is_private target_dir exists; do
      local updated_date="${updated:0:10}"
      [ -z "$updated_date" ] && updated_date="-"
      local size_human
      size_human=$(__mt_clone_human_size "$size")
      local exists_label="No" exists_color="${CB_GREEN}"
      if [ "$exists" = "true" ]; then
        exists_label="Yes"
        exists_color="${C_DIM}"
      fi
      printf "%-30s %-12s %-10s ${exists_color}%-8s${C_RESET} %-15s\n" "${slug:0:30}" "$updated_date" "$size_human" "$exists_label" "${lang:--}"
    done < "$plan_file"
    echo ""
  fi
}

#######################################
# Git: Wizard picker for the "last updated" filter -- quick calendar-
# boundary options (today/this week/this month/this year, per spec)
# resolved via clone_wizard.py's quick-date subcommand, or a specific
# date typed in the same format --from-date already accepts.
# Globals (written, expected pre-declared local by the caller):
#   from_date
#######################################
__mt_clone_wizard_pick_last_updated() {
  local choice
  choice=$(
    printf '%s\n' \
      "1. Today" \
      "2. This week" \
      "3. This month" \
      "4. This year" \
      "5. Specific date (dd-mm-yyyy)" \
      "6. No filter" |
      fzf --prompt="📅 Last Updated > " --height=~12 --layout=reverse --border
  )

  case "$choice" in
    1.*) from_date=$(python3 "$CLONE_WIZARD" quick-date today) ;;
    2.*) from_date=$(python3 "$CLONE_WIZARD" quick-date week) ;;
    3.*) from_date=$(python3 "$CLONE_WIZARD" quick-date month) ;;
    4.*) from_date=$(python3 "$CLONE_WIZARD" quick-date year) ;;
    5.*) read -r -p "Date (dd-mm-yyyy): " from_date < /dev/tty ;;
    6.*) from_date="" ;;
    *) ;;
  esac
}

#######################################
# Git: Wizard picker for the type (visibility) filter
# Globals (written, expected pre-declared local by the caller):
#   type_filter
#######################################
__mt_clone_wizard_pick_type() {
  local choice
  choice=$(printf '%s\n' "1. Private" "2. Public" "3. No filter" | fzf --prompt="🔒 Type > " --height=~10 --layout=reverse --border)
  case "$choice" in
    1.*) type_filter="private" ;;
    2.*) type_filter="public" ;;
    3.*) type_filter="" ;;
    *) ;;
  esac
}

#######################################
# Git: Wizard picker for the language filter -- populated from the
# distinct languages actually present in the already-fetched repo
# list, per spec, rather than an arbitrary free-typed value.
# Arguments:
#   $1 - Unfiltered repo list (same pipe-delimited format fetch prints)
# Globals (written, expected pre-declared local by the caller):
#   lang_filter
#######################################
__mt_clone_wizard_pick_language() {
  local repos_unfiltered="$1"
  local -a languages
  mapfile -t languages < <(awk -F'|' '$4!=""{print $4}' <<< "$repos_unfiltered" | sort -u)

  if [ "${#languages[@]}" -eq 0 ]; then
    echo -e "${CB_YELLOW}⚠️  No languages detected among these repositories.${C_RESET}"
    read -r -p "Press Enter to continue..." < /dev/tty
    return 0
  fi

  local choice
  choice=$(printf '%s\n' "${languages[@]}" "(No filter)" | fzf --prompt="💻 Language > " --height=~15 --layout=reverse --border)
  if [ -z "$choice" ] || [ "$choice" = "(No filter)" ]; then
    lang_filter=""
  else
    lang_filter="$choice"
  fi
}

#######################################
# Git: Interactively collect everything mt-clone needs (provider,
# workspace, project, filters) via fzf/prompts, fetching the project's
# full repo list once -- unfiltered, so the language picker can be
# populated from real data -- and applying whatever filters were chosen
# locally afterward via clone_wizard.py's filter subcommand, without a
# second API call.
# Globals (written, expected pre-declared local by the caller):
#   provider, raw_workspace, raw_project, repos_raw
# Returns:
#   0 on success, 1 if the user cancelled or nothing was found
#######################################
__mt_clone_run_wizard() {
  echo -e "${CB_CYAN}🧙 mt-clone Wizard${C_RESET}\n"

  provider=$(python3 "$CLONE_WIZARD" list-providers | fzf --prompt="🌐 Provider > " --height=~10 --layout=reverse --border)
  if [ -z "$provider" ]; then
    echo -e "${CB_YELLOW}🛑 Cancelled.${C_RESET}"
    return 1
  fi

  if [ "$provider" = "bitbucket" ] && { [ -z "${BITBUCKET_API_KEY:-}" ] || [ -z "${BITBUCKET_EMAIL:-}" ]; }; then
    echo -e "${CB_RED}🚨 Bitbucket credentials are not configured. Run 'mt-add-bitbucket-secret' first.${C_RESET}"
    return 1
  fi

  read -r -p "🏢 Workspace name: " raw_workspace < /dev/tty
  if [ -z "$raw_workspace" ]; then
    echo -e "${CB_YELLOW}🛑 Cancelled.${C_RESET}"
    return 1
  fi

  read -r -p "📁 Project name: " raw_project < /dev/tty
  if [ -z "$raw_project" ]; then
    echo -e "${CB_YELLOW}🛑 Cancelled.${C_RESET}"
    return 1
  fi

  echo -e "\n${CB_BLUE}🔍 Fetching repositories for ${raw_workspace}/${raw_project} (${provider})...${C_RESET}"
  local repos_unfiltered
  repos_unfiltered=$(python3 "$CLONE_WIZARD" fetch "$provider" "$raw_workspace" "$raw_project") || return 1
  [ "$provider" = "bitbucket" ] && python3 "$SECRETS_MANAGER" touch "BITBUCKET_API_KEY" 2> /dev/null

  if [ -z "$repos_unfiltered" ]; then
    echo -e "${CB_YELLOW}⚠️  No repositories found.${C_RESET}"
    return 1
  fi

  local type_filter="" lang_filter="" from_date=""
  while true; do
    local menu_choice
    menu_choice=$(
      printf '%s\n' \
        "1. Last Updated  (${from_date:-none})" \
        "2. Type          (${type_filter:-none})" \
        "3. Language      (${lang_filter:-none})" \
        "4. Continue -- show plan" |
        fzf --prompt="🧙 Filters > " --height=~12 --layout=reverse --border
    )

    case "$menu_choice" in
      1.*) __mt_clone_wizard_pick_last_updated ;;
      2.*) __mt_clone_wizard_pick_type ;;
      3.*) __mt_clone_wizard_pick_language "$repos_unfiltered" ;;
      4.* | "") break ;;
    esac
  done

  local -a filter_args=(filter)
  [ -n "$type_filter" ] && filter_args+=(--type "$type_filter")
  [ -n "$lang_filter" ] && filter_args+=(--lang "$lang_filter")
  [ -n "$from_date" ] && filter_args+=(--from-date "$from_date")

  repos_raw=$(printf '%s\n' "$repos_unfiltered" | python3 "$CLONE_WIZARD" "${filter_args[@]}")

  if [ -z "$repos_raw" ]; then
    echo -e "${CB_YELLOW}⚠️  No repositories matched your filters.${C_RESET}"
    return 1
  fi
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
# another. Filters (--type/--lang/--from-date/--year/--age) are applied
# client-side against the full project repo list, not via a provider
# query DSL -- if more than one date-ish filter is given, the OLDEST
# (most inclusive) cutoff wins. -i/--wizard runs an interactive flow
# instead (provider/workspace/project prompts, plus a filter menu whose
# language picker is populated from repositories actually present) and
# ignores -p/-w/-pr/filter flags even if also given.
# Usage: mt-clone -p <provider> -w <workspace> -pr <project> [filters] [--auto-approve]
#        mt-clone -i [--auto-approve]
# Options:
#   -p, --provider <name>     Source-control provider (currently: bitbucket)
#   -w, --workspace <name>    Workspace name
#   -pr, --project <name>     Project name (or key)
#   -t, --type <private|public>  Filter by repository visibility
#   -l, --lang <language>     Filter by programming language (case-insensitive)
#   -d, --from-date <date>    Only repos updated on/after this date --
#                              dd-mm-yyyy, dd/mm/yyyy, ddmmyyyy, or the
#                              4-digit ddmm shorthand (current year assumed)
#   -y, --year <yyyy>         Only repos updated during or after this year
#   -a, --age <days>          Only repos updated within the last N days
#   -i, --wizard               Run the interactive wizard instead
#   --auto-approve            Skip the confirmation prompt
#   -h, --help                 Show this help menu
# Globals:
#   VCS_ROOT, CLONE_WIZARD, SECRETS_MANAGER, BITBUCKET_API_KEY, BITBUCKET_EMAIL
#######################################
mt-clone() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local provider="" raw_workspace="" raw_project="" auto_approve=false do_wizard=false
  local type_filter="" lang_filter="" from_date="" year_filter="" age_filter=""
  local repos_raw

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -i | --wizard)
        do_wizard=true
        shift
        ;;
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
      -t | --type)
        type_filter="${2,,}"
        if [[ "$type_filter" != "private" && "$type_filter" != "public" ]]; then
          echo "mt-clone: --type must be 'private' or 'public'" >&2
          return 1
        fi
        shift 2
        ;;
      -l | --lang)
        lang_filter="$2"
        shift 2
        ;;
      -d | --from-date)
        from_date="$2"
        shift 2
        ;;
      -y | --year)
        if ! [[ "$2" =~ ^[0-9]{4}$ ]]; then
          echo "mt-clone: --year requires a 4-digit year" >&2
          return 1
        fi
        year_filter="$2"
        shift 2
        ;;
      -a | --age)
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          echo "mt-clone: --age requires a non-negative number of days" >&2
          return 1
        fi
        age_filter="$2"
        shift 2
        ;;
      --auto-approve)
        auto_approve=true
        shift
        ;;
      *)
        echo "Usage: mt-clone -p <provider> -w <workspace> -pr <project> [-t private|public] [-l language] [-d date] [-y year] [-a days] [--auto-approve] | mt-clone -i" >&2
        return 1
        ;;
    esac
  done

  if [ "$do_wizard" = true ]; then
    __mt_clone_run_wizard || return 1
  else
    if [ -z "$provider" ] || [ -z "$raw_workspace" ] || [ -z "$raw_project" ]; then
      echo -e "${CB_RED}🚨 --provider, --workspace, and --project are all required.${C_RESET}"
      return 1
    fi

    if [ "$provider" = "bitbucket" ] && { [ -z "${BITBUCKET_API_KEY:-}" ] || [ -z "${BITBUCKET_EMAIL:-}" ]; }; then
      echo -e "${CB_RED}🚨 Bitbucket credentials are not configured. Run 'mt-add-bitbucket-secret' first.${C_RESET}"
      return 1
    fi

    echo -e "${CB_BLUE}🔍 Fetching repositories for ${raw_workspace}/${raw_project} (${provider})...${C_RESET}"
    local -a fetch_args=(fetch "$provider" "$raw_workspace" "$raw_project")
    local filters_applied=false
    [ -n "$type_filter" ] && fetch_args+=(--type "$type_filter") && filters_applied=true
    [ -n "$lang_filter" ] && fetch_args+=(--lang "$lang_filter") && filters_applied=true
    [ -n "$from_date" ] && fetch_args+=(--from-date "$from_date") && filters_applied=true
    [ -n "$year_filter" ] && fetch_args+=(--year "$year_filter") && filters_applied=true
    [ -n "$age_filter" ] && fetch_args+=(--age "$age_filter") && filters_applied=true

    repos_raw=$(python3 "$CLONE_WIZARD" "${fetch_args[@]}") || return 1
    [ "$provider" = "bitbucket" ] && python3 "$SECRETS_MANAGER" touch "BITBUCKET_API_KEY" 2> /dev/null

    if [ -z "$repos_raw" ]; then
      if [ "$filters_applied" = true ]; then
        echo -e "${CB_YELLOW}⚠️  No repositories matched your filters.${C_RESET}"
      else
        echo -e "${CB_YELLOW}⚠️  No repositories found.${C_RESET}"
      fi
      return 0
    fi
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

  local MT_CLONE_TOTAL MT_CLONE_TO_CLONE MT_CLONE_ALREADY_EXIST
  __mt_clone_print_plan "$plan_file" "$raw_workspace" "$raw_project" "$project_dir"

  if [ "$MT_CLONE_TO_CLONE" -eq 0 ]; then
    echo -e "${CB_GREEN}✅ Nothing to do -- every repository already exists locally.${C_RESET}"
    rm -f "$plan_file"
    return 0
  fi

  if [ "$auto_approve" != true ]; then
    local reply
    # No-tty read failures must default to declining, not to the [Y/n]
    # prompt's own default-yes-on-Enter behavior -- an unreadable
    # terminal is a different situation than a user actually pressing
    # Enter, and silently proceeding with a bulk clone in the former
    # case would be a real surprise.
    read -r -p "🚀 Proceed with cloning ${MT_CLONE_TO_CLONE} repositories? [Y/n] " -n 1 reply < /dev/tty || reply="n"
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
