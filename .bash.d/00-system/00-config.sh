# shellcheck shell=bash disable=SC2119,SC2120
# ------------------------------------------
# Configuration Management
# ------------------------------------------
# ~/.bash.d/00-system/00-config.sh

#######################################
# System: Resolve one XDG Base Directory the same way config_manager.py's
# xdg_dir() does -- $<xdg_var> if it's set to an absolute path (a
# relative value is invalid per spec and ignored), otherwise
# ~/<fallback_rel>, with the framework's own directory appended either
# way. Needed here, before config.yaml can even be parsed, to compute
# CONFIG_FILE/ENV_CACHE's own bootstrap-time defaults (both can't
# depend on config.yaml content -- CONFIG_FILE because it's the file
# itself, ENV_CACHE because it's the parsed-config cache).
# Arguments:
#   $1 - XDG environment variable name (e.g. "XDG_CACHE_HOME")
#   $2 - Fallback path relative to $HOME (e.g. ".cache")
# Outputs:
#   Prints the resolved, framework-scoped directory path to stdout
#######################################
__mt_xdg_dir() {
  local xdg_var="$1" fallback_rel="$2"
  local xdg_value="${!xdg_var}"
  if [[ "$xdg_value" == /* ]]; then
    echo "${xdg_value}/mt-devops-framework"
  else
    echo "$HOME/${fallback_rel}/mt-devops-framework"
  fi
}

CONFIG_FILE="${CONFIG_FILE:-$(__mt_xdg_dir XDG_CONFIG_HOME .config)/config.yaml}"
CONFIG_MANAGER="$HOME/.bash.d/lib/python/config_manager.py"
SECRETS_MANAGER="$HOME/.bash.d/lib/python/secrets_manager.py"
ENV_CACHE="$(__mt_xdg_dir XDG_CACHE_HOME .cache)/.env.cache"
YAML_TEMPLATE="$HOME/.bash.d/lib/templates/config.yaml.tpl"

# Real secret values (API keys, tokens) never live in config.yaml or git --
# they're externalized to this file, outside ~/vcs entirely so a `mt-clone`
# or repo re-sync can never touch it. Single source of truth for the path;
# secrets_manager.py carries its own copy of this constant since it's a
# standalone Python script with no shared env with bash.
SECRETS_DIR="$HOME/secrets"
SECRETS_FILE="$SECRETS_DIR/secrets.sh"

# The framework's source-of-truth repository. Intentionally a hardcoded
# constant, not a config.yaml setting: it's where mt-get-update pulls
# releases from and where git-raise-pr/mt-push-update raise PRs against.
# Collaborators point their OWN pushes at a fork via SYNC_REPO_URL
# (mt-add-sync-url / mt-become-collaborator) -- this value only changes if
# the maintainer moves the repo itself.
UPSTREAM_REPO_PATH="MatStacey/mt-devops-framework"

# One-time move of config.yaml/.syncignore/secrets_metadata.yaml from
# the pre-XDG ~/.bash.d/config/ location, before the scaffold-if-
# missing check below -- otherwise a not-yet-migrated install would
# find nothing at the new CONFIG_FILE path and create a fresh default
# there, stranding the user's real settings unread at the old path.
# Runs once per new shell (this file isn't re-sourced per-prompt) and
# is a cheap no-op on every run after the first.
if [ -f "$CONFIG_MANAGER" ]; then
  __mt_config_files_moved="$(python3 "$CONFIG_MANAGER" migrate-config-files)"
  if [ -n "$__mt_config_files_moved" ]; then
    echo "📦 Moved config files to their new XDG location:"
    echo "   - ${__mt_config_files_moved//$'\n'/$'\n   - '}"
  fi
  unset __mt_config_files_moved
fi

if [ ! -s "$CONFIG_FILE" ]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  if [ -f "$YAML_TEMPLATE" ]; then
    cp "$YAML_TEMPLATE" "$CONFIG_FILE"
  else
    touch "$CONFIG_FILE"
  fi
fi
chmod 600 "$CONFIG_FILE" 2> /dev/null

#######################################
# System: Intercept shell prompt to intelligently reload config.yaml if
# modified -- also invalidates when config_manager.py itself is newer
# than the cache, since a new export line (e.g. a schema addition) can
# make the cache stale even though the user's own config.yaml data
# never changed.
#######################################
__reload_config_if_modified() {
  if [ -f "$CONFIG_MANAGER" ]; then
    if [ ! -f "$ENV_CACHE" ] || [ "$CONFIG_FILE" -nt "$ENV_CACHE" ] || [ "$CONFIG_MANAGER" -nt "$ENV_CACHE" ]; then
      local old_theme="$BASH_THEME"
      python3 "$CONFIG_MANAGER" load-env > "$ENV_CACHE"
      chmod 600 "$ENV_CACHE" 2> /dev/null
      # shellcheck disable=SC1090
      source "$ENV_CACHE"

      # Load externalized secrets
      if [ -f "$SECRETS_FILE" ]; then
        # shellcheck disable=SC1091
        source "$SECRETS_FILE"
      fi

      if [ "$old_theme" != "$BASH_THEME" ]; then
        source "$HOME/.bash.d/01-ui/01-colors.sh"
      fi
    fi
  fi
}

[[ "$PROMPT_COMMAND" != *"__reload_config_if_modified"* ]] && PROMPT_COMMAND="__reload_config_if_modified; ${PROMPT_COMMAND:-}"
__reload_config_if_modified

# Force load the cache for fresh terminal sessions
if [ -f "$ENV_CACHE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_CACHE"

  # Load externalized secrets
  if [ -f "$SECRETS_FILE" ]; then
    # shellcheck disable=SC1091
    source "$SECRETS_FILE"
  fi
fi

# Ensure color definitions are loaded before running startup checks
if [ -f "$HOME/.bash.d/01-ui/01-colors.sh" ]; then
  source "$HOME/.bash.d/01-ui/01-colors.sh"
fi

if [[ -z "$GEMINI_API_KEY" || "$GEMINI_API_KEY" == "YOUR_GEMINI_API_KEY" || "$GEMINI_API_KEY" == "null" ]]; then
  unset GEMINI_API_KEY
  if [[ "${DEFAULT_AI:-gemini}" == "gemini" ]]; then
    echo -e "${C_YELLOW}No Gemini API Key provided. Add one via:${C_RESET}"
    echo -e "    ${C_RESET}mt-add-gemini-key"
  fi
fi

if [[ -z "$CLAUDE_API_KEY" || "$CLAUDE_API_KEY" == "YOUR_CLAUDE_API_KEY" || "$CLAUDE_API_KEY" == "null" ]]; then
  unset CLAUDE_API_KEY
  if [[ "${DEFAULT_AI:-gemini}" == "claude" ]]; then
    echo -e "${C_YELLOW}No Claude API Key provided. Add one via:${C_RESET}"
    echo -e "    ${C_RESET}mt-add-claude-key"
  fi
fi

#######################################
# AI: Print current Gemini API model version and extended reasoning mode toggle
#######################################
mt-get-gemini-status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}                 GEMINI CONFIGURATION                     ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e " ${CB_CYAN}GEMINI_VERSION    ${C_RESET}: ${GEMINI_VERSION:-Not Set}"
  echo -e " ${CB_CYAN}GEMINI_EXTENDED   ${C_RESET}: ${GEMINI_EXTENDED:-false}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
}

#######################################
# Config: Toggle global format-on-push behavior (true/false)
#######################################
mt-toggle-format-on-push() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local current="${GIT_FORMAT_ON_PUSH:-true}"
  local next="true"
  [ "$current" = "true" ] && next="false"

  python3 "$CONFIG_MANAGER" update "git" "enable_format_on_push" "$next"
  export GIT_FORMAT_ON_PUSH="$next"
  echo "✅ Format-on-push set to $next."
}

#######################################
# Config: Toggle whether mt-get-update pauses to confirm before overwriting
# local ~/.bash.d modifications that diverge from the downloaded release
# (true/false). Defaults to false, since most users don't carry local,
# unpushed changes to their deployed tree and just want updates to apply.
#######################################
mt-toggle-update-confirm() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local current="${CONFIRM_UPDATE_DIVERGENCE:-false}"
  local next="true"
  [ "$current" = "true" ] && next="false"

  python3 "$CONFIG_MANAGER" update "core" "confirm_update_divergence" "$next"
  export CONFIRM_UPDATE_DIVERGENCE="$next"
  echo "✅ Update-divergence confirmation set to $next."
}

#######################################
# Config: Set default terminal IDE launcher
# Usage: mt-set-default-ide "vscode|intellij"
# Arguments:
#   $1 - IDE identifier (vscode or intellij)
#######################################
mt-set-default-ide() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [[ "$1" != "vscode" && "$1" != "intellij" ]]; then
    echo "Usage: mt-set-default-ide <vscode|intellij>"
    return 1
  fi
  python3 "$CONFIG_MANAGER" update "core" "default_ide" "$1"
  export DEFAULT_IDE="$1"
  echo "✅ Default IDE set to $1."
}

#######################################
# Config: Set default AI model provider
# Usage: mt-set-default-ai "gemini|claude|local"
# Arguments:
#   $1 - AI provider identifier
#######################################
mt-set-default-ai() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [[ "$1" != "gemini" && "$1" != "claude" && "$1" != "local" ]]; then
    echo "Usage: mt-set-default-ai <gemini|claude|local>"
    return 1
  fi
  python3 "$CONFIG_MANAGER" update "ai" "default_provider" "$1"
  export DEFAULT_AI="$1"
  echo "✅ Default AI set to $1."
}

#######################################
# Config: Set default CI/CD provider
# Usage: mt-set-cicd "github|bitbucket|gitlab|azure|jenkins"
# Arguments:
#   $1 - CI/CD provider identifier
#######################################
mt-set-cicd() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [[ "$1" != "github" && "$1" != "bitbucket" && "$1" != "gitlab" && "$1" != "azure" && "$1" != "jenkins" ]]; then
    echo "Usage: mt-set-cicd <github|bitbucket|gitlab|azure|jenkins>"
    return 1
  fi
  python3 "$CONFIG_MANAGER" update "cicd" "default_provider" "$1"
  export CICD_PROVIDER="$1"
  echo "✅ CI/CD provider set to $1."
}

#######################################
# Config: Toggle global AI prompt and workflow integration (true/false)
#######################################
mt-toggle-ai() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local new_val="true"
  [ "${AI_ENABLED:-true}" = "true" ] && new_val="false"
  python3 "$CONFIG_MANAGER" update "ai" "enable_ai" "$new_val"
  export AI_ENABLED="$new_val"
  echo "✅ AI integration set to $new_val."
}

#######################################
# Config: Show/hide individual prompt segments (Git, GCP, AI provider,
# K8s), pick which GCP identity field(s) the GCP segment shows,
# show/hide the AI segment's model/version parenthetical (e.g. "AI:
# Gemini (3.6-flash)" vs "AI: Gemini"), swap text labels for compact
# icons, or cap how long a Git branch name can get before truncating
# with an ellipsis. This is purely a prompt-display setting -- separate
# from mt-toggle-ai, which controls whether AI integration runs at all
# elsewhere in the framework. Called with no arguments, prints the
# current display configuration instead of changing anything.
# Usage: mt-toggle-display [-e|--element <git|gcp|ai|k8s>] [--gcp-mode <project|account|both>] [--ai-model] [--compact] [--git-branch-len <n>]
# Options:
#   -e, --element <git|gcp|ai|k8s>      Show/hide the given prompt segment
#   --gcp-mode <project|account|both>   Which GCP identity field(s) to show
#   --ai-model                          Show/hide the AI segment's model/version detail
#   --compact                           Toggle icon labels instead of text labels
#   --git-branch-len <n>                Max Git branch name length before truncation (0 = unlimited)
#   -h, --help                          Show this help menu
# Globals:
#   DISPLAY_SHOW_GIT, DISPLAY_SHOW_GCP, DISPLAY_SHOW_AI, DISPLAY_SHOW_K8S,
#   DISPLAY_SHOW_AI_MODEL, DISPLAY_COMPACT_LABELS, DISPLAY_GCP_MODE,
#   DISPLAY_GIT_BRANCH_MAX_LEN
#######################################
mt-toggle-display() {
  local element="" gcp_mode="" toggle_ai_model=false toggle_compact=false
  local branch_len=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -e | --element)
        element="$2"
        shift 2
        ;;
      --gcp-mode)
        gcp_mode="$2"
        shift 2
        ;;
      --ai-model)
        toggle_ai_model=true
        shift
        ;;
      --compact)
        toggle_compact=true
        shift
        ;;
      --git-branch-len)
        branch_len="$2"
        shift 2
        ;;
      *)
        echo "🚨 Unknown option: $1"
        return 1
        ;;
    esac
  done

  if [ -z "$element" ] && [ -z "$gcp_mode" ] && [ "$toggle_ai_model" = false ] &&
    [ "$toggle_compact" = false ] && [ -z "$branch_len" ]; then
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e "${CB_BLUE}               PROMPT DISPLAY SETTINGS                    ${C_RESET}"
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e " ${CB_CYAN}git    ${C_RESET} : ${DISPLAY_SHOW_GIT:-true} (max-len: ${DISPLAY_GIT_BRANCH_MAX_LEN:-30})"
    echo -e " ${CB_CYAN}gcp    ${C_RESET} : ${DISPLAY_SHOW_GCP:-true} (mode: ${DISPLAY_GCP_MODE:-both})"
    echo -e " ${CB_CYAN}ai     ${C_RESET} : ${DISPLAY_SHOW_AI:-true} (model: ${DISPLAY_SHOW_AI_MODEL:-true})"
    echo -e " ${CB_CYAN}k8s    ${C_RESET} : ${DISPLAY_SHOW_K8S:-true}"
    echo -e " ${CB_CYAN}compact${C_RESET} : ${DISPLAY_COMPACT_LABELS:-false}"
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    return 0
  fi

  if [ -n "$gcp_mode" ]; then
    if [[ "$gcp_mode" != "project" && "$gcp_mode" != "account" && "$gcp_mode" != "both" ]]; then
      echo "Usage: mt-toggle-display --gcp-mode <project|account|both>"
      return 1
    fi
    python3 "$CONFIG_MANAGER" update "display" "gcp_display" "$gcp_mode"
    export DISPLAY_GCP_MODE="$gcp_mode"
    echo "✅ GCP prompt display set to $gcp_mode."
  fi

  if [ -n "$branch_len" ]; then
    if ! [[ "$branch_len" =~ ^[0-9]+$ ]]; then
      echo "Usage: mt-toggle-display --git-branch-len <n> (0 = unlimited)"
      return 1
    fi
    python3 "$CONFIG_MANAGER" update "display" "git_branch_max_len" "$branch_len"
    export DISPLAY_GIT_BRANCH_MAX_LEN="$branch_len"
    echo "✅ Git branch name max length set to $branch_len."
  fi

  if [ "$toggle_ai_model" = true ]; then
    local next_ai_model="true"
    [ "${DISPLAY_SHOW_AI_MODEL:-true}" = "true" ] && next_ai_model="false"
    python3 "$CONFIG_MANAGER" update "display" "show_ai_model" "$next_ai_model"
    export DISPLAY_SHOW_AI_MODEL="$next_ai_model"
    echo "✅ AI model/version display set to $next_ai_model."
  fi

  if [ "$toggle_compact" = true ]; then
    local next_compact="true"
    [ "${DISPLAY_COMPACT_LABELS:-false}" = "true" ] && next_compact="false"
    python3 "$CONFIG_MANAGER" update "display" "compact_labels" "$next_compact"
    export DISPLAY_COMPACT_LABELS="$next_compact"
    echo "✅ Compact icon labels set to $next_compact."
  fi

  if [ -n "$element" ]; then
    local key="" current=""
    case "$element" in
      git)
        key="show_git"
        current="${DISPLAY_SHOW_GIT:-true}"
        ;;
      gcp)
        key="show_gcp"
        current="${DISPLAY_SHOW_GCP:-true}"
        ;;
      ai)
        key="show_ai"
        current="${DISPLAY_SHOW_AI:-true}"
        ;;
      k8s)
        key="show_k8s"
        current="${DISPLAY_SHOW_K8S:-true}"
        ;;
      *)
        echo "Usage: mt-toggle-display -e|--element <git|gcp|ai|k8s>"
        return 1
        ;;
    esac

    local next="true"
    [ "$current" = "true" ] && next="false"
    python3 "$CONFIG_MANAGER" update "display" "$key" "$next"

    case "$element" in
      git) export DISPLAY_SHOW_GIT="$next" ;;
      gcp) export DISPLAY_SHOW_GCP="$next" ;;
      ai) export DISPLAY_SHOW_AI="$next" ;;
      k8s) export DISPLAY_SHOW_K8S="$next" ;;
    esac

    echo "✅ Prompt element '$element' display set to $next."
  fi
}

#######################################
# Config: Open bash.d directory and config.yaml in IDE
# Usage: mt-open-config [-ide vscode|intellij]
# Options:
#   -ide <name>   Override default IDE launcher
#######################################
mt-open-config() {
  local selected_ide="${DEFAULT_IDE:-vscode}"
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -ide)
        selected_ide="$2"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  local config_dir="$HOME/.bash.d"

  if [ ! -s "$CONFIG_FILE" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    [ -f "$YAML_TEMPLATE" ] && cp "$YAML_TEMPLATE" "$CONFIG_FILE"
  fi

  echo "🚀 Opening bash config in $selected_ide..."
  if [ "$selected_ide" = "intellij" ]; then
    __launch_intellij "$config_dir" "$CONFIG_FILE" || echo "⚠️ Could not launch IntelliJ. Ensure 'idea' is on PATH (JetBrains Toolbox), or install IntelliJ IDEA via Homebrew on macOS."
  else
    code "$config_dir" "$CONFIG_FILE"
  fi
}

#######################################
# Config: Set terminal color theme
# Usage: mt-set-theme "theme_name"
# Arguments:
#   $1 - Valid theme name (e.g. default, dracula, monokai)
#######################################
mt-set-theme() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local theme="${1:-default}"

  if [ ! -f "$HOME/.bash.d/config/themes/$theme.sh" ]; then
    echo "🚨 Invalid theme. Ensure $theme.sh exists in $HOME/.bash.d/config/themes/"
    return 1
  fi
  python3 "$CONFIG_MANAGER" update "core" "theme" "$theme"
  export BASH_THEME="$theme"
  echo "✅ Terminal theme set to $theme."
}

#######################################
# Config: Launch the interactive Master Setup Wizard Menu
#######################################
mt-setup() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}        MT DEVOPS FRAMEWORK - MASTER SETUP WIZARD         ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}\n"

  local options=(
    "1. Quick Setup (First-Time Defaults)"
    "2. System Configuration"
    "3. AI Provider Configuration"
    "4. Exports & Cleanup Configuration"
    "5. Workspace & Directory Paths"
    "6. Git & Version Control"
    "7. CI/CD Default Provider"
    "8. Docker Preferences"
    "9. Minikube Preferences"
    "10. Exit"
  )

  local choice
  choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="⚙️ Select a category to configure > " --height=~15 --layout=reverse --border)

  case "$choice" in
    1*) __mt_setup_quick ;;
    2*) mt-wizard-system ;;
    3*) mt-wizard-ai ;;
    4*) mt-wizard-exports ;;
    5*) mt-wizard-paths ;;
    6*) mt-wizard-git ;;
    7*) mt-wizard-cicd ;;
    8*) mt-wizard-docker ;;
    9*) mt-wizard-minikube ;;
    *)
      echo "⚠️ Setup cancelled."
      return 0
      ;;
  esac

  mt-refresh-caches > /dev/null 2>&1
  echo -e "${CB_GREEN}✅ Configuration saved! Run 'reload' to apply changes fully.${C_RESET}"
}

#######################################
# Config: Internal Quick First-Time Setup workflow
#######################################
__mt_setup_quick() {
  echo -e "${CB_BLUE}--- Quick Setup ---${C_RESET}"
  read -r -p "1️⃣ Default IDE (vscode/intellij) [${DEFAULT_IDE:-vscode}]: " ide
  [ -n "$ide" ] && mt-set-default-ide "$ide"

  read -r -p "2️⃣ Default AI Provider (gemini/claude/local) [${DEFAULT_AI:-gemini}]: " provider
  [ -n "$provider" ] && mt-set-default-ai "$provider"

  local active_provider="${provider:-${DEFAULT_AI:-gemini}}"
  if [ "$active_provider" = "gemini" ]; then
    read -r -s -p "🔑 Enter Gemini API Key (Enter to skip): " key < /dev/tty
    echo
    if [ -n "$key" ]; then
      __mt_write_secret "GEMINI_API_KEY" "$key"
      export GEMINI_API_KEY="$key"
      python3 "$SECRETS_MANAGER" register "GEMINI_API_KEY"
      echo -e "${CB_GREEN}✅ Gemini API key saved.${C_RESET}"
    fi
  elif [ "$active_provider" = "claude" ]; then
    read -r -s -p "🔑 Enter Claude API Key (Enter to skip): " key < /dev/tty
    echo
    if [ -n "$key" ]; then
      __mt_write_secret "CLAUDE_API_KEY" "$key"
      export CLAUDE_API_KEY="$key"
      python3 "$SECRETS_MANAGER" register "CLAUDE_API_KEY"
      echo -e "${CB_GREEN}✅ Claude API key saved.${C_RESET}"
    fi
  fi

  read -r -p "3️⃣ CI/CD Provider (github/bitbucket/gitlab/azure/jenkins) [${CICD_PROVIDER:-github}]: " cicd
  [ -n "$cicd" ] && mt-set-cicd "$cicd"

  echo -e "4️⃣ Git Sync Repo:"
  echo -e "   ${C_DIM}This is where 'mt-push-update' pushes your config changes and raises PRs from.${C_RESET}"
  if [ -n "$SYNC_REPO_URL" ] && [ "$SYNC_REPO_URL" != "YOUR_SYNC_REPO_URL" ]; then
    read -r -p "   Sync Repo URL [${SYNC_REPO_URL}]: " sync_url
    [ -n "$sync_url" ] && mt-add-sync-url "$sync_url"
  else
    local is_maintainer
    read -r -p "   Do you have direct write access to ${UPSTREAM_REPO_PATH}? (y/N): " is_maintainer
    if [[ "$is_maintainer" =~ ^[Yy]$ ]]; then
      mt-add-sync-url "git@github.com:${UPSTREAM_REPO_PATH}.git"
    else
      echo -e "   ${C_DIM}No problem -- run 'mt-become-collaborator' any time to fork the repo and configure this automatically.${C_RESET}"
    fi
  fi
}

#######################################
# Config: Interactive System Setup Menu
#######################################
mt-wizard-system() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo -e "${CB_BLUE}--- System Configuration ---${C_RESET}"
  read -r -p "Default IDE (vscode/intellij) [${DEFAULT_IDE:-vscode}]: " ide
  [ -n "$ide" ] && python3 "$CONFIG_MANAGER" update "core" "default_ide" "$ide"
  read -r -p "Max Parallel Threads [${MAX_PARALLEL_THREADS:-8}]: " threads
  [ -n "$threads" ] && python3 "$CONFIG_MANAGER" update "core" "max_parallel_threads" "$threads"
  read -r -p "Update Check TTL (seconds) [${UPDATE_CHECK_TTL_SEC:-43200}]: " ttl
  [ -n "$ttl" ] && python3 "$CONFIG_MANAGER" update "core" "update_check_ttl_sec" "$ttl"
  echo -e "${CB_GREEN}✅ System config updated.${C_RESET}"
}

#######################################
# Config: Interactive System Setup Menu (deprecated alias)
# Deprecated: use mt-wizard-system instead.
#######################################
mt-setup-system() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  mt-wizard-system "$@"
}

#######################################
# Config: Interactive AI Setup Menu
#######################################
mt-wizard-ai() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo -e "${CB_BLUE}--- AI Configuration ---${C_RESET}"
  read -r -p "Enable AI Features? (true/false) [${AI_ENABLED:-true}]: " enabled
  [ -n "$enabled" ] && python3 "$CONFIG_MANAGER" update "ai" "enable_ai" "$enabled"
  read -r -p "Default Provider (gemini/claude/local) [${DEFAULT_AI:-gemini}]: " prov
  [ -n "$prov" ] && python3 "$CONFIG_MANAGER" update "ai" "default_provider" "$prov"

  echo -e "\n${CB_CYAN}Gemini Settings:${C_RESET}"
  read -r -p "Gemini Model Version [${GEMINI_VERSION:-gemini-3.6-flash}]: " g_ver
  [ -n "$g_ver" ] && python3 "$CONFIG_MANAGER" update "ai.providers.gemini" "model" "$g_ver"
  echo -e "  ${C_DIM}🔑 Run 'mt-add-gemini-key' to add/update your key${C_RESET}"

  echo -e "\n${CB_CYAN}Claude Settings:${C_RESET}"
  read -r -p "Claude Model Version [${CLAUDE_VERSION:-claude-3-7-sonnet-latest}]: " c_ver
  [ -n "$c_ver" ] && python3 "$CONFIG_MANAGER" update "ai.providers.claude" "model" "$c_ver"
  echo -e "  ${C_DIM}🔑 Run 'mt-add-claude-key' to add/update your key${C_RESET}"

  echo -e "\n${CB_CYAN}Local AI Settings:${C_RESET}"
  read -r -p "Local AI Base URL [${LOCAL_AI_BASE_URL:-http://localhost:11434/v1}]: " l_url
  [ -n "$l_url" ] && python3 "$CONFIG_MANAGER" update "ai.providers.local" "base_url" "$l_url"
  read -r -p "Local AI Model [${LOCAL_AI_MODEL:-llama3.2}]: " l_mod
  [ -n "$l_mod" ] && python3 "$CONFIG_MANAGER" update "ai.providers.local" "model" "$l_mod"

  echo -e "${CB_GREEN}✅ AI config updated.${C_RESET}"
}

#######################################
# Config: Interactive AI Setup Menu (deprecated alias)
# Deprecated: use mt-wizard-ai instead.
#######################################
mt-setup-ai() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  mt-wizard-ai "$@"
}

#######################################
# Config: Interactive Exports Setup Menu
#######################################
mt-wizard-exports() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo -e "${CB_BLUE}--- Exports Configuration ---${C_RESET}"
  read -r -p "Auto Cleanup Exports? (true/false) [${AUTO_CLEANUP_EXPORTS:-true}]: " cln
  [ -n "$cln" ] && python3 "$CONFIG_MANAGER" update "llm_exports" "enable_auto_cleanup" "$cln"
  read -r -p "Auto Cleanup Threshold (days) [${AUTO_CLEANUP_DAYS:-7}]: " days
  [ -n "$days" ] && python3 "$CONFIG_MANAGER" update "llm_exports" "auto_cleanup_days" "$days"
  read -r -p "Regex Blocklist [${EXPORT_BLOCKLIST}]: " blk
  [ -n "$blk" ] && python3 "$CONFIG_MANAGER" update "llm_exports" "file_blocklist_regex" "$blk"
  echo -e "${CB_GREEN}✅ Exports config updated.${C_RESET}"
}

#######################################
# Config: Interactive Exports Setup Menu (deprecated alias)
# Deprecated: use mt-wizard-exports instead.
#######################################
mt-setup-exports() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  mt-wizard-exports "$@"
}

#######################################
# Config: Interactive Paths Setup Menu -- prompts for and persists the
# framework's core filesystem paths (VCS roots, dotfiles repo, AI
# workspace, IAM scripts, Docker root, export/backup directories)
# Usage: mt-wizard-paths
# Globals:
#   VCS_ROOT, VCS_PERSONAL, VCS_EXPORTS, DOTFILES_DIR, AI_WORKSPACE_DIR,
#   SCRIPTS_IAM_DIR, DOCKER_ROOT_DIR, EXPORT_DIR, BACKUP_DIR, CONFIG_MANAGER
#######################################
mt-wizard-paths() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo -e "${CB_BLUE}--- Paths Configuration ---${C_RESET}"
  local vcs_root_input
  read -r -p "VCS Root [${VCS_ROOT:-~/vcs}]: " vcs_root_input
  [ -n "$vcs_root_input" ] && python3 "$CONFIG_MANAGER" update "paths" "vcs_root_dir" "$vcs_root_input"
  local vcs_personal_input
  read -r -p "VCS Personal [${VCS_PERSONAL:-~/vcs/personal}]: " vcs_personal_input
  [ -n "$vcs_personal_input" ] && python3 "$CONFIG_MANAGER" update "paths" "vcs_personal_dir" "$vcs_personal_input"
  local vcs_exports_input
  read -r -p "VCS Exports [${VCS_EXPORTS:-~/vcs/personal/exports}]: " vcs_exports_input
  [ -n "$vcs_exports_input" ] && python3 "$CONFIG_MANAGER" update "paths" "vcs_exports_dir" "$vcs_exports_input"
  local dotfiles_dir_input
  read -r -p "Dotfiles Repo [${DOTFILES_DIR:-~/vcs/personal/mt-devops-framework}]: " dotfiles_dir_input
  [ -n "$dotfiles_dir_input" ] && python3 "$CONFIG_MANAGER" update "paths" "dotfiles_dir" "$dotfiles_dir_input"
  local ai_workspace_input
  read -r -p "AI Workspace [${AI_WORKSPACE_DIR:-~/workspaces/ai}]: " ai_workspace_input
  [ -n "$ai_workspace_input" ] && python3 "$CONFIG_MANAGER" update "paths" "ai_workspace_dir" "$ai_workspace_input"
  local iam_scripts_input
  read -r -p "IAM Scripts [${SCRIPTS_IAM_DIR:-/tmp/scripts/iam}]: " iam_scripts_input
  [ -n "$iam_scripts_input" ] && python3 "$CONFIG_MANAGER" update "paths" "iam_scripts_dir" "$iam_scripts_input"
  local docker_root_input
  read -r -p "Docker Root [${DOCKER_ROOT_DIR:-~/.docker}]: " docker_root_input
  [ -n "$docker_root_input" ] && python3 "$CONFIG_MANAGER" update "paths" "docker_root_dir" "$docker_root_input"
  local export_dir_input
  read -r -p "Export Dir [${EXPORT_DIR:-/tmp/exports}]: " export_dir_input
  [ -n "$export_dir_input" ] && python3 "$CONFIG_MANAGER" update "paths" "export_dir" "$export_dir_input"
  local backup_dir_input
  read -r -p "Backup Dir [${BACKUP_DIR:-~/backups}]: " backup_dir_input
  [ -n "$backup_dir_input" ] && python3 "$CONFIG_MANAGER" update "paths" "backup_dir" "$backup_dir_input"
  echo -e "${CB_GREEN}✅ Paths config updated.${C_RESET}"
}

#######################################
# Config: Interactive Paths Setup Menu (deprecated alias)
# Deprecated: use mt-wizard-paths instead.
#######################################
mt-setup-paths() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  mt-wizard-paths "$@"
}

#######################################
# Config: Interactive Git Setup Menu
#######################################
mt-wizard-git() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo -e "${CB_BLUE}--- Git Configuration ---${C_RESET}"
  echo -e "${C_DIM}💡 Not the maintainer? Run 'mt-become-collaborator' instead -- it forks ${UPSTREAM_REPO_PATH} and sets this up for you automatically.${C_RESET}"
  read -r -p "Sync Repo URL [${SYNC_REPO_URL:-Not set}]: " sync_url
  [ -n "$sync_url" ] && python3 "$CONFIG_MANAGER" update "git" "sync_repo_url" "$sync_url"

  read -r -p "Format on Push? (true/false) [${GIT_FORMAT_ON_PUSH:-true}]: " fmt
  [ -n "$fmt" ] && python3 "$CONFIG_MANAGER" update "git" "enable_format_on_push" "$fmt"

  read -r -p "Feature Branch Prefix [${GIT_FEATURE_PREFIX:-feature/}]: " prefix
  [ -n "$prefix" ] && python3 "$CONFIG_MANAGER" update "git" "feature_branch_prefix" "$prefix"

  read -r -p "AI Max Diff Bytes [${AI_MAX_DIFF_BYTES:-4000}]: " bytes
  [ -n "$bytes" ] && python3 "$CONFIG_MANAGER" update "ai" "max_context_bytes" "$bytes"
  echo -e "${CB_GREEN}✅ Git config updated.${C_RESET}"
}

#######################################
# Config: Interactive Git Setup Menu (deprecated alias)
# Deprecated: use mt-wizard-git instead.
#######################################
mt-setup-git() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  mt-wizard-git "$@"
}

#######################################
# Config: Interactive CI/CD Setup Menu
#######################################
mt-wizard-cicd() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo -e "${CB_BLUE}--- CI/CD Configuration ---${C_RESET}"
  read -r -p "Default Provider (github/bitbucket/gitlab/azure/jenkins) [${CICD_PROVIDER:-github}]: " prov
  [ -n "$prov" ] && python3 "$CONFIG_MANAGER" update "cicd" "default_provider" "$prov"
  echo -e "${CB_GREEN}✅ CI/CD config updated.${C_RESET}"
}

#######################################
# Config: Interactive CI/CD Setup Menu (deprecated alias)
# Deprecated: use mt-wizard-cicd instead.
#######################################
mt-setup-cicd() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  mt-wizard-cicd "$@"
}

#######################################
# Config: Interactive Docker Configuration Wizard -- restart blocklist
# plus the registry defaults docker-push/docker-release/docker-deploy
# use (default registry, GAR region/repo, Docker Hub namespace), so none
# of those are hardcoded at the call site.
# Usage: mt-wizard-docker
#######################################
mt-wizard-docker() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo -e "${CB_BLUE}--- Docker Configuration ---${C_RESET}"
  read -r -p "Restart Blocklist (comma-separated) [${DOCKER_BLOCKLIST:-redis,postgres,local-db}]: " blk
  [ -n "$blk" ] && python3 "$CONFIG_MANAGER" update "docker" "restart_blocklist_csv" "$blk"
  read -r -p "Default Registry for docker-push/docker-release (gar/dockerhub) [${DOCKER_DEFAULT_REGISTRY:-gar}]: " reg
  [ -n "$reg" ] && python3 "$CONFIG_MANAGER" update "docker" "default_registry" "$reg"
  read -r -p "Google Artifact Registry Region [${DOCKER_GAR_REGION:-europe-west2}]: " gar_region
  [ -n "$gar_region" ] && python3 "$CONFIG_MANAGER" update "docker" "gar_region" "$gar_region"
  read -r -p "Google Artifact Registry Repository Name [${DOCKER_GAR_REPO:-none}]: " gar_repo
  [ -n "$gar_repo" ] && python3 "$CONFIG_MANAGER" update "docker" "gar_repo" "$gar_repo"
  read -r -p "Docker Hub Namespace (username/org) [${DOCKER_DOCKERHUB_NAMESPACE:-none}]: " dh_ns
  [ -n "$dh_ns" ] && python3 "$CONFIG_MANAGER" update "docker" "dockerhub_namespace" "$dh_ns"
  echo -e "${CB_GREEN}✅ Docker config updated.${C_RESET}"
}

#######################################
# Config: Interactive Minikube Configuration Wizard -- sets the
# driver/CPU/memory defaults 'mk-start' uses to create a local cluster,
# so those never need to be hardcoded at the call site.
#######################################
mt-wizard-minikube() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo -e "${CB_BLUE}--- Minikube Configuration ---${C_RESET}"
  read -r -p "Driver (docker/virtualbox/hyperv/kvm2/podman) [${MK_DRIVER:-docker}]: " drv
  [ -n "$drv" ] && python3 "$CONFIG_MANAGER" update "minikube" "driver" "$drv"
  read -r -p "CPUs [${MK_CPUS:-2}]: " cpus
  [ -n "$cpus" ] && python3 "$CONFIG_MANAGER" update "minikube" "cpus" "$cpus"
  read -r -p "Memory in MB [${MK_MEMORY_MB:-4000}]: " mem
  [ -n "$mem" ] && python3 "$CONFIG_MANAGER" update "minikube" "memory_mb" "$mem"
  echo -e "${CB_GREEN}✅ Minikube config updated.${C_RESET}"
}

#######################################
# Config: Interactive Docker Setup Menu (deprecated alias)
# Deprecated: use mt-wizard-docker instead.
#######################################
mt-setup-docker() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  mt-wizard-docker "$@"
}

#######################################
# Config: Forcefully re-parse config.yaml and reload environment variables
#######################################
mt-load-config() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  echo -e "${CB_BLUE}🔄 Forcefully re-parsing config.yaml...${C_RESET}"

  rm -f "$ENV_CACHE" "$HOME/.bash.d/config/.env.cache" "$HOME/.bash.d/data/cache/.env.cache" 2> /dev/null

  if [ -f "$CONFIG_MANAGER" ]; then
    mkdir -p "$(dirname "$ENV_CACHE")"
    python3 "$CONFIG_MANAGER" load-env > "$ENV_CACHE"
    chmod 600 "$ENV_CACHE" 2> /dev/null
    # shellcheck disable=SC1090
    source "$ENV_CACHE"
    if [ -f "$SECRETS_FILE" ]; then
      # shellcheck disable=SC1091
      source "$SECRETS_FILE"
    fi
    echo -e "${CB_GREEN}✅ Config reloaded! Active variables updated.${C_RESET}"
  else
    echo -e "${CB_RED}🚨 Error: config_manager.py not found.${C_RESET}"
    return 1
  fi
}

#######################################
# Config: Forcefully re-parse config.yaml and reload environment variables
#######################################
alias mt-reload-config='mt-load-config'

#######################################
# Config: Detect and clean up legacy config.yaml keys left behind by past
# schema renames. config.yaml is only ever created once, from
# config.yaml.tpl, the first time a shell starts with none present -- it
# is never otherwise migrated across framework updates. So when a later
# release renames a setting (e.g. paths.vcs_root -> paths.vcs_root_dir),
# every wizard/update call-site only knows the current canonical name and
# writes it alongside the old one instead of replacing it, and
# config.yaml quietly accumulates both the legacy and canonical key for
# every rename it has lived through. Backs up config.yaml to
# BACKUP_DIR/config-migrations/ before making any change, and is a safe
# no-op if nothing legacy is found. Also moves any cache/log/version-file
# data still sitting at the pre-XDG ~/.bash.d/data locations into their
# new XDG Base Directory homes (see migrate_runtime_dirs() in
# config_manager.py) -- likewise a safe no-op once nothing is left
# there. Also runs automatically at the end of every 'mt-get-update'
# install.
# Globals:
#   CONFIG_MANAGER
#######################################
mt-migrate-config() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [ ! -f "$CONFIG_MANAGER" ]; then
    echo -e "${CB_RED}🚨 Error: config_manager.py not found.${C_RESET}"
    return 1
  fi

  python3 "$CONFIG_MANAGER" migrate
  __mt_report_runtime_dir_migration
  mt-load-config
}

#######################################
# System: Run config_manager.py's runtime-dir migration (cache/logs/
# version-file from the old ~/.bash.d/data locations to their new XDG
# homes) and print a report only if it actually moved something -- a
# silent no-op otherwise. Shared by mt-migrate-config and both
# mt-get-update install paths (see 52-git-sync.sh) so the same one-time
# move is offered wherever a config migration already happens.
# Globals:
#   CONFIG_MANAGER
#######################################
__mt_report_runtime_dir_migration() {
  local moved
  moved=$(python3 "$CONFIG_MANAGER" migrate-runtime-dirs)
  if [ -n "$moved" ]; then
    echo -e "${CB_BLUE}📦 Moved runtime data to its new XDG location:${C_RESET}"
    echo "   - ${moved//$'\n'/$'\n   - '}"
  fi
}

#######################################
# Config: Set the sync repository URL
# Arguments:
#   $1 - Remote repository URL
#######################################
mt-add-sync-url() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [ -z "$1" ]; then
    echo "Usage: mt-add-sync-url <repo_url>"
    return 1
  fi
  python3 "$CONFIG_MANAGER" update "git" "sync_repo_url" "$1"
  export SYNC_REPO_URL="$1"
  echo "✅ Sync repository URL set to $1."
}

#######################################
# Config: Ensure the GitHub CLI is authenticated, offering to run
# 'gh auth login' interactively if it isn't yet. Used by
# mt-become-collaborator so a brand-new collaborator doesn't need to know
# to authenticate before forking.
# Returns:
#   0 if 'gh' ends up authenticated, 1 if the user declined or login failed
#######################################
__mt_collab_ensure_gh_auth() {
  gh auth status > /dev/null 2>&1 && return 0

  echo -e "${CB_YELLOW}⚠️  You're not authenticated with the GitHub CLI yet.${C_RESET}"
  read -r -p "Authenticate now via 'gh auth login'? [Y/n] " -n 1 < /dev/tty || REPLY="n"
  echo
  if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ] && [ -n "$REPLY" ]; then
    echo -e "${CB_RED}🚨 Aborted. Run 'gh auth login' manually, then re-run 'mt-become-collaborator'.${C_RESET}"
    return 1
  fi

  gh auth login

  if ! gh auth status > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 GitHub CLI still isn't authenticated. Aborting.${C_RESET}"
    return 1
  fi
  echo -e "${CB_GREEN}✅ Authenticated with GitHub CLI.${C_RESET}"
}

#######################################
# Config: Interactive one-time setup wizard for collaborators who don't
# have direct write access to the upstream repository. Verifies (and, if
# needed, bootstraps) 'gh' authentication, forks UPSTREAM_REPO_PATH under
# the user's own GitHub account, and points SYNC_REPO_URL at that fork via
# mt-add-sync-url -- so 'mt-push-update' raises PRs against the upstream
# repo straight from the fork with no manual URL typing required. Safe to
# re-run at any time (both the fork and the sync-URL update are idempotent).
# Usage: mt-become-collaborator
# Globals:
#   UPSTREAM_REPO_PATH
#######################################
mt-become-collaborator() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}       BECOME A COLLABORATOR -- FORK SETUP WIZARD         ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "This forks ${CB_CYAN}${UPSTREAM_REPO_PATH}${C_RESET} to your GitHub account and points"
  echo -e "'mt-push-update' at your fork, so your changes land as Pull Requests"
  echo -e "against the upstream repo instead of failing to push directly.\n"

  if ! command -v gh > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 GitHub CLI ('gh') is required but not installed.${C_RESET}"
    echo -e "Install it from ${CB_CYAN}https://cli.github.com${C_RESET} and re-run this command."
    return 1
  fi

  __mt_collab_ensure_gh_auth || return 1

  local username
  username=$(gh api user -q .login 2> /dev/null)
  if [ -z "$username" ]; then
    echo -e "${CB_RED}🚨 Could not determine your GitHub username via 'gh api user'.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}🍴 Forking ${UPSTREAM_REPO_PATH} to ${username}/... (safe to re-run if you're already forked)${C_RESET}"
  if ! gh repo fork "$UPSTREAM_REPO_PATH" --clone=false; then
    echo -e "${CB_RED}🚨 Fork failed. See the error above.${C_RESET}"
    return 1
  fi

  local repo_name="${UPSTREAM_REPO_PATH#*/}"
  local protocol
  protocol=$(gh config get git_protocol 2> /dev/null || echo ssh)
  local fork_url="git@github.com:${username}/${repo_name}.git"
  [ "$protocol" = "https" ] && fork_url="https://github.com/${username}/${repo_name}.git"

  mt-add-sync-url "$fork_url"

  echo -e "\n${CB_GREEN}✅ You're set up as a collaborator!${C_RESET}"
  echo -e "${C_DIM}Your fork: https://github.com/${username}/${repo_name}${C_RESET}"
  echo -e "${C_DIM}Sync URL:  ${fork_url}${C_RESET}"
  echo -e "\n📝 Make your changes in ${CB_CYAN}~/.bash.d/${C_RESET} (the live environment you're actually running) --"
  echo -e "   not in the repo checkout. ${CB_CYAN}mt-push-update${C_RESET} only ever copies ~/.bash.d/ INTO the repo, one-way,"
  echo -e "   so any edit made directly in the repo checkout gets silently overwritten instead of picked up."
  echo -e "\n💡 Run ${CB_CYAN}mt-push-update${C_RESET} any time to sync your local config changes and raise a PR against ${UPSTREAM_REPO_PATH}."
}
