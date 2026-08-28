# shellcheck shell=bash
# ------------------------------------------
# General System Utilities
# ------------------------------------------
# ~/.bash.d/02-utilities/99-utils.sh

#######################################
# System: Display the top largest files in a directory
# Arguments:
#   $1 - Count (default: 10)
#   $2 - Target directory (default: .)
#######################################
mt-top-files() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local count="${1:-10}"
  local target_dir="${2:-.}"
  echo -e "${CB_BLUE}📊 Finding the top ${count} largest files in ${target_dir}...${C_RESET}"
  find "$target_dir" -type f -exec du -h {} + 2> /dev/null | sort -rh | head -n "$count"
}

#######################################
# AI: Retrieve prompt string from prompts.yaml
# Arguments:
#   $1 - Prompt key
#######################################
__get_prompt() {
  python3 "$HOME/.bash.d/lib/python/get_prompt.py" "$1"
}

#######################################
# System: Audit VCS root for unorganized files and directories
#######################################
mt-vcs-audit() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local vcs_dir="${VCS_ROOT:-$HOME/vcs}"
  echo -e "${CB_BLUE}🔍 Auditing ${vcs_dir} for unorganized items...${C_RESET}\n"

  if command -v eza > /dev/null 2>&1; then
    # Print a tree up to 3 levels deep, ignoring our organized folders
    eza -la --tree --level=3 --group-directories-first -I "external|personal|work|workspaces|misc|.git" "$vcs_dir"
  else
    # Fallback to standard ls if eza is unavailable
    # shellcheck disable=SC2010
    ls -la "$vcs_dir" | grep -vE "(external|personal|work|workspaces|misc)"
  fi
}

#######################################
# System: Interactively create or update an alias
# Usage: mt-alias [-u alias_name] [-i] [-p]
# Options:
#   -u, --update <name>   Update a specific existing alias
#   -i, --interactive     Select an existing alias to update via fzf
#   -p, --private         Create the alias in a local-only file that is
#                         never synced to the framework repo (matches
#                         install.sh's own *private*.sh protection, so it
#                         also survives fresh installs and mt-get-update)
#######################################
mt-alias() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local update_name="" interactive=false private=false
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -u | --update)
        update_name="$2"
        shift 2
        ;;
      -i | --interactive)
        interactive=true
        shift
        ;;
      -p | --private)
        private=true
        shift
        ;;
      *)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
  done
  if [ "$interactive" = true ]; then
    update_name=$(awk -F'\t' '$1 == "alias" { printf "%-24s │ %-20s │ %s\n", $3, $2, $4 }' "$HOME/.bash.d/data/cache/.mt_data.tsv" | fzf --ansi --prompt="Select Alias to Update > " | awk '{print $1}')
    [ -z "$update_name" ] && return 0
  fi
  local alias_name="$update_name" default_cmd="" default_cat="User Custom" default_desc=""
  local public_aliases_file="$HOME/.bash.d/02-utilities/20-aliases.sh"
  local private_aliases_file="$HOME/.bash.d/02-utilities/20-aliases.private.sh"
  local aliases_file="$public_aliases_file"
  [ "$private" = true ] && aliases_file="$private_aliases_file"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  if [ -n "$alias_name" ]; then
    if grep -qE "^[ \t]*alias ${alias_name}=" "$private_aliases_file" 2> /dev/null; then
      aliases_file="$private_aliases_file"
    elif ! grep -qE "^[ \t]*alias ${alias_name}=" "$public_aliases_file" 2> /dev/null; then
      echo -e "${CB_RED}🚨 Error: Alias '${alias_name}' not found.${C_RESET}"
      return 1
    else
      aliases_file="$public_aliases_file"
    fi
    echo -e "${CB_CYAN} 🛠️  Update Existing Alias: ${alias_name}${C_RESET}"
    default_cmd=$(grep -E "^[ \t]*alias ${alias_name}=" "$aliases_file" | sed -E "s/^[ \t]*alias ${alias_name}=['\"]?//;s/['\"]?$//")
    local tsv_line
    tsv_line=$(awk -F'\t' -v n="$alias_name" '$1=="alias" && $3==n {print $2 "|" $4}' "$HOME/.bash.d/data/cache/.mt_data.tsv" | head -n 1)
    if [ -n "$tsv_line" ]; then
      default_cat=$(echo "$tsv_line" | cut -d'|' -f1)
      default_desc=$(echo "$tsv_line" | cut -d'|' -f2)
    fi
  else
    echo -e "${CB_CYAN} 🛠️  Create New $([ "$private" = true ] && echo "Private ")Alias${C_RESET}"
    read -r -p "1️⃣  Alias Name (e.g., kgpo)     : " alias_name
    [ -z "$alias_name" ] && return 1
    if grep -qE "^[ \t]*alias ${alias_name}=" "$public_aliases_file" 2> /dev/null || grep -qE "^[ \t]*alias ${alias_name}=" "$private_aliases_file" 2> /dev/null; then
      echo -e "${CB_RED}🚨 Alias already exists. Use -u to update.${C_RESET}"
      return 1
    fi
  fi
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  local alias_cmd="" alias_cat="" alias_desc=""
  read -r -e -i "$default_cmd" -p "2️⃣  Target Command             : " alias_cmd
  [ -z "$alias_cmd" ] && return 1
  read -r -e -i "$default_cat" -p "3️⃣  Category (e.g., Docker)    : " alias_cat
  [ -z "$alias_cat" ] && alias_cat="User Custom"
  read -r -e -i "$default_desc" -p "4️⃣  Description                : " alias_desc
  [ -z "$alias_desc" ] && alias_desc="Custom shortcut for ${alias_cmd}"
  if [ -n "$update_name" ]; then
    python3 "$HOME/.bash.d/lib/python/remove_alias_block.py" "$aliases_file" "$alias_name"
  fi
  if [ ! -f "$aliases_file" ]; then
    cat << HEADEREOF > "$aliases_file"
# shellcheck shell=bash
# ------------------------------------------
# Private Aliases (local-only -- never synced to the framework repo)
# ------------------------------------------
# ~/.bash.d/02-utilities/20-aliases.private.sh
HEADEREOF
  fi
  cat << ALIASEOF >> "$aliases_file"

#######################################
# ${alias_cat}: ${alias_desc}
#######################################
alias ${alias_name}='${alias_cmd}'
ALIASEOF
  # shellcheck disable=SC1090
  source "$aliases_file"
  mt-refresh-caches > /dev/null 2>&1
  echo -e "${CB_GREEN}🎉 Success! You can now use '${alias_name}'.${C_RESET}"
}

#######################################
# System: Display history of executed framework commands
# Usage: mt-cmd-history [-i|--interactive] [-n count]
# Options:
#   -i, --interactive  Select a past framework command via fzf to re-run
#   -n, --lines <num>  Number of entries to show (default: 20)
#######################################
mt-cmd-history() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local interactive=false
  local limit=20

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -i | --interactive) interactive=true ;;
      -n | --lines)
        limit="$2"
        shift
        ;;
      *)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
    shift
  done

  local tsv_file="$HOME/.bash.d/data/cache/.mt_data.tsv"
  if [ ! -f "$tsv_file" ]; then
    mt-refresh-caches > /dev/null 2>&1
  fi

  local tmp_cmds tmp_hist
  tmp_cmds=$(mktemp)
  tmp_hist=$(mktemp)

  # Extract list of framework functions and aliases into a clean file
  awk -F"\t" "{print \$3}" "$tsv_file" | sort -u | grep -v "^$" > "$tmp_cmds"

  if [ ! -s "$tmp_cmds" ]; then
    echo -e "${CB_RED}🚨 Failed to load framework command definitions.${C_RESET}"
    rm -f "$tmp_cmds" "$tmp_hist"
    return 1
  fi

  # Flush current in-memory history to disk
  history -a 2> /dev/null || true

  local hist_source="$HOME/.bash_history"

  if [ -f "$hist_source" ]; then
    local awk_script="$HOME/.bash.d/lib/awk/history_filter.awk"
    # Force grep -a (text mode) and strip non-printable characters
    strings "$hist_source" 2> /dev/null | grep -a -v -E "^(#|[[:space:]]*$)" |
      sed "s/^[[:space:]]*[0-9]*[[:space:]]*//" |
      awk -v cmd_file="$tmp_cmds" -f "$awk_script" | awk "!seen[\$0]++" | tail -n "$limit" > "$tmp_hist"
  fi

  rm -f "$tmp_cmds"

  if [ ! -s "$tmp_hist" ]; then
    echo -e "${CB_YELLOW}⚠️ No recorded framework commands found in shell history.${C_RESET}"
    rm -f "$tmp_hist"
    return 0
  fi

  if [ "$interactive" = true ]; then
    local selected_cmd
    selected_cmd=$(fzf --prompt="Re-run Framework Command > " --header="Framework Command History" < "$tmp_hist")
    rm -f "$tmp_hist"

    if [ -n "$selected_cmd" ]; then
      echo -e "${CB_GREEN}🚀 Executing:${C_RESET} ${selected_cmd}"
      eval "$selected_cmd"
    fi
  else
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e "${CB_CYAN} 📜 Recent Framework Command History${C_RESET}"
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    awk -v yellow="$CB_YELLOW" -v white="$C_WHITE" -v rst="$C_RESET" '{printf "  %s%3d%s  %s%s%s\n", yellow, NR, rst, white, $0, rst}' "$tmp_hist"
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e "${C_DIM}Run 'mt-history -i' to select and re-run a command via fzf.${C_RESET}"
    rm -f "$tmp_hist"
  fi
}

#######################################
# System: Display history of executed framework commands (Alias)
#######################################
alias mt-history="mt-cmd-history"

#######################################
# System: Safely execute or write clipboard code without terminal paste truncation
# Usage: mt-apply [optional_target_file_path]
#######################################
mt-apply() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local tmp_raw tmp_clean
  tmp_raw=$(mktemp /tmp/mt_apply_raw_XXXXXX)
  tmp_clean=$(mktemp /tmp/mt_apply_clean_XXXXXX)
  local target_file="${1:-}"

  if command -v powershell.exe > /dev/null 2>&1; then
    powershell.exe -Command "Get-Clipboard" | tr -d "\r" > "$tmp_raw"
  elif command -v xclip > /dev/null 2>&1; then
    xclip -o -selection clipboard > "$tmp_raw"
  elif command -v pbpaste > /dev/null 2>&1; then
    pbpaste > "$tmp_raw"
  else
    echo -e "${CB_RED}🚨 No clipboard helper found.${C_RESET}"
    rm -f "$tmp_raw" "$tmp_clean"
    return 1
  fi

  if [ ! -s "$tmp_raw" ]; then
    echo -e "${CB_YELLOW}⚠️ Clipboard is empty!${C_RESET}"
    rm -f "$tmp_raw" "$tmp_clean"
    return 1
  fi

  grep -v -E "^[[:space:]]*\`\`\`" "$tmp_raw" | sed -E "s/^[[:space:]]*\$[[:space:]]*//" > "$tmp_clean"

  if [ -n "$target_file" ]; then
    mkdir -p "$(dirname "$target_file")"
    mv "$tmp_clean" "$target_file"
    rm -f "$tmp_raw"
    echo -e "${CB_GREEN}✅ Successfully written clipboard content to ${target_file}!${C_RESET}"
    return 0
  fi

  if python3 -c 'import sys; txt=open(sys.argv[1]).read(); sys.exit(0 if ("import " in txt or "shutil." in txt or "os.path" in txt) and not "python3 -c" in txt else 1)' "$tmp_clean"; then
    echo -e "${CB_BLUE}⚡ Executing native Python script from clipboard...${C_RESET}"
    python3 "$tmp_clean"
  else
    echo -e "${CB_BLUE}⚡ Executing Bash script from clipboard...${C_RESET}"
    bash "$tmp_clean"
  fi

  local exit_code=$?
  rm -f "$tmp_raw" "$tmp_clean"
  return $exit_code
}
