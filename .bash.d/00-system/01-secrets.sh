# shellcheck shell=bash
# ------------------------------------------
# Secrets Management
# ------------------------------------------
# ~/.bash.d/00-system/01-secrets.sh

#######################################
# System: Safely write or update one exported variable inside
# $SECRETS_FILE (~/secrets/secrets.sh), preserving every other line
# already in the file. Creates the file/directory (with restrictive
# permissions) if they don't exist yet.
# Arguments:
#   $1 - Variable name (e.g. GEMINI_API_KEY)
#   $2 - Value to store
# Globals:
#   SECRETS_DIR, SECRETS_FILE
#######################################
__mt_write_secret() {
  local var_name="$1" value="$2"

  mkdir -p "$SECRETS_DIR"
  chmod 700 "$SECRETS_DIR" 2> /dev/null

  if [ ! -f "$SECRETS_FILE" ]; then
    cat << 'HDR' > "$SECRETS_FILE"
#!/usr/bin/env bash
# Externalized MT DevOps Secrets
# Sourced by ~/.bash.d/00-system/00-config.sh on every shell startup and
# whenever config.yaml changes. Never tracked in git -- this directory
# lives outside ~/vcs entirely.
HDR
  fi
  chmod 600 "$SECRETS_FILE"

  local quoted_value
  printf -v quoted_value '%q' "$value"
  local new_line="export ${var_name}=${quoted_value}"

  if grep -q "^export ${var_name}=" "$SECRETS_FILE" 2> /dev/null; then
    local tmp_file
    tmp_file=$(mktemp)
    awk -v pat="^export ${var_name}=" -v line="$new_line" '
      $0 ~ pat { print line; next }
      { print }
    ' "$SECRETS_FILE" > "$tmp_file" && mv "$tmp_file" "$SECRETS_FILE"
  else
    # A missing trailing newline on the file's last line would otherwise
    # make this append land on the SAME physical line as it -- bash then
    # concatenates the two adjacent tokens with no separator, silently
    # corrupting whatever secret was already on that line.
    [ -s "$SECRETS_FILE" ] && [ -n "$(tail -c1 "$SECRETS_FILE")" ] && echo >> "$SECRETS_FILE"
    echo "$new_line" >> "$SECRETS_FILE"
  fi

  chmod 600 "$SECRETS_FILE"
}

#######################################
# System: Remove a secret's value from secrets.sh (and its paired
# variable, if it has one -- e.g. Bitbucket's token+email), unset it from
# the current shell, and clear its tracked metadata (created/expiry/
# last-used) so a later re-add starts a fresh history.
# Arguments:
#   $1 - Secret variable name
#   $2 - Paired variable name, if any (empty string if none)
# Globals:
#   SECRETS_FILE
#######################################
__mt_delete_secret() {
  local name="$1" paired="$2"

  if [ -f "$SECRETS_FILE" ]; then
    local tmp_file
    tmp_file=$(mktemp)
    grep -v -E "^export (${name}|${paired})=" "$SECRETS_FILE" > "$tmp_file"
    mv "$tmp_file" "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
  fi

  unset "${name?}"
  [ -n "$paired" ] && unset "${paired?}"

  python3 "$SECRETS_MANAGER" unregister "$name"
}

#######################################
# AI: Interactively add or update your Gemini API key
# Usage: mt-add-gemini-key
# Globals:
#   Writes to ~/secrets/secrets.sh (never touches config.yaml or git)
#   and exports GEMINI_API_KEY into the current shell immediately.
#######################################
mt-add-gemini-key() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local key
  read -r -s -p "🔑 Enter your Gemini API key (input hidden): " key < /dev/tty
  echo

  if [ -z "$key" ]; then
    echo -e "${CB_YELLOW}⚠️  No key entered. Aborted.${C_RESET}"
    return 1
  fi

  __mt_write_secret "GEMINI_API_KEY" "$key"
  export GEMINI_API_KEY="$key"
  python3 "$SECRETS_MANAGER" register "GEMINI_API_KEY"
  echo -e "${CB_GREEN}✅ Gemini API key saved to ~/secrets/secrets.sh and loaded into this shell.${C_RESET}"
}

#######################################
# AI: Interactively add or update your Claude API key
# Usage: mt-add-claude-key
# Globals:
#   Writes to ~/secrets/secrets.sh (never touches config.yaml or git)
#   and exports CLAUDE_API_KEY into the current shell immediately.
#######################################
mt-add-claude-key() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local key
  read -r -s -p "🔑 Enter your Claude API key (input hidden): " key < /dev/tty
  echo

  if [ -z "$key" ]; then
    echo -e "${CB_YELLOW}⚠️  No key entered. Aborted.${C_RESET}"
    return 1
  fi

  __mt_write_secret "CLAUDE_API_KEY" "$key"
  export CLAUDE_API_KEY="$key"
  python3 "$SECRETS_MANAGER" register "CLAUDE_API_KEY"
  echo -e "${CB_GREEN}✅ Claude API key saved to ~/secrets/secrets.sh and loaded into this shell.${C_RESET}"
}

#######################################
# System: Interactively add or update your Bitbucket API token, paired
# with the Atlassian account email it belongs to. Bitbucket's REST API
# authenticates API tokens via HTTP Basic Auth as <email>:<token> -- the
# token alone isn't enough to actually call the API, so both are always
# collected and stored together.
# Usage: mt-add-bitbucket-secret
# Globals:
#   Writes to ~/secrets/secrets.sh (never touches config.yaml or git)
#   and exports BITBUCKET_API_KEY/BITBUCKET_EMAIL into the current shell
#   immediately.
#######################################
mt-add-bitbucket-secret() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local email
  read -r -p "📧 Atlassian account email: " email < /dev/tty
  if [ -z "$email" ]; then
    echo -e "${CB_YELLOW}⚠️  No email entered. Aborted.${C_RESET}"
    return 1
  fi

  local key
  read -r -s -p "🔑 Enter your Bitbucket API token (input hidden): " key < /dev/tty
  echo
  if [ -z "$key" ]; then
    echo -e "${CB_YELLOW}⚠️  No token entered. Aborted.${C_RESET}"
    return 1
  fi

  local expiry
  read -r -p "📅 Token expiry date, YYYY-MM-DD (leave blank if unknown): " expiry < /dev/tty
  if [ -n "$expiry" ] && ! [[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo -e "${CB_YELLOW}⚠️  '$expiry' doesn't look like YYYY-MM-DD -- saving without an expiry date.${C_RESET}"
    expiry=""
  fi

  __mt_write_secret "BITBUCKET_EMAIL" "$email"
  __mt_write_secret "BITBUCKET_API_KEY" "$key"
  export BITBUCKET_EMAIL="$email"
  export BITBUCKET_API_KEY="$key"
  python3 "$SECRETS_MANAGER" register "BITBUCKET_API_KEY" "$expiry"
  echo -e "${CB_GREEN}🎉 Bitbucket credentials saved to ~/secrets/secrets.sh and loaded into this shell.${C_RESET}"
}

#######################################
# System: Print the framework's supported-secrets registry as a
# colorized status table -- never displays secret values, only whether
# each is configured plus its tracked metadata (system, description,
# created/expiry/last-used dates).
# Globals:
#   SECRETS_MANAGER
#######################################
__mt_secrets_print_table() {
  printf "\n${CB_BLUE}%-20s %-22s %-16s %-12s %-10s${C_RESET}\n" "SECRET" "SYSTEM" "STATUS" "EXPIRY" "LAST USED"
  echo -e "${CB_BLUE}--------------------------------------------------------------------------------${C_RESET}"

  local name system desc configured created expiry status days last_used
  while IFS='|' read -r name system desc configured created expiry status days last_used; do
    local status_label status_color
    if [ "$configured" != "true" ]; then
      status_label="Not Configured"
      status_color="${C_DIM}"
    else
      case "$status" in
        expired)
          status_label="EXPIRED"
          status_color="${CB_RED}"
          ;;
        expiring)
          status_label="Expires in ${days}d"
          status_color="${CB_YELLOW}"
          ;;
        *)
          status_label="Active"
          status_color="${CB_GREEN}"
          ;;
      esac
    fi
    printf "%-20s %-22s ${status_color}%-16s${C_RESET} %-12s %-10s\n" "$name" "$system" "$status_label" "${expiry:--}" "${last_used:--}"
  done < <(python3 "$SECRETS_MANAGER" list)

  echo -e "\n${C_DIM}Secret values are never shown. Use 'Add / Update' or 'Delete' from the mt-secrets menu to manage them.${C_RESET}"
}

#######################################
# System: fzf-pick one secret NAME from the full registry (configured or
# not), printing "NAME System" pairs but only ever returning the NAME
# Globals:
#   SECRETS_MANAGER
#######################################
__mt_secrets_pick_name() {
  python3 "$SECRETS_MANAGER" list | awk -F'|' '{print $1 "\t" $2}' | fzf --delimiter="\t" --with-nth=1,2 --prompt="Select Secret > " | cut -f1
}

#######################################
# System: Add or update a secret -- fzf-picks any registered secret type
# (whether currently configured or not) and delegates to its own
# mt-add-*-key/mt-add-*-secret command, since each type may need
# different prompts (e.g. Bitbucket's paired email).
# Globals:
#   SECRETS_MANAGER
#######################################
__mt_secrets_add_or_update() {
  local name
  name=$(__mt_secrets_pick_name)
  [ -z "$name" ] && return 0

  local desc_line add_cmd
  desc_line=$(python3 "$SECRETS_MANAGER" describe "$name")
  add_cmd="${desc_line%%|*}"
  "$add_cmd"
}

#######################################
# System: Delete a configured secret (and its paired variable, if any)
# after confirmation
# Globals:
#   SECRETS_MANAGER
#######################################
__mt_secrets_delete() {
  local name
  name=$(python3 "$SECRETS_MANAGER" list | awk -F'|' '$4=="true"{print $1"\t"$2}' | fzf --delimiter="\t" --with-nth=1,2 --prompt="Select Secret to Delete > " | cut -f1)
  [ -z "$name" ] && return 0

  echo -e "${CB_YELLOW}⚠️  This will remove ${name} (and its paired variable, if any) from secrets.sh.${C_RESET}"
  local reply
  read -r -p "Proceed? [y/N] " -n 1 reply < /dev/tty
  echo
  if [[ ! $reply =~ ^[Yy]$ ]]; then
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 0
  fi

  local desc_line paired
  desc_line=$(python3 "$SECRETS_MANAGER" describe "$name")
  paired="${desc_line#*|}"
  __mt_delete_secret "$name" "$paired"
  echo -e "${CB_GREEN}✅ ${name} removed.${C_RESET}"
}

#######################################
# System: Show full metadata for one secret (system, features using it,
# expiry, last used) -- never the value itself
# Globals:
#   SECRETS_MANAGER
#######################################
__mt_secrets_info() {
  local name
  name=$(__mt_secrets_pick_name)
  [ -z "$name" ] && return 0

  local line
  line=$(python3 "$SECRETS_MANAGER" list | grep "^${name}|")
  local n system desc configured created expiry status days last_used
  IFS='|' read -r n system desc configured created expiry status days last_used <<< "$line"

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_CYAN} 🔐 ${n}${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e " ${CB_CYAN}System        ${C_RESET}: ${system}"
  echo -e " ${CB_CYAN}Used by       ${C_RESET}: ${desc}"
  if [ "$configured" = "true" ]; then
    echo -e " ${CB_CYAN}Configured    ${C_RESET}: ${CB_GREEN}Yes${C_RESET} (added ${created:-unknown})"
    local expiry_color="${CB_GREEN}" expiry_label="${expiry:-No expiry}"
    case "$status" in
      expired)
        expiry_color="${CB_RED}"
        expiry_label="${expiry} (EXPIRED)"
        ;;
      expiring)
        expiry_color="${CB_YELLOW}"
        expiry_label="${expiry} (${days}d remaining)"
        ;;
    esac
    echo -e " ${CB_CYAN}Expiry        ${C_RESET}: ${expiry_color}${expiry_label}${C_RESET}"
    echo -e " ${CB_CYAN}Last Used     ${C_RESET}: ${last_used:-Never}"
  else
    echo -e " ${CB_CYAN}Configured    ${C_RESET}: ${CB_YELLOW}No${C_RESET}"
  fi
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
}

#######################################
# System: Interactive menu for managing the framework's supported
# secrets (currently Gemini, Claude, Bitbucket) -- add/update, delete,
# and view metadata (system, features using it, expiry, last used).
# Secret VALUES are never displayed, only whether each is configured.
# Usage: mt-secrets
#######################################
mt-secrets() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mt_menu_submenu "🔐 Secrets Manager" \
    "List Secrets" __mt_secrets_print_table \
    "Add / Update a Secret" __mt_secrets_add_or_update \
    "Delete a Secret" __mt_secrets_delete \
    "View Secret Info" __mt_secrets_info
}
