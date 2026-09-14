# 🛠️ MT DevOps Framework - Technical Command Reference

> **Auto-generated Reference Document**  
> Generated: Mon Sep 14 06:13:18 AM BST 2026  
> Environment: Linux (x86_64)

---


## 🔗 Shell Aliases

- **`mt-reload-config`** *(Configuration Management)*: Config: Forcefully re-parse config.yaml and reload environment variables
- **`boot-run`** *(Development & Build Tools)*: Dev: Spring Boot - Run application
- **`mci`** *(Development & Build Tools)*: Dev: Maven - Clean and Install
- **`pip-load`** *(Development & Build Tools)*: Dev: Python - Install pip requirements
- **`pip-save`** *(Development & Build Tools)*: Dev: Python - Save pip requirements
- **`ruff-fmt`** *(Development & Build Tools)*: Dev: Python - Format Python files and imports using Ruff (recursive)
- **`sh-fmt-all`** *(Development & Build Tools)*: Dev: Shell - Format all shell scripts in current directory (recursive)
- **`shfmtlw`** *(Development & Build Tools)*: Dev: Shell - Format all shell scripts in current directory (recursive) (Alias)
- **`venv-make`** *(Development & Build Tools)*: Dev: Python - Create & active Python venv
- **`venv-up`** *(Development & Build Tools)*: Dev: Python - Activate existing Python venv
- **`gcpp`** *(GCP: Configuration & Authentication)*: GCP: Legacy shortcut to set project
- **`bq-ls`** *(GCP: Resources & Services)*: GCP: BigQuery - List datasets in project
- **`gce-ls`** *(GCP: Resources & Services)*: GCP: Compute - List all VM instances
- **`gce-ssh`** *(GCP: Resources & Services)*: GCP: Compute - SSH into an instance
- **`gcl-gar-ls`** *(GCP: Resources & Services)*: GCP: Artifact Registry - List repositories
- **`gcl-iam-ls`** *(GCP: Resources & Services)*: GCP: IAM - List service accounts in active project
- **`gcl-ps-subs`** *(GCP: Resources & Services)*: GCP: PubSub - List subscriptions
- **`gcl-ps-topics`** *(GCP: Resources & Services)*: GCP: PubSub - List topics
- **`gcp-crf-ls`** *(GCP: Resources & Services)*: GCP: Cloud Run Functions - List functions
- **`gcs-ls`** *(GCP: Resources & Services)*: GCP: Cloud Storage - List buckets or contents
- **`cat`** *(Modern CLI Replacements)*: CLI: bat - Print file contents with syntax highlighting
- **`ccat`** *(Modern CLI Replacements)*: CLI: bat - Print file contents with line numbers & Git gutters
- **`json-fmt`** *(Modern CLI Replacements)*: CLI: jq - Pretty-print JSON stream
- **`ll`** *(Modern CLI Replacements)*: CLI: eza - Detailed list with Git status
- **`ls`** *(Modern CLI Replacements)*: CLI: eza - List files with directories first
- **`rg`** *(Modern CLI Replacements)*: CLI: rg - Search with smart case, include hidden, ignore .git
- **`tree`** *(Modern CLI Replacements)*: CLI: eza - Display directory structure as a tree
- **`tree-clean`** *(Modern CLI Replacements)*: CLI: eza - Display directory structure ignoring bloat (.git, node_modules, etc)
- **`yaml-fmt`** *(Modern CLI Replacements)*: CLI: yq - Pretty-print YAML stream
- **`mt-search`** *(MyTools Documentation & Runner)*: MyTools: Search through available mytools commands (Alias)
- **`cd-mt-git-local`** *(Path & URL Launchers (Config-Driven))*: System: Change directory to dotfiles repository root (Alias)
- **`mt-history`** *(Private Aliases (local-only -- never synced to the framework repo))*: System: Display history of executed framework commands (Alias)
- **`cd-bashd`** *(System & Navigation Aliases)*: System: Change directory to ~/.bash.d
- **`cd-git-home`** *(System & Navigation Aliases)*: System: Change directory to ~/vcs
- **`cd-git-personal`** *(System & Navigation Aliases)*: System: Change directory to ~/vcs/personal
- **`refresh`** *(System & Navigation Aliases)*: System: Reload Bash profile and caches
- **`reload`** *(System & Navigation Aliases)*: System: Reload Bash profile and caches
- **`sys-update-install`** *(System & Navigation Aliases)*: System: Update, Upgrade, Boostrap, and Reload
- **`tf`** *(Terraform Aliases)*: Terraform: Core Execution
- **`tfa`** *(Terraform Aliases)*: Terraform: Apply changes
- **`tfap`** *(Terraform Aliases)*: Terraform: Apply the saved plan file
- **`tfay`** *(Terraform Aliases)*: Terraform: Apply changes (Auto-Approve)
- **`tfc`** *(Terraform Aliases)*: Terraform: Open interactive console
- **`tfd`** *(Terraform Aliases)*: Terraform: Destroy infrastructure
- **`tfdy`** *(Terraform Aliases)*: Terraform: Destroy infrastructure (Auto-Approve)
- **`tff`** *(Terraform Aliases)*: Terraform: Format all files recursively
- **`tfin`** *(Terraform Aliases)*: Terraform: Initialize working directory
- **`tfinu`** *(Terraform Aliases)*: Terraform: Initialize and upgrade modules/providers
- **`tfo`** *(Terraform Aliases)*: Terraform: Read outputs from state
- **`tfp`** *(Terraform Aliases)*: Terraform: Generate execution plan
- **`tfpd`** *(Terraform Aliases)*: Terraform: Generate destruction plan
- **`tfpo`** *(Terraform Aliases)*: Terraform: Generate a saved plan file (tfplan)
- **`tf-refresh`** *(Terraform Aliases)*: Terraform: Refresh state without applying changes (Modern)
- **`tfs`** *(Terraform Aliases)*: Terraform: State management commands
- **`tfsh`** *(Terraform Aliases)*: Terraform: Show current state or plan
- **`tfsls`** *(Terraform Aliases)*: Terraform: List resources in state
- **`tfsmv`** *(Terraform Aliases)*: Terraform: Move an item in state
- **`tfsrm`** *(Terraform Aliases)*: Terraform: Remove an item from state
- **`tfssw`** *(Terraform Aliases)*: Terraform: Show a single resource in state
- **`tfv`** *(Terraform Aliases)*: Terraform: Validate configuration files
- **`tfw`** *(Terraform Aliases)*: Terraform: Workspace management commands
- **`tfwde`** *(Terraform Aliases)*: Terraform: Delete a workspace
- **`tfwls`** *(Terraform Aliases)*: Terraform: List workspaces
- **`tfwnw`** *(Terraform Aliases)*: Terraform: Create a new workspace
- **`tfwst`** *(Terraform Aliases)*: Terraform: Select an existing workspace
- **`tfwsw`** *(Terraform Aliases)*: Terraform: Show the current workspace name
- **`tfy`** *(Terraform Aliases)*: Terraform: Shortcut alias for tf-yaml
- **`tf-scan`** *(Terraform & Kubernetes Wrappers)*: Terraform: Scan local terraform directory (./terraform) with Checkov
- **`git-clean-local`** *(Version Control (Git) - Core Helpers)*: Git: Delete local and remote branches merged into default branch
- **`mt-hard-reload`** *(Zoxide (Smart cd replacement))*: System: Forcefully clear and rebuild all background caches and reload profile
- **`mtindp`** *(Zoxide (Smart cd replacement))*: MT-Framework: Update the DevOps-MT-Framework with Shellcheck and Backup Creation
- **`mtupd`** *(Zoxide (Smart cd replacement))*: Version Control (Git) - Profile Synchronisation: Auto-sync framework with Shellcheck, Backup, AI Commit-Grouping/README Summary, and Auto-Merge
- **`mtupd-fast`** *(Zoxide (Smart cd replacement))*: Version Control (Git) - Fast Update: Update Framework with Shellcheck, Backup and Auto-Merge, skipping AI commit-grouping/README summarization

---

## 🛠️ Public Functions


### 📂 AI Workflows & LLM API Integration


#### `ai`

> AI: Query configured LLM with prompt and optional context

```bash
#######################################
# AI: Query configured LLM with prompt and optional context
# Globals:
#   DEFAULT_AI
# Usage: ai [OPTIONS] <prompt>
# Options:
#   -m <model>     Override provider model (gemini, claude, claude-code, local)
#   -t <title>     Set context title
#   -e             Attach entire active directory as context
#   -f <file>      Attach a single file as context
#   -o <out_file>  Save output directly to specified file
#   -v <version>   Override model version
#   -x             Force extended reasoning mode
#   -h, --help     Show this help menu
#######################################
ai() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }

  local title="" export_context=false target_file="" explicit_out_file="" req_version="" req_extended=false
  local provider="${DEFAULT_AI:-gemini}" prompt=""

  OPTIND=1
  while getopts "m:t:ef:o:v:x" opt; do
    case ${opt} in
      m) provider="$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')" ;;
      t) title=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]' | tr ' ' '-') ;;
      e) export_context=true ;;
      f) target_file="$OPTARG" ;;
      o) explicit_out_file="$OPTARG" ;;
      v) req_version="$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')" ;;
      x) req_extended=true ;;
      \?)
        echo "Usage: ai [-m gemini|claude|claude-code|local] [-t title] [-e] [-f file] [-o out_file] [-v version] [-x] <prompt>" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
  prompt="$*"

  [ -z "${prompt}" ] && {
    echo "Usage: ai [-m gemini|claude|claude-code|local] [-t title] [-e] [-f file] [-o out_file] [-v version] [-x] <your question>" >&2
    return 1
  }

  local context_file
  if ! context_file=$(__ai_build_context "$target_file" "$export_context"); then
    return 1
  fi

  local content=""
  if ! content=$(__ai_query_provider "$provider" "$prompt" "$title" "$context_file" "$req_version" "$req_extended"); then
    return 1
  fi

  [ -f "$context_file" ] && rm -f "$context_file"

  __ai_parse_response "$content" "$provider" "$title" "$explicit_out_file"
}
```

#### `ai-explain`

> AI: Explain a terminal command in detail, grounding the explanation in its

```bash
#######################################
# AI: Explain a terminal command in detail, grounding the explanation in its
# actual local implementation when one is found under ~/.bash.d -- or, with
# -f, explain arbitrary source code (a whole file, or a snippet/selection
# already written to a temp file by the caller) instead of a command
# Usage: ai-explain "<command>"
#        ai-explain -f|--file <file>
# Arguments:
#   $1 - Command string to explain (default mode)
# Options:
#   -f, --file <file>   Explain this file's code instead of looking up a
#                        command implementation
#######################################
ai-explain() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [[ "$1" == "-f" || "$1" == "--file" ]]; then
    local code_file="$2"
    if [ -z "$code_file" ] || [ ! -f "$code_file" ]; then
      echo "Usage: ai-explain -f <file>" >&2
      return 1
    fi

    ai \
      -t "code-explanation" \
      -f "$code_file" \
      "Explain what this code does.

Cover:
- purpose and overall logic flow
- key functions/classes and what they do
- edge cases handled (or not handled)
- any bugs or risks you notice"
    return
  fi

  if [ -z "$1" ]; then
    echo "Usage: ai-explain \"<command>\""
    return 1
  fi

  local cmd="$1"
  local source_file

  mt-log INFO "Looking up implementation: $cmd..."

  source_file=$(__ai_find_command_source "$cmd")

  if [ -n "$source_file" ]; then
    mt-log INFO "Found implementation: $source_file"

    ai \
      -t "command-explanation" \
      -f "$source_file" \
      "Explain the command '$cmd' from the supplied implementation.

Cover:
- purpose of the command
- arguments and flags
- variables used
- helper functions called
- side effects
- examples of usage"
  else
    mt-log INFO "No local implementation found, explaining command syntax only..."

    ai \
      -t "command-explanation" \
      "Explain this terminal command in detail, breaking down what each flag and argument does: $cmd"
  fi
}
```

#### `mt-ai-debug`

> AI: Debug and explain the last failed terminal command

```bash
#######################################
# AI: Debug and explain the last failed terminal command
#######################################
mt-ai-debug() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local last_cmd
  last_cmd=$(fc -ln -2 | head -n 1 | xargs)

  mt-log INFO "Re-running and debugging: $last_cmd..."
  local err_out
  err_out=$(eval "$last_cmd" 2>&1 > /dev/null)

  if [ -z "$err_out" ]; then
    mt-log SUCCESS "Command executed successfully. No errors to debug!"
  else
    ai -t "debug-error" "The command \`$last_cmd\` failed with this stderr output:\n\n$err_out\n\nPlease explain why it failed and provide the exact command to fix it."
  fi
}
```

#### `mt-ai-models`

> AI: Print the live model catalog for one or both cloud providers,

```bash
#######################################
# AI: Print the live model catalog for one or both cloud providers,
# refreshing the cache first when it's missing, stale (past
# AI_MODEL_CHECK_TTL_SEC), or -r/--refresh was passed. Backs both direct
# use and the interactive picker in mt-set-claude-model/mt-set-gemini-model,
# so a provider is only ever queried once per refresh window.
# Usage: mt-ai-models [-p|--provider gemini|claude|all] [-r|--refresh] [-j|--json]
# Options:
#   -p, --provider <gemini|claude|all>   Which provider's catalog to show (default: all)
#   -r, --refresh                        Force a live refresh instead of using the cache
#   -j, --json                           Print raw JSON instead of a formatted table
#   -h, --help                           Show this help menu
# Returns:
#   0 if at least one provider's catalog was shown, 1 if every requested
#   provider failed to refresh and had no prior cache to fall back on
# Globals:
#   CACHE_DIR, AI_MODEL_CHECK_TTL_SEC
#######################################
mt-ai-models() {
  local provider="all" refresh=false as_json=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -p | --provider)
        provider="$2"
        shift 2
        ;;
      -r | --refresh)
        refresh=true
        shift
        ;;
      -j | --json)
        as_json=true
        shift
        ;;
      *)
        echo "Usage: mt-ai-models [-p gemini|claude|all] [-r|--refresh] [-j|--json]" >&2
        return 1
        ;;
    esac
  done

  local -a providers=()
  case "$provider" in
    all) providers=(claude gemini) ;;
    claude | gemini) providers=("$provider") ;;
    *)
      echo "🚨 Error: Invalid provider '$provider'. Use claude, gemini, or all." >&2
      return 1
      ;;
  esac

  mkdir -p "$CACHE_DIR"
  local ttl="${AI_MODEL_CHECK_TTL_SEC:-86400}"
  local now
  now=$(date +%s)

  local p had_output=false
  for p in "${providers[@]}"; do
    local data_file="$CACHE_DIR/.ai_models_${p}.json"
    local ts_file="$CACHE_DIR/.ai_models_${p}_cache"
    local last_check=0
    [ -f "$ts_file" ] && last_check=$(command cat "$ts_file")

    if [ "$refresh" = true ] || [ ! -f "$data_file" ] || ((now - last_check >= ttl)); then
      if [ "$p" = "claude" ]; then
        __ai_fetch_models_claude "$data_file" "$ts_file" || echo "🚨 Error: Could not refresh Claude's model catalog (check CLAUDE_API_KEY)." >&2
      else
        __ai_fetch_models_gemini "$data_file" "$ts_file" || echo "🚨 Error: Could not refresh Gemini's model catalog (check GEMINI_API_KEY)." >&2
      fi
    fi

    [ -f "$data_file" ] || continue
    had_output=true

    if [ "$as_json" = true ]; then
      jq --arg provider "$p" '{provider: $provider, models: .}' "$data_file"
    else
      echo -e "${CB_BLUE}🤖 ${p^} models:${C_RESET}"
      jq -r '.[] | .id + "\t" + .display_name' "$data_file" | column -t -s $'\t'
      echo
    fi
  done

  [ "$had_output" = true ]
}
```

#### `mt-ai-quota`

> AI: Check API quota and rate limits for the active AI provider

```bash
#######################################
# AI: Check API quota and rate limits for the active AI provider
# Usage: mt-ai-quota
# Globals:
#   DEFAULT_AI
#######################################
mt-ai-quota() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local provider="${DEFAULT_AI:-gemini}"

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_CYAN} 📊 AI Provider Quota Check (${provider^})${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"

  case "$provider" in
    claude) __mt_ai_quota_check_claude ;;
    gemini) __mt_ai_quota_check_gemini ;;
    claude-code)
      echo -e "  ${CB_GREEN}✅ Claude Code (headless) selected -- no Console API key involved.${C_RESET}"
      echo -e "  ${C_DIM}Usage is tracked against whatever account 'claude' is logged into. Run 'claude' and check '/status', or your Anthropic Console usage page, for limits.${C_RESET}"
      ;;
    local)
      echo -e "  ${CB_GREEN}✅ Local LLM selected.${C_RESET}"
      echo -e "  ${C_DIM}No cloud quotas apply to localhost environments! Run indefinitely.${C_RESET}"
      ;;
  esac

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
}
```

#### `mt-set-claude-model`

> AI: Set which Claude model 'ai'/'ai-explain'/'tf-ai-iam' use when

```bash
#######################################
# AI: Set which Claude model 'ai'/'ai-explain'/'tf-ai-iam' use when
# Claude is the active provider.
# Usage: mt-set-claude-model [<model-id>]
# Arguments:
#   $1 - (Optional) Exact model ID (e.g. claude-sonnet-5). Omit to
#        refresh Anthropic's live catalog and fzf-pick from it.
# Options:
#   -h, --help   Show this help menu
# Globals:
#   CACHE_DIR, CONFIG_MANAGER, CLAUDE_API_KEY
#######################################
mt-set-claude-model() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __ai_set_model claude "$1"
}
```

#### `mt-set-gemini-model`

> AI: Set which Gemini model 'ai'/'ai-explain'/'tf-ai-iam' use when

```bash
#######################################
# AI: Set which Gemini model 'ai'/'ai-explain'/'tf-ai-iam' use when
# Gemini is the active provider.
# Usage: mt-set-gemini-model [<model-id>]
# Arguments:
#   $1 - (Optional) Exact model ID (e.g. gemini-3.6-flash). Omit to
#        refresh Google's live catalog and fzf-pick from it.
# Options:
#   -h, --help   Show this help menu
# Globals:
#   CACHE_DIR, CONFIG_MANAGER, GEMINI_API_KEY
#######################################
mt-set-gemini-model() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __ai_set_model gemini "$1"
}
```

### 📂 Base64 Encoding & Decoding Utilities


#### `base64-cli`

> System: Encode or decode a string, file, or stream to/from Base64

```bash
#######################################
# System: Encode or decode a string, file, or stream to/from Base64
# Usage: base64-cli [-d] [-f file] [-o file] [string]
# Arguments:
#   -d          Decode instead of encode
#   -f <file>   Path to local input file
#   -o <file>   Path to write output file (defaults to stdout)
#   [string]    Literal string to encode/decode if no file or stdin is provided
#######################################
base64-cli() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local input_file="" output_file="" input_str="" decode=false

  local OPTIND opt
  while getopts "df:o:" opt; do
    case ${opt} in
      d) decode=true ;;
      f) input_file="$OPTARG" ;;
      o) output_file="$OPTARG" ;;
      \?)
        echo "Usage: base64-cli [-d] [-f file] [-o file] [string]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
  input_str="$*"

  local b64_flag=() verb="Encoded"
  if [ "$decode" = true ]; then
    b64_flag=(-d)
    verb="Decoded"
  fi

  local result=""

  if [ -n "$input_file" ]; then
    if [ ! -f "$input_file" ]; then
      echo -e "${C_RED}🚨 Error: Input file '$input_file' not found.${C_RESET}" >&2
      return 1
    fi
    result=$(base64 "${b64_flag[@]}" < "$input_file")
  elif [ -n "$input_str" ]; then
    result=$(echo -n "$input_str" | base64 "${b64_flag[@]}")
  else
    if [ ! -t 0 ]; then
      result=$(base64 "${b64_flag[@]}")
    else
      echo "Usage: base64-cli [-d] [-f file] [-o file] [string]" >&2
      return 1
    fi
  fi

  if [ -n "$output_file" ]; then
    echo -n "$result" > "$output_file"
    echo -e "${C_GREEN}✅ ${verb} output written to $output_file${C_RESET}"
  else
    echo "$result"
  fi
}
```

#### `base64-dec`

> System: Decode a Base64 string, file, or stream (shortcut for `base64-cli -d`)

```bash
#######################################
# System: Decode a Base64 string, file, or stream (shortcut for `base64-cli -d`)
# Arguments:
#   -f <file>   Path to local input file containing Base64 text
#   -o <file>   Path to write output file (defaults to stdout)
#   [string]    Literal Base64 string to decode if no file or stdin is provided
#######################################
base64-dec() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  base64-cli -d "$@"
}
```

#### `base64-enc`

> System: Encode a string, file, or stream to Base64 (shortcut for `base64-cli`)

```bash
#######################################
# System: Encode a string, file, or stream to Base64 (shortcut for `base64-cli`)
# Arguments:
#   -f <file>   Path to local input file
#   -o <file>   Path to write output file (defaults to stdout)
#   [string]    Literal string to encode if no file or stdin is provided
#######################################
base64-enc() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  base64-cli "$@"
}
```

### 📂 Configuration Management


#### `mt-add-sync-url`

> Config: Set the sync repository URL

```bash
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
```

#### `mt-become-collaborator`

> Config: Interactive one-time setup wizard for collaborators who don't

```bash
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

  __mt_ensure_gh_auth || return 1

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
```

#### `mt-get-gemini-status`

> AI: Print current Gemini API model version and extended reasoning mode toggle

```bash
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
```

#### `mt-load-config`

> Config: Forcefully re-parse config.yaml and reload environment variables

```bash
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
```

#### `mt-migrate-config`

> Config: Detect and clean up legacy config.yaml keys left behind by past

```bash
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
```

#### `mt-open-config`

> Config: Open bash.d directory and config.yaml in IDE

```bash
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
```

#### `mt-set-cicd`

> Config: Set default CI/CD provider

```bash
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
```

#### `mt-set-default-ai`

> Config: Set default AI model provider

```bash
#######################################
# Config: Set default AI model provider
# Usage: mt-set-default-ai "gemini|claude|claude-code|local"
# Arguments:
#   $1 - AI provider identifier ("claude-code" shells out to a headless
#        'claude -p' using Claude Code's own login, no CLAUDE_API_KEY needed)
#######################################
mt-set-default-ai() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [[ "$1" != "gemini" && "$1" != "claude" && "$1" != "claude-code" && "$1" != "local" ]]; then
    echo "Usage: mt-set-default-ai <gemini|claude|claude-code|local>"
    return 1
  fi
  python3 "$CONFIG_MANAGER" update "ai" "default_provider" "$1"
  export DEFAULT_AI="$1"
  echo "✅ Default AI set to $1."
}
```

#### `mt-set-default-ide`

> Config: Set default terminal IDE launcher

```bash
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
```

#### `mt-set-radar-index-warning-threshold`

> Config: Set how many repos mt-radar --index can be about to actually

```bash
#######################################
# Config: Set how many repos mt-radar --index can be about to actually
# index (post cache/gap filtering) before its bulk-indexing quota
# warning kicks in
# Usage: mt-set-radar-index-warning-threshold <n>
# Arguments:
#   $1 - Positive integer repo count
#######################################
mt-set-radar-index-warning-threshold() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ]; then
    echo "Usage: mt-set-radar-index-warning-threshold <positive integer>"
    return 1
  fi
  python3 "$CONFIG_MANAGER" update "ai" "bulk_index_warning_threshold" "$1"
  export RADAR_INDEX_WARN_THRESHOLD="$1"
  echo "✅ mt-radar bulk-indexing quota warning threshold set to $1 repos."
}
```

#### `mt-set-theme`

> Config: Set terminal color theme

```bash
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
```

#### `mt-setup`

> Config: Launch the interactive Master Setup Wizard Menu

```bash
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
```

#### `mt-setup-ai`

> Config: Interactive AI Setup Menu (deprecated alias)

```bash
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
```

#### `mt-setup-cicd`

> Config: Interactive CI/CD Setup Menu (deprecated alias)

```bash
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
```

#### `mt-setup-docker`

> Config: Interactive Docker Setup Menu (deprecated alias)

```bash
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
```

#### `mt-setup-exports`

> Config: Interactive Exports Setup Menu (deprecated alias)

```bash
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
```

#### `mt-setup-git`

> Config: Interactive Git Setup Menu (deprecated alias)

```bash
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
```

#### `mt-setup-paths`

> Config: Interactive Paths Setup Menu (deprecated alias)

```bash
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
```

#### `mt-setup-system`

> Config: Interactive System Setup Menu (deprecated alias)

```bash
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
```

#### `mt-toggle-ai`

> Config: Toggle global AI prompt and workflow integration (true/false)

```bash
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
```

#### `mt-toggle-display`

> Config: Show/hide individual prompt segments (Git, GCP, AI provider,

```bash
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
# Usage: mt-toggle-display [-e|--element <git|gcp|ai|k8s>] [--gcp-mode <project|account|both>] [--ai-model] [--compact] [--git-branch-len <n>] [--prod-bg-warning]
# Options:
#   -e, --element <git|gcp|ai|k8s>      Show/hide the given prompt segment
#   --gcp-mode <project|account|both>   Which GCP identity field(s) to show
#   --ai-model                          Show/hide the AI segment's model/version detail
#   --compact                           Toggle icon labels instead of text labels
#   --git-branch-len <n>                Max Git branch name length before truncation (0 = unlimited)
#   --prod-bg-warning                   Toggle a subtle red terminal-background warning
#                                        when the active GCP project looks like production
#   -h, --help                          Show this help menu
# Globals:
#   DISPLAY_SHOW_GIT, DISPLAY_SHOW_GCP, DISPLAY_SHOW_AI, DISPLAY_SHOW_K8S,
#   DISPLAY_SHOW_AI_MODEL, DISPLAY_COMPACT_LABELS, DISPLAY_GCP_MODE,
#   DISPLAY_GIT_BRANCH_MAX_LEN, DISPLAY_PROD_BG_WARNING
#######################################
mt-toggle-display() {
  local element="" gcp_mode="" toggle_ai_model=false toggle_compact=false
  local branch_len="" toggle_prod_bg=false

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
      --prod-bg-warning)
        toggle_prod_bg=true
        shift
        ;;
      *)
        echo "🚨 Unknown option: $1"
        return 1
        ;;
    esac
  done

  if [ -z "$element" ] && [ -z "$gcp_mode" ] && [ "$toggle_ai_model" = false ] &&
    [ "$toggle_compact" = false ] && [ -z "$branch_len" ] && [ "$toggle_prod_bg" = false ]; then
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e "${CB_BLUE}               PROMPT DISPLAY SETTINGS                    ${C_RESET}"
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e " ${CB_CYAN}git    ${C_RESET} : ${DISPLAY_SHOW_GIT:-true} (max-len: ${DISPLAY_GIT_BRANCH_MAX_LEN:-30})"
    echo -e " ${CB_CYAN}gcp    ${C_RESET} : ${DISPLAY_SHOW_GCP:-true} (mode: ${DISPLAY_GCP_MODE:-both})"
    echo -e " ${CB_CYAN}ai     ${C_RESET} : ${DISPLAY_SHOW_AI:-true} (model: ${DISPLAY_SHOW_AI_MODEL:-true})"
    echo -e " ${CB_CYAN}k8s    ${C_RESET} : ${DISPLAY_SHOW_K8S:-true}"
    echo -e " ${CB_CYAN}compact${C_RESET} : ${DISPLAY_COMPACT_LABELS:-false}"
    echo -e " ${CB_CYAN}prod-bg${C_RESET} : ${DISPLAY_PROD_BG_WARNING:-false}"
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

  if [ "$toggle_prod_bg" = true ]; then
    local next_prod_bg="true"
    [ "${DISPLAY_PROD_BG_WARNING:-false}" = "true" ] && next_prod_bg="false"
    python3 "$CONFIG_MANAGER" update "display" "prod_bg_warning" "$next_prod_bg"
    export DISPLAY_PROD_BG_WARNING="$next_prod_bg"
    echo "✅ Production GCP background warning set to $next_prod_bg."
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
```

#### `mt-toggle-format-on-push`

> Config: Toggle global format-on-push behavior (true/false)

```bash
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
```

#### `mt-toggle-radar-index-warning`

> Config: Toggle mt-radar --index's bulk-indexing quota warning (true/false)

```bash
#######################################
# Config: Toggle mt-radar --index's bulk-indexing quota warning (true/false)
# -- see RADAR_INDEX_WARN_ENABLED/RADAR_INDEX_WARN_THRESHOLD
#######################################
mt-toggle-radar-index-warning() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local new_val="true"
  [ "${RADAR_INDEX_WARN_ENABLED:-true}" = "true" ] && new_val="false"
  python3 "$CONFIG_MANAGER" update "ai" "enable_bulk_index_warning" "$new_val"
  export RADAR_INDEX_WARN_ENABLED="$new_val"
  echo "✅ mt-radar bulk-indexing quota warning set to $new_val."
}
```

#### `mt-toggle-update-confirm`

> Config: Toggle whether mt-get-update pauses to confirm before overwriting

```bash
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
```

#### `mt-wizard-ai`

> Config: Interactive AI Setup Menu

```bash
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
  read -r -p "Default Provider (gemini/claude/claude-code/local) [${DEFAULT_AI:-gemini}]: " prov
  [ -n "$prov" ] && python3 "$CONFIG_MANAGER" update "ai" "default_provider" "$prov"

  echo -e "\n${CB_CYAN}Gemini Settings:${C_RESET}"
  read -r -p "Gemini Model Version [${GEMINI_VERSION:-gemini-3.6-flash}]: " g_ver
  [ -n "$g_ver" ] && python3 "$CONFIG_MANAGER" update "ai.providers.gemini" "model" "$g_ver"
  echo -e "  ${C_DIM}🔑 Run 'mt-add-gemini-key' to add/update your key${C_RESET}"
  echo -e "  ${C_DIM}💡 Or run 'mt-set-gemini-model' to fzf-pick from Google's live model catalog instead of typing an ID here${C_RESET}"

  echo -e "\n${CB_CYAN}Claude Settings:${C_RESET}"
  read -r -p "Claude Model Version [${CLAUDE_VERSION:-claude-sonnet-5}]: " c_ver
  [ -n "$c_ver" ] && python3 "$CONFIG_MANAGER" update "ai.providers.claude" "model" "$c_ver"
  echo -e "  ${C_DIM}🔑 Run 'mt-add-claude-key' to add/update your key${C_RESET}"
  echo -e "  ${C_DIM}💡 Or run 'mt-set-claude-model' to fzf-pick from Anthropic's live model catalog instead of typing an ID here${C_RESET}"

  echo -e "\n${CB_CYAN}Claude Code Settings:${C_RESET}"
  echo -e "  ${C_DIM}No API key needed -- shells out to a headless 'claude -p' using whichever account Claude Code itself is logged into.${C_RESET}"
  read -r -p "Claude Code Model Alias/ID (blank = Claude Code's own default) [${CLAUDE_CODE_VERSION:-}]: " cc_ver
  [ -n "$cc_ver" ] && python3 "$CONFIG_MANAGER" update "ai.providers.claude_code" "model" "$cc_ver"

  echo -e "\n${CB_CYAN}Local AI Settings:${C_RESET}"
  read -r -p "Local AI Base URL [${LOCAL_AI_BASE_URL:-http://localhost:11434/v1}]: " l_url
  [ -n "$l_url" ] && python3 "$CONFIG_MANAGER" update "ai.providers.local" "base_url" "$l_url"
  read -r -p "Local AI Model [${LOCAL_AI_MODEL:-llama3.2}]: " l_mod
  [ -n "$l_mod" ] && python3 "$CONFIG_MANAGER" update "ai.providers.local" "model" "$l_mod"

  echo -e "${CB_GREEN}✅ AI config updated.${C_RESET}"
}
```

#### `mt-wizard-cicd`

> Config: Interactive CI/CD Setup Menu

```bash
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
```

#### `mt-wizard-docker`

> Config: Interactive Docker Configuration Wizard -- restart blocklist

```bash
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
```

#### `mt-wizard-exports`

> Config: Interactive Exports Setup Menu

```bash
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
```

#### `mt-wizard-git`

> Config: Interactive Git Setup Menu

```bash
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

  echo -e "${C_DIM}💡 Used by mt-git-clone to route Bitbucket clones into ~/vcs/work/bitbucket/<server>/<workspace>/ -- a Bitbucket clone URL doesn't encode the workspace/project grouping, so it can't be derived automatically.${C_RESET}"
  read -r -p "Bitbucket Server [${BITBUCKET_SERVER:-Not set}]: " bb_server
  [ -n "$bb_server" ] && python3 "$CONFIG_MANAGER" update "git" "bitbucket_server" "$bb_server"

  read -r -p "Bitbucket Workspace [${BITBUCKET_WORKSPACE:-Not set}]: " bb_workspace
  [ -n "$bb_workspace" ] && python3 "$CONFIG_MANAGER" update "git" "bitbucket_workspace" "$bb_workspace"

  read -r -p "AI Max Diff Bytes [${AI_MAX_DIFF_BYTES:-4000}]: " bytes
  [ -n "$bytes" ] && python3 "$CONFIG_MANAGER" update "ai" "max_context_bytes" "$bytes"
  echo -e "${CB_GREEN}✅ Git config updated.${C_RESET}"
}
```

#### `mt-wizard-minikube`

> Config: Interactive Minikube Configuration Wizard -- sets the

```bash
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
```

#### `mt-wizard-paths`

> Config: Interactive Paths Setup Menu -- prompts for and persists the

```bash
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
```

#### `mt-wizard-system`

> Config: Interactive System Setup Menu

```bash
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
```

### 📂 Container Orchestration


#### `kubectl`

> Kubernetes: Core kubectl wrapper (preserves args)

```bash
#######################################
# Kubernetes: Core kubectl wrapper (preserves args)
# Note: Does NOT intercept --help to preserve native kubectl help.
# Run `mt-help kubectl` for framework documentation.
#######################################
kubectl() {
  echo "+ kubectl $*" >&2
  command kubectl "$@"
}
```

### 📂 Container Orchestration (Kubernetes) Tools


#### `k8s-ctx`

> Kubernetes: Switch the active kubectl context

```bash
#######################################
# Kubernetes: Switch the active kubectl context
# Usage: k8s-ctx [context-name]
# Arguments:
#   $1 - (Optional) Context name to switch to. If blank, opens an
#        interactive fzf menu of contexts already in kubeconfig.
#######################################
k8s-ctx() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if ! command -v kubectl > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 kubectl is not installed.${C_RESET}"
    return 1
  fi

  local ctx="$1"
  if [ -z "$ctx" ]; then
    ctx=$(kubectl config get-contexts -o name 2> /dev/null | fzf --prompt="⎈  Select Context > " --height=~15 --layout=reverse --border)
    if [ -z "$ctx" ]; then
      echo -e "${CB_YELLOW}⚠️  Context selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  kubectl config use-context "$ctx" > /dev/null && echo -e "${CB_GREEN}✅ Active context set to: ${ctx}${C_RESET}"
}
```

#### `k8s-delete`

> Kubernetes: Delete a resource, always confirmed via the destructive-op

```bash
#######################################
# Kubernetes: Delete a resource, always confirmed via the destructive-op
# guard first -- this is the one genuinely irreversible action in this
# file, so unlike k8s-restart/k8s-scale it's never allowed to skip it.
# Usage: k8s-delete <resource-type> [name]
# Arguments:
#   $1 - Resource type (pod, deployment, service, ...)
#   $2 - (Optional) Resource name. If blank, opens an fzf menu of that
#        resource type.
#######################################
k8s-delete() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1

  local kind="$1" name="$2"
  if [ -z "$kind" ]; then
    echo "Usage: k8s-delete <resource-type> [name]" >&2
    return 1
  fi

  if [ -z "$name" ]; then
    name=$(kubectl get "$kind" --no-headers -o custom-columns=":metadata.name" 2> /dev/null | fzf --prompt="⎈  Select ${kind} to Delete > " --height=~10 --layout=reverse --border)
    if [ -z "$name" ]; then
      echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  __k8s_confirm_destructive "About to delete ${kind}/${name}." || {
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 1
  }

  kubectl delete "$kind" "$name" && echo -e "${CB_GREEN}✅ Deleted ${kind}/${name}.${C_RESET}"
}
```

#### `k8s-gke-connect`

> Kubernetes: Fetch credentials for a live GKE cluster and switch to it

```bash
#######################################
# Kubernetes: Fetch credentials for a live GKE cluster and switch to it
# in one step -- unlike k8s-ctx (which only shows contexts already in
# kubeconfig), this lists actual clusters in the active gcloud project
# via the GKE API, so it also works for a cluster never connected to
# before. Tries the cluster as zonal first, falling back to regional,
# since 'gcloud container clusters get-credentials' needs to know which.
# Usage: k8s-gke-connect
#######################################
k8s-gke-connect() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if ! command -v gcloud > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 gcloud is not installed.${C_RESET}"
    return 1
  fi

  local project
  project=$(gcl-get-project)
  if [ -z "$project" ]; then
    echo -e "${CB_RED}🚨 No active gcloud project. Run 'gcp-set-project' first.${C_RESET}"
    return 1
  fi

  local selection
  selection=$(gcloud container clusters list --project="$project" --format="value(name,location)" 2> /dev/null | fzf --prompt="⎈  Select GKE Cluster (${project}) > " --height=~15 --layout=reverse --border)
  if [ -z "$selection" ]; then
    echo -e "${CB_YELLOW}⚠️  Cluster selection cancelled.${C_RESET}"
    return 0
  fi

  local cluster location
  cluster=$(echo "$selection" | awk '{print $1}')
  location=$(echo "$selection" | awk '{print $2}')

  echo -e "${CB_BLUE}🔄 Connecting to ${cluster} (${location})...${C_RESET}"
  if gcloud container clusters get-credentials "$cluster" --zone="$location" --project="$project" > /dev/null 2>&1; then
    echo -e "${CB_GREEN}✅ Connected to ${cluster}.${C_RESET}"
  elif gcloud container clusters get-credentials "$cluster" --region="$location" --project="$project" > /dev/null 2>&1; then
    echo -e "${CB_GREEN}✅ Connected to ${cluster}.${C_RESET}"
  else
    echo -e "${CB_RED}🚨 Failed to connect to ${cluster}.${C_RESET}"
    return 1
  fi
}
```

#### `k8s-ns`

> Kubernetes: Get or interactively set the active namespace in the

```bash
#######################################
# Kubernetes: Get or interactively set the active namespace in the
# current context
# Usage: k8s-ns [namespace]
# Arguments:
#   $1 - (Optional) Namespace name to switch to. If blank, prints the
#        active namespace and opens an fzf menu to switch.
#######################################
k8s-ns() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1

  if [ -n "$1" ]; then
    kubectl config set-context --current --namespace="$1" > /dev/null && echo -e "${CB_GREEN}✅ Active namespace set to: $1${C_RESET}"
    return
  fi

  local current
  current=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2> /dev/null)
  echo -e "${CB_CYAN}Current Namespace:${C_RESET} ${current:-default}"

  local ns
  ns=$(kubectl get namespaces -o=jsonpath='{.items[*].metadata.name}' 2> /dev/null | tr ' ' '\n' | fzf --prompt="⎈  Select Namespace > " --height=~15 --layout=reverse --border)
  if [ -z "$ns" ]; then
    echo -e "${CB_YELLOW}⚠️  Namespace selection cancelled.${C_RESET}"
    return 0
  fi

  kubectl config set-context --current --namespace="$ns" > /dev/null && echo -e "${CB_GREEN}✅ Active namespace set to: ${ns}${C_RESET}"
}
```

#### `k8s-pods`

> Kubernetes: List pods in a clean table

```bash
#######################################
# Kubernetes: List pods in a clean table
# Usage: k8s-pods [-A] [-j|--json]
# Options:
#   -A           Show pods across all namespaces
#   -j, --json   Print pods via kubectl's own full JSON output instead
#                of the wide table
#######################################
k8s-pods() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1

  local all_namespaces=false json_mode=false
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -A) all_namespaces=true ;;
      -j | --json) json_mode=true ;;
    esac
    shift
  done

  local -a scope=()
  [ "$all_namespaces" = true ] && scope=(--all-namespaces)

  if [ "$json_mode" = true ]; then
    kubectl get pods "${scope[@]}" -o json
  else
    kubectl get pods "${scope[@]}" -o wide
  fi
}
```

#### `k8s-restart`

> Kubernetes: Trigger a rolling restart of a deployment -- the correct

```bash
#######################################
# Kubernetes: Trigger a rolling restart of a deployment -- the correct
# way to force pods to recreate, since it respects the deployment's
# rollout strategy rather than deleting pods and hoping the controller
# recreates them.
# Usage: k8s-restart [deployment-name]
#######################################
k8s-restart() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1

  local target="$1"
  if [ -z "$target" ]; then
    target=$(kubectl get deployments --no-headers -o custom-columns=":metadata.name" 2> /dev/null | fzf --prompt="⎈  Select Deployment > " --height=~10 --layout=reverse --border)
    if [ -z "$target" ]; then
      echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  kubectl rollout restart "deployment/${target}" && echo -e "${CB_GREEN}✅ Rollout restart triggered for ${target}.${C_RESET}"
}
```

#### `k8s-scale`

> Kubernetes: Scale a deployment's replica count. Routed through the

```bash
#######################################
# Kubernetes: Scale a deployment's replica count. Routed through the
# destructive-op guard when scaling to zero.
# Usage: k8s-scale [deployment-name] [replicas]
#######################################
k8s-scale() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1

  local target="$1" replicas="$2"
  if [ -z "$target" ]; then
    target=$(kubectl get deployments --no-headers -o custom-columns=":metadata.name" 2> /dev/null | fzf --prompt="⎈  Select Deployment > " --height=~10 --layout=reverse --border)
    if [ -z "$target" ]; then
      echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  if [ -z "$replicas" ]; then
    read -r -p "Replica count for ${target}: " replicas < /dev/tty
  fi

  if ! [[ "$replicas" =~ ^[0-9]+$ ]]; then
    echo -e "${CB_RED}🚨 Replica count must be a non-negative integer.${C_RESET}"
    return 1
  fi

  if [ "$replicas" -eq 0 ]; then
    __k8s_confirm_destructive "Scaling ${target} to 0 replicas." || {
      echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
      return 1
    }
  fi

  kubectl scale "deployment/${target}" --replicas="$replicas" && echo -e "${CB_GREEN}✅ ${target} scaled to ${replicas}.${C_RESET}"
}
```

#### `k8s-shell`

> Kubernetes: Interactive fuzzy-finder to exec into a running pod

```bash
#######################################
# Kubernetes: Interactive fuzzy-finder to exec into a running pod
# Usage: k8s-shell
#######################################
k8s-shell() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1

  local target
  target=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" 2> /dev/null | fzf --prompt="⎈  Select Pod > " --height=~10 --layout=reverse --border)

  if [ -z "$target" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi

  echo -e "${CB_GREEN}🚀 Entering sandbox for: ${target}...${C_RESET}"
  kubectl exec -it "$target" -- /bin/bash || kubectl exec -it "$target" -- /bin/sh
}
```

#### `k8s-status`

> Kubernetes: Dashboard summarizing the active context -- cluster,

```bash
#######################################
# Kubernetes: Dashboard summarizing the active context -- cluster,
# namespace, server version, node and pod counts.
# Usage: k8s-status [-j|--json]
# Options:
#   -j, --json   Print the same fields as one JSON object instead of the
#                colorized dashboard
#######################################
k8s-status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1
  local json_mode=false
  [[ "$1" == "-j" || "$1" == "--json" ]] && json_mode=true

  local ctx ns version nodes pods
  ctx=$(kubectl config current-context)
  ns=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2> /dev/null)
  ns="${ns:-default}"
  version=$(kubectl get --raw /version 2> /dev/null | jq -r '.gitVersion // "unknown"' 2> /dev/null)
  nodes=$(kubectl get nodes --no-headers 2> /dev/null | wc -l | tr -d ' ')
  pods=$(kubectl get pods -n "$ns" --no-headers 2> /dev/null | wc -l | tr -d ' ')

  if [ "$json_mode" = true ]; then
    jq -n --arg context "$ctx" --arg namespace "$ns" --arg server_version "${version:-unknown}" \
      --argjson nodes "${nodes:-0}" --argjson pods "${pods:-0}" \
      '{context: $context, namespace: $namespace, server_version: $server_version, nodes: $nodes, pods: $pods}'
    return
  fi

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}              KUBERNETES STATUS                            ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_CYAN}Context   :${C_RESET} ${ctx}"
  echo -e "${CB_CYAN}Namespace :${C_RESET} ${ns}"
  echo -e "${CB_CYAN}Server    :${C_RESET} ${version:-unknown}"
  echo -e "${CB_CYAN}Nodes     :${C_RESET} ${nodes:-0}"
  echo -e "${CB_CYAN}Pods      :${C_RESET} ${pods:-0} (in ${ns})"
}
```

#### `k8s-tail`

> Kubernetes: Concurrently tail logs from multiple selected pods

```bash
#######################################
# Kubernetes: Concurrently tail logs from multiple selected pods
# Usage: k8s-tail
# Globals:
#   OS_FAMILY
#######################################
k8s-tail() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1

  local selected
  selected=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" 2> /dev/null | fzf --multi --prompt="⎈  Select Pods (TAB to multi-select) > " --height=~15 --layout=reverse --border)

  if [ -z "$selected" ]; then
    echo -e "${CB_YELLOW}⚠️  No pods selected.${C_RESET}"
    return 0
  fi

  echo -e "${CB_GREEN}🚀 Tailing logs:${C_RESET}"
  echo "$selected"
  echo -e "${C_DIM}(Press Ctrl+C to stop)${C_RESET}\n"

  local colors=("$CB_CYAN" "$CB_GREEN" "$CB_YELLOW" "$CB_BLUE" "$CB_MAGENTA" "$CB_RED")
  local pids=()
  trap __k8s_tail_cleanup SIGINT

  local sed_buf="-u"
  [ "$OS_FAMILY" = "macos" ] && sed_buf="-l"

  local i=0 pod
  while read -r pod; do
    [ -z "$pod" ] && continue
    local color="${colors[$((i % ${#colors[@]}))]}"
    kubectl logs -f --tail=50 "$pod" 2>&1 | sed "$sed_buf" "s/^/${color}[$pod]${C_RESET} /" &
    pids+=("$!")
    ((i++))
  done <<< "$selected"

  wait "${pids[@]}" 2> /dev/null || true
  trap - SIGINT
}
```

### 📂 Docker: Container Management Utilities


#### `docker-containers`

> Docker: Interactive container management console -- fzf-pick any

```bash
#######################################
# Docker: Interactive container management console -- fzf-pick any
# container (running or stopped), then choose an action to run against
# it (logs, shell, stop/start/restart, stats, inspect, remove). The
# action list adapts to the container's current state (e.g. Start only
# appears for a stopped container), and the console loops back to the
# container list after each action until backed out.
# Usage: docker-containers
#######################################
docker-containers() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  while true; do
    local picked
    picked=$(docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.Status}}" |
      fzf --delimiter=$'\t' --with-nth=1,2,3 --prompt="🐳 Select Container > " --height=~15 --layout=reverse --border)

    [ -z "$picked" ] && return 0

    local target status running
    target=$(cut -f1 <<< "$picked")
    status=$(cut -f3 <<< "$picked")
    running=false
    [[ "$status" == Up* ]] && running=true

    local -a labels=() commands=()
    labels+=("Show Logs (follow)")
    commands+=("__docker_container_logs")

    if $running; then
      labels+=("Shell Into Container")
      commands+=("__docker_container_shell")
      labels+=("Show Live Stats")
      commands+=("__docker_container_stats")
      labels+=("Restart")
      commands+=("__docker_container_restart")
      labels+=("Stop")
      commands+=("__docker_container_stop")
    else
      labels+=("Start")
      commands+=("__docker_container_start")
    fi

    labels+=("Inspect (full details)")
    commands+=("__docker_container_inspect")
    labels+=("⚠️  Remove Container")
    commands+=("__docker_container_remove")

    local -a options=("${labels[@]}" "⬅  Back to Container List")
    local choice
    choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="🐳 ${target} (${status}) > " --height=~15 --layout=reverse --border)

    [ -z "$choice" ] && continue
    [ "$choice" = "⬅  Back to Container List" ] && continue

    local i
    for i in "${!labels[@]}"; do
      if [ "${labels[$i]}" = "$choice" ]; then
        "${commands[$i]}" "$target"
        echo -e "\n${C_DIM}Press Enter to continue...${C_RESET}"
        read -r < /dev/tty
        break
      fi
    done
  done
}
```

#### `docker-daemon`

> Docker: Start, stop, restart, or check the status of the Docker daemon

```bash
#######################################
# Docker: Start, stop, restart, or check the status of the Docker daemon
# Usage: docker-daemon [start|stop|restart|status]
# Arguments:
#   $1 - Action: start, stop, restart, or status (default: status)
#######################################
docker-daemon() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if ! command -v systemctl > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 systemctl not found -- don't know how to manage the Docker daemon on this system.${C_RESET}"
    return 1
  fi

  local action="${1:-status}"
  case "$action" in
    start)
      if __docker_is_running; then
        echo -e "${CB_GREEN}✅ Docker daemon is already running.${C_RESET}"
        return 0
      fi
      __docker_daemon_start
      ;;
    stop)
      if ! __docker_is_running; then
        echo -e "${CB_GREEN}✅ Docker daemon is already stopped.${C_RESET}"
        return 0
      fi
      echo -e "${CB_BLUE}🐳 Stopping Docker daemon...${C_RESET}"
      sudo systemctl stop docker && echo -e "${CB_GREEN}✅ Docker daemon stopped.${C_RESET}"
      ;;
    restart)
      echo -e "${CB_BLUE}🐳 Restarting Docker daemon...${C_RESET}"
      sudo systemctl stop docker 2> /dev/null
      __docker_daemon_start
      ;;
    status)
      if __docker_is_running; then
        echo -e "${CB_GREEN}✅ Docker daemon is running.${C_RESET}"
      else
        echo -e "${CB_YELLOW}⚠️  Docker daemon is not running.${C_RESET}"
      fi
      ;;
    *)
      echo "Usage: docker-daemon [start|stop|restart|status]" >&2
      return 1
      ;;
  esac
}
```

#### `docker-ls`

> Docker: List all running containers in a clean table format

```bash
#######################################
# Docker: List all running containers in a clean table format
# Usage: docker-ls [-j|--json]
# Options:
#   -j, --json   Print containers as a JSON array (docker ps's own
#                per-container fields) instead of the table
#######################################
docker-ls() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  if [[ "$1" == "-j" || "$1" == "--json" ]]; then
    docker ps --format '{{json .}}' | jq -s .
    return
  fi
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}
```

#### `docker-nuke`

> Docker: Aggressive cleanup of all unused containers, images, and volumes

```bash
#######################################
# Docker: Aggressive cleanup of all unused containers, images, and volumes
# Usage: docker-nuke [--dry-run]
# Options:
#   --dry-run  Show what would be removed without actually deleting anything
#######################################
docker-nuke() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  if [[ "$1" == "--dry-run" ]]; then
    echo "🔍 Simulating destruction of unused Docker resources..."
    docker system prune -a --volumes
    return 0
  fi

  echo -e "${CB_RED}⚠️  WARNING: This will destroy all stopped containers, unused networks, dangling images, and unused volumes.${C_RESET}"
  read -r -p "Are you sure you want to proceed? [y/N] " -n 1 < /dev/tty || REPLY="n"
  echo

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 0
  fi

  echo "💥 Nuking unused Docker resources..."
  docker system prune -a --volumes -f
  mt-log SUCCESS "Docker environment sanitized."
}
```

#### `docker-reboot`

> Docker: Recreate a single Compose project

```bash
#######################################
# Docker: Recreate a single Compose project
#
# Usage:
#   docker-reboot <container|project> [--verbose]
#
# Examples:
#   docker-reboot immich
#   docker-reboot immich --verbose
#######################################
docker-reboot() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1

  local target="$1"
  local verbose=false

  if [[ "$2" == "--verbose" ]]; then
    verbose=true
  fi

  if [[ -z "$target" ]]; then
    echo "Usage: docker-reboot <container|project> [--verbose]"
    return 1
  fi

  local project=""
  local compose_file=""

  # Resolve container name to compose metadata
  if docker inspect "$target" > /dev/null 2>&1; then
    if ! __docker_reboot_compose_metadata "$target" project compose_file; then
      echo -e "${CB_RED}❌ Unable to resolve Compose project for: $target${C_RESET}"
      return 1
    fi
  else
    # Allow project name directly
    local container
    container=$(docker ps --format "{{.Names}}" | while read -r c; do
      local p
      # f is required by __docker_reboot_compose_metadata's 3-arg signature; only $p is checked here
      # shellcheck disable=SC2034
      local f
      __docker_reboot_compose_metadata "$c" p f || continue
      [[ "$p" == "$target" ]] && echo "$c" && break
    done)

    if [[ -z "$container" ]]; then
      echo -e "${CB_RED}❌ Compose project not found: $target${C_RESET}"
      return 1
    fi

    __docker_reboot_compose_metadata "$container" project compose_file
  fi

  echo "🔄 Restarting Docker Compose project: ${project}"

  if $verbose; then
    echo "📁 Compose: ${compose_file}"
  fi

  if $verbose; then
    docker compose -f "$compose_file" down
  else
    docker compose -f "$compose_file" down > /dev/null 2>&1
  fi

  if $verbose; then
    docker compose -f "$compose_file" up -d
  else
    docker compose -f "$compose_file" up -d > /dev/null 2>&1
  fi

  echo "⏳ Waiting for recovery..."

  if __docker_reboot_wait_for_project "$compose_file"; then
    echo -e "${CB_GREEN}✅ Project recreated: ${project}${C_RESET}"
    return 0
  fi

  echo -e "${CB_YELLOW}⚠️  Project did not become healthy: ${project}${C_RESET}"
  return 1
}
```

#### `docker-reboot-all`

> Docker: Recreate every running Docker Compose project on this host --

```bash
#######################################
# Docker: Recreate every running Docker Compose project on this host --
# a full 'down' then 'up -d' per project rather than a naive per-
# container 'docker restart', so shared networks/volumes and startup
# ordering within a project are respected. A container excluded via -x
# or DOCKER_BLOCKLIST takes its entire project out of the run, since a
# Compose project can't be partially recreated. Containers not managed
# by Compose are reported and skipped, since there's no project to
# recreate them as part of.
# Usage: docker-reboot-all [-x container1,container2]
# Options:
#   -x <names>  Comma-separated list of container names to exclude, in
#               addition to the permanent DOCKER_BLOCKLIST
# Globals:
#   DOCKER_BLOCKLIST
#######################################
docker-reboot-all() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1

  local manual_excludes=""
  local verbose=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -x)
        if [[ -z "$2" ]]; then
          echo -e "${CB_RED}❌ -x requires a comma-separated exclusion list.${C_RESET}"
          return 1
        fi
        manual_excludes="$2"
        shift 2
        ;;
      --verbose | -v)
        verbose=true
        shift
        ;;
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      *)
        echo "Usage: docker-reboot-all [-x container1,container2] [--verbose]" 1>&2
        return 1
        ;;
    esac
  done

  local full_excludes="${DOCKER_BLOCKLIST:-}"
  [ -n "$manual_excludes" ] && full_excludes="${full_excludes:+${full_excludes},}${manual_excludes}"

  local exclude_pattern=""
  [ -n "$full_excludes" ] && exclude_pattern=$(echo "$full_excludes" | sed 's/,/|/g; s/ //g')

  local running_containers
  running_containers=$(docker ps --format "{{.Names}}")

  if [ -z "$running_containers" ]; then
    mt-log WARN "No running Docker containers found."
    return 0
  fi

  local -A project_seen=() project_excluded=()
  local project_order=()

  local container project compose_file

  while read -r container; do
    [ -z "$container" ] && continue

    if ! __docker_reboot_compose_metadata "$container" project compose_file; then
      echo -e "${CB_YELLOW}⚠️  Skipping non-Compose container: ${container}${C_RESET}"
      continue
    fi

    if [ -n "$exclude_pattern" ] && [[ "$container" =~ ^(${exclude_pattern})$ ]]; then
      project_excluded["$project"]=1
      continue
    fi

    if [ -z "${project_seen[$project]:-}" ]; then
      project_seen["$project"]=1
      project_order+=("$project")
    fi
  done <<< "$running_containers"

  if [ "${#project_order[@]}" -eq 0 ]; then
    mt-log WARN "No Compose projects found among running containers."
    return 0
  fi

  echo -e "${CB_BLUE}🚀 Queueing Docker Compose projects for parallel restart...${C_RESET}"

  local queued=0 skipped=0
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)

  for project in "${project_order[@]}"; do

    if [ -n "${project_excluded[$project]:-}" ]; then
      echo -e "${CB_YELLOW}⚠️  Skipping project: ${project} (excluded)${C_RESET}"
      ((skipped++))
      continue
    fi

    local verbose_arg=""
    [ "$verbose" = true ] && verbose_arg=" --verbose"

    local log_file="${LOG_DIR}/docker-reboot_${project}_${timestamp}.log"
    local cmd_string="docker-reboot '${project}'${verbose_arg}"

    __mt_bg_run "docker-reboot: ${project}" "$log_file" "$cmd_string"

    ((queued++))
  done

  echo
  echo -e "${CB_GREEN}✅ ${queued} Docker reboot job(s) queued.${C_RESET}"

  if [ "$skipped" -gt 0 ]; then
    echo -e "${CB_YELLOW}⚠️  ${skipped} project(s) skipped due to exclusions.${C_RESET}"
  fi

  echo -e "${C_DIM}Run 'mt-jobs' to monitor progress.${C_RESET}"
}
```

#### `docker-sandbox`

> Docker: Spin up a temporary, throwaway container sandbox

```bash
#######################################
# Docker: Spin up a temporary, throwaway container sandbox
# Usage: docker-sandbox [image]
# Arguments:
#   $1 - Target image (default: debian)
#######################################
docker-sandbox() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  local image="${1:-debian}"
  echo -e "${CB_BLUE}🚀 Launching temporary ${image} sandbox...${C_RESET}"
  docker run --rm -it "$image" /bin/bash || docker run --rm -it "$image" /bin/sh
}
```

#### `docker-shell`

> Docker: Interactive fuzzy-finder to exec into a running container

```bash
#######################################
# Docker: Interactive fuzzy-finder to exec into a running container
# Usage: docker-shell
#######################################
docker-shell() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  local target
  target=$(docker ps --format "{{.Names}}" | fzf --prompt="🐳 Select Container > " --height=~10 --layout=reverse --border)

  if [ -z "$target" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi

  echo -e "${CB_GREEN}🚀 Entering sandbox for: ${target}...${C_RESET}"
  # Try bash first, fallback to standard sh if bash isn't installed in the container
  docker exec -it "$target" /bin/bash || docker exec -it "$target" /bin/sh
}
```

#### `docker-tail`

> Docker: Concurrently tail logs from multiple selected containers

```bash
#######################################
# Docker: Concurrently tail logs from multiple selected containers
# Usage: docker-tail
# Globals:
#   OS_FAMILY
#######################################
docker-tail() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  local selected
  selected=$(docker ps --format "{{.Names}}" | fzf --multi --prompt="🐳 Select Containers (TAB to multi-select) > " --height=~15 --layout=reverse --border)

  if [ -z "$selected" ]; then
    echo -e "${CB_YELLOW}⚠️  No containers selected.${C_RESET}"
    return 0
  fi

  local flat_selected
  flat_selected=$(echo "$selected" | tr '\n' ' ')
  echo -e "${CB_GREEN}🚀 Tailing logs for: ${flat_selected}${C_RESET}"
  echo -e "${C_DIM}(Press Ctrl+C to stop)${C_RESET}\n"

  local colors=("$CB_CYAN" "$CB_GREEN" "$CB_YELLOW" "$CB_BLUE" "$CB_MAGENTA" "$CB_RED")
  local pids=()
  trap __docker_tail_cleanup SIGINT

  local sed_buf="-u"
  [ "$OS_FAMILY" = "macos" ] && sed_buf="-l"

  local i=0 container
  for container in $selected; do
    local color="${colors[$((i % ${#colors[@]}))]}"
    docker logs -f --tail 50 "$container" 2>&1 | sed "$sed_buf" "s/^/${color}[$container]${C_RESET} /" &
    pids+=($!)
    ((i++))
  done

  wait "${pids[@]}" 2> /dev/null || true
  trap - SIGINT
}
```

#### `docker-update`

> Docker: Check a Compose project for image updates and optionally

```bash
#######################################
# Docker: Check a Compose project for image updates and optionally
# update it interactively.
#
# Usage:
#   docker-update <container|project>
#
# Behaviour:
#   1. Resolve the Compose project and canonical Compose configuration.
#   2. Inspect each service image used by the running project.
#   3. Compare the locally running image digest with the current registry
#      digest without pulling the image.
#   4. Report services with updates available.
#   5. Ask whether the project should be updated.
#   6. If approved, ask which release channel should be used for this
#      update: current, latest, stable, or release.
#   7. For latest/stable/release, a temporary Compose override is used;
#      the user's original Compose file is never modified.
#   8. Pull the selected images, recreate the project with Compose, and
#      wait for the project to become ready.
#
# Notes:
#   - Services using pinned/version-specific tags remain on their current
#     tag when an alternate release channel is selected.
#   - Digest-pinned images are not considered updateable.
#   - Services without a running container are skipped during the check.
#######################################
docker-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1

  if ! command -v jq > /dev/null 2>&1; then
    echo -e "${CB_RED}❌ jq is required by docker-update but was not found.${C_RESET}"
    echo -e "${C_DIM}Run 'bootstrap' to install missing dependencies.${C_RESET}"
    return 1
  fi

  if ! docker buildx version > /dev/null 2>&1; then
    echo -e "${CB_RED}❌ Docker Buildx is required by docker-update but was not found.${C_RESET}"
    return 1
  fi

  local target="$1"

  if [[ -z "$target" ]]; then
    echo "Usage: docker-update <container|project>"
    return 1
  fi

  local project=""
  local compose_file=""

  # Resolve container name to compose metadata.
  if docker inspect "$target" > /dev/null 2>&1; then
    if ! __docker_reboot_compose_metadata "$target" project compose_file; then
      echo -e "${CB_RED}❌ Unable to resolve Compose project for: $target${C_RESET}"
      return 1
    fi
  else
    # Allow project name directly.
    local container
    container=$(docker ps --format "{{.Names}}" | while read -r c; do
      local p
      # f is required by __docker_reboot_compose_metadata's 3-arg signature; only $p is checked here.
      # shellcheck disable=SC2034
      local f
      __docker_reboot_compose_metadata "$c" p f || continue
      [[ "$p" == "$target" ]] && echo "$c" && break
    done)

    if [[ -z "$container" ]]; then
      echo -e "${CB_RED}❌ Compose project not found: $target${C_RESET}"
      return 1
    fi

    __docker_reboot_compose_metadata "$container" project compose_file
  fi

  echo -e "${CB_BLUE}🐳 Checking Docker Compose project: ${project}${C_RESET}"
  echo -e "${C_DIM}📁 Compose: ${compose_file}${C_RESET}"
  echo

  local compose_config
  compose_config=$(docker compose -f "$compose_file" config --format json 2> /dev/null)

  if [[ -z "$compose_config" ]]; then
    echo -e "${CB_RED}❌ Unable to resolve Compose configuration for: ${project}${C_RESET}"
    return 1
  fi

  local update_services=()
  local update_images=()
  local update_tags=()

  local service image container current_tag local_digest remote_digest

  echo -e "${CB_BLUE}🔍 Checking registry for image updates...${C_RESET}"
  echo

  printf "%-28s %-38s %s\n" "Service" "Current image" "Status"
  printf "%-28s %-38s %s\n" "----------------------------" "--------------------------------------" "----------------"

  while IFS=$'\t' read -r service image; do
    [ -z "$service" ] && continue
    [ -z "$image" ] && continue

    # Digest-pinned images cannot be updated through a tag/channel change.
    if [[ "$image" == *@* ]]; then
      printf "%-28s %-38s %s\n" "$service" "$image" "Pinned digest"
      continue
    fi

    container=$(docker compose -f "$compose_file" ps -q "$service" 2> /dev/null | head -n 1)

    if [[ -z "$container" ]]; then
      printf "%-28s %-38s %s\n" "$service" "$image" "Not running"
      continue
    fi

    current_tag=$(__docker_update_image_tag "$image")

    local_digest=$(__docker_update_local_digest "$container")

    if [[ -z "$local_digest" ]]; then
      printf "%-28s %-38s %s\n" "$service" "$image" "Unable to verify"
      continue
    fi

    remote_digest=$(__docker_update_remote_digest "$image")

    if [[ -z "$remote_digest" ]]; then
      printf "%-28s %-38s %s\n" "$service" "$image" "Registry unavailable"
      continue
    fi

    if [[ "$local_digest" != "$remote_digest" ]]; then
      printf "%-28s %-38s %s\n" "$service" "$image" "${CB_YELLOW}Update available${C_RESET}"
      update_services+=("$service")
      update_images+=("$image")
      update_tags+=("$current_tag")
    else
      printf "%-28s %-38s %s\n" "$service" "$image" "${CB_GREEN}Up to date${C_RESET}"
    fi
  done < <(
    jq -r '
      .services
      | to_entries[]
      | select(.value.image != null)
      | [.key, .value.image]
      | @tsv
    ' <<< "$compose_config"
  )

  echo

  if [[ "${#update_services[@]}" -eq 0 ]]; then
    echo -e "${CB_GREEN}✅ No image updates are currently available for: ${project}${C_RESET}"
    return 0
  fi

  echo -e "${CB_YELLOW}⚠️  Updates are available for ${#update_services[@]} service(s).${C_RESET}"
  echo

  local reply
  read -r -p "Update project '${project}'? [y/N] " -n 1 reply < /dev/tty || reply="n"
  echo

  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo -e "${CB_YELLOW}🛑 Update cancelled.${C_RESET}"
    return 0
  fi

  echo
  echo "Which release channel would you like to use for this update?"
  echo
  echo "  1) Keep current"
  echo "  2) latest"
  echo "  3) stable"
  echo "  4) release"
  echo

  local channel_choice channel="current"
  read -r -p "Select [1-4]: " channel_choice < /dev/tty || channel_choice=""

  case "$channel_choice" in
    1 | "")
      channel="current"
      ;;
    2)
      channel="latest"
      ;;
    3)
      channel="stable"
      ;;
    4)
      channel="release"
      ;;
    *)
      echo -e "${CB_YELLOW}🛑 Invalid selection. Update cancelled.${C_RESET}"
      return 1
      ;;
  esac

  echo

  local override_file=""
  local pull_compose_args=()
  local up_compose_args=()

  if [[ "$channel" == "current" ]]; then
    echo -e "${CB_BLUE}⬇️  Updating services using their current Compose image tags...${C_RESET}"

    for service in "${update_services[@]}"; do
      echo -e "  ${CB_BLUE}→${C_RESET} ${service}"
    done

    pull_compose_args=(-f "$compose_file")
    up_compose_args=(-f "$compose_file")
  else
    echo -e "${CB_BLUE}🔍 Checking '${channel}' channel availability...${C_RESET}"

    override_file=$(mktemp "${TMPDIR:-/tmp}/docker-update-${project}.XXXXXX.json") || {
      echo -e "${CB_RED}❌ Unable to create temporary Compose override.${C_RESET}"
      return 1
    }

    jq -n '{services:{}}' > "$override_file"

    local changed_services=0
    local index new_image candidate_digest repo current_channel

    for index in "${!update_services[@]}"; do
      service="${update_services[$index]}"
      image="${update_images[$index]}"
      current_channel="${update_tags[$index]}"

      # Only switch release channels for services already using a
      # recognised channel tag. Version-pinned services remain pinned.
      case "$current_channel" in
        latest | stable | release) ;;
        *)
          echo -e "  ${CB_YELLOW}⚠️${C_RESET} ${service}: keeping pinned tag '${current_channel}'"
          continue
          ;;
      esac

      repo=$(__docker_update_image_repo "$image")
      new_image="${repo}:${channel}"

      candidate_digest=$(__docker_update_remote_digest "$new_image")

      if [[ -z "$candidate_digest" ]]; then
        echo -e "  ${CB_YELLOW}⚠️${C_RESET} ${service}: ${new_image} is unavailable"
        continue
      fi

      container=$(docker compose -f "$compose_file" ps -q "$service" 2> /dev/null | head -n 1)
      local_digest=$(__docker_update_local_digest "$container")

      if [[ -z "$local_digest" ]]; then
        echo -e "  ${CB_YELLOW}⚠️${C_RESET} ${service}: unable to verify local digest"
        continue
      fi

      if [[ "$local_digest" == "$candidate_digest" ]]; then
        echo -e "  ${CB_GREEN}✓${C_RESET} ${service}: already running the '${channel}' image"
        continue
      fi

      jq \
        --arg service "$service" \
        --arg image "$new_image" \
        '.services[$service] = {"image": $image}' \
        "$override_file" > "${override_file}.tmp" && mv "${override_file}.tmp" "$override_file"

      echo -e "  ${CB_GREEN}→${C_RESET} ${service}: ${image} → ${new_image}"
      ((changed_services++))
    done

    if [[ "$changed_services" -eq 0 ]]; then
      rm -f "$override_file"
      echo
      echo -e "${CB_YELLOW}⚠️  No services can be updated to the '${channel}' channel.${C_RESET}"
      return 0
    fi

    pull_compose_args=(-f "$compose_file" -f "$override_file")
    up_compose_args=(-f "$compose_file" -f "$override_file")
  fi

  echo

  if ! docker compose "${pull_compose_args[@]}" pull; then
    [ -n "$override_file" ] && rm -f "$override_file"
    echo -e "${CB_RED}❌ Failed to pull updated images for: ${project}${C_RESET}"
    return 1
  fi

  echo
  echo -e "${CB_BLUE}🔄 Recreating updated project...${C_RESET}"

  if ! docker compose "${up_compose_args[@]}" up -d; then
    [ -n "$override_file" ] && rm -f "$override_file"
    echo -e "${CB_RED}❌ Failed to recreate Docker Compose project: ${project}${C_RESET}"
    return 1
  fi

  [ -n "$override_file" ] && rm -f "$override_file"

  echo
  echo "⏳ Waiting for recovery..."

  if __docker_reboot_wait_for_project "$compose_file"; then
    if [[ "$channel" == "current" ]]; then
      echo -e "${CB_GREEN}✅ Project updated: ${project}${C_RESET}"
    else
      echo -e "${CB_GREEN}✅ Project updated using '${channel}' channel: ${project}${C_RESET}"
      echo -e "${C_DIM}The original Compose file was not modified.${C_RESET}"
    fi
    return 0
  fi

  echo -e "${CB_YELLOW}⚠️  Project did not become healthy after update: ${project}${C_RESET}"
  return 1
}
```

### 📂 Docker: Image Build, Versioning & Registry Push


#### `docker-build`

> Docker: Build an image from a Dockerfile, auto-versioning it (see

```bash
#######################################
# Docker: Build an image from a Dockerfile, auto-versioning it (see
# __docker_next_version) rather than requiring a manually-picked tag.
# Always tags both the versioned reference and ':latest'.
# Usage: docker-build [image] [context] [dockerfile]
# Arguments:
#   $1 - (Optional) Image name. Prompted (defaulting to the context
#        directory's basename) if omitted.
#   $2 - (Optional) Build context directory. Defaults to ".".
#   $3 - (Optional) Dockerfile path. Defaults to "<context>/Dockerfile".
#######################################
docker-build() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  local context="${2:-.}"
  local image="$1"
  if [ -z "$image" ]; then
    local default_image
    default_image=$(basename "$(cd "$context" && pwd)")
    read -r -p "Image name [${default_image}]: " image < /dev/tty
    image="${image:-$default_image}"
  fi

  local dockerfile="${3:-${context}/Dockerfile}"
  if [ ! -f "$dockerfile" ]; then
    echo -e "${CB_RED}🚨 Dockerfile not found: ${dockerfile}${C_RESET}"
    return 1
  fi

  local version
  version=$(__docker_next_version "$image")

  echo -e "${CB_BLUE}🔄 Building ${image}:${version} from ${dockerfile}...${C_RESET}"
  if docker build -t "${image}:${version}" -t "${image}:latest" -f "$dockerfile" "$context"; then
    __docker_record_version "$image" "$version"
    echo -e "${CB_GREEN}✅ Built ${image}:${version} (also tagged latest).${C_RESET}"
  else
    echo -e "${CB_RED}🚨 Build failed.${C_RESET}"
    return 1
  fi
}
```

#### `docker-push`

> Docker: Tag (via docker-tag) and push a locally-built image to a

```bash
#######################################
# Docker: Tag (via docker-tag) and push a locally-built image to a
# registry, authenticating first via __docker_registry_login.
# Usage: docker-push [image] [registry] [version]
# Arguments:
#   $1 - (Optional) Local image name. fzf-picks from local images if
#        omitted.
#   $2 - (Optional) Registry: gar or dockerhub. Defaults to
#        $DOCKER_DEFAULT_REGISTRY.
#   $3 - (Optional) Version to push. Defaults to the last version
#        recorded by docker-build for this image.
# Globals:
#   DOCKER_DEFAULT_REGISTRY
#######################################
docker-push() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  local image="$1"
  if [ -z "$image" ]; then
    image=$(docker images --format '{{.Repository}}' 2> /dev/null | sort -u | fzf --prompt="🐳 Select Local Image > " --height=~15 --layout=reverse --border)
    if [ -z "$image" ]; then
      echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  local registry="${2:-$DOCKER_DEFAULT_REGISTRY}"
  local version="$3"
  if [ -z "$version" ]; then
    version=$(__docker_last_version "$image")
    if [ -z "$version" ]; then
      echo -e "${CB_RED}🚨 No recorded build for '${image}'. Run 'docker-build' first, or pass a version explicitly.${C_RESET}"
      return 1
    fi
  fi

  docker-tag "$image" "$registry" "$version" || return 1

  local fq_ref fq_repo
  fq_ref=$(__docker_registry_ref "$image" "$version" "$registry") || return 1
  fq_repo="${fq_ref%:*}"

  echo -e "${CB_BLUE}🔐 Authenticating with ${registry}...${C_RESET}"
  __docker_registry_login "$registry" || return 1

  echo -e "${CB_BLUE}🔄 Pushing ${fq_ref}...${C_RESET}"
  docker push "$fq_ref" && docker push "${fq_repo}:latest" && echo -e "${CB_GREEN}✅ Pushed ${fq_ref} (and latest).${C_RESET}"
}
```

#### `docker-release`

> Docker: Build and push in one step -- the convenience wrapper around

```bash
#######################################
# Docker: Build and push in one step -- the convenience wrapper around
# docker-build + docker-push, same relationship as mtupd wraps
# mt-push-update.
# Usage: docker-release [image] [context] [registry]
# Arguments:
#   $1 - (Optional) Image name. Prompted (defaulting to the context
#        directory's basename) if omitted -- resolved once upfront so
#        docker-build and docker-push always act on the same name.
#   $2 - (Optional) Build context directory. Defaults to ".".
#   $3 - (Optional) Registry: gar or dockerhub. Defaults to
#        $DOCKER_DEFAULT_REGISTRY.
# Globals:
#   DOCKER_DEFAULT_REGISTRY
#######################################
docker-release() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  local context="${2:-.}"
  local image="$1"
  if [ -z "$image" ]; then
    local default_image
    default_image=$(basename "$(cd "$context" && pwd)")
    read -r -p "Image name [${default_image}]: " image < /dev/tty
    image="${image:-$default_image}"
  fi

  local registry="${3:-$DOCKER_DEFAULT_REGISTRY}"

  docker-build "$image" "$context" || return 1
  docker-push "$image" "$registry"
}
```

#### `docker-tag`

> Docker: Tag a locally-built image with a registry's fully-qualified

```bash
#######################################
# Docker: Tag a locally-built image with a registry's fully-qualified
# reference, without pushing it.
# Usage: docker-tag [image] [registry] [version]
# Arguments:
#   $1 - (Optional) Local image name. fzf-picks from local images if
#        omitted.
#   $2 - (Optional) Registry: gar or dockerhub. Prompted if omitted.
#   $3 - (Optional) Version to tag. Defaults to the last version
#        recorded by docker-build for this image.
#######################################
docker-tag() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1

  local image="$1"
  if [ -z "$image" ]; then
    image=$(docker images --format '{{.Repository}}' 2> /dev/null | sort -u | fzf --prompt="🐳 Select Local Image > " --height=~15 --layout=reverse --border)
    if [ -z "$image" ]; then
      echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  local registry="$2"
  if [ -z "$registry" ]; then
    registry=$(printf '%s\n' gar dockerhub | fzf --prompt="📦 Select Registry > " --height=~10 --layout=reverse --border)
    if [ -z "$registry" ]; then
      echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  local version="$3"
  if [ -z "$version" ]; then
    version=$(__docker_last_version "$image")
    if [ -z "$version" ]; then
      echo -e "${CB_RED}🚨 No recorded build for '${image}'. Run 'docker-build' first, or pass a version explicitly.${C_RESET}"
      return 1
    fi
  fi

  local fq_ref fq_repo
  fq_ref=$(__docker_registry_ref "$image" "$version" "$registry") || return 1
  fq_repo="${fq_ref%:*}"

  docker tag "${image}:${version}" "$fq_ref" || return 1
  docker tag "${image}:latest" "${fq_repo}:latest" || return 1

  echo -e "${CB_GREEN}✅ Tagged: ${fq_ref} (and ${fq_repo}:latest)${C_RESET}"
}
```

### 📂 Docker -> Kubernetes/Helm/Minikube Bridge


#### `docker-deploy`

> Docker->Helm bridge: Run a locally-built image on whichever cluster is

```bash
#######################################
# Docker->Helm bridge: Run a locally-built image on whichever cluster is
# currently active. If the active kubectl context is a local minikube
# profile, the image is loaded directly via mk-load-image (no registry
# round-trip needed for local dev); otherwise (e.g. GKE) it's pushed to
# the configured default registry first via docker-push. Either way, the
# result is deployed with 'helm upgrade --install'.
#
# Assumes the target chart uses the common .Values.image.repository/
# .Values.image.tag convention (true for helm-create scaffolds and most
# published charts). A chart with a different values shape needs a
# plain 'helm upgrade' with custom --set overrides instead.
# Usage: docker-deploy [image] [chart]
# Arguments:
#   $1 - (Optional) Image name, as recorded by docker-build. fzf-picks
#        from previously built images if omitted.
#   $2 - (Optional) Path to a Helm chart. Auto-detects ./chart or
#        ./helm if either contains a Chart.yaml; prompted otherwise.
# Globals:
#   DOCKER_DEFAULT_REGISTRY
#######################################
docker-deploy() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local image="$1"
  if [ -z "$image" ]; then
    local version_file="$CACHE_DIR/.docker_image_versions.tsv"
    image=$([ -f "$version_file" ] && cut -f1 "$version_file" | fzf --prompt="🐳 Select Built Image > " --height=~15 --layout=reverse --border)
    if [ -z "$image" ]; then
      echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  local version
  version=$(__docker_last_version "$image")
  if [ -z "$version" ]; then
    echo -e "${CB_RED}🚨 No recorded build for '${image}'. Run 'docker-build' first.${C_RESET}"
    return 1
  fi

  local chart="$2"
  if [ -z "$chart" ]; then
    if [ -f "./chart/Chart.yaml" ]; then
      chart="./chart"
    elif [ -f "./helm/Chart.yaml" ]; then
      chart="./helm"
    else
      read -r -p "Path to Helm chart: " chart < /dev/tty
    fi
  fi
  if [ -z "$chart" ] || [ ! -f "${chart}/Chart.yaml" ]; then
    echo -e "${CB_RED}🚨 No Chart.yaml found at '${chart}'.${C_RESET}"
    return 1
  fi

  local release="$image"
  local ctx
  ctx=$(kubectl config current-context 2> /dev/null)

  local -a mk_profiles
  mapfile -t mk_profiles < <(minikube profile list -o json 2> /dev/null | jq -r '.valid[]?.Name' 2> /dev/null)

  local repository
  local -a extra_set_args=()
  if printf '%s\n' "${mk_profiles[@]}" | grep -qx "$ctx" 2> /dev/null; then
    echo -e "${CB_BLUE}🔄 Active context '${ctx}' is a local minikube profile -- loading the image directly, no registry needed.${C_RESET}"
    mk-load-image "${image}:${version}" "$ctx" || return 1
    repository="$image"
    extra_set_args=(--set "image.pullPolicy=Never")
  else
    echo -e "${CB_BLUE}🔄 Active context '${ctx}' looks like a remote cluster -- pushing to ${DOCKER_DEFAULT_REGISTRY} first.${C_RESET}"
    docker-push "$image" "$DOCKER_DEFAULT_REGISTRY" "$version" || return 1
    local fq_ref
    fq_ref=$(__docker_registry_ref "$image" "$version" "$DOCKER_DEFAULT_REGISTRY") || return 1
    repository="${fq_ref%:*}"
  fi

  echo -e "${CB_BLUE}🔄 Deploying ${release} (${repository}:${version}) via Helm...${C_RESET}"
  helm upgrade --install "$release" "$chart" \
    --set "image.repository=${repository}" \
    --set "image.tag=${version}" \
    "${extra_set_args[@]}" &&
    echo -e "${CB_GREEN}✅ Deployed ${release}.${C_RESET}" &&
    echo -e "${C_DIM}Run 'helm-list' or 'k8s-status' to check on it.${C_RESET}"
}
```

### 📂 Framework: Repository Scaffolding from Blueprints


#### `mt-blueprint`

> Framework: Scaffold a new repository using standardized DevOps blueprints

```bash
#######################################
# Framework: Scaffold a new repository using standardized DevOps blueprints
# Usage: mt-blueprint [-t <blueprint_name>]
# Options:
#   -t <name>  Blueprint to apply (skips the interactive fzf picker)
# Globals:
#   CICD_PROVIDER
#######################################
mt-blueprint() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local blueprints_dir="$HOME/.bash.d/lib/blueprints"
  if [ ! -d "$blueprints_dir" ]; then
    mt-log ERROR "Blueprints directory not found at $blueprints_dir"
    return 1
  fi

  local requested=""
  local OPTIND opt
  while getopts "t:" opt; do
    case ${opt} in
      t) requested="$OPTARG" ;;
      \?)
        echo "Usage: mt-blueprint [-t <blueprint_name>]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  local target
  target=$(__mt_blueprint_select "$requested" "$blueprints_dir")
  if [ -z "$target" ]; then
    echo -e "${CB_YELLOW}⚠️  Blueprint selection cancelled.${C_RESET}"
    return 0
  fi

  local source_dir="${blueprints_dir}/${target}"
  if [ ! -d "$source_dir" ]; then
    mt-log ERROR "Blueprint '$target' does not exist."
    return 1
  fi

  echo -e "${CB_BLUE}🏗️  Scaffolding '$target' into $PWD...${C_RESET}"
  __mt_blueprint_scaffold "$source_dir"
  __mt_blueprint_route_cicd

  mt-log SUCCESS "Blueprint '$target' applied successfully!"
}
```

### 📂 GCP: Configuration & Authentication


#### `gcl-config`

> GCP: List active configuration properties

```bash
#######################################
# GCP: List active configuration properties
# Arguments:
#   $@ - (Optional) Additional arguments passed directly to 'gcloud config list'
#######################################
gcl-config() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud config list "$@"
}
```

#### `gcl-export-vars`

> GCP: Export PROJECT_ID and PROJECT_NUMBER env vars to shell

```bash
#######################################
# GCP: Export PROJECT_ID and PROJECT_NUMBER env vars to shell
# Arguments:
#   $1 - (Optional) <project_id> to export.
#        Pass '-ls' to list available projects.
#        If left blank, opens an interactive fzf menu.
#######################################
gcl-export-vars() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [[ "$1" == "-ls" ]]; then
    gcloud projects list --format="table(projectId,name,projectNumber)"
    return 0
  fi

  local target_project="$1"

  if [ -z "$target_project" ]; then
    target_project=$(gcloud projects list --format="value(projectId)" | fzf --prompt="Select GCP Project to Export > ")
    if [ -z "$target_project" ]; then
      echo "⚠️ Project selection cancelled."
      return 0
    fi
  fi

  export PROJECT_ID="$target_project"

  if [ -n "$PROJECT_ID" ]; then
    export PROJECT_NUMBER
    PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
    echo "✅ Exported PROJECT_ID=${PROJECT_ID} and PROJECT_NUMBER=${PROJECT_NUMBER}"
  else
    echo "🚨 Error: Could not determine active project ID."
  fi
}
```

#### `gcl-get`

> GCP: Print an active gcloud configuration property

```bash
#######################################
# GCP: Print an active gcloud configuration property
# Usage: gcl-get <project|project-number|region|user|zone>
#######################################
gcl-get() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  case "$1" in
    project) __get_gcp_config_val "project" ;;
    project-number)
      local project_id
      project_id=$(__get_gcp_config_val "project")
      [ -n "$project_id" ] && gcloud projects describe "$project_id" --format="value(projectNumber)"
      ;;
    region) __get_gcp_config_val "region" ;;
    zone) __get_gcp_config_val "zone" ;;
    user) __get_gcp_config_val "account" ;;
    *)
      echo "Usage: gcl-get <project|project-number|region|user|zone>" >&2
      return 1
      ;;
  esac
}
```

#### `gcl-get-project`

> GCP: Print active project ID (shortcut for `gcl-get project`)

```bash
#######################################
# GCP: Print active project ID (shortcut for `gcl-get project`)
#######################################
gcl-get-project() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get project
}
```

#### `gcl-get-project-number`

> GCP: Print active project Number, API call required (shortcut for `gcl-get project-number`)

```bash
#######################################
# GCP: Print active project Number, API call required (shortcut for `gcl-get project-number`)
#######################################
gcl-get-project-number() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get project-number
}
```

#### `gcl-get-region`

> GCP: Print active compute region (shortcut for `gcl-get region`)

```bash
#######################################
# GCP: Print active compute region (shortcut for `gcl-get region`)
#######################################
gcl-get-region() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get region
}
```

#### `gcl-get-user`

> GCP: Print active user account (shortcut for `gcl-get user`)

```bash
#######################################
# GCP: Print active user account (shortcut for `gcl-get user`)
#######################################
gcl-get-user() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get user
}
```

#### `gcl-get-zone`

> GCP: Print active compute zone (shortcut for `gcl-get zone`)

```bash
#######################################
# GCP: Print active compute zone (shortcut for `gcl-get zone`)
#######################################
gcl-get-zone() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get zone
}
```

#### `gcl-org-policies`

> GCP: List org policies for active project

```bash
#######################################
# GCP: List org policies for active project
#######################################
gcl-org-policies() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local project_id
  project_id=$(gcl-get-project)
  [ -n "$project_id" ] && gcloud alpha resource-manager org-policies list --project="$project_id"
}
```

#### `gcl-update`

> GCP: Update Google Cloud CLI tools

```bash
#######################################
# GCP: Update Google Cloud CLI tools
#######################################
gcl-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo "Checking for Google Cloud CLI updates..."
  if command -v apt-get > /dev/null && dpkg -l | grep -q "google-cloud-cli"; then
    sudo apt-get update && sudo apt-get install --only-upgrade google-cloud-cli
  else
    gcloud components update
  fi
}
```

#### `gcp-login`

> GCP: Login to user & application default

```bash
#######################################
# GCP: Login to user & application default
#######################################
gcp-login() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud auth login && gcloud auth application-default login
}
```

#### `gcp-login-adc`

> GCP: Login to application default only

```bash
#######################################
# GCP: Login to application default only
#######################################
gcp-login-adc() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud auth application-default login
}
```

#### `gcp-set-project`

> GCP: Switch active project

```bash
#######################################
# GCP: Switch active project
# Arguments:
#   $1 - (Optional) <project_id> to switch to.
#        Pass '-ls' to list available projects.
#        If left blank, opens an interactive fzf menu.
#######################################
gcp-set-project() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [[ "$1" == "-ls" ]]; then
    gcloud projects list --format="table(projectId,name,projectNumber)"
    return 0
  fi

  local project="$1"

  if [ -z "$project" ]; then
    project=$(gcloud projects list --format="value(projectId)" | fzf --prompt="Select GCP Project > ")
    if [ -z "$project" ]; then
      echo "⚠️ Project selection cancelled."
      return 0
    fi
  fi

  gcloud config set project "$project"
}
```

### 📂 GCP: Resources & Services


#### `bq-query`

> GCP: Run standard SQL query in BigQuery

```bash
#######################################
# GCP: Run standard SQL query in BigQuery
# Arguments:
#   $1 - SQL query string (e.g., "SELECT...")
# Outputs:
#   Prints query results table to STDOUT
#######################################
bq-query() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  bq query --use_legacy_sql=false "$1"
}
```

#### `gcl-as-json`

> GCP: Run any gcloud command and output as formatted JSON

```bash
#######################################
# GCP: Run any gcloud command and output as formatted JSON
# Arguments:
#   $@ - gcloud command and arguments
# Outputs:
#   Prints formatted JSON to STDOUT
#######################################
gcl-as-json() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud "$@" --format="json" | jq '.'
}
```

#### `gcp-crf-logs`

> GCP: Tail logs of a Cloud Run Function

```bash
#######################################
# GCP: Tail logs of a Cloud Run Function
# Arguments:
#   $1 - Function Name
#   $2 - Limit (default: 50)
# Outputs:
#   Prints log stream to STDOUT
#######################################
gcp-crf-logs() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local target_function="$1"
  local line_limit="${2:-50}"

  gcloud functions logs read "$target_function" --limit="$line_limit"
}
```

#### `gcp-gar-docker`

> GCP: Configure Docker auth for Artifact Registry

```bash
#######################################
# GCP: Configure Docker auth for Artifact Registry
# Arguments:
#   $1 - Region (e.g., us-central1)
#######################################
gcp-gar-docker() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud auth configure-docker "$1-docker.pkg.dev"
}
```

#### `gcp-get-secret`

> GCP: Read the latest payload of a secret

```bash
#######################################
# GCP: Read the latest payload of a secret
# Arguments:
#   $1 - Secret Name
# Outputs:
#   Prints secret payload string to STDOUT
#######################################
gcp-get-secret() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud secrets versions access latest --secret="$1"
}
```

#### `gcp-iam-show`

> GCP: View IAM policy for the active project

```bash
#######################################
# GCP: View IAM policy for the active project
# Globals:
#   gcl-get-project (Framework Function)
# Outputs:
#   Prints tabular IAM policy bindings to STDOUT
#######################################
gcp-iam-show() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud projects get-iam-policy "$(gcl-get-project)" --format="table(bindings.role, bindings.members)"
}
```

#### `gcp-ps-pull`

> GCP: Pull and auto-ack one message from a Pub/Sub subscription

```bash
#######################################
# GCP: Pull and auto-ack one message from a Pub/Sub subscription
# Arguments:
#   $1 - Subscription Name
# Outputs:
#   Prints the pulled message to STDOUT
#######################################
gcp-ps-pull() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud pubsub subscriptions pull "$1" --auto-ack --limit=1
}
```

### 📂 General System Utilities


#### `mt-alias`

> System: Interactively create or update an alias

```bash
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
    update_name=$(awk -F'\t' '$1 == "alias" { printf "%-24s │ %-20s │ %s\n", $3, $2, $4 }' "$CACHE_DIR/.mt_data.tsv" | fzf --ansi --prompt="Select Alias to Update > " | awk '{print $1}')
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
    tsv_line=$(awk -F'\t' -v n="$alias_name" '$1=="alias" && $3==n {print $2 "|" $4}' "$CACHE_DIR/.mt_data.tsv" | head -n 1)
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
HEADEREOF
  fi
  cat << ALIASEOF >> "$aliases_file"

alias ${alias_name}='${alias_cmd}'
ALIASEOF
  # shellcheck disable=SC1090
  source "$aliases_file"
  mt-refresh-caches > /dev/null 2>&1
  echo -e "${CB_GREEN}🎉 Success! You can now use '${alias_name}'.${C_RESET}"
}
```

#### `mt-top-files`

> System: Display the top largest files in a directory

```bash
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
```

#### `mt-vcs-audit`

> System: Audit VCS root for unorganized files and directories

```bash
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
```

### 📂 Git: Bulk Repository Cloning (mt-clone)


#### `mt-clone`

> Git: Clone every repository in a source-control provider's project

```bash
#######################################
# Git: Clone every repository in a source-control provider's project
# into config.paths.vcs_root_dir/<scope>/<provider>/<workspace>/<project>/,
# skipping any that already exist locally. Shows a plan (repositories
# to clone vs already present), offers an fzf multi-select to exclude
# specific repos from it (e.g. one large repo you don't personally
# need), and asks for confirmation before cloning anything -- all
# skipped if --auto-approve is set. Currently supports
# Bitbucket only -- see clone_wizard.py's PROVIDERS registry to add
# another. Filters (--type/--lang/--from-date/--year/--age) are applied
# client-side against the full project repo list, not via a provider
# query DSL -- if more than one date-ish filter is given, the OLDEST
# (most inclusive) cutoff wins. -i/--wizard runs an interactive flow
# instead (scope/provider/workspace/project prompts, plus a filter menu
# whose language picker is populated from repositories actually
# present) and ignores -s/-p/-w/-pr/filter flags even if also given.
# Usage: mt-clone -s <work|personal> -p <provider> -w <workspace> -pr <project> [filters] [--auto-approve]
#        mt-clone -i [--auto-approve]
# Options:
#   -s, --scope <work|personal>  Top-level VCS_ROOT subdirectory to clone into
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

  local scope="" provider="" raw_workspace="" raw_project="" auto_approve=false do_wizard=false
  local type_filter="" lang_filter="" from_date="" year_filter="" age_filter=""
  local repos_raw

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -i | --wizard)
        do_wizard=true
        shift
        ;;
      -s | --scope)
        scope="${2,,}"
        if [[ "$scope" != "work" && "$scope" != "personal" ]]; then
          echo "mt-clone: --scope must be 'work' or 'personal'" >&2
          return 1
        fi
        shift 2
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
        echo "Usage: mt-clone -s <work|personal> -p <provider> -w <workspace> -pr <project> [-t private|public] [-l language] [-d date] [-y year] [-a days] [--auto-approve] | mt-clone -i" >&2
        return 1
        ;;
    esac
  done

  if [ "$do_wizard" = true ]; then
    __mt_clone_run_wizard || return 1
  else
    if [ -z "$scope" ] || [ -z "$provider" ] || [ -z "$raw_workspace" ] || [ -z "$raw_project" ]; then
      echo -e "${CB_RED}🚨 --scope, --provider, --workspace, and --project are all required.${C_RESET}"
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
  local project_dir="${VCS_ROOT:-$HOME/vcs}/${scope}/${provider}/${sanitized_workspace}/${sanitized_project}"

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
    local want_exclude
    read -r -p "✂️  Exclude specific repositories from this clone? [y/N] " -n 1 want_exclude < /dev/tty || want_exclude="n"
    echo
    if [[ "$want_exclude" =~ ^[Yy]$ ]]; then
      __mt_clone_pick_exclusions "$plan_file"
      __mt_clone_print_plan "$plan_file" "$raw_workspace" "$raw_project" "$project_dir"
      if [ "$MT_CLONE_TO_CLONE" -eq 0 ]; then
        echo -e "${CB_GREEN}✅ Nothing left to clone after exclusions.${C_RESET}"
        rm -f "$plan_file"
        return 0
      fi
    fi
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
```

### 📂 Git: Bulk Repository Updates


#### `mt-bulk-update`

> Git: Bulk-update every local repository under VCS_ROOT -- fetches each

```bash
#######################################
# Git: Bulk-update every local repository under VCS_ROOT -- fetches each
# repo's remote and fast-forwards its local main/master branch to match.
# Pull-only: this never pushes anything, to any branch, ever. A repo
# sitting on a local branch other than its default is left exactly
# where it is -- its uncommitted changes are never touched and it's
# never checked out anywhere else -- and a repo whose default branch has
# diverged from its remote is skipped and reported rather than
# force-merged. Prints a summary table of every repo checked: its
# current branch, whether its default branch was updated, whether that
# current branch has ever been pushed to its remote, and how far ahead/
# behind it is of the (now-updated) default branch.
# Usage: mt-bulk-update [-s work|personal] [-p provider] [-w workspace]
#                       [-pr project] [-b|--bg|--background] [-j|--json]
#        mt-bulk-update --repo <path> [-j|--json]
# Options:
#   -s, --scope <work|personal>   Only update repos under this scope
#   -p, --provider <name>         Only update repos under this provider (work scope only, e.g. bitbucket)
#   -w, --workspace <name>        Only update repos under this workspace (work scope only, e.g. rentokilinitial)
#   -pr, --project <name>         Only update repos under this project (work scope; e.g. cloudconnect groups many repos) or this exact repo (personal scope)
#   --repo <path>                 Update exactly this repo by absolute path, bypassing every other filter
#   -b, --bg, --background        Run as a background job -- see 'mt-jobs' to monitor/view its log (ignored with --repo/--json)
#   -j, --json                    Print results as a JSON array instead of the colored table
#   -h, --help                    Show this help
# Globals:
#   VCS_ROOT
#######################################
mt-bulk-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local scope="" provider="" workspace="" project="" repo_path="" run_bg=false json_mode=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s | --scope)
        scope="${2,,}"
        if [[ "$scope" != "work" && "$scope" != "personal" ]]; then
          echo "mt-bulk-update: --scope must be 'work' or 'personal'" >&2
          return 1
        fi
        shift 2
        ;;
      -p | --provider)
        provider="$2"
        shift 2
        ;;
      -w | --workspace)
        workspace="$2"
        shift 2
        ;;
      -pr | --project)
        project="$2"
        shift 2
        ;;
      --repo)
        repo_path="$2"
        shift 2
        ;;
      -b | --bg | --background)
        run_bg=true
        shift
        ;;
      -j | --json)
        json_mode=true
        shift
        ;;
      *)
        echo "Usage: mt-bulk-update [-s work|personal] [-p provider] [-w workspace] [-pr project] [-b|--background] [-j|--json] | --repo <path> [-j|--json]" >&2
        return 1
        ;;
    esac
  done

  if [ -n "$repo_path" ]; then
    __mt_bulk_update_run_single "$repo_path" "$json_mode"
  elif [ "$run_bg" = true ]; then
    local log_out
    log_out="$LOG_DIR/bulk_update_$(date +%s).log"
    local cmd_str="__mt_bulk_update_run \"$scope\" \"$provider\" \"$workspace\" \"$project\""
    __mt_bg_run "mt-bulk-update" "$log_out" "$cmd_str"
  else
    __mt_bulk_update_run "$scope" "$provider" "$workspace" "$project" "$json_mode"
  fi
}
```

### 📂 Git: Dependency Vulnerability Audit


#### `mt-audit-deps`

> Repo: Run a dependency vulnerability audit for the current directory's

```bash
#######################################
# Repo: Run a dependency vulnerability audit for the current directory's
# project, dispatching to the right tool based on its manifest files --
# npm audit for a package.json, pip-audit for a Python project, OWASP
# dependency-check for a Maven pom.xml. Anything else reports as
# unsupported rather than guessing wrong, since there's no single audit
# tool that covers every build ecosystem the way
# __mt_radar_detect_build_tool's file-presence checks do for detection
# alone. On-demand only (not part of mt-radar --index) since a real audit
# hits a registry/database and can take real time -- from a few seconds
# (npm/pip) up to several minutes on a cold cache (Maven's OWASP
# dependency-check, which builds a local CVE database on first run) --
# too slow to run automatically for every repo on every index pass.
# Usage: mt-audit-deps [-j|--json]
# Options:
#   -j, --json   Print the result as a single JSON object instead of a
#                colorized summary
# Globals:
#   NVD_API_KEY (optional) -- speeds up the Maven branch's first-run CVE
#     database build (see mt-add-nvd-key); works without one, just slower.
#   DEPENDENCY_CHECK_PLUGIN_VERSION -- pinned org.owasp:dependency-check-
#     maven version for the Maven branch (config.yaml's
#     java.dependency_check_plugin_version).
#######################################
mt-audit-deps() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local json_mode=false
  [[ "$1" == "-j" || "$1" == "--json" ]] && json_mode=true

  local tool="" status="unsupported" message="" vulns="null"

  if [ -f "package.json" ]; then
    tool="npm audit"
    if ! command -v npm > /dev/null 2>&1; then
      status="tool-missing"
      message="npm is not installed."
    else
      local raw
      raw=$(npm audit --json 2> /dev/null)
      if echo "$raw" | jq -e '.metadata.vulnerabilities' > /dev/null 2>&1; then
        status="ok"
        vulns=$(echo "$raw" | jq -c '.metadata.vulnerabilities')
      else
        status="error"
        message="npm audit did not return the expected JSON shape."
      fi
    fi
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    tool="pip-audit"
    if ! command -v pip-audit > /dev/null 2>&1; then
      status="tool-missing"
      message="pip-audit is not installed (pip install pip-audit)."
    else
      local raw
      raw=$(pip-audit -f json 2> /dev/null)
      if echo "$raw" | jq -e 'type == "array"' > /dev/null 2>&1; then
        status="ok"
        # pip-audit doesn't categorize findings by severity the way npm
        # audit does -- total is the only honest number to report here.
        local total
        total=$(echo "$raw" | jq '[.[].vulns[]?] | length')
        vulns=$(jq -n --argjson total "$total" '{critical: null, high: null, moderate: null, low: null, info: null, total: $total}')
      else
        status="error"
        message="pip-audit did not return the expected JSON shape."
      fi
    fi
  elif [ -f "pom.xml" ]; then
    tool="OWASP dependency-check"
    if ! command -v mvn > /dev/null 2>&1; then
      status="tool-missing"
      message="Maven is not installed."
    else
      # First run on a repo builds OWASP's local NVD (CVE) database from
      # scratch -- can take several minutes, much longer without an NVD
      # API key (see mt-add-nvd-key) since NVD rate-limits anonymous
      # requests hard. Later runs reuse that cache and are quick.
      [ "$json_mode" = true ] || echo -e "${C_DIM}⏳ Running OWASP dependency-check (first run builds a local CVE database -- can take several minutes)...${C_RESET}"

      local nvd_key_flag=()
      [ -n "${NVD_API_KEY:-}" ] && nvd_key_flag=(-DnvdApiKey="$NVD_API_KEY")

      local report_file="target/dependency-check-report.json"
      rm -f "$report_file"
      local raw mvn_exit
      raw=$(mvn -B -q "org.owasp:dependency-check-maven:${DEPENDENCY_CHECK_PLUGIN_VERSION:-9.2.0}:check" \
        -Dformat=JSON "${nvd_key_flag[@]}" 2>&1)
      mvn_exit=$?

      if [ "$mvn_exit" -ne 0 ]; then
        status="error"
        if echo "$raw" | grep -qE "NVD API Key|NoDataException"; then
          # Confirmed against a real run: without an API key, NVD's own
          # rate limiting doesn't just slow the first-time CVE database
          # build down (as its own docs suggest) -- it can fail it
          # outright with this exact error. Give a direct, actionable
          # message instead of a raw Maven stack trace tail.
          message="OWASP dependency-check couldn't build its local CVE database -- NVD's rate limit blocks this without an API key. Run 'mt-add-nvd-key' (free, see https://nvd.nist.gov/developers/request-an-api-key) and try again."
        else
          message="mvn dependency-check failed: $(echo "$raw" | tail -n 10 | tr '\n' ' ')"
        fi
      elif [ ! -f "$report_file" ]; then
        status="error"
        message="dependency-check ran but produced no report at ${report_file}."
      else
        status="ok"
        vulns=$(jq -c '
          ([.dependencies[]?.vulnerabilities[]?.severity // empty] | map(ascii_upcase)) as $sevs |
          {
            critical: ($sevs | map(select(. == "CRITICAL")) | length),
            high: ($sevs | map(select(. == "HIGH")) | length),
            moderate: ($sevs | map(select(. == "MEDIUM")) | length),
            low: ($sevs | map(select(. == "LOW")) | length),
            info: null,
            total: ($sevs | length)
          }' "$report_file")
        rm -f "$report_file"
      fi
    fi
  else
    message="No supported manifest found in this directory (npm/pip/Maven projects only, for now)."
  fi

  if [ "$json_mode" = true ]; then
    jq -n --arg status "$status" --arg tool "$tool" --arg message "$message" --argjson vulns "$vulns" \
      '{status: $status, tool: (if $tool == "" then null else $tool end), message: (if $message == "" then null else $message end), vulnerabilities: $vulns}'
    return 0
  fi

  case "$status" in
    ok)
      echo -e "${CB_BLUE}🔍 ${tool} results:${C_RESET}"
      echo "$vulns" | jq -r 'to_entries[] | "  \(.key): \(.value // "n/a")"'
      ;;
    tool-missing | unsupported)
      echo -e "${CB_YELLOW}⚠️  ${message}${C_RESET}"
      ;;
    error)
      echo -e "${CB_RED}🚨 ${message}${C_RESET}"
      ;;
  esac
}
```

#### `mt-deps-outdated`

> Repo: Check whether the current directory's project has newer versions

```bash
#######################################
# Repo: Check whether the current directory's project has newer versions
# available for its dependencies -- distinct from mt-audit-deps, which
# checks for known *vulnerabilities*, not version currency. Dispatches by
# manifest file, same pattern as mt-audit-deps: npm outdated for a
# package.json, pip list --outdated for a Python project, and the Maven
# Versions Plugin's three separate display-*-updates goals for a pom.xml
# -- regular <dependencies>, <properties>-defined versions, and the
# <parent> POM itself (easy to miss by hand, since a parent-version bump
# -- e.g. Spring Boot's own starter-parent -- isn't a <dependency> at
# all). On-demand only, same reasoning as mt-audit-deps: a real registry
# lookup takes real time, too slow for every repo on every index pass.
# Usage: mt-deps-outdated [-j|--json]
# Options:
#   -j, --json   Print the result as a single JSON object instead of a
#                colorized summary
# Globals:
#   VERSIONS_PLUGIN_VERSION -- pinned org.codehaus.mojo:versions-maven-
#     plugin version for the Maven branch (config.yaml's
#     java.versions_plugin_version).
#######################################
mt-deps-outdated() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local json_mode=false
  [[ "$1" == "-j" || "$1" == "--json" ]] && json_mode=true

  local tool="" status="unsupported" message="" updates="[]"

  if [ -f "package.json" ]; then
    tool="npm outdated"
    if ! command -v npm > /dev/null 2>&1; then
      status="tool-missing"
      message="npm is not installed."
    else
      # npm outdated exits non-zero when it finds outdated packages -- by
      # design, same as npm audit -- so the JSON shape is what's checked,
      # never the exit code.
      local raw
      raw=$(npm outdated --json 2> /dev/null)
      [ -z "$raw" ] && raw="{}"
      if echo "$raw" | jq -e 'type == "object"' > /dev/null 2>&1; then
        status="ok"
        updates=$(echo "$raw" | jq -c '
          to_entries | map({scope: "dependency", artifact: .key, current: (.value.current // "none"), latest: .value.latest})
        ')
      else
        status="error"
        message="npm outdated did not return the expected JSON shape."
      fi
    fi
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    tool="pip list --outdated"
    local pip_bin="pip"
    command -v pip > /dev/null 2>&1 || pip_bin="pip3"
    if ! command -v "$pip_bin" > /dev/null 2>&1; then
      status="tool-missing"
      message="pip is not installed."
    else
      local raw
      raw=$("$pip_bin" list --outdated --format=json 2> /dev/null)
      if echo "$raw" | jq -e 'type == "array"' > /dev/null 2>&1; then
        status="ok"
        updates=$(echo "$raw" | jq -c '
          map({scope: "dependency", artifact: .name, current: .version, latest: .latest_version})
        ')
      else
        status="error"
        message="pip list --outdated did not return the expected JSON shape."
      fi
    fi
  elif [ -f "pom.xml" ]; then
    tool="Maven Versions Plugin"
    if ! command -v mvn > /dev/null 2>&1; then
      status="tool-missing"
      message="Maven is not installed."
    else
      local vp_version="${VERSIONS_PLUGIN_VERSION:-2.16.2}"
      # Deliberately no -q here (unlike mt-audit-deps's Maven branch) --
      # the plugin's report is [INFO]-level console output, not a file, so
      # quiet mode would suppress the exact lines being parsed.
      #
      # -DprocessDependencyManagement=false restricts display-dependency-
      # updates to what this project's own pom.xml actually declares,
      # rather than every artifact touched by an inherited BOM (e.g.
      # Spring Boot's own starter-parent, or a google-cloud libraries-bom
      # import) -- without it, a project with either pulls in 1000+
      # transitive entries the developer has no direct control over
      # anyway, burying the handful of updates that are actually theirs
      # to act on (confirmed against a real Spring Boot + GCP BOM project:
      # 1108 lines of noise down to 16 real ones).
      local raw mvn_exit
      raw=$(mvn -B -DprocessDependencyManagement=false \
        "org.codehaus.mojo:versions-maven-plugin:${vp_version}:display-dependency-updates" \
        "org.codehaus.mojo:versions-maven-plugin:${vp_version}:display-property-updates" \
        "org.codehaus.mojo:versions-maven-plugin:${vp_version}:display-parent-updates" 2>&1)
      mvn_exit=$?

      if [ "$mvn_exit" -ne 0 ]; then
        status="error"
        message="mvn versions-plugin failed: $(echo "$raw" | tail -n 10 | tr '\n' ' ')"
      else
        status="ok"
        updates=$(__mt_parse_maven_version_updates "$raw")
      fi
    fi
  else
    message="No supported manifest found in this directory (npm/pip/Maven projects only, for now)."
  fi

  if [ "$json_mode" = true ]; then
    jq -n --arg status "$status" --arg tool "$tool" --arg message "$message" --argjson updates "$updates" \
      '{status: $status, tool: (if $tool == "" then null else $tool end), message: (if $message == "" then null else $message end), updates: $updates}'
    return 0
  fi

  case "$status" in
    ok)
      local count
      count=$(echo "$updates" | jq 'length')
      if [ "$count" -eq 0 ]; then
        echo -e "${CB_GREEN}✅ Everything is up to date (${tool}).${C_RESET}"
      else
        echo -e "${CB_BLUE}📦 ${tool} found ${count} update(s):${C_RESET}"
        echo "$updates" | jq -r '.[] | "  [\(.scope)] \(.artifact): \(.current) -> \(.latest)"'
      fi
      ;;
    tool-missing | unsupported)
      echo -e "${CB_YELLOW}⚠️  ${message}${C_RESET}"
      ;;
    error)
      echo -e "${CB_RED}🚨 ${message}${C_RESET}"
      ;;
  esac
}
```

### 📂 Google Style Code Formatting


#### `google-fmt`

> Formats Python, Shell, and Java source according to Google Style Guides.

```bash
#######################################
# Formats Python, Shell, and Java source according to Google Style Guides.
# Uses yapf for Python, shfmt for Shell scripts, and google-java-format
# for Java.
# Outputs:
#   Writes formatting status updates to STDOUT.
# Returns:
#   0 on success.
#######################################
google-fmt() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  echo "🔍 Linting and formatting Python scripts (Ruff)..."
  if command -v ruff > /dev/null 2>&1; then
    ruff check --fix .
    ruff format .
  fi

  echo "🎨 Formatting Python scripts (Google Python Style)..."
  if command -v yapf > /dev/null 2>&1; then
    yapf -r -i --style="{based_on_style: google, column_limit: 88, spaces_before_comment: 2}" .
    echo "✅ Python formatting complete."
  else
    echo "⚠️ 'yapf' not found. Run 'bootstrap' to install it."
  fi

  echo "🎨 Formatting Shell scripts (Google Shell Style Guide)..."
  if command -v shfmt > /dev/null 2>&1; then
    # Google Shell Style Guide: 2-space indents (-i 2), switch case indent (-ci), and space after redirects (-sr)
    shfmt -i 2 -ci -sr -w .
    echo "✅ Shell script formatting complete."
  else
    echo "⚠️ 'shfmt' not found."
  fi

  echo "🎨 Formatting Java source (Google Java Format)..."
  if command -v google-java-format > /dev/null 2>&1; then
    local -a java_files=()
    while IFS= read -r -d '' f; do java_files+=("$f"); done < <(
      find . -name "*.java" -not -path "*/target/*" -not -path "*/build/*" -print0 2> /dev/null
    )
    if [ "${#java_files[@]}" -gt 0 ]; then
      google-java-format --replace "${java_files[@]}"
      echo "✅ Java formatting complete (${#java_files[@]} file(s))."
    else
      echo "ℹ️  No .java files found."
    fi
  else
    echo "⚠️ 'google-java-format' not found. Run 'bootstrap' to install it."
  fi
}
```

### 📂 Helm (Kubernetes Package Manager) Tools


#### `helm-install`

> Helm: Install a chart as a new release in the current namespace

```bash
#######################################
# Helm: Install a chart as a new release in the current namespace
# Usage: helm-install [release] [chart]
# Arguments:
#   $1 - (Optional) Release name. Defaults to the chart's basename.
#   $2 - (Optional) Chart reference (e.g. bitnami/nginx). Prompted if
#        omitted.
#######################################
helm-install() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local release="$1" chart="$2"
  [ -z "$chart" ] && read -r -p "Chart (e.g. bitnami/nginx): " chart < /dev/tty
  if [ -z "$chart" ]; then
    echo -e "${CB_YELLOW}⚠️  A chart reference is required.${C_RESET}"
    return 1
  fi

  if [ -z "$release" ]; then
    local default_release="${chart##*/}"
    read -r -p "Release name [${default_release}]: " release < /dev/tty
    release="${release:-$default_release}"
  fi

  echo -e "${CB_BLUE}🔄 Installing ${chart} as ${release}...${C_RESET}"
  helm install "$release" "$chart" && echo -e "${CB_GREEN}✅ Installed ${release}.${C_RESET}"
}
```

#### `helm-list`

> Helm: List releases in a clean table

```bash
#######################################
# Helm: List releases in a clean table
# Usage: helm-list [-A] [-j|--json]
# Options:
#   -A           Show releases across all namespaces
#   -j, --json   Print releases via helm's own full JSON output (always
#                all-namespaces, regardless of -A) instead of the table
#######################################
helm-list() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local all_namespaces=false
  local json_mode=false
  for arg in "$@"; do
    case "$arg" in
      -A) all_namespaces=true ;;
      -j | --json) json_mode=true ;;
    esac
  done

  if [ "$json_mode" = true ]; then
    helm list --all-namespaces -o json
  elif [ "$all_namespaces" = true ]; then
    helm list --all-namespaces
  else
    helm list
  fi
}
```

#### `helm-repo`

> Helm: Manage chart repositories -- list/add/update, mirroring

```bash
#######################################
# Helm: Manage chart repositories -- list/add/update, mirroring
# docker-daemon's subcommand-dispatch style since these are all verbs on
# the one "repo" noun rather than separate commands.
# Usage: helm-repo [list|add [name] [url]|update]
# Arguments:
#   $1 - Subcommand: list (default), add, or update
#   $2 - (add only) Repo name. Prompted if omitted.
#   $3 - (add only) Repo URL. Prompted if omitted.
#######################################
helm-repo() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local action="${1:-list}"
  case "$action" in
    list)
      helm repo list
      ;;
    add)
      local name="$2" url="$3"
      [ -z "$name" ] && read -r -p "Repo name: " name < /dev/tty
      [ -z "$url" ] && read -r -p "Repo URL: " url < /dev/tty
      if [ -z "$name" ] || [ -z "$url" ]; then
        echo -e "${CB_YELLOW}⚠️  Repo name and URL are both required.${C_RESET}"
        return 1
      fi
      helm repo add "$name" "$url" && helm repo update "$name" > /dev/null && echo -e "${CB_GREEN}✅ Added and refreshed repo: ${name}.${C_RESET}"
      ;;
    update)
      helm repo update && echo -e "${CB_GREEN}✅ Repos refreshed.${C_RESET}"
      ;;
    *)
      echo "Usage: helm-repo [list|add <name> <url>|update]" >&2
      return 1
      ;;
  esac
}
```

#### `helm-rollback`

> Helm: Roll back a release to a previous revision, always confirmed via

```bash
#######################################
# Helm: Roll back a release to a previous revision, always confirmed via
# the destructive-op guard first since a bad rollback target can take a
# release backward unexpectedly.
# Usage: helm-rollback
#######################################
helm-rollback() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local release
  release=$(helm list --short 2> /dev/null | fzf --prompt="⎈  Select Release to Roll Back > " --height=~10 --layout=reverse --border)
  if [ -z "$release" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi

  helm history "$release"

  local revision
  read -r -p "Revision to roll back to: " revision < /dev/tty
  if ! [[ "$revision" =~ ^[0-9]+$ ]]; then
    echo -e "${CB_RED}🚨 Revision must be a positive integer.${C_RESET}"
    return 1
  fi

  __k8s_confirm_destructive "Rolling back ${release} to revision ${revision}." || {
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 1
  }

  helm rollback "$release" "$revision" && echo -e "${CB_GREEN}✅ ${release} rolled back to revision ${revision}.${C_RESET}"
}
```

#### `helm-search`

> Helm: Search configured repos for a chart

```bash
#######################################
# Helm: Search configured repos for a chart
# Usage: helm-search [term]
# Arguments:
#   $1 - (Optional) Search term. Prompted if omitted.
#######################################
helm-search() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local term="$1"
  [ -z "$term" ] && read -r -p "Search term: " term < /dev/tty
  if [ -z "$term" ]; then
    echo -e "${CB_YELLOW}⚠️  No search term provided.${C_RESET}"
    return 0
  fi

  helm search repo "$term"
}
```

#### `helm-status`

> Helm: Dashboard summarizing helm's view of the active context -- CLI

```bash
#######################################
# Helm: Dashboard summarizing helm's view of the active context -- CLI
# version, release count across all namespaces, and configured repo
# count.
# Usage: helm-status [-j|--json]
# Options:
#   -j, --json   Print the same fields as one JSON object instead of the
#                colorized dashboard
#######################################
helm-status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1
  local json_mode=false
  [[ "$1" == "-j" || "$1" == "--json" ]] && json_mode=true

  local ctx version releases repos
  ctx=$(kubectl config current-context 2> /dev/null)
  version=$(helm version --short 2> /dev/null)
  releases=$(helm list -A --short 2> /dev/null | wc -l | tr -d ' ')
  repos=$(helm repo list -o json 2> /dev/null | jq 'length' 2> /dev/null)

  if [ "$json_mode" = true ]; then
    jq -n --arg context "$ctx" --arg version "${version:-unknown}" \
      --argjson releases "${releases:-0}" --argjson repos "${repos:-0}" \
      '{context: $context, version: $version, releases: $releases, repos: $repos}'
    return
  fi

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}              HELM STATUS                                  ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_CYAN}Context   :${C_RESET} ${ctx}"
  echo -e "${CB_CYAN}Version   :${C_RESET} ${version:-unknown}"
  echo -e "${CB_CYAN}Releases  :${C_RESET} ${releases:-0} (all namespaces)"
  echo -e "${CB_CYAN}Repos     :${C_RESET} ${repos:-0}"
}
```

#### `helm-uninstall`

> Helm: Uninstall a release, always confirmed via the destructive-op

```bash
#######################################
# Helm: Uninstall a release, always confirmed via the destructive-op
# guard first -- the one genuinely irreversible action in this file.
# Usage: helm-uninstall [<release> [-n <namespace>]]
# Arguments:
#   $1 - (Optional) Release name. Omit to fzf-pick from the current
#        namespace interactively; given explicitly, skips both the
#        picker and the fzf dependency entirely (e.g. for a caller that
#        already knows the exact release, like the VS Code companion's
#        own confirmation dialog).
# Options:
#   -n, --namespace <ns>   Release's namespace, if not the current one
#                          (only meaningful with an explicit release name)
#######################################
helm-uninstall() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local release="" namespace=""
  if [[ -n "$1" && "$1" != "-n" && "$1" != "--namespace" ]]; then
    release="$1"
    shift
  fi
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -n | --namespace)
        namespace="$2"
        shift
        ;;
    esac
    shift
  done

  if [ -z "$release" ]; then
    release=$(helm list --short 2> /dev/null | fzf --prompt="⎈  Select Release to Uninstall > " --height=~10 --layout=reverse --border)
    if [ -z "$release" ]; then
      echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  __k8s_confirm_destructive "About to uninstall release ${release}." || {
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 1
  }

  if [ -n "$namespace" ]; then
    helm uninstall "$release" -n "$namespace" && echo -e "${CB_GREEN}✅ Uninstalled ${release}.${C_RESET}"
  else
    helm uninstall "$release" && echo -e "${CB_GREEN}✅ Uninstalled ${release}.${C_RESET}"
  fi
}
```

#### `helm-upgrade`

> Helm: Upgrade an existing release to a new chart/version -- the

```bash
#######################################
# Helm: Upgrade an existing release to a new chart/version -- the
# release's current chart is shown as a hint only, since Helm doesn't
# retain the repo/chart shorthand originally used to install it, so it
# can't be safely reused as a default.
# Usage: helm-upgrade
#######################################
helm-upgrade() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local selection
  selection=$(helm list -o json 2> /dev/null | jq -r '.[] | "\(.name)\t\(.chart)"' 2> /dev/null | fzf --prompt="⎈  Select Release to Upgrade > " --height=~10 --layout=reverse --border --with-nth=1 --delimiter='\t')
  if [ -z "$selection" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi

  local release current_chart chart
  release=$(echo "$selection" | cut -f1)
  current_chart=$(echo "$selection" | cut -f2)
  echo -e "${CB_CYAN}Current chart:${C_RESET} ${current_chart}"

  read -r -p "Chart to upgrade to (repo/chart): " chart < /dev/tty
  if [ -z "$chart" ]; then
    echo -e "${CB_YELLOW}⚠️  A chart reference is required.${C_RESET}"
    return 1
  fi

  helm upgrade "$release" "$chart" && echo -e "${CB_GREEN}✅ Upgraded ${release} to ${chart}.${C_RESET}"
}
```

#### `helm-values`

> Helm: Show the user-supplied values for a release

```bash
#######################################
# Helm: Show the user-supplied values for a release
# Usage: helm-values
#######################################
helm-values() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local release
  release=$(helm list --short 2> /dev/null | fzf --prompt="⎈  Select Release > " --height=~10 --layout=reverse --border)
  if [ -z "$release" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi

  helm get values "$release"
}
```

### 📂 Homelab: mst-homelab-media-stack Integration


#### `mt-homelab-backup`

> Homelab: Archive the media stack's per-service config/state

```bash
#######################################
# Homelab: Archive the media stack's per-service config/state
# (./config/<service>/, git-ignored -- Sonarr/Radarr/Bazarr/Jellyfin/
# Seerr/Homepage/Tailscale credentials and settings) to a timestamped
# zip, since none of it lives in the stack's own repo.
# Usage: mt-homelab-backup
# Outputs:
#   Path to the created archive
#######################################
mt-homelab-backup() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local backup_dir="$HOME/backups/homelab-media-stack"
  mkdir -p "$backup_dir"

  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local archive="$backup_dir/config_${timestamp}.zip"

  echo -e "${CB_BLUE}📦 Backing up ./config to ${archive}...${C_RESET}"
  # Built from an explicit file list (regular files/symlinks only)
  # rather than 'zip -r' directly -- qBittorrent's config directory
  # holds a live Unix socket (ipc-socket) while the container is
  # running, which zip can't read and aborts on with an I/O error;
  # 'find -type f' never selects it in the first place.
  if (cd "$_HOMELAB_STACK_DIR" && find config \( -type f -o -type l \) 2> /dev/null | zip -q "$archive" -@); then
    local size
    size=$(du -h "$archive" | cut -f1)
    echo -e "${CB_GREEN}✅ Backup saved: ${archive} (${size})${C_RESET}"
  else
    echo -e "${CB_RED}🚨 Backup failed.${C_RESET}" >&2
    return 1
  fi
}
```

#### `mt-homelab-cd`

> Homelab: cd into the media stack's own repo directory.

```bash
#######################################
# Homelab: cd into the media stack's own repo directory.
# Usage: mt-homelab-cd
# Globals:
#   _HOMELAB_STACK_DIR
#######################################
mt-homelab-cd() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  cd "$_HOMELAB_STACK_DIR" || return 1
}
```

#### `mt-homelab-logs`

> Homelab: Tail logs for the media stack -- every container by default,

```bash
#######################################
# Homelab: Tail logs for the media stack -- every container by default,
# or one service with --service (see mt-homelab-status for names).
# Usage: mt-homelab-logs [-s|--service <name>] [-f|--follow]
# Options:
#   -s, --service <name>   Only show logs for this compose service
#   -f, --follow            Stream new log lines instead of a fixed 200-line snapshot
#   -h, --help              Show this help menu
#######################################
mt-homelab-logs() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local service="" follow=false
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -s | --service)
        service="$2"
        shift 2
        ;;
      -f | --follow)
        follow=true
        shift
        ;;
      *)
        echo "Usage: mt-homelab-logs [-s|--service <name>] [-f|--follow]" >&2
        return 1
        ;;
    esac
  done

  local -a args=(logs --tail 200)
  [[ "$follow" == true ]] && args+=(-f)
  [[ -n "$service" ]] && args+=("$service")
  __homelab_compose "${args[@]}"
}
```

#### `mt-homelab-restart`

> Homelab: Restart every media stack container in place.

```bash
#######################################
# Homelab: Restart every media stack container in place.
# Usage: mt-homelab-restart
#######################################
mt-homelab-restart() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1
  echo -e "${CB_BLUE}🎬 Restarting the media stack...${C_RESET}"
  __homelab_compose restart
}
```

#### `mt-homelab-setup`

> Homelab: Re-run the media stack's own configuration wizard

```bash
#######################################
# Homelab: Re-run the media stack's own configuration wizard
# (scripts/setup.sh) -- safe to re-run any time, it checks each app's
# current state first and only fills in what's missing.
# Usage: mt-homelab-setup
#######################################
mt-homelab-setup() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1
  (cd "$_HOMELAB_STACK_DIR" && ./scripts/setup.sh)
}
```

#### `mt-homelab-start`

> Homelab: Bring the media stack up (creating containers on first run,

```bash
#######################################
# Homelab: Bring the media stack up (creating containers on first run,
# starting existing ones otherwise), starting the Docker daemon first if
# it isn't already running.
# Usage: mt-homelab-start
#######################################
mt-homelab-start() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1
  echo -e "${CB_BLUE}🎬 Starting the media stack...${C_RESET}"
  __homelab_compose up -d
}
```

#### `mt-homelab-status`

> Homelab: Show docker compose's status table (state, health, ports) for

```bash
#######################################
# Homelab: Show docker compose's status table (state, health, ports) for
# every media stack container.
# Usage: mt-homelab-status
#######################################
mt-homelab-status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __homelab_compose ps
}
```

#### `mt-homelab-stop`

> Homelab: Stop every media stack container without removing them --

```bash
#######################################
# Homelab: Stop every media stack container without removing them --
# containers/volumes/networks are left in place for a fast restart.
# Usage: mt-homelab-stop
#######################################
mt-homelab-stop() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  echo -e "${CB_BLUE}🎬 Stopping the media stack...${C_RESET}"
  __homelab_compose stop
}
```

#### `mt-homelab-update`

> Homelab: Pull the latest image for every media stack service, recreate

```bash
#######################################
# Homelab: Pull the latest image for every media stack service, recreate
# any containers whose image changed, then prune the now-unused old
# images.
# Usage: mt-homelab-update
#######################################
mt-homelab-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1
  echo -e "${CB_BLUE}🎬 Pulling latest images...${C_RESET}"
  __homelab_compose pull || return 1
  echo -e "${CB_BLUE}🎬 Recreating containers with updated images...${C_RESET}"
  __homelab_compose up -d
  echo -e "${CB_BLUE}🧹 Pruning old images...${C_RESET}"
  docker image prune -f
}
```

#### `mt-homelab-web`

> Homelab: Open one of the media stack's service webpages (or its

```bash
#######################################
# Homelab: Open one of the media stack's service webpages (or its
# landing page, if none is given) in the default browser -- locally by
# default, or over Tailscale with --remote. Checks the stack is actually
# running first (offering to start it if not) and, with --remote, that
# this machine is connected to Tailscale (attempting to connect if not).
# Usage: mt-homelab-web [-s|--service <name>] [--remote]
# Options:
#   -s, --service <name>   Which service to open (qbittorrent, prowlarr,
#                          sonarr, radarr, bazarr, jellyfin, dovi-convert,
#                          seerr, status) -- omit for the landing page
#   --remote                Use the stack's Tailscale MagicDNS URL instead
#                          of its LAN address (only some services are
#                          exposed this way -- see tailscale/serve-config.json)
#   -h, --help              Show this help menu
# Returns:
#   1 if an unknown --service value is given, the stack isn't running
#   and the user declines to start it, or the URL can't be resolved
#   (see __homelab_resolve_local_url/__homelab_resolve_remote_url)
#######################################
mt-homelab-web() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local service="" remote=false
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -s | --service)
        service="$2"
        shift 2
        ;;
      --remote)
        remote=true
        shift
        ;;
      *)
        echo "Usage: mt-homelab-web [-s|--service <name>] [--remote]" >&2
        return 1
        ;;
    esac
  done

  if [[ -n "$service" && -z "${_HOMELAB_SERVICES[$service]:-}" ]]; then
    echo "Error: unknown service '$service'. Known services: ${_HOMELAB_SERVICE_KEYS[*]}" >&2
    return 1
  fi

  __homelab_ensure_stack_running || return 1

  local url
  if [[ "$remote" == true ]]; then
    url=$(__homelab_resolve_remote_url "$service") || return 1
  else
    url=$(__homelab_resolve_local_url "$service") || return 1
  fi

  echo -e "${CB_GREEN}🌐 Opening ${url}${C_RESET}"
  __open_url "$url"
}
```

### 📂 Homelab - Tab Completion


#### `mt-homelab-menu`

> Homelab: Interactive menu for every media stack management command --

```bash
#######################################
# Homelab: Interactive menu for every media stack management command --
# lifecycle (start/stop/restart/status/logs/update/backup), the setup
# wizard, opening a service webpage (local or --remote), and jumping to
# the stack's own directory.
# Usage: mt-homelab-menu
#######################################
mt-homelab-menu() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local choice
  choice=$(
    printf '%s\n' \
      "▶️  Start stack" \
      "⏹️  Stop stack" \
      "🔁 Restart stack" \
      "📊 Status" \
      "📜 Logs" \
      "⬆️  Update (pull + recreate)" \
      "📦 Backup config" \
      "🧙 Run setup wizard" \
      "🌐 Open a service webpage" \
      "📂 cd to stack directory" |
      fzf --prompt="Homelab > "
  )

  case "$choice" in
    "▶️  Start stack") mt-homelab-start ;;
    "⏹️  Stop stack") mt-homelab-stop ;;
    "🔁 Restart stack") mt-homelab-restart ;;
    "📊 Status") mt-homelab-status ;;
    "📜 Logs") __homelab_menu_logs ;;
    "⬆️  Update (pull + recreate)") mt-homelab-update ;;
    "📦 Backup config") mt-homelab-backup ;;
    "🧙 Run setup wizard") mt-homelab-setup ;;
    "🌐 Open a service webpage") __homelab_menu_web ;;
    "📂 cd to stack directory") mt-homelab-cd ;;
    *) echo "🛑 Cancelled." ;;
  esac
}
```

### 📂 Infrastructure as Code


#### `tf-val-all`

> Terraform: Recursively validate and scan all Terraform directories

```bash
#######################################
# Terraform: Recursively validate and scan all Terraform directories
#######################################
tf-val-all() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local threads="${MAX_PARALLEL_THREADS:-8}"

  # shellcheck disable=SC2016  # inner bash -c script intentionally uses its own $1, passed via the trailing _ "{}" args
  find terraform/ -type f -name "*.tf" -exec dirname {} \; | sort -u | xargs -I {} -P "$threads" bash -c '
        echo -e "\n🔍 Validating $1..."
        terraform -chdir="$1" init -backend=false > /dev/null 2>&1
        if terraform -chdir="$1" validate; then
            echo -e "🛡️ Scanning $1 with Checkov..."
            checkov -d "$1" --framework terraform --quiet
        else
            echo -e "🚨 Validation failed for $1"
        fi
    ' _ "{}"
}
```

### 📂 LLM Context & Export Utilities


#### `mt-copy`

> LLM: Copy a file or directory tree to clipboard with headers and extension filters

```bash
#######################################
# LLM: Copy a file or directory tree to clipboard with headers and extension filters
# Usage: mt-copy [-e <extensions>] <file-or-directory>
#######################################
mt-copy() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local ext_list="" target=""
  local OPTIND opt
  while getopts "e:" opt; do
    case ${opt} in
      e) ext_list="$OPTARG" ;;
      *)
        echo "Usage: mt-copy [-e <extensions>] <file-or-directory>" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  target="${1:-.}"
  if [ ! -e "$target" ]; then
    echo -e "${CB_RED}🚨 Error: '$target' missing.${C_RESET}"
    return 1
  fi

  local clip_cmd=""
  if command -v clip.exe > /dev/null 2>&1; then
    clip_cmd="clip.exe"
  elif command -v pbcopy > /dev/null 2>&1; then
    clip_cmd="pbcopy"
  elif command -v xclip > /dev/null 2>&1; then
    clip_cmd="xclip -selection clipboard"
  else
    echo "🚨 No clipboard utility."
    return 1
  fi

  echo -e "${CB_BLUE}🔍 Scanning '$target'...${C_RESET}"

  local temp_file
  temp_file=$(mktemp)

  local blocklist_regex="${EXPORT_BLOCKLIST:-(secret|token|credential|pass|key|rsa|env|lock\.hcl|__pycache__)}"

  local filter_ext=".*"
  if [ -n "$ext_list" ]; then
    local ext_fmt
    ext_fmt=$(echo "$ext_list" | sed 's/,/|/g; s/ //g')
    filter_ext="\.(${ext_fmt})$"
    echo -e "${C_DIM}   (Filtering for: $ext_list)${C_RESET}"
  fi

  local prune_dirs=(-name .git -o -name node_modules -o -name .terraform -o -name __pycache__ -o -name .venv)

  if [ -d "$target" ]; then
    find "$target" -type d \( "${prune_dirs[@]}" \) -prune -o -type f -print | grep -E -v "$blocklist_regex" | grep -Ei "$filter_ext" | while IFS= read -r file; do
      if file -b --mime-encoding "$file" | grep -qv "binary"; then
        echo -e "\n==> $file <==" >> "$temp_file"
        cat "$file" >> "$temp_file"
      fi
    done
  elif [ -f "$target" ]; then
    echo -e "==> $target <==" >> "$temp_file"
    cat "$target" >> "$temp_file"
  fi

  local bytes
  bytes=$(wc -c < "$temp_file")
  if [ "$bytes" -eq 0 ]; then
    echo -e "${CB_YELLOW}⚠️ Nothing copied.${C_RESET}"
  else
    eval "$clip_cmd" < "$temp_file"
    local lines
    lines=$(wc -l < "$temp_file")
    echo -e "${CB_GREEN}✅ Copied $lines lines to clipboard!${C_RESET}"
  fi
  rm -f "$temp_file"
}
```

#### `mt-export`

> LLM: Export codebase to text/zip for LLM context window using dynamic schemas

```bash
#######################################
# LLM: Export codebase to text/zip for LLM context window using dynamic schemas
# Usage: mt-export [-d dir] [-s schema] [-e folder[,folder...]] [-x ext[,ext...]] [-z] [-q] [-p] [-v] [-i] [-j]
# Options:
#   -d, --dir <path>     Target directory to export (default: current directory)
#   -s, --schema <name>  Export schema to apply (default, terraform, shell, python, springboot, cloudrun)
#   -e, --exclude <folder>[,<folder>...]  Extra folder/file path(s) to exclude, on top of
#                        the schema's own exclude_patterns and EXPORT_BLOCKLIST
#                        (repeatable, and/or comma-separated; matched anywhere in
#                        a file's path, e.g. -e vendor,test-fixtures)
#   -x, --exclude-ext <ext>[,<ext>...]  Extra file extension(s) to exclude (e.g. log,tmp,map),
#                        matched only at the end of a file's name -- unlike -e, this
#                        excludes an extension everywhere it appears, not one specific path
#   -z, --zip            Compress output into a .zip file
#   -q, --quiet          Do not automatically open the output directory
#   -p, --plan           Dry-run: show estimated size and included files, prompt to proceed
#   -v, --verbose        Show detailed terraform-style plan of inclusions/exclusions
#   -i, --interactive    Open an interactive menu to adjust export files, format, schema, and exclusions
#   -j, --json           Headless JSON output, for a caller with no /dev/tty to prompt on
#                        (e.g. the VS Code extension's export wizard). Combined with
#                        --plan, prints one JSON plan object and exits without writing
#                        anything -- no prompts, not even the file-count warning.
#                        Without --plan, runs the export for real and prints a JSON
#                        result object instead of the colorized summary.
#######################################
mt-export() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local target_dir="."
  local schema_query="default"
  local user_exclude=""
  local exclude_ext=""
  local zip_out=false
  local quiet_mode=false
  local plan_mode=false
  local verbose_mode=false
  local interactive_mode=false
  local json_mode=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -d | --dir)
        target_dir="$2"
        shift
        ;;
      -s | --schema)
        schema_query="$2"
        shift
        ;;
      -e | --exclude)
        user_exclude="${user_exclude:+$user_exclude,}$2"
        shift
        ;;
      -x | --exclude-ext)
        exclude_ext="${exclude_ext:+$exclude_ext,}$2"
        shift
        ;;
      -z | --zip) zip_out=true ;;
      -q | --quiet) quiet_mode=true ;;
      -p | --plan) plan_mode=true ;;
      -v | --verbose) verbose_mode=true ;;
      -i | --interactive) interactive_mode=true ;;
      -j | --json) json_mode=true ;;
      *) target_dir="$1" ;;
    esac
    shift
  done

  if [ ! -d "$target_dir" ]; then
    echo -e "${CB_RED}🚨 Error: Directory '$target_dir' not found.${C_RESET}"
    return 1
  fi

  local schemas_dir="$HOME/.bash.d/config/export/schemas"
  local schema_file=""
  local s_name="Code Export"
  local s_inc=".*"
  local s_exc=""

  local tmp_file="/tmp/mt_export_${RANDOM}.txt"
  local file_list="/tmp/mt_export_files_${RANDOM}.txt"
  local all_files="/tmp/mt_export_all_${RANDOM}.txt"

  local date_prefix
  date_prefix=$(date +"%Y%m%d")

  local safe_dir_name
  safe_dir_name=$(basename "$(realpath "$target_dir")" | tr '.' '_')

  local dest_dir="${EXPORT_DIR:-/tmp/exports}/${safe_dir_name}"
  mkdir -p "$dest_dir"
  local out_ext="txt"
  local v_num=1
  local base_out_name=""

  __mt_export_calc_output_name
  __mt_export_build_file_lists

  local __mt_export_aborted=false
  if [ "$interactive_mode" = true ]; then
    __mt_export_interactive_menu
    [ "$__mt_export_aborted" = true ] && return 0
  elif [ "$plan_mode" = true ]; then
    if [ "$json_mode" = true ]; then
      __mt_export_print_plan_json
      rm -f "$tmp_file" "$file_list" "$all_files"
      return 0
    fi
    __mt_export_plan_mode
    [ "$__mt_export_aborted" = true ] && return 0
  fi

  __mt_export_check_file_count_guards || return 1

  if [ "$plan_mode" = false ] && [ "$interactive_mode" = false ] && [ "$json_mode" = false ]; then
    echo -e "${CB_BLUE}📦 Running: $s_name${C_RESET}"
  fi

  __mt_export_write_context_file
  __mt_export_finalize
}
```

#### `mt-export-cleanup`

> LLM: Safely remove stale mt-export output from EXPORT_DIR

```bash
#######################################
# LLM: Safely remove stale mt-export output from EXPORT_DIR
# Usage: mt-export-cleanup [-f] [-q] [-b] [-B] [-i] [target_dir]
# Options:
#   -f, --force        Skip the pre-flight table and confirmation prompt
#   -q, --quiet        Suppress terminal output (implies --force)
#   -b, --backup       Zip each target directory to BACKUP_DIR before
#                      deleting (reuses mt-backup); a failed backup skips
#                      deletion for that directory only
#   -B, --background   Run as a background job (implies force and quiet);
#                      track and view its result via mt-jobs -i
#   -i, --interactive  Pick a target directory and toggle flags via fzf
#   target_dir         Optional: scope to one EXPORT_DIR subdirectory
#                      (name or path; defaults to all of EXPORT_DIR)
# Globals:
#   EXPORT_DIR, AUTO_CLEANUP_DAYS, LOG_DIR
#######################################
mt-export-cleanup() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local force=false quiet=false backup=false background=false interactive=false
  local target=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -f | --force) force=true ;;
      -q | --quiet)
        quiet=true
        force=true
        ;;
      -b | --backup) backup=true ;;
      -B | --background) background=true ;;
      -i | --interactive) interactive=true ;;
      -*)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
      *) target="$1" ;;
    esac
    shift
  done

  if [ "$interactive" = true ] && [ "$background" = true ]; then
    echo -e "${CB_RED}🚨 Error: --interactive and --background cannot be combined.${C_RESET}"
    return 1
  fi

  local export_dir="${EXPORT_DIR:-/tmp/exports}"

  if [ "$interactive" = true ]; then
    __mt_export_cleanup_interactive
    return $?
  fi

  if [ "$background" = true ]; then
    force=true
    quiet=true
    local log_out
    log_out="$LOG_DIR/export_cleanup_$(date +%s).log"
    local cmd_str
    printf -v cmd_str '__mt_export_cleanup_run %q %q %q %q %q %q' \
      "$export_dir" "$target" "$force" "$quiet" "$backup" "$background"
    __mt_bg_run "mt-export-cleanup" "$log_out" "$cmd_str"
    return 0
  fi

  __mt_export_cleanup_run "$export_dir" "$target" "$force" "$quiet" "$backup" "$background"
}
```

### 📂 Master Tag List


#### `find-dynamic`

> System: Search indexed videos by tag(s), resolution tier(s),

```bash
#######################################
# System: Search indexed videos by tag(s), resolution tier(s),
# orientation, length range, datarate range, filename text, and/or
# date(s) using dynamic PowerShell Windows Search parameters instead of
# a static YAML profile. Comma-separated --tag/--res values are OR'd
# together by the underlying PowerShell module (any listed tag/tier
# matches); --orientation, when combined with --res, narrows each
# selected tier down to just that orientation instead of OR-ing both.
# --date-created and --today/--this-week/--this-month/--this-year all
# constrain the SAME underlying property, so at most one of them may be
# given. Also aliased as find-<tag> for every tag in the Multi-Tag
# Aliases block below, each pre-filling --tag.
# Usage: find-dynamic [--tag <tag>[,<tag>...]] [--tag-logic <and|or>] [--all-tags | --all-videos] [--res <res>[,<res>...]] [--orientation <l|p>] [--len-min <mm:ss>] [--len-max <mm:ss>] [--rate-min <mb>] [--rate-max <mb>] [--filename <text>] [--exclude-folder <pattern>[,<pattern>...]] [--date <DD-MM-YYYY>] [--date-created <DD-MM-YYYY> | --today | --this-week | --this-month | --this-year] [--scope <scope>] [--gui]
# Options:
#   --tag <tag>[,<tag>...]    Filter by one or more filename tags (default: OR logic -- any
#                             match; see --tag-logic to require every tag instead)
#   --tag-logic <and|or>      With multiple --tag values: "and" requires every tag, "or" (the
#                             default) matches any one of them. Ignored with 0-1 tags or --all-tags
#   --all-tags                Catch-all: match a video carrying ANY tag (a single wildcard
#                             clause, not one per known tag -- cheap regardless of filters stacked with it)
#   --all-videos              No tag filter at all -- matches tagged and untagged videos alike.
#                             This is also what omitting --tag/--all-tags entirely already does;
#                             --all-videos just makes that choice explicit (e.g. in a saved
#                             find-save profile) instead of looking like a forgotten filter.
#                             Conflicts with --tag/--all-tags.
#   --res <res>[,<res>...]    Filter by one or more resolution tiers (OR logic) -- sd (<720p), 720p, 1080p, 4k, 4k+
#   --orientation <l|p>       Landscape (l) or portrait (p). Omit to match either orientation
#   --len-min <mm:ss>         Only videos at least this long
#   --len-max <mm:ss>         Only videos at most this long
#   --rate-min <mb>           Only videos with a data rate at least this many Mbps
#   --rate-max <mb>           Only videos with a data rate at most this many Mbps
#   --filename <text>         Free-text filename substring search
#   --exclude-folder <pattern>[,<pattern>...]  Exclude results under any matching folder path
#                             (repeatable; wildcard * supported, e.g. E:\Backups\*)
#   --date <DD-MM-YYYY>       Filter on the file's general Date property
#   --date-created <DD-MM-YYYY>  Filter on the file's Date Created property (exact day)
#   --today                   Quick filter: Date Created is today
#   --this-week               Quick filter: Date Created is this week
#   --this-month              Quick filter: Date Created is this month
#   --this-year               Quick filter: Date Created is this year
#   --scope <scope>           Windows Library to search (default: all) --
#                             all, no_ts_bin, no_bin, no_of_ts_bin, no_ts, no_of
#   --gui                     Open the results directly in File Explorer instead of printing the query
#                             (stacking many --tag/--exclude-folder values can still exceed
#                             Explorer's URI length limit; if so this fails with a clear error
#                             rather than opening nothing silently)
#   -h, --help                Show this help menu
# Returns:
#   1 if an unknown parameter, an invalid --orientation/--len-*/--rate-*/
#   --date*value, or more than one Date Created filter, is passed
# Outputs:
#   The AQS query text, exactly as you'd type it into Explorer's own search
#   box (unless --gui is set, which opens it directly instead of printing it)
#######################################
find-dynamic() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  # Captured before the parsing loop below consumes $@ via shift, so
  # find-menu/find-history/find-save can log/replay the exact flags this
  # was invoked with, however it was invoked (typed directly, an alias,
  # or built interactively).
  local -a __fd_orig_args=("$@")

  local tag=""
  local tag_logic="or"
  local all_tags=""
  local all_videos=""
  local scope="all"
  local res=""
  local orientation=""
  local len_min=""
  local len_max=""
  local rate_min=""
  local rate_max=""
  local filename=""
  local exclude_folder=""
  local date_val=""
  local date_created=""
  local date_created_flag=""
  local gui=""

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --tag)
        tag="$2"
        shift
        ;;
      --tag-logic)
        tag_logic="${2,,}"
        if [[ "$tag_logic" != "and" && "$tag_logic" != "or" ]]; then
          echo "Error: --tag-logic must be 'and' or 'or', got '$2'." >&2
          return 1
        fi
        shift
        ;;
      --all-tags) all_tags="1" ;;
      --all-videos) all_videos="1" ;;
      --scope)
        scope="$2"
        shift
        ;;
      --res)
        res="$2"
        shift
        ;;
      --orientation)
        orientation="$2"
        shift
        ;;
      --len-min)
        len_min=$(__mmss_to_seconds "$2") || return 1
        shift
        ;;
      --len-max)
        len_max=$(__mmss_to_seconds "$2") || return 1
        shift
        ;;
      --rate-min)
        rate_min=$(__validate_mbps "$2") || return 1
        shift
        ;;
      --rate-max)
        rate_max=$(__validate_mbps "$2") || return 1
        shift
        ;;
      --filename)
        filename="$2"
        shift
        ;;
      --exclude-folder)
        if [[ -n "$exclude_folder" ]]; then
          exclude_folder="${exclude_folder},${2}"
        else
          exclude_folder="$2"
        fi
        shift
        ;;
      --date)
        date_val=$(__ddmmyyyy_to_iso "$2") || return 1
        shift
        ;;
      --date-created)
        if [[ -n "$date_created_flag" ]]; then
          echo "Error: --date-created conflicts with $date_created_flag -- only one Date Created filter may be given." >&2
          return 1
        fi
        date_created=$(__ddmmyyyy_to_iso "$2") || return 1
        date_created_flag="--date-created"
        shift
        ;;
      --today)
        if [[ -n "$date_created_flag" ]]; then
          echo "Error: --today conflicts with $date_created_flag -- only one Date Created filter may be given." >&2
          return 1
        fi
        date_created="today"
        date_created_flag="--today"
        ;;
      --this-week)
        if [[ -n "$date_created_flag" ]]; then
          echo "Error: --this-week conflicts with $date_created_flag -- only one Date Created filter may be given." >&2
          return 1
        fi
        date_created="thisweek"
        date_created_flag="--this-week"
        ;;
      --this-month)
        if [[ -n "$date_created_flag" ]]; then
          echo "Error: --this-month conflicts with $date_created_flag -- only one Date Created filter may be given." >&2
          return 1
        fi
        date_created="thismonth"
        date_created_flag="--this-month"
        ;;
      --this-year)
        if [[ -n "$date_created_flag" ]]; then
          echo "Error: --this-year conflicts with $date_created_flag -- only one Date Created filter may be given." >&2
          return 1
        fi
        date_created="thisyear"
        date_created_flag="--this-year"
        ;;
      --gui) gui="-LaunchGui" ;;
      *)
        echo "Unknown parameter: $1"
        return 1
        ;;
    esac
    shift
  done

  if [[ -n "$orientation" && "$orientation" != "l" && "$orientation" != "p" ]]; then
    echo "Error: --orientation must be 'l' or 'p', got '$orientation'." >&2
    return 1
  fi

  # --all-videos is a documentation/no-op flag -- omitting --tag/--all-tags
  # entirely already means "no tag filter", but that absence looks
  # identical to "forgot to add a filter" in a saved find-save profile or
  # a script. Rejecting it alongside a real tag filter (rather than
  # silently letting one win) keeps a saved --all-videos profile
  # trustworthy as "deliberately every video", not just "whatever was
  # left over".
  if [[ -n "$all_videos" && ( -n "$tag" || -n "$all_tags" ) ]]; then
    echo "Error: --all-videos conflicts with --tag/--all-tags -- it means no tag filter at all." >&2
    return 1
  fi

  # Build the PowerShell command string
  local module_path
  module_path=$(__video_module_path)
  local ps_cmd="Import-Module '$module_path'; Find-IndexedVideo -LibraryScope '$scope'"

  # Comma-separated variables are natively cast to [string[]] in PowerShell
  [[ -n "$all_tags" ]] && ps_cmd+=" -AllTags"
  [[ -n "$tag" ]] && ps_cmd+=" -Tag $tag"
  [[ -n "$tag" && "$tag_logic" == "and" ]] && ps_cmd+=" -TagLogic and"
  [[ -n "$res" ]] && ps_cmd+=" -Resolution $res"
  [[ -n "$orientation" ]] && ps_cmd+=" -Orientation $orientation"
  [[ -n "$len_min" ]] && ps_cmd+=" -MinLengthSeconds $len_min"
  [[ -n "$len_max" ]] && ps_cmd+=" -MaxLengthSeconds $len_max"
  [[ -n "$rate_min" ]] && ps_cmd+=" -MinDatarateMb $rate_min"
  [[ -n "$rate_max" ]] && ps_cmd+=" -MaxDatarateMb $rate_max"
  # Single-quoted PowerShell literal -- double any embedded single quote
  # so free-text filename input can't break out of the string.
  [[ -n "$filename" ]] && ps_cmd+=" -Filename '${filename//\'/\'\'}'"
  [[ -n "$exclude_folder" ]] && ps_cmd+=" -ExcludeFolder $(__find_dynamic_ps_array_literal "$exclude_folder")"
  [[ -n "$date_val" ]] && ps_cmd+=" -Date '$date_val'"
  [[ -n "$date_created" ]] && ps_cmd+=" -DateCreated '$date_created'"
  [[ -n "$gui" ]] && ps_cmd+=" $gui"

  __find_dynamic_log_history "${__fd_orig_args[@]}"
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command "$ps_cmd"
}
```

### 📂 Minikube (Local Kubernetes Cluster) Tools


#### `mk-addons`

> Minikube: fzf-pick an addon and toggle it on/off based on its current

```bash
#######################################
# Minikube: fzf-pick an addon and toggle it on/off based on its current
# state.
# Usage: mk-addons [profile]
# Arguments:
#   $1 - (Optional) Profile name. Defaults to "minikube".
#######################################
mk-addons() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  local profile="${1:-minikube}"
  local selection
  selection=$(minikube addons list -p "$profile" -o json 2> /dev/null | jq -r '.[] | "\(.AddonName)\t\(.Status)"' 2> /dev/null | awk -F'\t' '{printf "%-25s %s\n", $1, $2}' | fzf --prompt="🧪 Toggle Addon > " --height=~15 --layout=reverse --border)
  if [ -z "$selection" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi

  local addon status
  addon=$(echo "$selection" | awk '{print $1}')
  status=$(echo "$selection" | awk '{print $2}')

  if [[ "${status,,}" == "enabled" ]]; then
    minikube addons disable "$addon" -p "$profile" && echo -e "${CB_GREEN}✅ Disabled ${addon}.${C_RESET}"
  else
    minikube addons enable "$addon" -p "$profile" && echo -e "${CB_GREEN}✅ Enabled ${addon}.${C_RESET}"
  fi
}
```

#### `mk-dashboard`

> Minikube: Launch the Kubernetes dashboard web UI in the background via

```bash
#######################################
# Minikube: Launch the Kubernetes dashboard web UI in the background via
# the framework's shared job runner (mt-jobs), since 'minikube dashboard'
# blocks in the foreground running its own proxy.
# Usage: mk-dashboard [profile]
# Arguments:
#   $1 - (Optional) Profile name. Defaults to "minikube".
#######################################
mk-dashboard() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  local profile="${1:-minikube}"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local log_file="${LOG_DIR}/minikube-dashboard_${timestamp}.log"

  __mt_bg_run "minikube-dashboard: ${profile}" "$log_file" "minikube dashboard -p '${profile}'"
}
```

#### `mk-delete`

> Minikube: Permanently delete a local cluster and its profile, always

```bash
#######################################
# Minikube: Permanently delete a local cluster and its profile, always
# confirmed via the destructive-op guard first -- the one genuinely
# irreversible action in this file.
# Usage: mk-delete [profile]
# Arguments:
#   $1 - (Optional) Profile name. If blank and more than one profile
#        exists, opens an fzf picker; otherwise defaults to the sole
#        existing profile (or "minikube").
#######################################
mk-delete() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  local profile="$1"
  [ -z "$profile" ] && profile=$(__mk_pick_profile "🧪 Select Profile to Delete")
  if [ -z "$profile" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi

  __k8s_confirm_destructive "About to delete minikube profile '${profile}' -- this destroys the cluster and cannot be undone." || {
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 1
  }

  minikube delete -p "$profile" && echo -e "${CB_GREEN}✅ Deleted '${profile}'.${C_RESET}"
}
```

#### `mk-load-image`

> Minikube: Load a locally-built Docker image into the cluster's

```bash
#######################################
# Minikube: Load a locally-built Docker image into the cluster's
# container runtime -- the "use" bridge to the existing docker-* family
# for local dev loops that skip a registry entirely.
# Usage: mk-load-image [image] [profile]
# Arguments:
#   $1 - (Optional) Image reference (e.g. myapp:latest). If blank, opens
#        an fzf picker over local 'docker images'.
#   $2 - (Optional) Profile name. Defaults to "minikube".
#######################################
mk-load-image() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  local image="$1"
  if [ -z "$image" ]; then
    image=$(docker images --format '{{.Repository}}:{{.Tag}}' 2> /dev/null | fzf --prompt="🐳 Select Local Image > " --height=~15 --layout=reverse --border)
    if [ -z "$image" ]; then
      echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
      return 0
    fi
  fi

  local profile="${2:-minikube}"
  echo -e "${CB_BLUE}🔄 Loading ${image} into '${profile}'...${C_RESET}"
  minikube image load "$image" -p "$profile" && echo -e "${CB_GREEN}✅ Loaded ${image}.${C_RESET}"
}
```

#### `mk-ssh`

> Minikube: Open an interactive shell on the cluster's node -- the

```bash
#######################################
# Minikube: Open an interactive shell on the cluster's node -- the
# minikube analogue of k8s-shell's pod-level exec, one layer down.
# Usage: mk-ssh [profile]
# Arguments:
#   $1 - (Optional) Profile name. Defaults to "minikube".
#######################################
mk-ssh() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  minikube ssh -p "${1:-minikube}"
}
```

#### `mk-start`

> Minikube: Create (or resume) a local cluster using the configured

```bash
#######################################
# Minikube: Create (or resume) a local cluster using the configured
# driver/CPU/memory defaults from config.yaml (see mt-wizard-minikube),
# so those values are never hardcoded at the call site.
# Usage: mk-start [profile]
# Arguments:
#   $1 - (Optional) Profile name. Defaults to "minikube".
# Globals:
#   MK_DRIVER, MK_CPUS, MK_MEMORY_MB
#######################################
mk-start() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  local profile="${1:-minikube}"
  echo -e "${CB_BLUE}🔄 Starting minikube profile '${profile}' (driver=${MK_DRIVER:-docker}, cpus=${MK_CPUS:-2}, memory=${MK_MEMORY_MB:-4000}MB)...${C_RESET}"
  minikube start -p "$profile" --driver="${MK_DRIVER:-docker}" --cpus="${MK_CPUS:-2}" --memory="${MK_MEMORY_MB:-4000}" &&
    echo -e "${CB_GREEN}✅ Cluster '${profile}' is up.${C_RESET}" &&
    echo -e "${C_DIM}Run 'k8s-status' to view the new context.${C_RESET}"
}
```

#### `mk-status`

> Minikube: Dashboard summarizing a local cluster's lifecycle state --

```bash
#######################################
# Minikube: Dashboard summarizing a local cluster's lifecycle state --
# profile, driver, and Host/Kubelet/APIServer status.
# Usage: mk-status [profile] [-j|--json]
# Arguments:
#   $1 - (Optional) Profile name. Defaults to "minikube".
# Options:
#   -j, --json   Print the same fields as one JSON object instead of the
#                colorized dashboard
#######################################
mk-status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  local profile="minikube"
  local json_mode=false
  for arg in "$@"; do
    case "$arg" in
      -j | --json) json_mode=true ;;
      *) profile="$arg" ;;
    esac
  done

  # A non-existent profile doesn't make minikube print nothing -- it
  # exits non-zero and prints a stream of CloudEvents-shaped error
  # objects on stdout (one per line), which is non-empty and would
  # otherwise slip past a plain `[ -z ]` check; jq then runs against
  # each of those lines as a separate input, silently duplicating every
  # field ("unknown\nunknown"...) instead of showing the "no cluster"
  # message. The exit code is the only reliable signal here.
  local status_json
  if ! status_json=$(minikube status -p "$profile" -o json 2> /dev/null); then
    echo -e "${CB_YELLOW}⚠️  No minikube cluster found for profile '${profile}'. Run 'mk-start' first.${C_RESET}"
    return 1
  fi

  local host kubelet apiserver driver
  host=$(echo "$status_json" | jq -r '.Host // "unknown"')
  kubelet=$(echo "$status_json" | jq -r '.Kubelet // "unknown"')
  apiserver=$(echo "$status_json" | jq -r '.APIServer // "unknown"')
  driver=$(minikube profile list -o json 2> /dev/null | jq -r --arg p "$profile" '.valid[]? | select(.Name==$p) | .Config.Driver // "unknown"')

  if [ "$json_mode" = true ]; then
    jq -n --arg profile "$profile" --arg driver "${driver:-unknown}" --arg host "$host" \
      --arg kubelet "$kubelet" --arg apiserver "$apiserver" \
      '{profile: $profile, driver: $driver, host: $host, kubelet: $kubelet, apiserver: $apiserver}'
    return
  fi

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}              MINIKUBE STATUS                              ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_CYAN}Profile   :${C_RESET} ${profile}"
  echo -e "${CB_CYAN}Driver    :${C_RESET} ${driver:-unknown}"
  echo -e "${CB_CYAN}Host      :${C_RESET} ${host}"
  echo -e "${CB_CYAN}Kubelet   :${C_RESET} ${kubelet}"
  echo -e "${CB_CYAN}APIServer :${C_RESET} ${apiserver}"
}
```

#### `mk-stop`

> Minikube: Stop a local cluster without destroying it -- state is

```bash
#######################################
# Minikube: Stop a local cluster without destroying it -- state is
# preserved and 'mk-start' resumes it. Non-destructive, so no
# confirmation guard is needed.
# Usage: mk-stop [profile]
# Arguments:
#   $1 - (Optional) Profile name. If blank and more than one profile
#        exists, opens an fzf picker; otherwise defaults to the sole
#        existing profile (or "minikube").
#######################################
mk-stop() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  local profile="$1"
  [ -z "$profile" ] && profile=$(__mk_pick_profile "🧪 Select Profile to Stop")
  if [ -z "$profile" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi

  minikube stop -p "$profile" && echo -e "${CB_GREEN}✅ Stopped '${profile}'.${C_RESET}"
}
```

#### `mk-tunnel`

> Minikube: Open a network tunnel so LoadBalancer-type services get a

```bash
#######################################
# Minikube: Open a network tunnel so LoadBalancer-type services get a
# reachable external IP. Runs in the foreground (not backgrounded) since
# it needs an attached terminal for the sudo password prompt and is
# meant to stay running until Ctrl+C, same as k8s-tail.
# Usage: mk-tunnel [profile]
# Arguments:
#   $1 - (Optional) Profile name. Defaults to "minikube".
#######################################
mk-tunnel() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  local profile="${1:-minikube}"
  echo -e "${CB_BLUE}🔄 Starting tunnel for '${profile}' -- this blocks until Ctrl+C and may prompt for your sudo password.${C_RESET}"
  minikube tunnel -p "$profile"
}
```

### 📂 MT Repo Radar - AI & Heuristic Metadata Dashboard


#### `mt-hub`

> Repo Radar: Deprecated name for mt-radar, kept as a thin forwarding

```bash
#######################################
# Repo Radar: Deprecated name for mt-radar, kept as a thin forwarding
# shim so anyone with mt-hub memorized, scripted, or aliased elsewhere
# doesn't hit a hard break -- prints a one-line notice (to stderr, so it
# never pollutes -j/--json output piped elsewhere) then forwards every
# argument through unchanged. No fixed removal date; drop it once this
# has been out long enough that muscle memory has caught up.
# Usage: mt-hub [any mt-radar argument]
#######################################
mt-hub() {
  echo -e "${CB_YELLOW}⚠️  mt-hub has been renamed to mt-radar -- update your muscle memory (this alias will be removed eventually).${C_RESET}" >&2
  mt-radar "$@"
}
```

#### `mt-radar`

> System: Interactive AI-powered Repository Dashboard. An unfiltered

```bash
#######################################
# System: Interactive AI-powered Repository Dashboard. An unfiltered
# --index run also prunes cache entries for repos no longer found on
# disk (moved, renamed, or deleted) before indexing.
# Usage: mt-radar [--index [-b] [-f] [-u] [-t <type>] [-r <name>] [-p <provider>] [--infra]] [--infra [-t <type>] [-r <name>]] [--show-infra <repo>] [--preview <repo>] [--scan-gcp -r <repo> [--gcp-project <id>]]
# Options:
#   --index                    Scan and build the AI metadata cache
#   -b, --bg, --background     Run the index scan as a background job (with --index)
#   -f, --force                Force reindex even if a repo is already cached (with --index)
#   -u, --update               Re-index an already-cached repo anyway if its entry has a
#                              gap (AI category/description never came back, or the stack
#                              heuristic found nothing) -- unlike -f, repos with a complete
#                              entry are still skipped. Ignored if -f is also given.
#   -t, --type <name>          Filter indexing to a specific folder (e.g. personal, work) --
#                              also disables stale-entry pruning for this run
#   -r, --repo <name>          Filter indexing to a specific repository name --
#                              also disables stale-entry pruning for this run
#   -p, --provider <name>      Override DEFAULT_AI for this indexing run only
#                              (gemini, claude, claude-code, local) -- e.g. to
#                              save Claude usage by indexing with Gemini instead
#                              without changing your actual default provider
#   --infra                    Generate a Terraform infrastructure overview (resources
#                              grouped by category -- compute/networking/storage/
#                              database/messaging/IAM/data/other -- plus providers and
#                              modules used) for every repo matching -t/-r that contains
#                              Terraform, into a separate cache (.vcs_infra.json). No AI
#                              call, heuristic only -- safe to combine with --index (runs
#                              right after each repo's normal indexing step) or use on
#                              its own against already-indexed repos. Repos with no
#                              Terraform are silently skipped, not recorded.
#   --show-infra <repo>        Show the cached infrastructure overview for one repo (by
#                              absolute path or bare repo name) and exit
#   --scan-gcp                 Check every google_* resource in one repo's already-generated
#                              infrastructure overview (run --infra first) against a live GCP
#                              project via `gcloud ... list` -- deployed/not-deployed, console
#                              links, and a red/amber/green sync status (green = all deployed,
#                              red = none, amber = partial). Existence-based only, not a real
#                              `terraform plan` drift check. Requires -r/--repo; on-demand
#                              only, never run automatically by --index/--infra
#   --gcp-project <id>         GCP project to scan against (with --scan-gcp). Defaults to
#                              gcloud's own active project (`gcloud config get-value project`)
#   --preview <repo>           Show cached metadata for one repo (by absolute path or
#                              bare repo name) and exit
#   --search <term>            Search the indexed cache (name, description, category,
#                              stack) for a term and print matches, then exit
#   -j, --json                 With --search, print matches as a JSON array instead
#                              of a table
#   -h, --help                 Show this help menu
#######################################
mt-radar() {
  local cache_file="$CACHE_DIR/.vcs_radar.json"
  mkdir -p "$(dirname "$cache_file")"
  # One-time migration from this command's pre-rename name (mt-hub) --
  # non-destructive and idempotent, same pattern as the XDG config-file
  # migration: only copies when the new path doesn't exist yet and the
  # old one does, so a user's already-indexed repo metadata (including
  # AI-generated summaries, real cost to regenerate) survives the rename
  # instead of silently starting over. The old file is left in place
  # rather than deleted -- cheap insurance if this ever needs re-running.
  if [ ! -f "$cache_file" ] && [ -f "$CACHE_DIR/.vcs_hub.json" ]; then
    cp -p "$CACHE_DIR/.vcs_hub.json" "$cache_file"
    mt-log INFO "Migrated .vcs_hub.json to .vcs_radar.json (mt-hub was renamed to mt-radar)."
  fi
  [ ! -f "$cache_file" ] && echo "{}" > "$cache_file"

  local infra_cache_file="$CACHE_DIR/.vcs_infra.json"
  [ ! -f "$infra_cache_file" ] && echo "{}" > "$infra_cache_file"

  local do_index=false
  local run_bg=false
  local force_index=false
  local update_missing=false
  local filter_type=""
  local filter_repo=""
  local provider_override=""
  local search_term=""
  local json_mode=false
  local run_infra=false
  local show_infra_repo=""
  local run_scan_gcp=false
  local gcp_project_override=""

  # Argument parsing
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --index) do_index=true ;;
      -b | --bg | --background) run_bg=true ;;
      -f | --force) force_index=true ;;
      -u | --update) update_missing=true ;;
      -t | --type)
        filter_type="$2"
        shift
        ;;
      -r | --repo)
        filter_repo="$2"
        shift
        ;;
      -p | --provider)
        provider_override="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
        if [[ "$provider_override" != "gemini" && "$provider_override" != "claude" && "$provider_override" != "claude-code" && "$provider_override" != "local" ]]; then
          echo -e "${CB_RED}🚨 Invalid provider '$2'. Use gemini, claude, claude-code, or local.${C_RESET}"
          return 1
        fi
        shift
        ;;
      --preview)
        __mt_radar_preview "$2" "$cache_file"
        return 0
        ;;
      --search)
        search_term="$2"
        shift
        ;;
      --infra) run_infra=true ;;
      --show-infra)
        show_infra_repo="$2"
        shift
        ;;
      --scan-gcp) run_scan_gcp=true ;;
      --gcp-project)
        gcp_project_override="$2"
        shift
        ;;
      -j | --json) json_mode=true ;;
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      *)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
    shift
  done

  if [ -n "$search_term" ]; then
    __mt_radar_search "$cache_file" "$search_term" "$json_mode"
    return 0
  fi

  if [ -n "$show_infra_repo" ]; then
    __mt_radar_infra_show "$show_infra_repo" "$infra_cache_file" "$json_mode"
    return 0
  fi

  if [ "$run_scan_gcp" = true ]; then
    if [ -z "$filter_repo" ]; then
      echo -e "${CB_RED}🚨 --scan-gcp requires -r/--repo <name>.${C_RESET}"
      return 1
    fi

    if ! __mt_radar_gcp_available; then
      echo -e "${CB_RED}🚨 gcloud CLI not found or no active credentialed account. Run 'gcloud auth login' first.${C_RESET}"
      return 1
    fi

    local scan_project="$gcp_project_override"
    [ -z "$scan_project" ] && scan_project=$(gcloud config get-value project 2> /dev/null)
    if [ -z "$scan_project" ]; then
      echo -e "${CB_RED}🚨 No GCP project set. Pass --gcp-project <id> or run 'gcloud config set project <id>' first.${C_RESET}"
      return 1
    fi

    local infra_entry
    infra_entry=$(jq -c --arg name "$filter_repo" '
      [to_entries[] | select((.key | split("/") | last) == $name)] | .[0].value // empty
    ' "$infra_cache_file" 2> /dev/null)
    if [ -z "$infra_entry" ] || [ "$infra_entry" == "null" ]; then
      echo -e "${CB_YELLOW}⚠️  No infrastructure overview found for \"${filter_repo}\". Run 'mt-radar --infra -r ${filter_repo}' first.${C_RESET}"
      return 1
    fi

    local resolved_repo_path
    resolved_repo_path=$(jq -r --arg name "$filter_repo" '
      to_entries[] | select((.key | split("/") | last) == $name) | .key
    ' "$infra_cache_file" 2> /dev/null | head -n1)

    echo -e "${CB_BLUE}🔍 Scanning ${filter_repo}'s Terraform resources against GCP project '${scan_project}'...${C_RESET}"
    local scan_result
    scan_result=$(__mt_radar_gcp_scan_repo "$infra_entry" "$scan_project")
    __mt_radar_infra_write_gcp_scan "$infra_cache_file" "$resolved_repo_path" "$scan_result"

    if [ "$json_mode" = true ]; then
      echo "$scan_result"
    else
      __mt_radar_gcp_scan_show "$scan_result"
    fi
    return 0
  fi

  local search_dir="${VCS_ROOT:-$HOME/vcs}"

  if [ "$do_index" = true ]; then
    if [ "$run_bg" = true ]; then
      local log_out
      log_out="$LOG_DIR/indexer_$(date +%s).log"
      local cmd_str="__mt_radar_index \"$cache_file\" \"$filter_type\" \"$filter_repo\" \"$force_index\" \"$provider_override\" \"$update_missing\" \"$run_infra\" \"$infra_cache_file\""
      __mt_bg_run "mt-radar-indexer" "$log_out" "$cmd_str"
    else
      __mt_radar_index "$cache_file" "$filter_type" "$filter_repo" "$force_index" "$provider_override" "$update_missing" "$run_infra" "$infra_cache_file"
    fi
    return 0
  fi

  if [ "$run_infra" = true ]; then
    __mt_radar_infra_run "$search_dir" "$filter_type" "$filter_repo" "$infra_cache_file"
    return 0
  fi

  local tmp_out
  tmp_out=$(mktemp)

  while IFS= read -r repo_path; do
    [ -z "$repo_path" ] && continue
    local repo_name
    repo_name=$(basename "$repo_path")

    local rel_path="${repo_path#"$search_dir"/}"
    local repo_type="Root"
    if [[ "$rel_path" == */* ]]; then
      repo_type="${rel_path%%/*}"
    fi
    repo_type="$(tr '[:lower:]' '[:upper:]' <<< "${repo_type:0:1}")${repo_type:1}"

    local branch
    branch=$(git -C "$repo_path" branch --show-current 2> /dev/null || echo "HEAD detached")
    [ -z "$branch" ] && branch="No commits"

    echo "${repo_type}|${repo_name}|${branch}|${repo_path}" >> "$tmp_out"
  done < <(__mt_radar_find_repos "$search_dir")

  sort -t'|' -k1,1 -k2,2 "$tmp_out" -o "$tmp_out"

  # See vcs_radar_table.awk for why the raw path rides along as a hidden
  # tab-delimited first field, recovered below via fzf's {1}.
  local awk_script="$HOME/.bash.d/lib/awk/vcs_radar_table.awk"
  local selected
  selected=$(awk -f "$awk_script" "$tmp_out" | fzf --ansi --delimiter=$'\t' --with-nth=2 --prompt="VCS Radar > " --header="TYPE            │ REPOSITORY                          │ BRANCH               " --preview="bash -c 'source ~/.bash.d/01-ui/01-colors.sh; source ~/.bash.d/20-vcs/53-vcs-insight.sh; __mt_radar_preview \"{1}\" \"$cache_file\"'")

  rm -f "$tmp_out"

  if [ -n "$selected" ]; then
    local target_path
    target_path=$(awk -F'\t' '{print $1}' <<< "$selected")
    echo -e "${CB_GREEN}📂 Navigating to: $target_path${C_RESET}"
    cd "$target_path" || true
  fi
}
```

### 📂 MyTools Documentation & Runner


#### `mt`

> MyTools: Central dispatcher -- run any framework command as `mt <name>`

```bash
#######################################
# MyTools: Central dispatcher -- run any framework command as `mt <name>`
# instead of typing its full `mt-<name>` form. Bare `mt` (no arguments)
# keeps today's behavior and prints the full command listing via mytools.
# Usage: mt <subcommand> [args...]
#######################################
mt() {
  if [ $# -eq 0 ]; then
    mytools
    return $?
  fi

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "mt"
    return 0
  fi

  local subcmd="$1"
  shift

  if [[ ! "$subcmd" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    echo -e "${CB_RED}🚨 Error: invalid subcommand '$subcmd'.${C_RESET}"
    return 1
  fi

  local target_cmd="mt-${subcmd}"
  local kind
  kind=$(type -t "$target_cmd" 2> /dev/null)

  case "$kind" in
    function)
      "$target_cmd" "$@"
      ;;
    alias)
      # target_cmd was just built from a regex-validated, alnum/-/_-only
      # subcmd and confirmed by `type -t` to be a real registered alias,
      # so it is safe to re-parse here -- this is the only way to invoke
      # an alias whose name is held in a variable (bash does not expand
      # aliases through indirection).
      eval "$target_cmd \"\$@\""
      ;;
    *)
      echo -e "${CB_RED}🚨 Error: Framework command '${target_cmd}' not found.${C_RESET}"
      echo -e "${C_DIM}Run 'mt lookup ${subcmd}' or 'mt cat' to discover available tools.${C_RESET}"
      return 1
      ;;
  esac
}
```

#### `mt-aliases`

> MyTools: List all documented shell aliases (shortcut for `mt-list --alias`)

```bash
#######################################
# MyTools: List all documented shell aliases (shortcut for `mt-list --alias`)
#######################################
mt-aliases() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }
  mt-list --alias
}
```

#### `mt-cat`

> MyTools: List all tools within a specific category (shortcut for `mt-list <category>`)

```bash
#######################################
# MyTools: List all tools within a specific category (shortcut for `mt-list <category>`)
# Arguments:
#   $1 - Category name
#######################################
mt-cat() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }
  [ -z "$1" ] && {
    echo "Usage: mt-cat <category>"
    mt-cats
    return 1
  }
  mt-list "$1"
}
```

#### `mt-cats`

> MyTools: List all available command categories (shortcut for `mt-list`)

```bash
#######################################
# MyTools: List all available command categories (shortcut for `mt-list`)
#######################################
mt-cats() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }
  mt-list
}
```

#### `mt-config`

> MyTools: Display active framework configuration variables

```bash
#######################################
# MyTools: Display active framework configuration variables
#######################################
mt-config() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}                ACTIVE CONFIGURATION                      ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e " ${CB_CYAN}DEFAULT_AI        ${C_RESET}: ${DEFAULT_AI:-gemini}"
  echo -e " ${CB_CYAN}GEMINI_VERSION    ${C_RESET}: ${GEMINI_VERSION:-gemini-1.5-pro}"
  echo -e " ${CB_CYAN}CLAUDE_VERSION    ${C_RESET}: ${CLAUDE_VERSION:-claude-sonnet-5}"
  echo -e " ${CB_CYAN}CLAUDE_CODE_MODEL ${C_RESET}: ${CLAUDE_CODE_VERSION:-<claude CLI default>}"
  echo -e " ${CB_CYAN}VCS_ROOT          ${C_RESET}: ${VCS_ROOT}"
  echo -e " ${CB_CYAN}VCS_PERSONAL      ${C_RESET}: ${VCS_PERSONAL}"
  echo -e " ${CB_CYAN}DOTFILES_DIR      ${C_RESET}: ${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  echo -e " ${CB_CYAN}AI_WORKSPACE      ${C_RESET}: ${AI_WORKSPACE_DIR}"
  echo -e " ${CB_CYAN}EXPORT_DIR        ${C_RESET}: ${EXPORT_DIR:-/tmp/exports}"
  echo -e " ${CB_CYAN}BACKUP_DIR        ${C_RESET}: ${BACKUP_DIR:-~/backups}"
  echo -e " ${CB_CYAN}AUTO_CLEANUP      ${C_RESET}: ${AUTO_CLEANUP_EXPORTS:-false} (${AUTO_CLEANUP_DAYS:-7} days)"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
}
```

#### `mt-dump`

> MyTools: Generate a detailed technical Markdown dump of all functions and aliases

```bash
#######################################
# MyTools: Generate a detailed technical Markdown dump of all functions and aliases
# Usage: mt-dump [OPTIONS]
# Options:
#   -d, --dir <path>       Specify export directory (default: ~/.bash.d/docs)
#   --private              Include private/internal framework functions (starting with _ or __)
#   -h, --help             Show this help menu
#######################################
mt-dump() {
  local export_dir="$HOME/.bash.d/docs"
  local include_private=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -d | --dir)
        export_dir="$2"
        shift
        ;;
      --private)
        include_private=true
        ;;
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      *)
        echo "Usage: mt-dump [-d <export_dir>] [--private]"
        return 1
        ;;
    esac
    shift
  done

  mkdir -p "$export_dir"
  local out_file="${export_dir}/TECHNICAL_REFERENCE.md"

  echo -e "${CB_BLUE}📝 Generating technical reference manual...${C_RESET}"

  cat << HDR > "$out_file"

> **Auto-generated Reference Document**  
> Generated: $(date)  
> Environment: $(uname -s) ($(uname -m))

---

HDR

  local tsv_index="$CACHE_DIR/.mt_data.tsv"
  mytools > /dev/null

  if [ -f "$tsv_index" ]; then
    # shellcheck disable=SC2129  # part of a long, loop/conditional-heavy markdown generator; grouping would require restructuring control flow
    echo "" >> "$out_file"
    echo "## 🔗 Shell Aliases" >> "$out_file"
    echo "" >> "$out_file"
    awk -F'\t' '$1 == "alias" { printf "- **`%s`** *(%s)*: %s\n", $3, $2, $4 }' "$tsv_index" >> "$out_file"
    echo "" >> "$out_file"
    echo "---" >> "$out_file"
    echo "" >> "$out_file"
    echo "## 🛠️ Public Functions" >> "$out_file"
    echo "" >> "$out_file"

    local current_cat=""
    # Same 5-column-TSV/4-variable-read mismatch as __rebuild_mytools_cache
    # above -- without naming the 5th (FILENAME) column here, read folds it
    # onto the end of $desc, leaking a source path into the "> $desc" line
    # below.
    while IFS=$'\t' read -r type cat name desc _source_file; do
      [ "$type" != "func" ] && continue

      if [ "$cat" != "$current_cat" ]; then
        current_cat="$cat"
        # shellcheck disable=SC2129
        echo "" >> "$out_file"
        echo "### 📂 ${current_cat}" >> "$out_file"
        echo "" >> "$out_file"
      fi

      # shellcheck disable=SC2129
      echo "" >> "$out_file"
      echo "#### \`$name\`" >> "$out_file"
      echo "" >> "$out_file"
      echo "> $desc" >> "$out_file"
      echo "" >> "$out_file"

      local src_file
      src_file=$(grep -rlE "^${name}\(\)[ \t]*\{" "$HOME/.bash.d/" 2> /dev/null | head -n 1)
      if [ -n "$src_file" ]; then
        # shellcheck disable=SC2129
        echo "\`\`\`bash" >> "$out_file"
        awk -v target="$name" -f "$HOME/.bash.d/lib/awk/mt_help.awk" "$src_file" >> "$out_file"
        echo "\`\`\`" >> "$out_file"
      fi
    done < <(sort -t$'\t' -k2,2 -k3,3 "$tsv_index")
  fi

  if [ "$include_private" = true ]; then
    # shellcheck disable=SC2129
    echo "" >> "$out_file"
    echo "---" >> "$out_file"
    echo "" >> "$out_file"
    echo "## 🔒 Internal Framework Helpers (Private Functions)" >> "$out_file"
    echo "" >> "$out_file"
    echo "Private functions prefixed with \`_\` or \`__\` used internally by the framework." >> "$out_file"

    find -L "$HOME/.bash.d" -type f -name "*.sh" -exec grep -HnE "^_{1,2}[a-zA-Z0-9_-]+\(\)[ \t]*\{" {} + | while read -r line; do
      local fpath
      fpath=$(echo "$line" | cut -d: -f1)
      local func_name
      func_name=$(echo "$line" | grep -oE "_{1,2}[a-zA-Z0-9_-]+")

      [ -z "$func_name" ] && continue
      local rel_fpath="${fpath#"$HOME"/.bash.d/}"

      # shellcheck disable=SC2129
      echo "" >> "$out_file"
      echo "### \`$func_name\` *(File: \`00-system/${rel_fpath}\`)*" >> "$out_file"
      echo "" >> "$out_file"
      echo "\`\`\`bash" >> "$out_file"
      awk -v target="$func_name" -f "$HOME/.bash.d/lib/awk/mt_help.awk" "$fpath" >> "$out_file"
      echo "\`\`\`" >> "$out_file"
    done
  fi

  echo -e "${CB_GREEN}✅ Technical reference generated at:${C_RESET} ${out_file}"

  if type __open_path_gui > /dev/null 2>&1; then
    __open_path_gui "$export_dir" 2> /dev/null || true
  fi
}
```

#### `mt-funcs`

> MyTools: List all documented shell functions (shortcut for `mt-list --func`)

```bash
#######################################
# MyTools: List all documented shell functions (shortcut for `mt-list --func`)
#######################################
mt-funcs() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }
  mt-list --func
}
```

#### `mt-fzf`

> MyTools: Interactive fuzzy-finder to search for a command

```bash
#######################################
# MyTools: Interactive fuzzy-finder to search for a command
#######################################
mt-fzf() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }
  mytools > /dev/null
  local selected
  selected=$(awk -F'\t' '{ printf "%-24s │ %-20s │ %s\n", $3, $2, $4 }' "$CACHE_DIR/.mt_data.tsv" | fzf --ansi --prompt="Search MyTools > " --header="COMMAND                  │ CATEGORY             │ DESCRIPTION")
  [ -n "$selected" ] && echo "$selected" | awk '{print $1}'
}
```

#### `mt-get-version`

> System: Print the current local version of the terminal profile

```bash
#######################################
# System: Print the current local version of the terminal profile
#######################################
mt-get-version() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [ -f "$VERSION_FILE" ]; then
    local current_version
    current_version=$(command cat "$VERSION_FILE")
    echo -e "${CB_CYAN}Profile Version:${C_RESET} ${current_version}"
  elif [ -n "$DOTFILES_DIR" ] && [ -d "$DOTFILES_DIR/.git" ] && command -v git > /dev/null 2>&1; then
    local current_version
    current_version=$(git -C "$DOTFILES_DIR" describe --tags --abbrev=0 2> /dev/null || echo "Local")
    echo -e "${CB_CYAN}Profile Version:${C_RESET} ${current_version}"
  elif [ -n "$SYNC_REPO_DIR" ] && [ -d "$SYNC_REPO_DIR/.git" ] && command -v git > /dev/null 2>&1; then
    local current_version
    current_version=$(git -C "$SYNC_REPO_DIR" describe --tags --abbrev=0 2> /dev/null || echo "Local")
    echo -e "${CB_CYAN}Profile Version:${C_RESET} ${current_version}"
  else
    echo -e "${CB_CYAN}Profile Version:${C_RESET} Local (Unversioned/Standalone)"
  fi
}
```

#### `mt-help`

> MyTools: Display detailed help and source code for a command

```bash
#######################################
# MyTools: Display detailed help and source code for a command
# Usage: mt-help [-v|--verbose] <command>
# Arguments:
#   $1 - Command name or keyword
#######################################
mt-help() {
  local show_code=false
  local target=""

  # Parse Arguments
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -v | --verbose) show_code=true ;;
      -h | --help)
        echo -e "${CB_BLUE}Usage:${C_RESET} mt-help [-v|--verbose] <command>"
        return 0
        ;;
      -*)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        echo "Usage: mt-help [-v|--verbose] <command>"
        return 1
        ;;
      *) target="$1" ;;
    esac
    shift
  done

  [ -z "$target" ] && {
    echo "Usage: mt-help [-v|--verbose] <command>"
    return 1
  }

  __render_help() {
    local cmd="$1"
    local fpath="$2"
    local show_code="$3"

    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e "${CB_CYAN} 🛠️  ${cmd}${C_RESET}"
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e "${CB_YELLOW} 📄 File: ${C_RESET} $(wslpath -m "$fpath" 2> /dev/null || echo "$fpath")"
    echo -e "${CB_BLUE}----------------------------------------------------------${C_RESET}"

    # Use AWK to cleanly separate the docstring from the codeblock
    local raw_data
    raw_data=$(awk -v target="$cmd" -f "$HOME/.bash.d/lib/awk/mt_render_help.awk" "$fpath")

    local docstring="${raw_data%%---MT_CODE_DELIMITER---*}"
    local codeblock="${raw_data#*---MT_CODE_DELIMITER---}"

    # Parse and colorize the documentation string
    local section="desc"
    while IFS= read -r line; do
      [ -z "$line" ] && continue

      # Catch Headers (Usage:, Options:, Arguments:, etc.)
      if [[ "$line" =~ ^(Usage|Options|Arguments|Returns|Outputs|Globals): ]]; then
        echo -e "\n${CB_CYAN}▶ ${line}${C_RESET}"
        section="details"
      elif [ "$section" = "desc" ]; then
        # Main description text is standard white
        echo -e "${C_WHITE}${line}${C_RESET}"
      else
        # In details sections, look for flags starting with a dash
        if [[ "$line" =~ ^[[:space:]]*- ]]; then
          # Color the flag yellow, and the description dim text
          echo -e "  ${CB_YELLOW}${line%%  *}${C_RESET}  ${C_DIM}${line#*  }${C_RESET}"
        else
          echo -e "  ${C_DIM}${line}${C_RESET}"
        fi
      fi
    done <<< "$docstring"

    # Only show source code if the flag was provided
    if [ "$show_code" = true ] && [ -n "$codeblock" ]; then
      echo -e "\n${CB_BLUE}▶ SOURCE CODE${C_RESET}"
      echo -e "${CB_BLUE}----------------------------------------------------------${C_RESET}"
      if command -v "$BAT_BIN" > /dev/null 2>&1; then
        echo "$codeblock" | "$BAT_BIN" --language=bash --style=plain --paging=never 2> /dev/null
      else
        echo -e "${C_DIM}${codeblock}${C_RESET}"
      fi
    fi
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
  }

  local file_path
  file_path=$(grep -rlE "^(alias ${target}=|${target}\(\)[ \t]*\{)" "$HOME/.bash.d/" 2> /dev/null | head -n 1)
  if [ -n "$file_path" ]; then
    __render_help "$target" "$file_path" "$show_code"
    return 0
  fi

  mytools > /dev/null
  local tsv_file="$CACHE_DIR/.mt_data.tsv"
  local candidates=()

  if [ -f "$tsv_file" ]; then
    while read -r match; do
      [ -n "$match" ] && candidates+=("$match")
    done < <(awk -F'\t' -v q="${target,,}" 'tolower($3) ~ q { print $3 }' "$tsv_file" | sort -u)
  fi

  local count="${#candidates[@]}"

  if [ "$count" -eq 1 ]; then
    local single_target="${candidates[0]}"
    file_path=$(grep -rlE "^(alias ${single_target}=|${single_target}\(\)[ \t]*\{)" "$HOME/.bash.d/" 2> /dev/null | head -n 1)
    if [ -n "$file_path" ]; then
      __render_help "$single_target" "$file_path" "$show_code"
      return 0
    fi
  elif [ "$count" -gt 1 ]; then
    echo -e "${CB_YELLOW}⚠️  No exact match found for '${target}'. Did you mean one of these?${C_RESET}\n"
    for cand in "${candidates[@]}"; do
      echo -e "  ${C_DIM}•${C_RESET} ${CB_CYAN}${cand}${C_RESET}"
    done
    echo ""
    return 0
  fi

  echo -e "${CB_RED}🚨 Error: '${target}' is not a recognized custom MyTools command.${C_RESET}"
  return 1
}
```

#### `mt-list`

> MyTools: List all available command categories

```bash
#######################################
# MyTools: List all available command categories
#######################################
#######################################
# MyTools: List categories, functions, aliases, or a specific category's tools
# Usage: mt-list [category] [-f|--func] [-a|--alias]
# Arguments:
#   [category]   Category name -- list tools within it
#   -f, --func   List all documented shell functions
#   -a, --alias  List all documented shell aliases
#   (none)       List all available categories
#######################################
mt-list() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }
  mytools > /dev/null

  case "$1" in
    "")
      echo -e "\n${CB_BLUE}▶ AVAILABLE CATEGORIES${C_RESET}"
      cut -f2 "$CACHE_DIR/.mt_data.tsv" 2> /dev/null | sort -u | while read -r cat; do
        [ -n "$cat" ] && echo -e "  ${CB_YELLOW}[${cat}]${C_RESET}"
      done
      echo ""
      ;;
    -f | --func)
      echo -e "\n${CB_BLUE}▶ FUNCTIONS${C_RESET}\n"
      awk -F'\t' -v dim="$C_DIM" -v cyan="$CB_CYAN" -v yellow="$CB_YELLOW" -v white="$C_WHITE" -v rst="$C_RESET" '$1 == "func" { printf "  %s•%s %s%-24s%s (%s%s%s) %s→%s %s%s%s\n", dim, rst, cyan, $3, rst, yellow, $2, rst, dim, rst, white, $4, rst }' "$CACHE_DIR/.mt_data.tsv"
      echo ""
      ;;
    -a | --alias)
      echo -e "\n${CB_BLUE}▶ ALIASES${C_RESET}\n"
      awk -F'\t' -v dim="$C_DIM" -v cyan="$CB_CYAN" -v yellow="$CB_YELLOW" -v white="$C_WHITE" -v rst="$C_RESET" '$1 == "alias" { printf "  %s•%s %s%-24s%s (%s%s%s) %s→%s %s%s%s\n", dim, rst, cyan, $3, rst, yellow, $2, rst, dim, rst, white, $4, rst }' "$CACHE_DIR/.mt_data.tsv"
      echo ""
      ;;
    *)
      local target_cat="${1,,}"
      echo -e "\n${CB_BLUE}▶ CATEGORY: ${1}${C_RESET}\n"
      awk -F'\t' -v target="$target_cat" -v dim="$C_DIM" -v cyan="$CB_CYAN" -v white="$C_WHITE" -v rst="$C_RESET" 'tolower($2) == target { printf "  %s•%s %s%-24s%s %s→%s %s%s%s\n", dim, rst, cyan, $3, rst, dim, rst, white, $4, rst }' "$CACHE_DIR/.mt_data.tsv"
      echo ""
      ;;
  esac
}
```

#### `mt-lookup`

> MyTools: Search through available mytools commands with tab-completion

```bash
#######################################
# MyTools: Search through available mytools commands with tab-completion
# Usage: mt-lookup [-i|--interactive] [-v|--verbose] [keyword]
# Arguments:
#   -i, --interactive  Open an fzf menu to select a tool
#   -v, --verbose      Open interactive menu and print the full code using mt-help -v
#   $1                 Search term or command name
#######################################
mt-lookup() {
  local interactive=false
  local verbose=false
  local query=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -i | --interactive) interactive=true ;;
      -v | --verbose) verbose=true ;;
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -*)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        echo "Usage: mt-lookup [-i|--interactive] [-v|--verbose] [keyword]"
        return 1
        ;;
      *) query="$1" ;;
    esac
    shift
  done

  mytools > /dev/null
  local tsv_file="$CACHE_DIR/.mt_data.tsv"

  # Trigger the menu if -i or -v is passed
  if [ "$interactive" = true ] || [ "$verbose" = true ]; then
    local selected
    if [ -n "$query" ]; then
      selected=$(awk -F'\t' -v q="${query,,}" 'tolower($0) ~ q { printf "%-24s │ %-20s │ %s\n", $3, $2, $4 }' "$tsv_file" | fzf --ansi --prompt="Select Tool > " --header="COMMAND                  │ CATEGORY             │ DESCRIPTION")
    else
      selected=$(awk -F'\t' '{ printf "%-24s │ %-20s │ %s\n", $3, $2, $4 }' "$tsv_file" | fzf --ansi --prompt="Select Tool > " --header="COMMAND                  │ CATEGORY             │ DESCRIPTION")
    fi

    if [ -n "$selected" ]; then
      local cmd_name
      cmd_name=$(echo "$selected" | awk '{print $1}')
      if [ "$verbose" = true ]; then
        mt-help -v "$cmd_name"
      else
        mt-help "$cmd_name"
      fi
    fi
  else
    if [ -z "$query" ]; then
      echo "Usage: mt-lookup [-i|--interactive] [-v|--verbose] <keyword|command>"
      return 1
    fi
    # Standard non-interactive output
    awk -F'\t' -v q="${query,,}" -v dim="$C_DIM" -v cyan="$CB_CYAN" -v yellow="$CB_YELLOW" -v white="$C_WHITE" -v rst="$C_RESET" 'tolower($0) ~ q { printf "  %s•%s %s%-24s%s (%s%s%s) %s→%s %s%s%s\n", dim, rst, cyan, $3, rst, yellow, $2, rst, dim, rst, white, $4, rst }' "$tsv_file"
  fi
}
```

#### `mt-refresh-caches`

> System: Forcefully clear and rebuild all background caches (.env, mytools, updates)

```bash
#######################################
# System: Forcefully clear and rebuild all background caches (.env, mytools, updates)
#######################################
mt-refresh-caches() {
  # Self-heal missing cache directories (e.g., after clean git clone or update)
  mkdir -p "$CACHE_DIR" "$LOG_DIR" "$CONFIG_DIR"

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  echo -e "${CB_YELLOW}🧹 Clearing background caches...${C_RESET}"
  rm -f "$CACHE_DIR/.env.cache"
  rm -f "$HOME/.bash.d/config/.env.cache" # stray pre-fix location, harmless no-op once cleaned up
  # Legacy pre-migration cache locations (harmless no-op post-migration)
  rm -f "$HOME/.bash.d/.mt_cache" "$HOME/.bash.d/.mt_cache.time" "$HOME/.bash.d/.mt_data.tsv" 2> /dev/null
  rm -f "$HOME/.bash.d/.zoxide_cache.sh" "$HOME/.bash.d/.update_check_cache" "$HOME/.bash.d/.update_pending" 2> /dev/null
  rm -f "$HOME/.bash.d/.profile_update_cache" "$HOME/.bash.d/.profile_update_pending" 2> /dev/null
  rm -f "$CACHE_DIR/.mt_cache" "$CACHE_DIR/.mt_cache.time" "$CACHE_DIR/.mt_data.tsv"
  rm -f "$CACHE_DIR/.update_check_cache" "$CACHE_DIR/.update_pending"
  rm -f "$CACHE_DIR/.zoxide_cache.sh"
  rm -f "$CACHE_DIR/.profile_update_cache" "$CACHE_DIR/.profile_update_pending"
  rm -f "$CACHE_DIR/.kubectl_completion.bash"
  rm -f "$CACHE_DIR/.deps_check_cache" "$CACHE_DIR/.deps_pending"

  echo -e "${CB_BLUE}🔄 Rebuilding configurations and tool indexes...${C_RESET}"
  if [ -f "$HOME/.bash.d/lib/python/config_manager.py" ]; then
    mkdir -p "$CACHE_DIR" "$LOG_DIR" "$CONFIG_DIR"
    python3 "$HOME/.bash.d/lib/python/config_manager.py" load-env > "$CACHE_DIR/.env.cache"
    chmod 600 "$CACHE_DIR/.env.cache" 2> /dev/null
  fi

  __rebuild_mytools_cache

  source "$HOME/.bashrc"
  echo -e "${CB_GREEN}✅ All system caches refreshed successfully.${C_RESET}"
}
```

#### `mt-run`

> MyTools: Interactive fuzzy-finder to select and execute a command

```bash
#######################################
# MyTools: Interactive fuzzy-finder to select and execute a command
#######################################
mt-run() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }
  mytools > /dev/null
  local selected
  selected=$(awk -F'\t' '{ printf "%-24s │ %-20s │ %s\n", $3, $2, $4 }' "$CACHE_DIR/.mt_data.tsv" | fzf --ansi --prompt="Run Tool > " --header="COMMAND                  │ CATEGORY             │ DESCRIPTION")
  if [ -n "$selected" ]; then
    local cmd_name
    cmd_name=$(echo "$selected" | awk '{print $1}')
    echo -e "${CB_GREEN}🚀 Executing:${C_RESET} ${cmd_name}"
    eval "$cmd_name"
  fi
}
```

#### `mt-status`

> System: Display a unified health check and status dashboard

```bash
#######################################
# System: Display a unified health check and status dashboard
# Usage: mt-status [-j|--json]
# Options:
#   -j, --json   Print the same data as one JSON object instead of the
#                colorized dashboard (for scripts/editor integrations)
#   -h, --help   Show this help menu
#######################################
mt-status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local json_mode=false
  [[ "$1" == "-j" || "$1" == "--json" ]] && json_mode=true

  local current_version="Local"
  [ -f "$VERSION_FILE" ] && current_version=$(tr -d '[:space:]' < "$VERSION_FILE")

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  local repo_initialized=false repo_branch="" repo_changes=0
  if [ -n "$repo_dir" ] && [ -d "$repo_dir/.git" ]; then
    repo_initialized=true
    repo_branch=$(git -C "$repo_dir" branch --show-current 2> /dev/null)
    repo_changes=$(git -C "$repo_dir" status --porcelain 2> /dev/null | wc -l)
  fi

  local docker_running=false docker_containers_running=0 docker_containers_total=0
  if command -v docker > /dev/null 2>&1 && docker info > /dev/null 2>&1; then
    docker_running=true
    docker_containers_running=$(docker ps -q 2> /dev/null | wc -l)
    docker_containers_total=$(docker ps -aq 2> /dev/null | wc -l)
  fi

  local os_updates_pending=0
  [ -f "$CACHE_DIR/.update_pending" ] && os_updates_pending=$(tr -d '[:space:]' < "$CACHE_DIR/.update_pending")

  local framework_update_available=""
  [ -f "$CACHE_DIR/.profile_update_pending" ] && framework_update_available=$(tr -d '[:space:]' < "$CACHE_DIR/.profile_update_pending")

  if [ "$json_mode" = true ]; then
    jq -n \
      --arg version "$current_version" \
      --arg theme "${BASH_THEME:-default}" \
      --argjson ai_enabled "$([ "${AI_ENABLED:-true}" = "true" ] && echo true || echo false)" \
      --arg ai_provider "${DEFAULT_AI:-gemini}" \
      --argjson repo_initialized "$repo_initialized" \
      --arg repo_path "$repo_dir" \
      --arg repo_branch "$repo_branch" \
      --argjson repo_uncommitted "$repo_changes" \
      --argjson docker_running "$docker_running" \
      --argjson docker_containers_running "$docker_containers_running" \
      --argjson docker_containers_total "$docker_containers_total" \
      --argjson os_updates_pending "$os_updates_pending" \
      --arg fw_update "$framework_update_available" \
      '{framework: {version: $version, theme: $theme, ai_enabled: $ai_enabled, ai_provider: $ai_provider}, sync_repo: {initialized: $repo_initialized, path: $repo_path, branch: $repo_branch, uncommitted_files: $repo_uncommitted}, docker: {daemon_running: $docker_running, containers_running: $docker_containers_running, containers_total: $docker_containers_total}, updates: {os_packages_pending: $os_updates_pending, framework_update_available: (if ($fw_update | length) > 0 then $fw_update else null end)}}'
    return 0
  fi

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}                 MT DEVOPS DASHBOARD                      ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"

  echo -e "${CB_YELLOW}▶ FRAMEWORK${C_RESET}"
  echo -e "  ${CB_CYAN}Version       ${C_RESET}: ${current_version}"
  echo -e "  ${CB_CYAN}Theme         ${C_RESET}: ${BASH_THEME:-default}"
  echo -e "  ${CB_CYAN}AI Enabled    ${C_RESET}: ${AI_ENABLED:-true} (${DEFAULT_AI:-gemini})"

  echo -e "\n${CB_YELLOW}▶ PROFILE SYNC REPO${C_RESET}"
  if [ "$repo_initialized" = true ]; then
    echo -e "  ${CB_CYAN}Path          ${C_RESET}: ${repo_dir}"
    echo -e "  ${CB_CYAN}Branch        ${C_RESET}: ${repo_branch}"
    if [ "$repo_changes" -gt 0 ]; then
      echo -e "  ${CB_CYAN}Uncommitted   ${C_RESET}: ${CB_RED}${repo_changes} file(s) (Run mt-push-update)${C_RESET}"
    else
      echo -e "  ${CB_CYAN}Uncommitted   ${C_RESET}: ${CB_GREEN}Clean${C_RESET}"
    fi
  else
    echo -e "  ${CB_RED}Not initialized or not a Git repository. Run mt-setup to configure.${C_RESET}"
  fi

  echo -e "\n${CB_YELLOW}▶ DOCKER ENVIRONMENT${C_RESET}"
  if [ "$docker_running" = true ]; then
    echo -e "  ${CB_CYAN}Daemon        ${C_RESET}: ${CB_GREEN}Running${C_RESET}"
    echo -e "  ${CB_CYAN}Containers    ${C_RESET}: ${docker_containers_running} running / ${docker_containers_total} total"
  else
    echo -e "  ${CB_CYAN}Daemon        ${C_RESET}: ${CB_RED}Stopped or Not Installed${C_RESET}"
  fi

  echo -e "\n${CB_YELLOW}▶ SYSTEM UPDATES${C_RESET}"
  if [ "$os_updates_pending" -gt 0 ]; then
    echo -e "  ${CB_CYAN}OS Packages   ${C_RESET}: ${CB_RED}${os_updates_pending} available (Run sys-install)${C_RESET}"
  else
    echo -e "  ${CB_CYAN}OS Packages   ${C_RESET}: ${CB_GREEN}Up to date${C_RESET}"
  fi

  if [ -n "$framework_update_available" ]; then
    echo -e "  ${CB_CYAN}Framework     ${C_RESET}: ${CB_RED}${framework_update_available} available (Run mt-get-update)${C_RESET}"
  else
    echo -e "  ${CB_CYAN}Framework     ${C_RESET}: ${CB_GREEN}Up to date${C_RESET}"
  fi

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
}
```

#### `mytools`

> MyTools: Primary runner and documentation index

```bash
#######################################
# MyTools: Primary runner and documentation index
#######################################
mytools() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }

  local bashd_dir="$HOME/.bash.d"
  local cache_file="$CACHE_DIR/.mt_cache"
  local time_file="${cache_file}.time"
  local latest_mod
  latest_mod=$(__bashd_latest_mod "$bashd_dir")

  if [ ! -f "$cache_file" ] || [ ! -f "$time_file" ] || [ "$(command cat "$time_file" 2> /dev/null)" != "$latest_mod" ]; then
    __rebuild_mytools_cache
  fi
  cat "$cache_file"
}
```

### 📂 Networking: Speed Test Utility


#### `mt-speedtest`

> Networking: Run an internet speed test via the Ookla Speedtest CLI,

```bash
#######################################
# Networking: Run an internet speed test via the Ookla Speedtest CLI,
# offering to install it first (via bootstrap's __install_speedtest) if
# it isn't already present
# Usage: mt-speedtest [-j]
# Options:
#   -j, --json  Output raw JSON instead of the formatted report
#######################################
mt-speedtest() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local json_output=false
  case "$1" in
    -j | --json) json_output=true ;;
    -*)
      echo "Usage: mt-speedtest [-j|--json]" >&2
      return 1
      ;;
  esac

  if ! command -v speedtest > /dev/null 2>&1; then
    echo -e "${CB_YELLOW}⚠️  Ookla Speedtest CLI is not installed.${C_RESET}"
    local reply
    if ! read -r -p "Install it now? [Y/n] " -n 1 reply < /dev/tty; then
      reply="n"
    fi
    echo
    if [[ ! $reply =~ ^[Yy]$ ]] && [ -n "$reply" ]; then
      echo -e "${CB_YELLOW}🛑 Aborted. Run 'bootstrap' anytime to install it.${C_RESET}"
      return 1
    fi
    __install_speedtest || return 1
  fi

  echo -e "${CB_BLUE}🌐 Running internet speed test...${C_RESET}"
  if [ "$json_output" = true ]; then
    speedtest --accept-license --accept-gdpr -f json
  else
    speedtest --accept-license --accept-gdpr
  fi
}
```

### 📂 Path & URL Launchers (Config-Driven)


#### `cd-ai-workspace`

> AI: Change directory to unified AI workspace

```bash
#######################################
# AI: Change directory to unified AI workspace
# Globals:
#   AI_WORKSPACE_DIR
#######################################
cd-ai-workspace() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  cd "$AI_WORKSPACE_DIR" || echo "🚨 Error: AI_WORKSPACE_DIR not set."
}
```

#### `cd-win-docker`

> Docker: Change to Docker directory (from config.yaml) and open in Windows Explorer

```bash
#######################################
# Docker: Change to Docker directory (from config.yaml) and open in Windows Explorer
#######################################
cd-win-docker() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local docker_path="$DOCKER_ROOT_DIR"

  if [ -d "$docker_path" ]; then
    echo -e "${CB_BLUE}📂 Navigating to ${docker_path}...${C_RESET}"
    cd "$docker_path" || return 1
    win-docker
  else
    echo -e "${CB_RED}🚨 Error: Directory does not exist on the Linux filesystem.${C_RESET}"
    return 1
  fi
}
```

#### `ide`

> System: Open current directory in the default IDE (VSCode/IntelliJ)

```bash
#######################################
# System: Open current directory in the default IDE (VSCode/IntelliJ)
# Globals:
#   DEFAULT_IDE
#######################################
ide() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local selected_ide="${DEFAULT_IDE:-vscode}"
  echo -e "${CB_GREEN}🚀 Opening current directory in ${selected_ide}...${C_RESET}"

  if [ "$selected_ide" = "intellij" ]; then
    __launch_intellij . || echo -e "${CB_RED}⚠️ Could not launch IntelliJ. Ensure 'idea' is on PATH (JetBrains Toolbox), or install IntelliJ IDEA via Homebrew on macOS.${C_RESET}"
  else
    code .
  fi
}
```

#### `mt-dotfiles`

> System: Change directory to dotfiles repository root

```bash
#######################################
# System: Change directory to dotfiles repository root
# Globals:
#   DOTFILES_DIR, SYNC_REPO_DIR
#######################################
mt-dotfiles() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local target="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  if [ -n "$target" ] && [ -d "$target" ]; then
    cd "$target" || return 1
  else
    echo "🚨 Error: DOTFILES_DIR is not set or directory does not exist."
    return 1
  fi
}
```

#### `mt-open-homepage`

> System: Open dotfiles repository remote URL in default web browser

```bash
#######################################
# System: Open dotfiles repository remote URL in default web browser
# Globals:
#   SYNC_REPO_URL
#######################################
mt-open-homepage() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [ -z "$SYNC_REPO_URL" ] || [ "$SYNC_REPO_URL" = "YOUR_SYNC_REPO_URL" ]; then
    echo "🚨 Error: No sync repository URL configured."
    return 1
  fi

  local web_url="$SYNC_REPO_URL"
  if [[ "$web_url" == git@* ]]; then
    web_url="${web_url#git@}"
    web_url="${web_url/:/\/}"
    web_url="https://${web_url}"
  fi
  web_url="${web_url%.git}"
  web_url=$(echo "$web_url" | sed -E 's#([^:])//+#\1/#g')

  echo "🌐 Opening $web_url in browser..."
  __open_url "$web_url"
}
```

#### `win-ai-workspace`

> AI: Open unified AI workspace in the platform's native file manager (shortcut for `win ai`)

```bash
#######################################
# AI: Open unified AI workspace in the platform's native file manager (shortcut for `win ai`)
#######################################
win-ai-workspace() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  win ai
}
```

#### `win-docker`

> Docker: Open Docker root directory in the platform's native file manager (shortcut for `win docker`)

```bash
#######################################
# Docker: Open Docker root directory in the platform's native file manager (shortcut for `win docker`)
#######################################
win-docker() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  win docker
}
```

#### `win-sync`

> System: Open sync repository in the platform's native file manager (shortcut for `win sync`)

```bash
#######################################
# System: Open sync repository in the platform's native file manager (shortcut for `win sync`)
#######################################
win-sync() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  win sync
}
```

### 📂 Private Aliases (local-only -- never synced to the framework repo)


#### `mt-apply`

> System: Safely execute or write clipboard code without terminal paste truncation

```bash
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
```

#### `mt-cmd-history`

> System: Display history of executed framework commands

```bash
#######################################
# System: Display history of executed framework commands
# Usage: mt-cmd-history [-i|--interactive] [-n count] [-j|--json]
# Options:
#   -i, --interactive  Select a past framework command via fzf to re-run
#   -n, --lines <num>  Number of entries to show (default: 20)
#   -j, --json         Print entries as a JSON array ({command}, oldest-last) instead of the numbered list
#######################################
mt-cmd-history() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local interactive=false
  local limit=20
  local json_mode=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -i | --interactive) interactive=true ;;
      -n | --lines)
        limit="$2"
        shift
        ;;
      -j | --json) json_mode=true ;;
      *)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
    shift
  done

  local tsv_file="$CACHE_DIR/.mt_data.tsv"
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
    if [ "$json_mode" = true ]; then
      echo "[]"
    else
      echo -e "${CB_YELLOW}⚠️ No recorded framework commands found in shell history.${C_RESET}"
    fi
    rm -f "$tmp_hist"
    return 0
  fi

  if [ "$json_mode" = true ]; then
    jq -R -n -c '[inputs | select(length > 0) | {command: .}]' "$tmp_hist"
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
```

### 📂 Secrets Management


#### `mt-add-bitbucket-secret`

> System: Interactively add or update your Bitbucket API token, paired

```bash
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
```

#### `mt-add-claude-key`

> AI: Interactively add or update your Claude API key

```bash
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
```

#### `mt-add-dockerhub-secret`

> System: Interactively add or update your Docker Hub credentials,

```bash
#######################################
# System: Interactively add or update your Docker Hub credentials,
# paired with the account username -- Docker Hub authenticates pushes
# via 'docker login -u <username> --password-stdin', so both are always
# collected and stored together, same reasoning as Bitbucket's
# email+token pairing.
# Usage: mt-add-dockerhub-secret
# Globals:
#   Writes to ~/secrets/secrets.sh (never touches config.yaml or git)
#   and exports DOCKERHUB_USERNAME/DOCKERHUB_TOKEN into the current
#   shell immediately.
#######################################
mt-add-dockerhub-secret() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local username
  read -r -p "🐳 Docker Hub username: " username < /dev/tty
  if [ -z "$username" ]; then
    echo -e "${CB_YELLOW}⚠️  No username entered. Aborted.${C_RESET}"
    return 1
  fi

  local token
  read -r -s -p "🔑 Enter your Docker Hub access token (input hidden): " token < /dev/tty
  echo
  if [ -z "$token" ]; then
    echo -e "${CB_YELLOW}⚠️  No token entered. Aborted.${C_RESET}"
    return 1
  fi

  local expiry
  read -r -p "📅 Token expiry date, YYYY-MM-DD (leave blank if unknown): " expiry < /dev/tty
  if [ -n "$expiry" ] && ! [[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo -e "${CB_YELLOW}⚠️  '$expiry' doesn't look like YYYY-MM-DD -- saving without an expiry date.${C_RESET}"
    expiry=""
  fi

  __mt_write_secret "DOCKERHUB_USERNAME" "$username"
  __mt_write_secret "DOCKERHUB_TOKEN" "$token"
  export DOCKERHUB_USERNAME="$username"
  export DOCKERHUB_TOKEN="$token"
  python3 "$SECRETS_MANAGER" register "DOCKERHUB_TOKEN" "$expiry"
  echo -e "${CB_GREEN}🎉 Docker Hub credentials saved to ~/secrets/secrets.sh and loaded into this shell.${C_RESET}"
}
```

#### `mt-add-gemini-key`

> AI: Interactively add or update your Gemini API key

```bash
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
```

#### `mt-add-nvd-key`

> Repo: Interactively add or update your NVD (National Vulnerability

```bash
#######################################
# Repo: Interactively add or update your NVD (National Vulnerability
# Database) API key -- optional, but without one mt-audit-deps's Maven
# branch (OWASP dependency-check) is throttled hard by NVD's public rate
# limit while it builds its local CVE database on first run, turning a
# few-minute wait into potentially much longer. Free to request at
# https://nvd.nist.gov/developers/request-an-api-key.
# Usage: mt-add-nvd-key
# Globals:
#   Writes to ~/secrets/secrets.sh (never touches config.yaml or git)
#   and exports NVD_API_KEY into the current shell immediately.
#######################################
mt-add-nvd-key() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local key
  read -r -s -p "🔑 Enter your NVD API key (input hidden): " key < /dev/tty
  echo

  if [ -z "$key" ]; then
    echo -e "${CB_YELLOW}⚠️  No key entered. Aborted.${C_RESET}"
    return 1
  fi

  __mt_write_secret "NVD_API_KEY" "$key"
  export NVD_API_KEY="$key"
  python3 "$SECRETS_MANAGER" register "NVD_API_KEY"
  echo -e "${CB_GREEN}✅ NVD API key saved to ~/secrets/secrets.sh and loaded into this shell.${C_RESET}"
}
```

#### `mt-secrets`

> System: Interactive menu for managing the framework's supported

```bash
#######################################
# System: Interactive menu for managing the framework's supported
# secrets (currently Gemini, Claude, Bitbucket, Docker Hub) -- add/update, delete,
# and view metadata (system, features using it, expiry, last used).
# Secret VALUES are never displayed, only whether each is configured.
# Usage: mt-secrets [--add <name>] [--delete <name>]
# Options:
#   --add <name>      Run the real add/update command for one registered
#                      secret name directly (no fzf picker) -- still
#                      prompts for the value itself on /dev/tty, so this
#                      needs a real attached terminal.
#   --delete <name>   Delete one configured secret by name, no fzf
#                      picker and no confirmation prompt of its own --
#                      the caller is responsible for confirming first.
#   -h, --help        Show this help menu
#######################################
mt-secrets() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local add_name="" delete_name=""
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --add)
        add_name="$2"
        shift
        ;;
      --delete)
        delete_name="$2"
        shift
        ;;
      *)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
    shift
  done

  if [ -n "$add_name" ]; then
    __mt_secrets_add_by_name "$add_name"
    return $?
  fi

  if [ -n "$delete_name" ]; then
    __mt_secrets_delete_by_name "$delete_name"
    return $?
  fi

  __mt_menu_submenu "🔐 Secrets Manager" \
    "List Secrets" __mt_secrets_print_table \
    "Add / Update a Secret" __mt_secrets_add_or_update \
    "Delete a Secret" __mt_secrets_delete \
    "View Secret Info" __mt_secrets_info
}
```

### 📂 System Diagnostics ("mt-doctor")


#### `mt-doctor`

> System: Diagnostic health-check for the framework's environment --

```bash
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
```

### 📂 System & Environment Bootstrap


#### `bootstrap`

> System: Bootstrap missing dependencies (Debian/WSL via APT, macOS via Homebrew)

```bash
#######################################
# System: Bootstrap missing dependencies (Debian/WSL via APT, macOS via Homebrew)
# Usage: bootstrap [OPTIONS]
# Options:
#   -h, --help    Show this help menu
#######################################
bootstrap() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo "🔍 Scanning system for missing dependencies..."

  if [ "$OS_FAMILY" = "macos" ]; then
    __bootstrap_brew
  else
    __bootstrap_apt
  fi
  __bootstrap_python
  __bootstrap_yq
  __bootstrap_external
  __bootstrap_check_complex

  echo -e "\n🎉 Environment bootstrap complete!"

  __bootstrap_gh_and_claude
}
```

#### `sys-install`

> System: Updates system packages and clears pending-update marker

```bash
#######################################
# System: Updates system packages and clears pending-update marker
# Usage: sys-install [OPTIONS]
# Options:
#   -h, --help    Show this help menu
#######################################
sys-install() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  sys-update
  rm -f "$CACHE_DIR/.update_pending"
}
```

#### `sys-update`

> System: Updates system packages (APT on Debian/WSL, Homebrew on macOS)

```bash
#######################################
# System: Updates system packages (APT on Debian/WSL, Homebrew on macOS)
# Usage: sys-update [OPTIONS]
# Options:
#   -h, --help    Show this help menu
#######################################
sys-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [ "$OS_FAMILY" = "macos" ]; then
    if ! command -v brew > /dev/null 2>&1; then
      echo "🚨 Homebrew not found. Run 'bootstrap' first."
      return 1
    fi
    brew update && brew upgrade
  else
    sudo apt update && sudo apt upgrade
  fi
}
```

### 📂 System: Interactive Master Menu


#### `mt-menu`

> System: Launch the interactive master router for the entire framework.

```bash
#######################################
# System: Launch the interactive master router for the entire framework.
# Categories are matched by exact label text rather than a numbered
# prefix, since fzf fuzzy-matches the text you type -- a visible number
# would suggest a quick-jump keystroke that doesn't actually work once
# more than 9 categories exist (typing "1" would fuzzy-match every label
# containing that digit, not just category 1).
# Usage: mt-menu
#######################################
mt-menu() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local -a labels=(
    "⚙️  Setup & Config"
    "🤖 AI Workflows"
    "📦 Code Exports"
    "🔍 Search & Docs"
    "🐳 Docker Tools"
    "⎈  Kubernetes Tools"
    "⛵ Helm Tools"
    "🧪 Minikube (Local Cluster)"
    "☁️  GCP"
    "🏔️  Terraform"
    "🌿 Git Workflows"
    "🛠️  General Utilities"
    "⚡ System & Bootstrap"
    "🚀 Launchers"
    "🔐 Secrets Manager"
    "🔒 Private Commands"
  )
  local -a commands=(
    __mt_menu_setup
    __mt_menu_ai
    __mt_menu_exports
    __mt_menu_docs
    __mt_menu_docker
    __mt_menu_k8s
    __mt_menu_helm
    __mt_menu_minikube
    __mt_menu_gcp
    __mt_menu_terraform
    __mt_menu_git
    __mt_menu_utilities
    __mt_menu_system
    __mt_menu_launchers
    mt-secrets
    __mt_menu_private
  )

  while true; do
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e "${CB_BLUE}              MT DEVOPS FRAMEWORK - MASTER MENU            ${C_RESET}"
    echo -e "${CB_BLUE}==========================================================${C_RESET}\n"

    local -a options=("${labels[@]}" "🚪 Exit")
    local choice
    choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="🚀 Select a category > " --height=~20 --layout=reverse --border)
    [ -z "$choice" ] && return 0
    [ "$choice" = "🚪 Exit" ] && return 0

    local i
    for i in "${!labels[@]}"; do
      if [ "${labels[$i]}" = "$choice" ]; then
        "${commands[$i]}"
        break
      fi
    done
  done
}
```

### 📂 System & Navigation Aliases


#### `clip`

> System: Pipe output to the system clipboard (e.g. cat file | clip)

```bash
#######################################
# System: Pipe output to the system clipboard (e.g. cat file | clip)
#######################################
clip() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __clip_copy
}
```

#### `win`

> System: Open a directory in the platform's native file manager

```bash
#######################################
# System: Open a directory in the platform's native file manager
# Usage: win [sync|ai|docker|export|vcs]
# Globals:
#   DOTFILES_DIR, SYNC_REPO_DIR, AI_WORKSPACE_DIR, DOCKER_ROOT_DIR, VCS_EXPORTS, VCS_ROOT
#######################################
win() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local target="$PWD"
  case "$1" in
    "") ;;
    sync) target="${DOTFILES_DIR:-$SYNC_REPO_DIR}" ;;
    ai) target="$AI_WORKSPACE_DIR" ;;
    docker) target="$DOCKER_ROOT_DIR" ;;
    export) target="$VCS_EXPORTS" ;;
    vcs) target="$VCS_ROOT" ;;
    *)
      echo "Usage: win [sync|ai|docker|export|vcs]" >&2
      return 1
      ;;
  esac
  __open_path_gui "$target"
}
```

#### `win-export`

> System: Open ~/vcs/personal/exports in the platform's native file manager (shortcut for `win export`)

```bash
#######################################
# System: Open ~/vcs/personal/exports in the platform's native file manager (shortcut for `win export`)
#######################################
win-export() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  win export
}
```

#### `win-vcs`

> System: Open ~/vcs in the platform's native file manager (shortcut for `win vcs`)

```bash
#######################################
# System: Open ~/vcs in the platform's native file manager (shortcut for `win vcs`)
#######################################
win-vcs() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  win vcs
}
```

### 📂 System Uninstaller ("mt-uninstall")


#### `mt-uninstall`

> System: Completely remove the MT DevOps Framework from this machine --

```bash
#######################################
# System: Completely remove the MT DevOps Framework from this machine --
# deletes ~/.bash.d and restores or removes ~/.bashrc, after a full
# backup and a typed "yes" confirmation (case-insensitive). Along the
# way, offers two independent choices: whether to preserve config.yaml/
# secrets_metadata.yaml/.vcs_radar.json outside ~/.bash.d (default: yes --
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

  echo -e "${CB_CYAN}config.yaml, secrets_metadata.yaml, and .vcs_radar.json won't survive a plain reinstall otherwise.${C_RESET}"
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
    echo -e "  ${CB_GREEN}💾 Preserve${C_RESET} config.yaml, secrets_metadata.yaml, .vcs_radar.json outside ~/.bash.d"
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
```

### 📂 Terraform & AI Integrations


#### `tf-ai-iam`

> AI: Analyze Terraform codebase for IAM requirements and optionally generate script

```bash
#######################################
# AI: Analyze Terraform codebase for IAM requirements and optionally generate script
# Usage: tf-ai-iam [-g] [-m model]
# Options:
#   -g            Generate a provisioning script instead of just outputting a chat analysis
#   -m <model>    Override the default AI model (e.g., gemini, claude)
#   -h, --help    Show this help menu
#######################################
tf-ai-iam() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local generate_script=false
  local override_ai=()

  local OPTIND opt
  while getopts "gm:" opt; do
    case ${opt} in
      g) generate_script=true ;;
      m) override_ai=("-m" "$OPTARG") ;;
      \?)
        echo "Usage: tf-ai-iam [-g] [-m gemini|claude]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  local tf_count
  tf_count=$(find . -maxdepth 3 -name "*.tf" 2> /dev/null | wc -l)
  if [ "$tf_count" -eq 0 ]; then
    echo "terraform modules not found"
    return 0
  fi

  local repo_name
  repo_name=$(basename "$(git rev-parse --show-toplevel 2> /dev/null || pwd)")

  local prompt
  prompt=$(__get_prompt "tf_iam_base")

  if [ "$generate_script" = true ]; then
    local target_dir="${SCRIPTS_IAM_DIR:-/tmp/scripts/iam}"
    mkdir -p "$target_dir"
    local target_script="${target_dir}/${repo_name}.sh"

    local script_prompt
    script_prompt=$(__get_prompt "tf_iam_script")
    prompt="${prompt}\n\n${script_prompt}"

    echo "🤖 Analyzing Terraform codebase and generating IAM provisioning script..."
    ai "${override_ai[@]}" -e -t "${repo_name}-iam-provisioning" -o "$target_script" "$prompt"
  else
    local chat_prompt
    chat_prompt=$(__get_prompt "tf_iam_chat")
    prompt="${prompt}\n\n${chat_prompt}"
    echo "🤖 Analyzing Terraform codebase for IAM requirements..."
    ai "${override_ai[@]}" -e "$prompt"
  fi
}
```

#### `tf-iam`

> AI: Analyze Terraform codebase for IAM requirements and optionally generate script (Alias for tf-ai-iam)

```bash
#######################################
# AI: Analyze Terraform codebase for IAM requirements and optionally generate script (Alias for tf-ai-iam)
# Usage: tf-iam [-g] [-m model]
#######################################
tf-iam() {
  tf-ai-iam "$@"
}
```

### 📂 Terraform Aliases


#### `tf-clean`

> Terraform: Aggressively clean local caching (.terraform, locks, plans)

```bash
#######################################
# Terraform: Aggressively clean local caching (.terraform, locks, plans)
#######################################
tf-clean() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo -e "${CB_RED}⚠️ WARNING: This will delete .terraform directories, lock files, and saved plans.${C_RESET}"
  read -r -p "Are you sure you want to proceed? [y/N] " -n 1 < /dev/tty || REPLY="n"
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Aborted."
    return 0
  fi
  echo "🧹 Cleaning local Terraform caches..."

  find . -type d -name ".terraform" -exec rm -rf {} + 2> /dev/null
  find . -type f -name ".terraform.lock.hcl" -delete 2> /dev/null
  find . -type f -name "tfplan" -delete 2> /dev/null
  echo -e "${CB_GREEN}✅ Clean complete. Run 'tfin' to reinitialize.${C_RESET}"
}
```

#### `tf-replace`

> Terraform: Replace a specific resource (Modern alternative to taint)

```bash
#######################################
# Terraform: Replace a specific resource (Modern alternative to taint)
# Arguments:
#   $1 - The resource address to replace (e.g., google_compute_instance.web)
#######################################
tf-replace() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [ -z "$1" ]; then
    echo "Usage: tf-replace <resource_address>"
    return 1
  fi
  echo "🔄 Planning replacement for: $1"
  terraform apply -replace="$1"
}
```

#### `tf-yaml`

> Terraform: Execute Terraform using a YAML config file for variables

```bash
#######################################
# Terraform: Execute Terraform using a YAML config file for variables
# Arguments:
#   $1 - Path to the YAML configuration file
#   $2 - (Optional) Target environment key if YAML is hierarchically structured
#   $@ - Terraform command and arguments (e.g., plan, apply)
#######################################
tf-yaml() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local yaml_file="$1"
  shift

  if [ -z "$yaml_file" ] || [ ! -f "$yaml_file" ]; then
    echo -e "${CB_RED}🚨 Error: You must provide a valid YAML file path.${C_RESET}"
    echo "Usage: tf-yaml <config.yaml> [environment] <terraform command> [args...]"
    return 1
  fi

  local env_name=""
  if [[ -n "$1" && ! "$1" =~ ^(-.*|plan|apply|destroy|init|validate|output|console|refresh|show|state|workspace|fmt|import)$ ]]; then
    env_name="$1"
    shift
  fi

  if [ $# -eq 0 ]; then
    echo -e "${CB_RED}🚨 Error: You must provide a Terraform command.${C_RESET}"
    echo "Usage: tf-yaml <config.yaml> [environment] <terraform command> [args...]"
    return 1
  fi

  if ! command -v yq > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 Error: 'yq' is not installed. Run 'bootstrap' to install it.${C_RESET}"
    return 1
  fi

  local tmp_vars
  tmp_vars=$(mktemp --suffix=.json)

  if [ -n "$env_name" ]; then
    echo -e "${CB_BLUE}🔄 Parsing variables for environment '${env_name}' from ${yaml_file}...${C_RESET}"
    local tmp_globals
    tmp_globals=$(mktemp)
    local tmp_env
    tmp_env=$(mktemp)

    yq 'del(.environments)' "$yaml_file" > "$tmp_globals"
    yq ".environments[\"${env_name}\"]" "$yaml_file" > "$tmp_env"

    if [ "$(command cat "$tmp_env")" = "null" ]; then
      echo -e "${CB_RED}🚨 Error: Environment '${env_name}' not found in ${yaml_file}.${C_RESET}"
      rm -f "$tmp_vars" "$tmp_globals" "$tmp_env"
      return 1
    fi

    yq -o=json eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$tmp_globals" "$tmp_env" > "$tmp_vars"
    rm -f "$tmp_globals" "$tmp_env"
  else
    echo -e "${CB_BLUE}🔄 Parsing variables from ${yaml_file}...${C_RESET}"
    yq -o=json '.' "$yaml_file" > "$tmp_vars"
  fi

  echo -e "${CB_GREEN}🚀 Executing: terraform $* -var-file=...${C_RESET}"
  terraform "$@" -var-file="$tmp_vars"
  local tf_exit=$?

  rm -f "$tmp_vars"
  return $tf_exit
}
```

### 📂 Terraform & Kubernetes Wrappers


#### `terraform`

> Terraform: Core wrapper (preserves args)

```bash
#######################################
# Terraform: Core wrapper (preserves args)
# Note: Does NOT intercept --help to preserve native terraform help.
# Run `mt-help terraform` for framework documentation.
#######################################
terraform() {
  echo "+ terraform $*" >&2
  command terraform "$@"
}
```

### 📂 Utilities: Background Job Registry


#### `mt-jobs`

> System: List and manage MT background jobs

```bash
#######################################
# System: List and manage MT background jobs
# Usage: mt-jobs [-i|--interactive] [-p|--purge] [-c|--clean] [-w|--watch]
#                [--restart <job_id>] [--stop <job_id>] [--remove <job_id>]
# Options:
#   -i, --interactive     fzf-pick a job, then an action to run against it
#   -p, --purge           Kill every RUNNING job (marks them CANCELLED)
#   -c, --clean           Drop every finished (non-RUNNING) job and its log
#   -w, --watch           Live-refreshing table view (Ctrl+C to exit)
#   --restart <job_id>    Replay one job's original command as a new job
#   --stop <job_id>       Cancel one RUNNING job by ID
#   --remove <job_id>     Drop one job's history entry (and log) by ID
#   -h, --help            Show this help menu
#######################################
mt-jobs() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local jobs_file="$CACHE_DIR/.mt_jobs.tsv"
  local interactive=false do_purge=false do_clean=false watch=false
  local restart_id="" stop_id="" remove_id=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -i | --interactive) interactive=true ;;
      -p | --purge) do_purge=true ;;
      -c | --clean) do_clean=true ;;
      -w | --watch) watch=true ;;
      --restart)
        restart_id="$2"
        shift
        ;;
      --stop)
        stop_id="$2"
        shift
        ;;
      --remove)
        remove_id="$2"
        shift
        ;;
      *)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
    shift
  done

  if [ -n "$restart_id" ]; then
    __mt_jobs_restart_by_id "$restart_id"
    return $?
  fi

  if [ -n "$stop_id" ]; then
    local current_time
    current_time=$(date +%s)
    __mt_jobs_stop_by_id "$stop_id"
    return $?
  fi

  if [ -n "$remove_id" ]; then
    __mt_jobs_remove_by_id "$remove_id"
    return $?
  fi

  if [ "$do_purge" = true ]; then
    local current_time
    current_time=$(date +%s)
    __mt_jobs_purge
    return 0
  fi

  if [ "$do_clean" = true ]; then
    __mt_jobs_clean
    return 0
  fi

  if [ "$watch" = true ]; then
    local current_time
    while true; do
      if [ ! -f "$jobs_file" ] || [ ! -s "$jobs_file" ]; then
        printf '\033[H\033[2J'
        echo -e "${CB_YELLOW}⚠️ No background jobs found.${C_RESET}"
        echo -e "${C_DIM}Watching for jobs... Press Ctrl+C to exit.${C_RESET}"
        sleep 1
        continue
      fi

      current_time=$(date +%s)
      __mt_jobs_reap_orphans

      printf '\033[H\033[2J'
      echo -e "${CB_BLUE}📊 MT Background Jobs — Live${C_RESET}"
      echo -e "${C_DIM}Refreshing every second • Press Ctrl+C to exit${C_RESET}"
      echo

      __mt_jobs_render_table
      __mt_jobs_print_table

      sleep 1
    done
  fi

  if [ ! -f "$jobs_file" ] || [ ! -s "$jobs_file" ]; then
    echo -e "${CB_YELLOW}⚠️ No background jobs found.${C_RESET}"
    return 0
  fi

  local current_time
  current_time=$(date +%s)

  __mt_jobs_reap_orphans

  local tmp_out
  __mt_jobs_render_table

  if [ "$interactive" = false ]; then
    __mt_jobs_print_table
    return 0
  fi

  __mt_jobs_interactive_select
}
```

### 📂 Utilities: Backup & Restore


#### `mt-backup`

> System: Create an archive backup of the current directory

```bash
#######################################
# System: Create an archive backup of the current directory
# Usage: mt-backup [-f|--force] [-l|--list] [-o|--output format] [-d|--dir path]
# Options:
#   -l, --list     List existing backups for the current directory
#   -f, --force    Skip the size limit warning check
#   -o, --output   Archive format: zip (default), rar, tz, gzip
#   -d, --dir      Override the base destination directory
# Globals:
#   BACKUP_DIR
#######################################
mt-backup() {
  local force=false
  local list_mode=false
  local format="zip"

  local base_dest="${BACKUP_DIR:-/tmp/backups}"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -l | --list) list_mode=true ;;
      -f | --force) force=true ;;
      -o | --output)
        format="${2,,}"
        shift
        ;;
      -d | --dir)
        base_dest="$2"
        shift
        ;;
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -*)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
      *) base_dest="$1" ;;
    esac
    shift
  done

  local threshold_mb="${BACKUP_WARNING_MB:-500}"

  if ! [[ "$threshold_mb" =~ ^[0-9]+$ ]]; then
    echo -e "${CB_RED}🚨 Error: 'backup_warning_mb' in config.yaml is invalid ('$threshold_mb'). It must be a whole number.${C_RESET}"
    return 1
  fi

  if [ "$list_mode" = false ]; then
    __mt_backup_check_size_warning || return 1
  fi

  # Sanitize target directory name (strip dots, special chars)
  local raw_dir_name
  raw_dir_name=$(basename "$(realpath "$PWD")")
  local safe_dir_name
  safe_dir_name=$(echo "$raw_dir_name" | tr -d '.' | sed 's/[^a-zA-Z0-9]/_/g')

  # Resolve base destination, expanding ~ if present
  local expanded_base="${base_dest/#\~/$HOME}"
  local dest="${expanded_base}/${safe_dir_name}"

  if [ "$list_mode" = true ]; then
    __mt_backup_list
    return 0
  fi

  __mt_backup_create
}
```

#### `mt-restore`

> System: Restore framework from a zip backup

```bash
#######################################
# System: Restore framework from a zip backup
# Usage: mt-restore [backup_file] [-i|--interactive]
# Options:
#   -i, --interactive  Choose a backup from an fzf menu
#######################################
mt-restore() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local selected_backup=""
  local backup_base_dir="${BACKUP_DIR:-$HOME/backups}"

  if [ -n "$1" ] && [ "$1" != "-i" ] && [ "$1" != "--interactive" ]; then
    if [ -f "$1" ]; then
      selected_backup="$1"
    elif [ -f "${backup_base_dir}/$1" ]; then
      selected_backup="${backup_base_dir}/$1"
    elif [ -f "${backup_base_dir}/bashd/$1" ]; then
      selected_backup="${backup_base_dir}/bashd/$1"
    else
      echo -e "${CB_RED}🚨 Backup file not found: $1${C_RESET}"
      return 1
    fi
  else
    echo -e "${CB_BLUE}🔍 Scanning for available backups in ${backup_base_dir}...${C_RESET}"
    local tmp_list
    tmp_list=$(mktemp)
    find "$backup_base_dir" -type f -name "*.zip" 2> /dev/null | sort -r > "$tmp_list"

    if [ ! -s "$tmp_list" ]; then
      echo -e "${CB_YELLOW}⚠️ No backup zip files found in ${backup_base_dir}.${C_RESET}"
      rm -f "$tmp_list"
      return 1
    fi

    selected_backup=$(fzf --prompt="Select Backup to Restore > " --header="Available Framework Backups" < "$tmp_list")
    rm -f "$tmp_list"

    [ -z "$selected_backup" ] && return 0
  fi

  echo -e "${CB_CYAN}📦 Selected Backup: ${selected_backup}${C_RESET}"
  read -r -p "🚀 Are you sure you want to restore this backup? [y/N] " -n 1
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${CB_RED}🛑 Restore aborted.${C_RESET}"
    return 0
  fi

  # 1. Pre-restore Safety Backup
  echo -e "${CB_BLUE}🛡️ Creating safety backup of current codebase before restoring...${C_RESET}"
  local pre_dest="${backup_base_dir}/pre-restore"
  mkdir -p "$pre_dest"
  local timestamp
  timestamp=$(date +"%Y%m%d_%H%M%S")
  local safety_file="${pre_dest}/pre_restore_safety_${timestamp}.zip"

  (
    cd "$HOME" || exit 1
    zip -q -r "$safety_file" .bash.d -x ".bash.d/.git/*" -x ".bash.d/data/cache/*" -x ".bash.d/node_modules/*" -x ".bash.d/**/__pycache__/*"
  )
  echo -e "${CB_GREEN}✅ Safety backup saved: ${safety_file}${C_RESET}"

  # 2. Extract selected backup
  echo -e "${CB_YELLOW}🔄 Restoring .bash.d directory...${C_RESET}"
  if ! unzip -q -o "$selected_backup" -d "$HOME/"; then
    echo -e "${CB_RED}🚨 Unzip failed during restore!${C_RESET}"
    return 1
  fi

  # 3. Sync to Git Workspace
  local git_repo_path="${DOTFILES_DIR:-$HOME/vcs/personal/mt-devops-framework}"
  if __mt_bashd_is_symlinked_into_repo "$git_repo_path"; then
    echo -e "${C_DIM}↪️  ~/.bash.d is already a symlink into ${git_repo_path}/.bash.d -- nothing separate to sync.${C_RESET}"
  elif [ -d "$git_repo_path" ]; then
    echo -e "${CB_BLUE}🔄 Syncing restored files to Git workspace (${git_repo_path})...${C_RESET}"
    rsync -a -u --delete "$HOME/.bash.d/" "${git_repo_path}/.bash.d/"
  fi

  echo -e "${CB_GREEN}🎉 Restore complete! Rebuilding caches...${C_RESET}"
  mt-refresh-caches > /dev/null 2>&1
}
```

### 📂 Utilities: Centralized Framework Logging


#### `mt-log`

> System: Centralized logging for MyTools

```bash
#######################################
# System: Centralized logging for MyTools
# Arguments:
#   $1 - Log level (INFO, SUCCESS, WARN, ERROR)
#   $2 - Message
#######################################
mt-log() {
  local level="$1"
  local msg="$2"
  local log_file="$LOG_DIR/framework.log"

  # Console Output
  case "$level" in
    INFO) echo -e "${CB_BLUE}ℹ️ ${msg}${C_RESET}" ;;
    SUCCESS) echo -e "${CB_GREEN}✅ ${msg}${C_RESET}" ;;
    WARN) echo -e "${CB_YELLOW}⚠️ ${msg}${C_RESET}" ;;
    ERROR) echo -e "${CB_RED}🚨 ${msg}${C_RESET}" >&2 ;;
    *) echo "$msg" ;;
  esac

  # File Logging (with 1MB basic rotation)
  mkdir -p "$LOG_DIR" 2> /dev/null
  if [ -f "$log_file" ]; then
    local size
    size=$(wc -c < "$log_file" 2> /dev/null || echo 0)
    if [ "$size" -gt "${LOG_ROTATE_BYTES:-1048576}" ]; then
      mv "$log_file" "${log_file}.old" 2> /dev/null
    fi
  fi

  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$ts] [$level] $msg" >> "$log_file" 2> /dev/null
}
```

#### `mt-logs`

> System: View, filter, and manage framework logs

```bash
#######################################
# System: View, filter, and manage framework logs
# Usage: mt-logs [-n lines] [-l level] [-s keyword] [-o] [-f] [-c] [-j|--json]
# Options:
#   -n, --lines <num>     Number of lines to display (default: 50)
#   -l, --level <level>   Filter by severity (INFO, SUCCESS, WARN, ERROR)
#   -s, --search <term>   Search for a specific keyword
#   -o, --open            Open the log file in your default IDE
#   -f, --follow          Tail the logs live
#   -c, --clear           Clear the log file
#   -j, --json            Print the matched lines as a JSON array of
#                          {ts, level, message} objects instead of raw
#                          text -- only applies to the default listing
#                          mode (ignored alongside -o/-f/-c)
#######################################
mt-logs() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local log_file="$LOG_DIR/framework.log"
  local lines=50
  local level_filter=""
  local search_term=""
  local do_open=false
  local do_follow=false
  local do_clear=false
  local json_mode=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -n | --lines)
        lines="$2"
        shift
        ;;
      -l | --level)
        level_filter="${2^^}"
        shift
        ;;
      -s | --search)
        search_term="$2"
        shift
        ;;
      -o | --open) do_open=true ;;
      -f | --follow) do_follow=true ;;
      -c | --clear) do_clear=true ;;
      -j | --json) json_mode=true ;;
      -*)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
    shift
  done

  if [ ! -f "$log_file" ]; then
    echo -e "${CB_YELLOW}⚠️ No log file found at $log_file${C_RESET}"
    return 0
  fi

  if [ "$do_clear" = true ]; then
    true > "$log_file"
    echo -e "${CB_GREEN}✅ Log file cleared.${C_RESET}"
    return 0
  fi

  if [ "$do_open" = true ]; then
    echo -e "${CB_BLUE}📂 Opening $log_file in ${DEFAULT_IDE:-vscode}...${C_RESET}"
    if [ "${DEFAULT_IDE:-vscode}" = "intellij" ]; then
      idea "$log_file" 2> /dev/null || cat "$log_file"
    else
      code "$log_file" 2> /dev/null || cat "$log_file"
    fi
    return 0
  fi

  if [ "$do_follow" = true ]; then
    tail -f "$log_file"
    return 0
  fi

  if [ "$json_mode" = true ]; then
    __mt_logs_filter_level "$level_filter" < "$log_file" | __mt_logs_filter_search "$search_term" | tail -n "$lines" |
      jq -R -n '[inputs | capture("^\\[(?<ts>[^]]+)\\] \\[(?<level>[^]]+)\\] (?<message>.*)$")? // {ts: null, level: null, message: .}]'
    return 0
  fi

  echo -e "${CB_CYAN}📜 Showing last $lines lines of framework logs...${C_RESET}"
  [ -n "$level_filter" ] && echo -e "${C_DIM}   Level: $level_filter${C_RESET}"
  [ -n "$search_term" ] && echo -e "${C_DIM}   Search: $search_term${C_RESET}"
  echo -e "${CB_BLUE}----------------------------------------------------------${C_RESET}"

  __mt_logs_filter_level "$level_filter" < "$log_file" | __mt_logs_filter_search "$search_term" | tail -n "$lines"
}
```

### 📂 Utilities: Temporary HTTP File Server


#### `mt-http-server`

> System: Host the current directory over a temporary HTTP server. Only

```bash
#######################################
# System: Host the current directory over a temporary HTTP server. Only
# one instance is supported at a time -- -b refuses to start a second one
# rather than running multiple concurrent servers. Binds to 127.0.0.1 only
# unless -w/LAN bridge is explicitly confirmed -- plain `mt-http-server`
# with no flags is never reachable from your network.
# Usage: mt-http-server [-p port] [-w|--no-wsl-bridge] [-a|--no-auth] [-t seconds|--no-idle-timeout] [-b] [--stop] [-l] [-i]
# Options:
#   -p, --port <port>          Specify custom port (default: config server.default_port, else 8000)
#   -w, --wsl-bridge            Prompt to expose the server to your LAN. On WSL this
#                               also adds a Windows portproxy + firewall rule (requires
#                               Admin elevation); on macOS/Linux it just binds every
#                               network interface instead of loopback-only. Default
#                               comes from config server.enable_lan_bridge.
#   --no-wsl-bridge             Force the LAN bridge off for this run, overriding a
#                               config default of true
#   -a, --auth                  Require HTTP Basic Auth -- generates a random
#                               password each run and prints it once. Default
#                               comes from config server.enable_auth.
#   --no-auth                   Force auth off for this run, overriding a config
#                               default of true
#   -t, --idle-timeout <secs>   Auto-shutdown after this many seconds with no
#                               requests. Default comes from config
#                               server.idle_timeout_sec (1800 = 30 minutes).
#   --no-idle-timeout           Disable auto-shutdown for this run
#   -b, --background            Run detached via the mt-jobs background registry
#                               instead of blocking the terminal. Refuses to start
#                               if an instance is already running.
#   --stop                      Stop the running background instance, if any, and
#                               tear down its LAN bridge if it had one
#   -l, --status                Show whether a background instance is running
#   -i, --wizard                Interactively set the config defaults above
#   -h, --help                  Show this help menu
# Globals:
#   OS_FAMILY, HTTP_SERVER_DEFAULT_PORT, HTTP_SERVER_ENABLE_AUTH,
#   HTTP_SERVER_ENABLE_LAN_BRIDGE, HTTP_SERVER_IDLE_TIMEOUT_SEC
#######################################
mt-http-server() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local port="${HTTP_SERVER_DEFAULT_PORT:-8000}"
  local expose_wsl="${HTTP_SERVER_ENABLE_LAN_BRIDGE:-false}"
  local require_auth="${HTTP_SERVER_ENABLE_AUTH:-false}"
  local idle_timeout="${HTTP_SERVER_IDLE_TIMEOUT_SEC:-1800}"
  local run_background=false do_stop=false do_status=false do_wizard=false
  local bridge_state_file="$CACHE_DIR/.mt_http_server_bridge_port"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --port)
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
          echo "mt-http-server: --port requires an integer between 1 and 65535" >&2
          return 1
        fi
        port="$2"
        shift 2
        ;;
      -w | --wsl-bridge)
        expose_wsl=true
        shift
        ;;
      --no-wsl-bridge)
        expose_wsl=false
        shift
        ;;
      -a | --auth)
        require_auth=true
        shift
        ;;
      --no-auth)
        require_auth=false
        shift
        ;;
      -t | --idle-timeout)
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          echo "mt-http-server: --idle-timeout requires a non-negative integer (seconds)" >&2
          return 1
        fi
        idle_timeout="$2"
        shift 2
        ;;
      --no-idle-timeout)
        idle_timeout=0
        shift
        ;;
      -b | --background)
        run_background=true
        shift
        ;;
      --stop)
        do_stop=true
        shift
        ;;
      -l | --status)
        do_status=true
        shift
        ;;
      -i | --wizard)
        do_wizard=true
        shift
        ;;
      *)
        echo "Usage: mt-http-server [-p port] [-w|--no-wsl-bridge] [-a|--no-auth] [-t seconds|--no-idle-timeout] [-b] [--stop] [-l] [-i]" >&2
        return 1
        ;;
    esac
  done

  if [ "$do_wizard" = true ]; then
    echo -e "${CB_BLUE}--- HTTP Server Configuration ---${C_RESET}"
    local val
    read -r -p "Default Port [${HTTP_SERVER_DEFAULT_PORT:-8000}]: " val
    [ -n "$val" ] && python3 "$CONFIG_MANAGER" update "server" "default_port" "$val"

    read -r -p "Require Auth by default? (true/false) [${HTTP_SERVER_ENABLE_AUTH:-false}]: " val
    [ -n "$val" ] && python3 "$CONFIG_MANAGER" update "server" "enable_auth" "$val"

    read -r -p "Expose to your LAN by default? (true/false) [${HTTP_SERVER_ENABLE_LAN_BRIDGE:-false}]: " val
    [ -n "$val" ] && python3 "$CONFIG_MANAGER" update "server" "enable_lan_bridge" "$val"

    read -r -p "Idle Timeout in seconds, 0 to disable [${HTTP_SERVER_IDLE_TIMEOUT_SEC:-1800}]: " val
    [ -n "$val" ] && python3 "$CONFIG_MANAGER" update "server" "idle_timeout_sec" "$val"

    echo -e "${CB_GREEN}✅ HTTP server config updated.${C_RESET}"
    return 0
  fi

  if [ "$do_status" = true ]; then
    local status_pid
    status_pid=$(__mt_http_server_running_job)
    if [ -n "$status_pid" ]; then
      echo -e "${CB_GREEN}✅ Running in background (PID ${status_pid}).${C_RESET}"
      [ -f "$bridge_state_file" ] && echo -e "${CB_CYAN}   LAN bridge active on port $(command cat "$bridge_state_file").${C_RESET}"
    else
      echo -e "${CB_YELLOW}⚠️  No background instance is running.${C_RESET}"
      if [ -f "$bridge_state_file" ]; then
        echo -e "${CB_RED}🚨 But a LAN bridge state file for port $(command cat "$bridge_state_file") still exists -- the Windows firewall rule/portproxy may still be open even though no server is running (likely left behind by an unclean shutdown). Run 'mt-http-server --stop' to clean it up.${C_RESET}"
      fi
    fi
    return 0
  fi

  if [ "$do_stop" = true ]; then
    local wrapper_pid
    wrapper_pid=$(__mt_http_server_running_job)
    if [ -z "$wrapper_pid" ]; then
      if [ -f "$bridge_state_file" ]; then
        echo -e "${CB_YELLOW}⚠️  No background instance is running, but a LAN bridge state file was left behind -- cleaning it up.${C_RESET}"
        __mt_http_server_teardown_bridge_if_active
      else
        echo -e "${CB_YELLOW}⚠️  No background instance is running.${C_RESET}"
      fi
      return 0
    fi

    local server_pid
    server_pid=$(__mt_http_server_pid)
    [ -n "$server_pid" ] && kill "$server_pid" 2> /dev/null

    echo -e "${CB_YELLOW}⏳ Stopping (may take a moment if a LAN bridge needs to be torn down)...${C_RESET}"
    local waited=0
    while kill -0 "$wrapper_pid" 2> /dev/null && [ "$waited" -lt 30 ]; do
      sleep 0.5
      waited=$((waited + 1))
    done

    if kill -0 "$wrapper_pid" 2> /dev/null; then
      echo -e "${CB_YELLOW}⚠️  Still shutting down in the background -- check 'mt-http-server -l' shortly.${C_RESET}"
    else
      echo -e "${CB_GREEN}✅ Background mt-http-server stopped.${C_RESET}"
    fi
    return 0
  fi

  if [ "$run_background" = true ]; then
    local existing_pid
    existing_pid=$(__mt_http_server_running_job)
    if [ -n "$existing_pid" ]; then
      echo -e "${CB_RED}🚨 A background mt-http-server is already running (PID ${existing_pid}).${C_RESET}"
      echo -e "${C_DIM}Only one instance is supported at a time. Run 'mt-http-server --stop' to stop it, or 'mt-jobs -i' to inspect it.${C_RESET}"
      return 1
    fi
  fi

  if [ "$require_auth" = true ] && ! command -v openssl > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 openssl is required for -a but was not found.${C_RESET}"
    return 1
  fi

  local -x MT_SERVE_BIND_ALL=""

  if [ "$expose_wsl" = true ]; then
    echo -e "${CB_YELLOW}⚠️  This will expose port ${port} to every device on your current network -- including public/untrusted Wi-Fi, not just a trusted home network.${C_RESET}"
    [ "${OS_FAMILY}" = "wsl" ] && echo -e "${CB_YELLOW}   On WSL this also opens a Windows firewall rule and requests Admin elevation.${C_RESET}"
    if [ "$require_auth" = true ]; then
      echo -e "${CB_CYAN}   Basic Auth will be required to connect.${C_RESET}"
    else
      echo -e "${CB_RED}   No authentication -- anyone who can reach this port can browse and download every file here.${C_RESET}"
    fi
    local reply
    read -r -p "Proceed? [y/N] " -n 1 reply < /dev/tty || reply="n"
    echo
    if [[ ! $reply =~ ^[Yy]$ ]]; then
      echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
      return 0
    fi
    MT_SERVE_BIND_ALL=1
  fi

  local cleaned_up=false
  __mt_http_server_cleanup() {
    [ "$cleaned_up" = true ] && return 0
    cleaned_up=true
    echo -e "\n${CB_YELLOW}🛑 Stopping server...${C_RESET}"
    __mt_http_server_teardown_bridge_if_active
    rm -f "$CACHE_DIR/.mt_http_server.pid"
  }

  echo -e "${CB_BLUE}🚀 Starting temporary HTTP server on port ${port}...${C_RESET}"

  if [ "$expose_wsl" = true ] && [ "${OS_FAMILY}" = "wsl" ]; then
    echo -e "${CB_YELLOW}⚠️  Requesting Windows Admin elevation to bridge the connection...${C_RESET}"
    if __mt_http_server_wsl_bridge "Add" "$port"; then
      echo -e "${CB_GREEN}✅ Portproxy established. LAN devices can connect!${C_RESET}"
      mt-log INFO "mt-http-server: WSL bridge for port ${port} established."
      echo "$port" > "$bridge_state_file"
    else
      echo -e "${CB_RED}🚨 Failed to establish the LAN bridge (elevation declined or unavailable). Continuing with local-only access.${C_RESET}"
      mt-log ERROR "mt-http-server: failed to establish the WSL portproxy/firewall bridge for port ${port}."
      expose_wsl=false
      MT_SERVE_BIND_ALL=""
    fi
  fi

  local -a serve_cmd=(python3 -m http.server "$port" --bind "$([ "$MT_SERVE_BIND_ALL" = 1 ] && echo "0.0.0.0" || echo "127.0.0.1")")
  local -x MT_SERVE_PORT="$port"
  local -x MT_SERVE_IDLE_TIMEOUT="$idle_timeout"
  # -b needs the custom script regardless of auth/idle-timeout, since
  # --stop targets the PID it writes to a pidfile -- plain
  # `python3 -m http.server` writes no such file, leaving --stop with
  # nothing to kill.
  local use_custom_script=false
  [ "$idle_timeout" -gt 0 ] && use_custom_script=true
  [ "$run_background" = true ] && use_custom_script=true

  if [ "$require_auth" = true ]; then
    local -x MT_SERVE_USER="mtserve"
    local -x MT_SERVE_PASSWORD
    MT_SERVE_PASSWORD=$(openssl rand -hex 8)
    use_custom_script=true

    echo -e "${CB_CYAN}🔐 Basic Auth enabled:${C_RESET}"
    echo -e "   ${CB_CYAN}Username:${C_RESET} ${MT_SERVE_USER}"
    echo -e "   ${CB_CYAN}Password:${C_RESET} ${MT_SERVE_PASSWORD}"
    echo -e "${C_DIM}(Sent as HTTP Basic Auth -- keeps casual LAN users out, not a substitute for TLS)${C_RESET}\n"
  fi

  if [ "$idle_timeout" -gt 0 ]; then
    echo -e "${CB_CYAN}⏱️  Auto-shutdown after ${idle_timeout}s of inactivity.${C_RESET}"
  fi

  [ "$use_custom_script" = true ] && serve_cmd=(python3 "$HOME/.bash.d/lib/python/mt_http_server.py")

  echo -e "${CB_CYAN}📡 Listening on:${C_RESET}"
  if [ "$MT_SERVE_BIND_ALL" = 1 ] && command -v ip > /dev/null 2>&1; then
    ip -4 addr show | grep inet | awk '{print "   http://" $2}' | sed 's|/.*||' | sed "s|$|:${port}|"
  else
    echo "   http://127.0.0.1:${port}"
  fi

  if [ "$run_background" = true ]; then
    echo "$port" > "$CACHE_DIR/.mt_http_server_port"

    local log_file
    log_file="$LOG_DIR/http_server_$(date +%s).log"

    # Deliberately NOT execed -- this wrapper subshell needs to stay alive
    # after the server process exits (whether via --stop or the server's
    # own idle-timeout auto-shutdown) so the cleanup steps below actually
    # run. --stop targets the server's own PID (from its pidfile, see
    # __mt_http_server_pid), not this wrapper's PID.
    local cmd_string part
    printf -v cmd_string '%q' "${serve_cmd[0]}"
    for part in "${serve_cmd[@]:1}"; do
      printf -v part '%q' "$part"
      cmd_string="$cmd_string $part"
    done
    # The pidfile removal is guarded by __mt_http_server_pid's own liveness
    # check rather than an unconditional rm -f: if two `-b` invocations
    # raced past the single-instance check before either registered, the
    # loser reaches this tail too, and an unconditional rm here would
    # delete the winner's still-valid pidfile out from under it.
    cmd_string="$cmd_string; __mt_http_server_teardown_bridge_if_active; rm -f '$CACHE_DIR/.mt_http_server_port'; [ -z \"\$(__mt_http_server_pid)\" ] && rm -f '$CACHE_DIR/.mt_http_server.pid'"

    __mt_bg_run "mt-http-server" "$log_file" "$cmd_string"
    echo -e "${C_DIM}Stop with: mt-http-server --stop${C_RESET}"
    return 0
  fi

  echo -e "${C_DIM}(Press Ctrl+C to stop)${C_RESET}\n"

  trap __mt_http_server_cleanup SIGINT
  "${serve_cmd[@]}"
  __mt_http_server_cleanup
  trap - SIGINT
}
```

#### `mt-serve`

> Utilities: Host the current directory over a temporary HTTP server

```bash
#######################################
# Utilities: Host the current directory over a temporary HTTP server
# (deprecated alias)
# Deprecated: use mt-http-server instead.
#######################################
mt-serve() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  mt-http-server "$@"
}
```

#### `mt-server-manager`

> Utilities: Interactive menu to manage the single mt-http-server

```bash
#######################################
# Utilities: Interactive menu to manage the single mt-http-server
# background instance -- narrowly scoped to genuinely server-specific
# actions (credentials, connection testing, browser launch); broader job
# management (cancel, restart, history) is delegated to the existing
# mt-jobs -i rather than rebuilt here.
# Usage: mt-server-manager
#######################################
mt-server-manager() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __mt_menu_submenu "🌐 HTTP Server Manager" \
    "Start Server (background)" __mt_server_manager_start \
    "Stop Server" __mt_server_manager_stop \
    "Restart Server" __mt_server_manager_restart \
    "Status" __mt_server_manager_status \
    "Open in Web Browser" __mt_server_manager_open \
    "Test Connection (curl)" __mt_server_manager_test \
    "View Logs" __mt_server_manager_view_logs \
    "Tail Logs (live)" __mt_server_manager_tail_logs \
    "Server Options (wizard)" __mt_server_manager_options \
    "Manage via mt-jobs" __mt_server_manager_jobs
}
```

### 📂 Version Control (Git) - AI Workflows


#### `git-ai-push-all`

> Git: Auto-format, stage, generate AI commits, and push all changes

```bash
#######################################
# Git: Auto-format, stage, generate AI commits, and push all changes
# Usage: git-ai-push-all [optional_commit_message]
# Arguments:
#   $1 - Optional user commit message (bypasses AI)
#######################################
git-ai-push-all() {
  __git_auto_format "."
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }

  git add .
  if git diff --staged --quiet; then
    echo "✅ No changes staged to commit."
    return 0
  fi

  local user_msg="${1:-}"
  if [ -n "$user_msg" ]; then
    echo "📦 Committing staged changes with provided message..."
    git commit -m "$user_msg"
  else
    echo "🤖 AI enabled: Generating feature-grouped commits..."

    # Update README.md "Recent Updates & Enhancements" using AI
    __git_sync_ai_update_readme_summary "."
    local readme_status=$?

    if [ "$readme_status" -eq 100 ]; then
      echo -e "${CB_RED}🚨 Aborting push: README AI update failed.${C_RESET}"
      return 1
    fi

    # README.md was modified by the AI summary, so make sure it is staged
    git add .

    local loop_count=0
    local max_loops=10

    while ! git diff --staged --quiet; do
      ((loop_count++))

      if [ "$loop_count" -gt "$max_loops" ]; then
        echo "⚠️ AI loop limit reached. Batch committing remaining files..."
        git commit -m "chore: automated changes (batch remainder)"
        break
      fi

      local prev_staged
      prev_staged=$(git diff --staged --name-only | wc -l)

      __git_sync_ai_commit "."
      local commit_status=$?
      if [ $commit_status -eq 100 ]; then
        echo -e "${CB_RED}🚨 Aborting push.${C_RESET}"
        return 1
      elif [ $commit_status -ne 0 ]; then
        echo "⚠️ AI commit generation skipped or failed. Falling back to default batch commit..."
        git add .
        git commit -m "chore: automated changes"
        break
      fi

      git add .

      local next_staged
      next_staged=$(git diff --staged --name-only | wc -l)
      if [ "$prev_staged" -eq "$next_staged" ]; then
        echo "⚠️ AI failed to process the remaining diff chunks. Batch committing..."
        git commit -m "chore: automated changes (batch remainder)"
        break
      fi
    done
  fi

  echo "🚀 Pushing changes to remote..."
  git push
}
```

#### `mt-ai-gitignore`

> AI: Generate a comprehensive .gitignore for the active repository

```bash
#######################################
# AI: Generate a comprehensive .gitignore for the active repository
# Usage: mt-ai-gitignore [-u|--update] [-f|--force] [-j|--json]
#        mt-ai-gitignore --apply-pending|--discard-pending
# Options:
#   -u, --update        Regenerate against an existing .gitignore, showing a
#                        diff before applying (see -f/-j)
#   -f, --force         With --update, skip the confirmation prompt
#   -j, --json          With --update, print {status, target, pending} JSON
#                        instead of showing a diff/prompt
#   --apply-pending      Apply a previously generated pending .gitignore
#   --discard-pending    Discard a previously generated pending .gitignore
#######################################
mt-ai-gitignore() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __git_ai_generate_or_update ".gitignore" "git_gitignore" "project-gitignore" "$@"
}
```

#### `mt-ai-readme`

> AI: Generate a comprehensive README.md for the active repository

```bash
#######################################
# AI: Generate a comprehensive README.md for the active repository
# Usage: mt-ai-readme [-u|--update] [-f|--force] [-j|--json]
#        mt-ai-readme --apply-pending|--discard-pending
# Options:
#   -u, --update        Regenerate against an existing README.md, showing a
#                        diff before applying (see -f/-j)
#   -f, --force         With --update, skip the confirmation prompt
#   -j, --json          With --update, print {status, target, pending} JSON
#                        instead of showing a diff/prompt
#   --apply-pending      Apply a previously generated pending README.md
#   --discard-pending    Discard a previously generated pending README.md
#######################################
mt-ai-readme() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __git_ai_generate_or_update "README.md" "git_readme" "project-readme" "$@"
}
```

### 📂 Version Control (Git) - Core Helpers


#### `cd-repo-root`

> Git: Change directory to the current repository's top-level root,

```bash
#######################################
# Git: Change directory to the current repository's top-level root,
# regardless of how deep the working directory is nested inside it
# Usage: cd-repo-root
#######################################
cd-repo-root() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2> /dev/null)
  if [ -z "$repo_root" ]; then
    echo -e "${CB_RED}🚨 Not inside a Git repository.${C_RESET}"
    return 1
  fi

  cd "$repo_root" || return 1
}
```

#### `git-clean-merged`

> Git: Delete local and remote branches merged into the default branch

```bash
#######################################
# Git: Delete local and remote branches merged into the default branch
#######################################
git-clean-merged() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local default_branch
  default_branch=$(__mt_git_default_branch)
  default_branch="${default_branch:-main}"

  echo -e "${CB_BLUE}🧹 Fetching latest remote state and pruning tracking branches...${C_RESET}"
  git fetch origin --prune

  echo -e "${CB_BLUE}🔄 Switching to ${default_branch} and pulling latest...${C_RESET}"
  git checkout "$default_branch" && git pull origin "$default_branch"

  echo -e "\n${CB_YELLOW}🔍 Scanning for fully merged local branches...${C_RESET}"
  local merged_branches
  merged_branches=$(git branch --merged | grep -v "\*" | grep -v -E "^[[:space:]]*${default_branch}$" | tr -d ' ' || true)

  if [ -z "$merged_branches" ]; then
    echo -e "${CB_GREEN}✅ Workspace is clean. No merged local branches found.${C_RESET}"
  else
    echo "$merged_branches" | xargs -n 1 git branch -d
    echo -e "${CB_GREEN}✅ Local branch cleanup complete.${C_RESET}"
  fi

  echo -e "\n${CB_YELLOW}🔍 Scanning for fully merged remote branches...${C_RESET}"
  local remote_merged
  remote_merged=$(git branch -r --merged "origin/$default_branch" | grep -v "\*" | grep -v HEAD | grep -v -E "origin/${default_branch}$" | sed 's/origin\///' | tr -d ' ' || true)

  if [ -z "$remote_merged" ]; then
    echo -e "${CB_GREEN}✅ No merged remote branches found on origin.${C_RESET}"
  else
    for r_branch in $remote_merged; do
      read -r -p "Delete remote branch 'origin/$r_branch'? [y/N] " -n 1 < /dev/tty
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin --delete "$r_branch"
      fi
    done
    echo -e "${CB_GREEN}✅ Remote cleanup complete.${C_RESET}"
  fi
}
```

#### `git-create-repo`

> Git: Create a new GitHub repository for the current directory and wire

```bash
#######################################
# Git: Create a new GitHub repository for the current directory and wire
# it up as the 'origin' remote -- for a directory that isn't a Git repo
# yet, or is one but has no remote configured. Initializes Git if needed,
# optionally generates a .gitignore/README.md, creates an initial commit
# if there's no history yet (gh needs something to push), then creates
# the GitHub repo via 'gh repo create --source=. --remote=origin
# --push'. Refuses to run if 'origin' is already configured -- this is
# a one-time bootstrap, not something meant to reconfigure an existing
# remote.
# Usage: git-create-repo [-n|--name <name>] [-d|--description <text>] [--private|--public] [--docs]
# Options:
#   -n, --name <name>          Repository name (default: current directory's name)
#   -d, --description <text>   Repository description
#   --private                  Create as a private repository
#   --public                   Create as a public repository
#   --docs                     Generate a .gitignore and README.md first (AI-generated if
#                              the directory has files, blank placeholders if not)
#   -h, --help                 Show this help
#######################################
git-create-repo() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local repo_name="" description="" visibility="" generate_docs=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -n | --name)
        repo_name="$2"
        shift
        ;;
      -d | --description)
        description="$2"
        shift
        ;;
      --private) visibility="--private" ;;
      --public) visibility="--public" ;;
      --docs) generate_docs=true ;;
      *)
        echo "Usage: git-create-repo [-n|--name <name>] [-d|--description <text>] [--private|--public] [--docs]" >&2
        return 1
        ;;
    esac
    shift
  done

  if ! command -v gh > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 GitHub CLI ('gh') is required but not installed.${C_RESET}"
    echo -e "Install it from ${CB_CYAN}https://cli.github.com${C_RESET} and re-run this command."
    return 1
  fi

  __mt_ensure_gh_auth || return 1

  local existing_remote
  existing_remote=$(git config --get remote.origin.url 2> /dev/null)
  if [ -n "$existing_remote" ]; then
    echo -e "${CB_YELLOW}⚠️  This directory already has an 'origin' remote configured:${C_RESET}"
    echo -e "${C_DIM}${existing_remote}${C_RESET}"
    echo -e "${CB_YELLOW}Nothing to do -- git-create-repo only bootstraps a fresh repo/remote.${C_RESET}"
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${CB_BLUE}📦 Initializing Git repository...${C_RESET}"
    git init -q
  fi

  local repo_had_commits=true
  git rev-parse HEAD > /dev/null 2>&1 || repo_had_commits=false

  if [ "$generate_docs" = true ]; then
    __git_create_repo_generate_docs
  fi

  local created_initial_commit=false
  if [ "$repo_had_commits" = false ]; then
    echo -e "${CB_YELLOW}⚠️  No commits yet -- an initial commit is needed before pushing to GitHub.${C_RESET}"
    git status --short
    local reply
    read -r -p "Stage everything and create an initial commit now? [Y/n] " -n 1 reply < /dev/tty || reply="y"
    echo
    if [[ -n "$reply" && ! "$reply" =~ ^[Yy]$ ]]; then
      echo -e "${CB_RED}🚨 Aborted -- commit your work first, then re-run git-create-repo.${C_RESET}"
      return 1
    fi
    git add -A
    git commit -q -m "Initial commit"
    created_initial_commit=true
  elif [ "$generate_docs" = true ] && git status --porcelain -- .gitignore README.md 2> /dev/null | grep -q .; then
    git add -- .gitignore README.md
    git commit -q -m "chore: add generated .gitignore and README.md"
  fi

  local large_files
  large_files=$(__git_create_repo_find_large_files)
  if [ -n "$large_files" ]; then
    echo -e "${CB_RED}🚨 Found file(s) at or above GitHub's 100MB push limit -- this would be rejected mid-push:${C_RESET}"
    echo "  ${large_files//$'\n'/$'\n  '}"
    if [ "$created_initial_commit" = true ]; then
      git update-ref -d HEAD
      echo -e "${CB_YELLOW}Undid the initial commit so nothing oversized got committed.${C_RESET}"
    else
      echo -e "${CB_YELLOW}These are already committed in this repo's history -- untrack them (git rm --cached) and add a .gitignore entry, or use Git LFS, before retrying.${C_RESET}"
    fi
    echo -e "${CB_YELLOW}Tip: run 'mt-ai-gitignore' to generate a .gitignore for this project, then re-run git-create-repo.${C_RESET}"
    return 1
  fi

  repo_name="${repo_name:-$(basename "$PWD")}"

  if [ -z "$visibility" ]; then
    local vis_choice
    vis_choice=$(printf '%s\n' private public | fzf --prompt="📦 Repository Visibility > " --height=~10 --layout=reverse --border)
    if [ -z "$vis_choice" ]; then
      echo -e "${CB_YELLOW}⚠️  Cancelled.${C_RESET}"
      return 0
    fi
    visibility="--${vis_choice}"
  fi

  local -a gh_args=(repo create "$repo_name" "$visibility" --source=. --remote=origin --push)
  [ -n "$description" ] && gh_args+=(--description "$description")

  echo -e "${CB_BLUE}🚀 Creating GitHub repository '${repo_name}' (${visibility#--})...${C_RESET}"
  if gh "${gh_args[@]}"; then
    echo -e "${CB_GREEN}✅ Repository created and pushed.${C_RESET}"
    git config --get remote.origin.url
    return 0
  fi

  echo -e "${CB_RED}🚨 Failed to create the GitHub repository.${C_RESET}"
  if git config --get remote.origin.url > /dev/null 2>&1; then
    echo -e "${CB_YELLOW}'gh' had already created the GitHub repo and added 'origin' before the failure -- it may now exist but be empty.${C_RESET}"
    echo -e "${CB_YELLOW}Removing the local 'origin' remote so a retry isn't blocked; delete the empty GitHub repo yourself if 'gh' didn't already roll it back.${C_RESET}"
    git remote remove origin
  fi
  return 1
}
```

#### `git-default-rebase`

> Git: Fetch upstream origin and rebase current branch onto default branch

```bash
#######################################
# Git: Fetch upstream origin and rebase current branch onto default branch
#######################################
git-default-rebase() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local current_branch
  current_branch=$(git branch --show-current)

  local default_branch
  default_branch=$(__mt_git_default_branch)
  default_branch="${default_branch:-main}"

  if [ "$current_branch" = "$default_branch" ]; then
    echo "You are already on the default branch (${default_branch}). Pulling latest..."
    git pull origin "$default_branch"
    return 0
  fi

  echo -e "${CB_BLUE}🔄 Fetching remote and rebasing ${current_branch} onto origin/${default_branch}...${C_RESET}"
  git fetch origin
  git rebase "origin/$default_branch"
}
```

#### `git-new-feature`

> Git: Create and checkout a new feature branch

```bash
#######################################
# Git: Create and checkout a new feature branch
# Globals:
#   GIT_FEATURE_PREFIX
# Arguments:
#   $1 - Jira ticket ID or branch descriptor suffix
# Usage: git-new-feature <CCON-123|suffix>
#######################################
git-new-feature() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  [ -z "$1" ] && {
    echo -e "🚨 Error: Jira ID / branch suffix cannot be empty.\nUsage: git-new-feature CCON-123"
    return 1
  }

  git checkout -b "${GIT_FEATURE_PREFIX:-feature/}$1"
}
```

#### `git-nuke`

> Git: Hard reset local branch to upstream state and wipe untracked files

```bash
#######################################
# Git: Hard reset local branch to upstream state and wipe untracked files
#######################################
git-nuke() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local current_branch
  current_branch=$(git branch --show-current)

  if [ -z "$current_branch" ]; then
    echo "🚨 Error: Not currently on any branch."
    return 1
  fi

  echo -e "${CB_RED}⚠️  WARNING: This will DESTROY all local uncommitted changes AND untracked files.${C_RESET}"
  read -r -p "Reset '${current_branch}' to origin/${current_branch}? [y/N] " -n 1 < /dev/tty
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "💥 Nuking local environment..."
    git fetch origin > /dev/null 2>&1
    if ! git ls-remote --exit-code --heads origin "$current_branch" > /dev/null 2>&1; then
      echo -e "${CB_RED}🚨 Error: Upstream branch 'origin/$current_branch' does not exist. Cannot safely reset.${C_RESET}"
      return 1
    fi
    git reset --hard "origin/$current_branch"
    git clean -fd
    echo -e "${CB_GREEN}✅ Branch reset to upstream state.${C_RESET}"
  else
    echo "🛑 Aborted."
  fi
}
```

#### `git-pretty-log`

> Git: Print a clean, color-coded, single-line log graph

```bash
#######################################
# Git: Print a clean, color-coded, single-line log graph
#######################################
git-pretty-log() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)' --all
}
```

#### `git-push-all`

> Git: Stage all files, commit with provided message, and push

```bash
#######################################
# Git: Stage all files, commit with provided message, and push
# Usage: git-push-all "commit message"
# Arguments:
#   $1 - Commit message string (Required)
#######################################
git-push-all() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local commit_msg="${1:-}"

  if [ -z "$commit_msg" ]; then
    echo -e "${CB_RED}🚨 Error: A commit message is required.${C_RESET}"
    echo -e "Usage: git-push-all \"Your commit message\""
    return 1
  fi

  git add .

  if git diff --staged --quiet; then
    echo -e "${CB_GREEN}✅ No changes staged to commit.${C_RESET}"
    return 0
  fi

  echo -e "${CB_BLUE}📦 Committing changes...${C_RESET}"
  git commit -m "$commit_msg"

  echo -e "${CB_BLUE}🚀 Pushing changes to remote...${C_RESET}"
  git push
}
```

#### `git-raise-pr`

> Git: Push current branch and raise a Pull Request (GitHub/GitLab/Bitbucket)

```bash
#######################################
# Git: Push current branch and raise a Pull Request (GitHub/GitLab/Bitbucket)
# Usage: git-raise-pr [-b target_branch] [-t pr_title] [-m pr_body]
# Options:
#   -b <branch>   Target branch to merge into (defaults to default branch)
#   -t <title>    Pull Request title
#   -m <message>  Pull Request body or description
#######################################
git-raise-pr() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local target_branch="" pr_title="" pr_body=""

  local OPTIND opt
  while getopts "b:t:m:" opt; do
    case ${opt} in
      b) target_branch="$OPTARG" ;;
      t) pr_title="$OPTARG" ;;
      m) pr_body="$OPTARG" ;;
      \?)
        echo "Usage: git-raise-pr [-b <target_branch>] [-t <pr_title>] [-m <pr_body>]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  local default_branch
  default_branch=$(__mt_git_default_branch)
  default_branch="${default_branch:-main}"
  target_branch="${target_branch:-$default_branch}"

  local current_branch
  current_branch=$(git branch --show-current)

  if [ -z "$current_branch" ]; then
    echo -e "${CB_RED}🚨 Error: Not currently on any branch.${C_RESET}"
    return 1
  fi

  if [ "$current_branch" = "$target_branch" ]; then
    echo -e "${CB_RED}🚨 Error: You are currently on the target branch ($target_branch). Please checkout a new feature branch first.${C_RESET}"
    return 1
  fi

  __git_raise_pr_sync_with_target || return 1

  local is_github=false
  local origin_url=""
  local __git_raise_pr_dead_pr_action="continue"
  __git_raise_pr_handle_dead_pr
  case "$__git_raise_pr_dead_pr_action" in
    done) return 0 ;;
    error) return 1 ;;
  esac

  __git_raise_pr_push_branch || return 1
  __git_raise_pr_create_or_open
}
```

#### `git-view-remote`

> Git: Open current repository remote URL in default web browser

```bash
#######################################
# Git: Open current repository remote URL in default web browser
#######################################
git-view-remote() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local origin_url
  origin_url=$(git config --get remote.origin.url 2> /dev/null)

  [ -z "$origin_url" ] && {
    echo "🚨 Error: No remote 'origin' found for the current repository."
    return 1
  }

  local web_url="$origin_url"
  if [[ "$web_url" == git@* ]]; then
    web_url="${web_url#git@}"
    web_url="${web_url/:/\//}"
    web_url="https://${web_url}"
  fi

  web_url="${web_url%.git}"
  web_url=$(echo "$web_url" | sed -E 's#([^:])//+#\1/#g')
  echo "🌐 Opening $web_url in browser..."
  __open_url "$web_url"
}
```

#### `mt-git-clone`

> Git: Clone a repository into a sensibly routed default location

```bash
#######################################
# Git: Clone a repository into a sensibly routed default location
# instead of leaving it wherever the current directory happens to be --
# ~/vcs/personal/<owner>/<repo> for GitHub/GitLab/etc (the owner read
# straight off the clone URL), or
# ~/vcs/work/bitbucket/<BITBUCKET_SERVER>/<BITBUCKET_WORKSPACE>/<repo>
# for Bitbucket, since a Bitbucket clone URL never encodes the
# workspace/project grouping the way GitHub/GitLab encode the owner.
# Refuses to clone over an already-existing destination. The routed
# default can be overridden entirely (--path), or swapped for the
# current directory (--here).
# Usage: mt-git-clone <repo-url> [-p|--path <dir>] [--here] [--ide]
#        [-e|--explore] [-fr|--fetch-remote] [-c|--checkout <branch>]
# Options:
#   -p, --path <dir>          Clone into this exact directory instead of the routed default
#   --here                    Clone into the current directory instead of the routed default
#   --ide                     Open the cloned repo in the default IDE afterward
#   -e, --explore             Open the cloned repo's directory in the file manager afterward
#   -fr, --fetch-remote       Fetch every remote branch after cloning
#   -c, --checkout <branch>   Create and check out a new local branch from the default branch
#   -h, --help                 Show this help
# Globals:
#   VCS_PERSONAL, VCS_ROOT, BITBUCKET_SERVER, BITBUCKET_WORKSPACE, DEFAULT_IDE
#######################################
mt-git-clone() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local usage="Usage: mt-git-clone <repo-url> [-p|--path <dir>] [--here] [--ide] [-e|--explore] [-fr|--fetch-remote] [-c|--checkout <branch>]"
  local repo_url="" override_path="" clone_here=false
  local open_ide=false open_explorer=false fetch_remote=false checkout_branch=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -p | --path)
        override_path="$2"
        shift
        ;;
      --here) clone_here=true ;;
      --ide) open_ide=true ;;
      -e | --explore) open_explorer=true ;;
      -fr | --fetch-remote) fetch_remote=true ;;
      -c | --checkout)
        checkout_branch="$2"
        shift
        ;;
      -*)
        echo "$usage" >&2
        return 1
        ;;
      *) repo_url="$1" ;;
    esac
    shift
  done

  if [ -z "$repo_url" ]; then
    echo "$usage" >&2
    return 1
  fi

  local repo_name
  repo_name=$(basename "$repo_url" .git)

  local target_dir
  if [ -n "$override_path" ]; then
    target_dir="$override_path"
  elif [ "$clone_here" = true ]; then
    target_dir="${PWD}/${repo_name}"
  else
    local owner
    owner=$(__mt_git_clone_parse_owner "$repo_url")
    if [ -z "$owner" ]; then
      echo -e "${CB_RED}🚨 Couldn't determine an owner/workspace from that URL. Use --path to specify a destination directly.${C_RESET}"
      return 1
    fi
    if [ "$owner" = "bitbucket" ]; then
      if [ -z "$BITBUCKET_SERVER" ] || [ -z "$BITBUCKET_WORKSPACE" ]; then
        echo -e "${CB_RED}🚨 BITBUCKET_SERVER/BITBUCKET_WORKSPACE aren't configured -- set them via mt-wizard-git, or clone with --path instead.${C_RESET}"
        return 1
      fi
      target_dir="${VCS_ROOT:-$HOME/vcs}/work/bitbucket/${BITBUCKET_SERVER}/${BITBUCKET_WORKSPACE}/${repo_name}"
    else
      target_dir="${VCS_PERSONAL:-$HOME/vcs/personal}/${owner}/${repo_name}"
    fi
  fi

  if [ -e "$target_dir" ]; then
    echo -e "${CB_YELLOW}⚠️  ${repo_name} already exists at: ${target_dir}${C_RESET}"
    return 1
  fi

  mkdir -p "$(dirname "$target_dir")"

  echo -e "${CB_BLUE}📥 Cloning ${repo_name} into ${target_dir}...${C_RESET}"
  if ! git clone "$repo_url" "$target_dir"; then
    echo -e "${CB_RED}🚨 Clone failed.${C_RESET}"
    return 1
  fi
  echo -e "${CB_GREEN}✅ Cloned to ${target_dir}${C_RESET}"

  if [ "$fetch_remote" = true ]; then
    echo -e "${CB_BLUE}🔄 Fetching all remote branches...${C_RESET}"
    git -C "$target_dir" fetch --all
  fi

  if [ -n "$checkout_branch" ]; then
    local default_branch
    default_branch=$(__mt_git_default_branch "$target_dir")
    if [ -z "$default_branch" ]; then
      echo -e "${CB_YELLOW}⚠️  Couldn't determine the default branch -- skipping checkout of '${checkout_branch}'.${C_RESET}"
    else
      echo -e "${CB_BLUE}🌱 Creating branch '${checkout_branch}' from ${default_branch}...${C_RESET}"
      git -C "$target_dir" checkout -b "$checkout_branch" "$default_branch"
    fi
  fi

  [ "$open_explorer" = true ] && __open_path_gui "$target_dir"

  if [ "$open_ide" = true ]; then
    local selected_ide="${DEFAULT_IDE:-vscode}"
    echo -e "${CB_BLUE}🚀 Opening in ${selected_ide}...${C_RESET}"
    if [ "$selected_ide" = "intellij" ]; then
      __launch_intellij "$target_dir" || echo -e "${CB_YELLOW}⚠️  Could not launch IntelliJ. Ensure 'idea' is on PATH.${C_RESET}"
    else
      code -n "$target_dir"
    fi
  fi
}
```

#### `mt-repos`

> Git: Scan VCS root and list all local repositories, optionally

```bash
#######################################
# Git: Scan VCS root and list all local repositories, optionally
# narrowed to a scope/provider/workspace/project -- useful on its own
# now that a single work-scope project can group 50+ repos (see
# __mt_vcs_path_context).
# Usage: mt-repos [-s work|personal] [-p provider] [-w workspace]
#                 [-pr project]
# Options:
#   -s, --scope <work|personal>   Only list repos under this scope
#   -p, --provider <name>         Only list repos under this provider (work scope only, e.g. bitbucket)
#   -w, --workspace <name>        Only list repos under this workspace (work scope only, e.g. rentokilinitial)
#   -pr, --project <name>         Only list repos under this project (work scope; e.g. cloudconnect groups many repos) or this exact repo (personal scope)
#   -h, --help                    Show this help
# Globals:
#   VCS_ROOT, WSL_DISTRO_NAME
#######################################
mt-repos() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local scope="" provider="" workspace="" project=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s | --scope)
        scope="${2,,}"
        if [[ "$scope" != "work" && "$scope" != "personal" ]]; then
          echo "mt-repos: --scope must be 'work' or 'personal'" >&2
          return 1
        fi
        shift 2
        ;;
      -p | --provider)
        provider="$2"
        shift 2
        ;;
      -w | --workspace)
        workspace="$2"
        shift 2
        ;;
      -pr | --project)
        project="$2"
        shift 2
        ;;
      *)
        echo "Usage: mt-repos [-s work|personal] [-p provider] [-w workspace] [-pr project]" >&2
        return 1
        ;;
    esac
  done

  local search_dir="${VCS_ROOT:-$HOME/vcs}"
  if [ ! -d "$search_dir" ]; then
    echo -e "${CB_RED}🚨 Error: VCS root directory '$search_dir' not found.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}🔍 Scanning '$search_dir' for Git repositories...${C_RESET}"

  local tmp_out
  tmp_out=$(mktemp)

  local repo_path total=0 matched=0
  while IFS= read -r repo_path; do
    [ -z "$repo_path" ] && continue
    ((++total))
    __mt_vcs_matches_filter "$repo_path" "$scope" "$provider" "$workspace" "$project" || continue
    ((++matched))

    local repo_name
    repo_name=$(basename "$repo_path")

    local context
    context=$(__mt_vcs_path_context "$repo_path")
    local repo_scope repo_provider repo_workspace repo_project
    IFS='|' read -r repo_scope repo_provider repo_workspace repo_project <<< "$context"

    local repo_type="Root"
    [ -n "$repo_scope" ] && repo_type="$(tr '[:lower:]' '[:upper:]' <<< "${repo_scope:0:1}")${repo_scope:1}"

    local context_disp="--"
    [ "$repo_scope" = "work" ] && context_disp="${repo_provider}/${repo_workspace}/${repo_project}"

    local branch
    branch=$(git -C "$repo_path" branch --show-current 2> /dev/null || echo "HEAD detached")
    [ -z "$branch" ] && branch="No commits"

    local remote
    remote=$(git -C "$repo_path" config --get remote.origin.url 2> /dev/null || echo "No remote")

    echo "${repo_type}|${context_disp}|${repo_name}|${branch}|${remote}|${repo_path}" >> "$tmp_out"
  done < <(__mt_vcs_find_repos "$search_dir")

  if [ "$matched" -eq 0 ]; then
    if [ "$total" -eq 0 ]; then
      echo -e "${CB_YELLOW}⚠️ No Git repositories found in $search_dir.${C_RESET}"
    else
      echo -e "${CB_YELLOW}⚠️  No repositories matched the given filters (${total} scanned).${C_RESET}"
    fi
    rm -f "$tmp_out"
    return 0
  fi

  echo -e "\n${CB_CYAN}📦 Found $matched repositories in $search_dir:${C_RESET}\n"

  sort -t'|' -k1,1 -k2,2 -k3,3 "$tmp_out" -o "$tmp_out"

  local awk_script="$HOME/.bash.d/lib/awk/mt_repos_table.awk"
  awk -F'|' -v home="$HOME" -v wsl_distro="${WSL_DISTRO_NAME:-Debian}" -v blue="$CB_BLUE" -v green="$CB_GREEN" -v yellow="$CB_YELLOW" -v dim="$C_DIM" -v rst="$C_RESET" -v magenta="$CB_MAGENTA" -v cyan="$CB_CYAN" -f "$awk_script" "$tmp_out"

  echo ""
  rm -f "$tmp_out"
}
```

### 📂 Version Control (Git) - Profile Synchronization


#### `mt-download-release`

> System: Download a release zip from the remote repository

```bash
#######################################
# System: Download a release zip from the remote repository
# Usage: mt-download-release [-v version] [-d directory]
# Options:
#   -v <version>    Specify target release version (defaults to latest)
#   -d <directory>  Specify destination directory (defaults to current directory)
#######################################
mt-download-release() {
  local target_version=""
  local dest_dir="$PWD"
  local OPTIND opt

  while getopts "v:d:h" opt; do
    case ${opt} in
      v) target_version="$OPTARG" ;;
      d) dest_dir="$OPTARG" ;;
      h)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      \?)
        echo "Usage: mt-download-release [-v <version>] [-d <directory>]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ ! -d "$dest_dir" ]; then
    echo -e "${CB_YELLOW}⚠️ Directory '${dest_dir}' does not exist. Creating it...${C_RESET}"
    mkdir -p "$dest_dir" || {
      echo -e "${CB_RED}🚨 Error: Failed to create directory '${dest_dir}'.${C_RESET}"
      return 1
    }
  fi

  echo -e "${CB_BLUE}⬇️ Fetching release information...${C_RESET}"

  local repo_path="$UPSTREAM_REPO_PATH"

  local api_url="https://api.github.com/repos/${repo_path}/releases/latest"
  if [ -n "$target_version" ]; then
    api_url="https://api.github.com/repos/${repo_path}/releases/tags/${target_version}"
  fi

  local release_data
  release_data=$(curl -s "$api_url")

  local download_url
  download_url=$(echo "$release_data" | jq -r ".assets[0].browser_download_url // empty")
  local asset_name
  asset_name=$(echo "$release_data" | jq -r ".assets[0].name // empty")
  local tag_name
  tag_name=$(echo "$release_data" | jq -r ".tag_name // empty")

  if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
    if [ -n "$target_version" ]; then
      echo -e "${CB_RED}🚨 Error: Could not find release assets for version ${target_version} in ${repo_path}.${C_RESET}"
    else
      echo -e "${CB_RED}🚨 Error: Could not find latest release assets for ${repo_path}.${C_RESET}"
    fi
    return 1
  fi

  [ -z "$asset_name" ] || [ "$asset_name" = "null" ] && asset_name="mt-devops-framework-${tag_name}.zip"

  local dest_file="${dest_dir}/${asset_name}"

  echo -e "${CB_GREEN}📦 Found release ${tag_name}. Downloading to ${dest_file}...${C_RESET}"

  if curl -L -# --fail "$download_url" -o "$dest_file"; then
    echo -e "${CB_GREEN}✅ Successfully downloaded release ${tag_name} to ${dest_file}${C_RESET}"
    if type __win_explorer_focus > /dev/null 2>&1; then
      __win_explorer_focus "$dest_dir" 2> /dev/null || true
    fi
  else
    echo -e "${CB_RED}🚨 Error: Failed to download release asset from ${download_url}.${C_RESET}"
    return 1
  fi
}
```

#### `mt-get-update`

> System: Download and install profile updates from GitHub releases --

```bash
#######################################
# System: Download and install profile updates from GitHub releases --
# or, on a machine already cut over by mt-migrate-symlink, pull the
# latest code directly via git instead (see __mt_get_update_git_pull).
# Usage: mt-get-update [-v <version>] [-V|--verbose]
# Options:
#   -v <version>     Specify a target release version (e.g., v1.1.0)
#   -V, --verbose    Show routine progress/no-op messages that are
#                    otherwise suppressed (e.g. "pulling directly via
#                    git", "nothing to migrate") -- errors and the
#                    final result are always shown regardless
#   -h, --help       Show this help menu
#######################################
mt-get-update() {
  local target_version="" verbose=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -v)
        target_version="$2"
        shift 2
        ;;
      -V | --verbose)
        verbose=true
        shift
        ;;
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      *)
        echo "Usage: mt-get-update [-v <version>] [-V|--verbose]" >&2
        return 1
        ;;
    esac
  done

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  if __mt_bashd_is_symlinked_into_repo "$repo_dir"; then
    __mt_get_update_git_pull "$target_version" "$verbose"
    local pull_status=$?
    [ "$pull_status" -eq 0 ] && __mt_get_update_clear_pending_cache
    return "$pull_status"
  fi

  echo -e "${CB_BLUE}⬇️ Fetching release information...${C_RESET}"

  local download_url="" tag_name=""
  __mt_get_update_resolve_release "$target_version"
  local resolve_status=$?
  if [ "$resolve_status" -eq 2 ]; then
    __mt_get_update_clear_pending_cache
    return 0
  fi
  [ "$resolve_status" -eq 1 ] && return 1

  local tmp_dir="" ext_root=""
  __mt_get_update_download_and_extract "$download_url" "$tag_name" || return 1

  if ! __mt_get_update_check_divergence "$ext_root"; then
    rm -rf "$tmp_dir"
    return 0
  fi

  __mt_get_update_install "$ext_root" "$tag_name" "$verbose"
  local install_status=$?
  [ "$install_status" -eq 0 ] && __mt_get_update_clear_pending_cache
  rm -rf "$tmp_dir"
  return "$install_status"
}
```

#### `mt-migrate-symlink`

> Git: One-time, idempotent cutover that replaces ~/.bash.d as a

```bash
#######################################
# Git: One-time, idempotent cutover that replaces ~/.bash.d as a
# standalone directory with a symlink into the sync repo's own
# .bash.d subtree, so there's exactly one physical copy of the
# framework on this machine instead of two kept in sync by
# mt-push-update/mt-get-update's copy steps. This is the fix for the
# collaborator merge-conflict root cause __mt_push_update_check_staleness
# only warns about: a deployed tree that's silently drifted from the
# checkout it gets pushed from becomes structurally impossible once
# there's nothing left to drift between. Once run,
# __mt_bashd_is_symlinked_into_repo starts returning true, which is
# what unlocks the faster git-based paths in __git_sync_copy_files,
# __mt_get_update_git_pull, and mt-restore.
# Refuses to run unless the sync repo checkout is clean, on its
# default branch, correctly pointed at SYNC_REPO_URL, and identical to
# ~/.bash.d already (i.e. right after a fresh 'mt-push-update') --
# anything else means there's real, uncopied local work that would be
# stranded the moment ~/.bash.d stops being its own directory. Safe to
# re-run: no-ops immediately if ~/.bash.d is already a symlink.
# Usage: mt-migrate-symlink
# Globals:
#   DOTFILES_DIR, SYNC_REPO_DIR, SYNC_REPO_URL
#######################################
mt-migrate-symlink() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [ -L "$HOME/.bash.d" ]; then
    echo -e "${CB_GREEN}✅ ~/.bash.d is already a symlink (-> $(readlink -f "$HOME/.bash.d")). Nothing to do.${C_RESET}"
    return 0
  fi

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  if [ ! -d "$repo_dir/.git" ]; then
    echo -e "${CB_RED}🚨 ${repo_dir} isn't a git checkout yet. Run 'mt-push-update' first.${C_RESET}"
    return 1
  fi

  local default_branch
  default_branch=$(__mt_git_default_branch "$repo_dir")
  default_branch="${default_branch:-main}"

  local current_branch
  current_branch=$(git -C "$repo_dir" branch --show-current)
  if [ "$current_branch" != "$default_branch" ]; then
    echo -e "${CB_RED}🚨 ${repo_dir} is on '${current_branch}', not '${default_branch}'. Run 'mt-push-update' to land or clean up that branch first.${C_RESET}"
    return 1
  fi

  if [ -n "$(git -C "$repo_dir" status --porcelain 2> /dev/null)" ]; then
    echo -e "${CB_RED}🚨 ${repo_dir} has uncommitted changes. Run 'mt-push-update' first.${C_RESET}"
    return 1
  fi

  local actual_origin
  actual_origin=$(git -C "$repo_dir" remote get-url origin 2> /dev/null)
  if [ -n "${SYNC_REPO_URL:-}" ] && [ "$actual_origin" != "$SYNC_REPO_URL" ]; then
    echo -e "${CB_RED}🚨 ${repo_dir}'s origin doesn't match SYNC_REPO_URL. Run 'mt-push-update' first -- it fixes this automatically.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}🔍 Checking ~/.bash.d matches ${repo_dir}/.bash.d before cutover...${C_RESET}"
  local drift
  drift=$(diff -rq \
    --exclude='config.yaml' --exclude='.env.cache' --exclude='*_token.sh' \
    --exclude='secrets_metadata.yaml' --exclude='.vcs_radar.json' --exclude='.syncignore' \
    --exclude='data' --exclude='40-private' --exclude='private' \
    "$HOME/.bash.d" "$repo_dir/.bash.d" 2> /dev/null)
  if [ -n "$drift" ]; then
    echo -e "${CB_RED}🚨 ~/.bash.d and ${repo_dir}/.bash.d differ:${C_RESET}"
    echo "  ${drift//$'\n'/$'\n  '}"
    echo -e "${CB_YELLOW}Run 'mt-push-update' first so they match, then re-run 'mt-migrate-symlink'.${C_RESET}"
    return 1
  fi
  echo -e "${CB_GREEN}✅ Trees match.${C_RESET}"

  echo -e "${CB_BLUE}📦 Copying local-only files (config, secrets, cache, private content) into ${repo_dir}/.bash.d...${C_RESET}"
  local local_only_paths=(
    "config/config.yaml" "config/.env.cache" "config/secrets_metadata.yaml"
    "data/.current_version" "data/cache" "data/logs" "40-private" "lib/private"
  )
  local rel_path
  for rel_path in "${local_only_paths[@]}"; do
    [ -e "$HOME/.bash.d/$rel_path" ] || continue
    mkdir -p "$(dirname "$repo_dir/.bash.d/$rel_path")"
    cp -a "$HOME/.bash.d/$rel_path" "$repo_dir/.bash.d/$rel_path"
  done
  local token_file
  for token_file in "$HOME/.bash.d/config/"*_token.sh; do
    [ -f "$token_file" ] || continue
    cp -p "$token_file" "$repo_dir/.bash.d/config/$(basename "$token_file")"
  done

  local backup_dir
  backup_dir="$HOME/.bash.d.pre-symlink-backup-$(date +%Y%m%d%H%M%S)"
  mv "$HOME/.bash.d" "$backup_dir"
  ln -s "$repo_dir/.bash.d" "$HOME/.bash.d"

  echo -e "${CB_GREEN}✅ ~/.bash.d is now a symlink into ${repo_dir}/.bash.d.${C_RESET}"
  echo -e "${C_DIM}   Your previous deployed tree is safely kept at ${backup_dir} -- delete it once you're confident everything works.${C_RESET}"
  echo -e "${CB_YELLOW}Open a new terminal (or run 'source ~/.bashrc') and 'mt-doctor' to verify.${C_RESET}"
}
```

#### `mt-push-update`

> System: Sync local bash configs to terminal dotfiles repo and create a Pull Request

```bash
#######################################
# System: Sync local bash configs to terminal dotfiles repo and create a Pull Request
# Usage: mt-push-update [-i|--issue <num>] [-s|--shellcheck] [-b|--backup] [-m|--no-ai] [-d|--delete-merged] [--prompt-remote] [-g|--merge] [message]
# Options:
#   -i, --issue <num>    Optional issue number to link to the Pull Request
#   -s, --shellcheck     Run ShellCheck locally before pushing to catch errors early
#   -b, --backup         Create a zip backup of .bash.d and .bashrc before syncing
#   -m, --no-ai          Skip AI commit-grouping/README summarization; the next
#                        non-flag argument (if any) is used as the commit message
#   -d, --delete-merged  Clean up local branches already merged into the default branch
#   --prompt-remote      With -d, also prompt to delete the matching remote branches
#   -g, --merge          Auto-merge the created PR via 'gh pr merge --admin --squash'
#   $@                   Optional commit message string
#######################################
mt-push-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local issue_num=""
  local run_shellcheck=false
  local backup_before_sync=false
  local delete_merged=false
  local prompt_remote=false
  local auto_merge=false
  local skip_ai=false
  local user_msg=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -i | --issue)
        issue_num="$2"
        shift 2
        ;;
      -s | --shellcheck)
        run_shellcheck=true
        shift
        ;;
      -b | --backup)
        backup_before_sync=true
        shift
        ;;
      -m | --no-ai)
        skip_ai=true
        export SKIP_AI=true
        shift
        # Check if the next argument is a message string and not another flag
        if [[ "$#" -gt 0 && "$1" != -* ]]; then
          user_msg="$1"
          shift
        fi
        ;;
      -d | --delete-merged)
        delete_merged=true
        shift
        ;;
      --prompt-remote)
        prompt_remote=true
        shift
        ;;
      -g | --merge)
        auto_merge=true
        shift
        ;;
      -*)
        echo "Usage: mt-push-update [-i|--issue <num>] [-s|--shellcheck] [-b|--backup] [-m|--no-ai] [-d|--delete-merged] [--prompt-remote] [-g|--merge] [message]" >&2
        return 1
        ;;
      *)
        if [ -z "$user_msg" ]; then
          user_msg="$1"
        else
          user_msg="${user_msg} $1"
        fi
        shift
        ;;
    esac
  done

  user_msg=$(__mt_push_update_trim_message "$user_msg")

  if [ "$run_shellcheck" = true ]; then
    __mt_push_update_run_shellcheck || return 1
  fi

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  local remote_url="${SYNC_REPO_URL:-}"

  if [[ -z "$remote_url" || "$remote_url" == "YOUR_SYNC_REPO_URL" || "$remote_url" == "null" ]]; then
    echo -e "${CB_YELLOW}⚠️  Profile Sync Not Configured${C_RESET}"
    echo -e "The ${C_BOLD}push-profile-update${C_RESET} feature automatically versions and pushes your terminal configuration to a remote Git repository."
    echo "If you don't want to sync this profile at all, you can safely ignore this command."
    echo -e "\nMost people should run:"
    echo -e "   ${CB_CYAN}mt-become-collaborator${C_RESET}   ${C_DIM}# forks ${UPSTREAM_REPO_PATH} and configures this automatically${C_RESET}"
    echo -e "\nIf you have direct write access to ${UPSTREAM_REPO_PATH}, or want to sync to your own separate repo instead, link it directly:"
    echo -e "   ${CB_CYAN}mt-add-sync-url \"git@github.com:username/my-terminal-repo.git\"${C_RESET}\n"
    return 1
  fi

  __mt_push_update_check_staleness || return 1

  if [ "$backup_before_sync" = true ]; then
    __mt_push_update_backup || return 1
  fi

  echo "🔄 Syncing bash configuration to $repo_dir..."
  __git_sync_init_repo "$repo_dir" "$remote_url"

  (__mt_push_update_reconcile_branch) || return 1

  __git_sync_copy_files "$repo_dir"

  (__mt_push_update_commit_and_raise_pr) || return 1
}
```

### 📂 Windows Video Search - History & Saved Queries


#### `find-history`

> Video: Browse and re-run a previous find-dynamic search

```bash
#######################################
# Video: Browse and re-run a previous find-dynamic search
# Usage: find-history
#######################################
find-history() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __find_dynamic_pick_and_rerun "$_FIND_DYNAMIC_DATA_DIR/history.tsv" "🕘 Search History" "No search history yet -- run a search with find-dynamic (or find-menu) first."
}
```

#### `find-menu`

> Video: Interactively build a find-dynamic query -- walks through

```bash
#######################################
# Video: Interactively build a find-dynamic query -- walks through
# tags, resolution/orientation, length, datarate, filename, and date
# filters one at a time via fzf pickers and validated prompts, then
# offers to run it, save it under a name for find-saved, or both. Every
# filter step can be skipped (empty fzf selection / blank Enter).
# Usage: find-menu
#######################################
find-menu() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local -a args=()

  echo -e "${CB_BLUE}🏷️  Tags${C_RESET} (TAB to multi-select, Enter to confirm; leave empty to skip)"
  local tag_picks
  tag_picks=$(printf '%s\n' "🎬 All Videos (no tag filter)" "★ All Tags (catch-all)" "${_FIND_DYNAMIC_TAGS[@]}" | fzf --multi --prompt="Tags > ")
  if grep -qxF "🎬 All Videos (no tag filter)" <<< "$tag_picks"; then
    args+=(--all-videos)
  elif grep -qxF "★ All Tags (catch-all)" <<< "$tag_picks"; then
    args+=(--all-tags)
  elif [[ -n "$tag_picks" ]]; then
    local tag_csv
    tag_csv=$(tr '\n' ',' <<< "$tag_picks")
    args+=(--tag "${tag_csv%,}")

    local -a tag_pick_arr=()
    mapfile -t tag_pick_arr <<< "$tag_picks"
    if [[ "${#tag_pick_arr[@]}" -gt 1 ]]; then
      echo -e "${CB_BLUE}🔗 Tag Logic${C_RESET} (multiple tags selected)"
      local tag_logic_pick
      tag_logic_pick=$(printf '%s\n' "Any tag (OR)" "All tags (AND)" | fzf --prompt="Tag Logic > ")
      [[ "$tag_logic_pick" == "All tags (AND)" ]] && args+=(--tag-logic and)
    fi
  fi

  echo -e "${CB_BLUE}📐 Resolution${C_RESET} (TAB to multi-select; leave empty for any)"
  local res_picks
  res_picks=$(printf '%s\n' sd 720p 1080p 4k "4k+" | fzf --multi --prompt="Resolution > ")
  if [[ -n "$res_picks" ]]; then
    local res_csv
    res_csv=$(tr '\n' ',' <<< "$res_picks")
    args+=(--res "${res_csv%,}")
  fi

  echo -e "${CB_BLUE}🔄 Orientation${C_RESET}"
  local orientation_pick
  orientation_pick=$(printf '%s\n' Any Landscape Portrait | fzf --prompt="Orientation > ")
  case "$orientation_pick" in
    Landscape) args+=(--orientation l) ;;
    Portrait) args+=(--orientation p) ;;
  esac

  echo -e "${CB_BLUE}⏱️  Length${C_RESET} (mm:ss, leave blank to skip either)"
  local len_min len_max
  len_min=$(__find_dynamic_prompt_validated "  Minimum length: " __mmss_to_seconds)
  [[ -n "$len_min" ]] && args+=(--len-min "$len_min")
  len_max=$(__find_dynamic_prompt_validated "  Maximum length: " __mmss_to_seconds)
  [[ -n "$len_max" ]] && args+=(--len-max "$len_max")

  echo -e "${CB_BLUE}📊 Data Rate${C_RESET} (Mbps, leave blank to skip either)"
  local rate_min rate_max
  rate_min=$(__find_dynamic_prompt_validated "  Minimum data rate: " __validate_mbps)
  [[ -n "$rate_min" ]] && args+=(--rate-min "$rate_min")
  rate_max=$(__find_dynamic_prompt_validated "  Maximum data rate: " __validate_mbps)
  [[ -n "$rate_max" ]] && args+=(--rate-max "$rate_max")

  echo -e "${CB_BLUE}🔍 Filename${C_RESET} (free text, leave blank to skip)"
  local filename_input
  read -r -p "  Filename contains: " filename_input < /dev/tty
  [[ -n "$filename_input" ]] && args+=(--filename "$filename_input")

  echo -e "${CB_BLUE}🚫 Exclude Folders${C_RESET} (TAB to multi-select known folders; leave empty to skip)"
  local -a known_exclude_folders=()
  mapfile -t known_exclude_folders < <(__find_dynamic_known_exclude_folders)
  local exclude_picks=""
  if [[ "${#known_exclude_folders[@]}" -gt 0 ]]; then
    exclude_picks=$(printf '%s\n' "${known_exclude_folders[@]}" | fzf --multi --prompt="Exclude Folders > ")
  fi
  echo -e "  ${C_DIM}Additional folders (free text, comma-separated, wildcard * supported; leave blank to skip)${C_RESET}"
  local exclude_freetext
  read -r -p "  Exclude: " exclude_freetext < /dev/tty
  local -a exclude_all=()
  [[ -n "$exclude_picks" ]] && mapfile -t -O "${#exclude_all[@]}" exclude_all <<< "$exclude_picks"
  if [[ -n "$exclude_freetext" ]]; then
    local -a freetext_items=()
    IFS=',' read -ra freetext_items <<< "$exclude_freetext"
    exclude_all+=("${freetext_items[@]}")
  fi
  if [[ "${#exclude_all[@]}" -gt 0 ]]; then
    local exclude_csv
    exclude_csv=$(
      IFS=,
      echo "${exclude_all[*]}"
    )
    args+=(--exclude-folder "$exclude_csv")
  fi

  echo -e "${CB_BLUE}📅 Date${C_RESET} (general Date property, DD-MM-YYYY, leave blank to skip)"
  local date_input
  date_input=$(__find_dynamic_prompt_validated "  Date: " __ddmmyyyy_to_iso)
  [[ -n "$date_input" ]] && args+=(--date "$date_input")

  echo -e "${CB_BLUE}📅 Date Created${C_RESET}"
  local dc_pick
  dc_pick=$(printf '%s\n' None "Exact date..." Today "This Week" "This Month" "This Year" | fzf --prompt="Date Created > ")
  case "$dc_pick" in
    "Exact date...")
      local dc_input
      dc_input=$(__find_dynamic_prompt_validated "  Date Created: " __ddmmyyyy_to_iso)
      [[ -n "$dc_input" ]] && args+=(--date-created "$dc_input")
      ;;
    Today) args+=(--today) ;;
    "This Week") args+=(--this-week) ;;
    "This Month") args+=(--this-month) ;;
    "This Year") args+=(--this-year) ;;
  esac

  echo -e "${CB_BLUE}📚 Library Scope${C_RESET}"
  local scope_pick
  scope_pick=$(printf '%s\n' all no_ts_bin no_bin no_of_ts_bin no_ts no_of | fzf --prompt="Scope > ")
  [[ -n "$scope_pick" && "$scope_pick" != "all" ]] && args+=(--scope "$scope_pick")

  echo -e "${CB_BLUE}🖥️  Open results in File Explorer instead of printing the link?${C_RESET}"
  local gui_reply
  # A full-line read (not -n 1) so the trailing Enter is consumed here,
  # not left in the input buffer to silently swallow the very next
  # prompt (the Save-as name, a few steps below).
  read -r -p "  [y/N] " gui_reply < /dev/tty
  [[ "$gui_reply" =~ ^[Yy] ]] && args+=(--gui)

  if [[ "${#args[@]}" -eq 0 ]]; then
    echo -e "${CB_YELLOW}⚠️  No filters selected -- that would search everything. Aborted.${C_RESET}"
    return 0
  fi

  echo
  echo -e "${CB_GREEN}▶ find-dynamic ${args[*]}${C_RESET}"
  echo

  local action
  action=$(printf '%s\n' Run "Save + Run" "Save only" Cancel | fzf --prompt="Action > ")
  case "$action" in
    Run)
      find-dynamic "${args[@]}"
      ;;
    "Save + Run")
      local save_name
      read -r -p "  Save as: " save_name < /dev/tty
      find-dynamic "${args[@]}"
      if [[ -n "$save_name" ]]; then
        __find_dynamic_save_query "$save_name" "$(tail -n1 "$_FIND_DYNAMIC_DATA_DIR/history.tsv")"
      else
        echo "No name given -- ran without saving."
      fi
      ;;
    "Save only")
      local save_name save_row
      read -r -p "  Save as: " save_name < /dev/tty
      if [[ -n "$save_name" ]]; then
        printf -v save_row '%s\t%s' "$(__find_dynamic_join_display "${args[@]}")" "$(__find_dynamic_encode_args "${args[@]}")"
        __find_dynamic_save_query "$save_name" "$save_row"
      else
        echo "No name given -- not saved."
      fi
      ;;
    *)
      echo "🛑 Cancelled."
      ;;
  esac
}
```

#### `find-save`

> Video: Save the most recent find-dynamic search (from history) under

```bash
#######################################
# Video: Save the most recent find-dynamic search (from history) under
# a name, so it can be re-run later via find-saved without rebuilding
# it.
# Usage: find-save <name>
# Arguments:
#   $1 - Name to save the query under (overwrites a query of the same
#        name, after confirmation)
# Returns:
#   1 if no name given, or no search history exists yet
#######################################
find-save() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Error: Must specify a name, e.g. find-save my-search" >&2
    return 1
  fi

  if [[ ! -s "$_FIND_DYNAMIC_DATA_DIR/history.tsv" ]]; then
    echo "Error: No search history yet -- run a find-dynamic search first." >&2
    return 1
  fi

  __find_dynamic_save_query "$name" "$(tail -n1 "$_FIND_DYNAMIC_DATA_DIR/history.tsv")"
}
```

#### `find-saved`

> Video: Browse and re-run a named saved query

```bash
#######################################
# Video: Browse and re-run a named saved query
# Usage: find-saved
#######################################
find-saved() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __find_dynamic_pick_and_rerun "$_FIND_DYNAMIC_DATA_DIR/saved-queries.tsv" "⭐ Saved Queries" "No saved queries yet -- use find-menu's Save option, or find-save <name> after a search."
}
```

#### `find-saved-delete`

> Video: Delete a saved query by name (fzf-picked)

```bash
#######################################
# Video: Delete a saved query by name (fzf-picked)
# Usage: find-saved-delete
#######################################
find-saved-delete() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local saved_file="$_FIND_DYNAMIC_DATA_DIR/saved-queries.tsv"
  if [[ ! -s "$saved_file" ]]; then
    echo "No saved queries yet."
    return 0
  fi

  local picked
  picked=$(fzf --delimiter='\t' --with-nth=1,2 --prompt="Delete saved query > " < "$saved_file")
  [[ -z "$picked" ]] && return 0

  local name="${picked%%$'\t'*}"
  local tmp_file
  tmp_file=$(mktemp)
  awk -F'\t' -v n="$name" '$1!=n' "$saved_file" > "$tmp_file" && mv "$tmp_file" "$saved_file"
  echo "🗑️  Deleted '${name}'."
}
```

### 📂 Workflow Gap / Backlog Capture


#### `mt-suggest`

> System: Quickly file a lightweight "workflow gap" issue against the

```bash
#######################################
# System: Quickly file a lightweight "workflow gap" issue against the
# framework's own repo (UPSTREAM_REPO_PATH) -- the low-friction capture
# mechanism for "I couldn't do this with an mt- command" or "this could
# be smoother" moments noticed while doing real work, from inside ANY
# project directory, not just this one. Prompts interactively for
# anything not given on the command line, so it works equally well as
# a fast one-liner or from the mt-menu. Filed with the workflow-gap
# label (plus bug or enhancement) so it surfaces separately from
# fully-written issues during the next recurring self-audit (see
# CONTRIBUTING.md).
# Usage: mt-suggest [-b|--bug | -e|--enhancement] [--context <text>] ["<description>"]
# Options:
#   -b, --bug             File as a bug (something broken) instead of an enhancement (something missing)
#   -e, --enhancement     File as an enhancement (something missing) instead of a bug -- skips the interactive prompt just like -b
#   --context <text>      What you were doing / what you did instead -- omit to be prompted
#   -h, --help             Show this help menu
# Arguments:
#   <description>          Short summary of the gap or idea (becomes the issue title) -- omit to be prompted
# Returns:
#   1 if gh issue creation fails
# Outputs:
#   The created issue's URL
#######################################
mt-suggest() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local is_bug=""
  local bug_given=""
  local context=""
  local context_given=""
  local -a description_words=()

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -b | --bug)
        is_bug="1"
        bug_given="1"
        ;;
      -e | --enhancement)
        is_bug=""
        bug_given="1"
        ;;
      --context)
        context="$2"
        context_given="1"
        shift
        ;;
      *) description_words+=("$1") ;;
    esac
    shift
  done

  local description="${description_words[*]}"
  while [[ -z "$description" ]]; do
    read -r -p "📝 Short description (becomes the issue title): " description < /dev/tty
  done

  if [[ -z "$bug_given" ]]; then
    local bug_reply
    read -r -p "🐛 Is this a bug (something broken), rather than a missing feature? [y/N] " bug_reply < /dev/tty
    [[ "$bug_reply" =~ ^[Yy] ]] && is_bug="1"
  fi

  if [[ -z "$context_given" ]]; then
    read -r -p "📎 Any extra context (what you were doing / worked around with)? [optional] " context < /dev/tty
  fi

  local label="enhancement"
  [[ -n "$is_bug" ]] && label="bug"

  local version="unknown"
  [[ -f "$VERSION_FILE" ]] && version=$(command cat "$VERSION_FILE")

  local body
  body=$(
    cat << EOF
${context:-Not specified}

- Working directory: $(pwd)
- Framework version: ${version}
- Captured: $(date '+%Y-%m-%d %H:%M:%S')

---
*Filed via \`mt-suggest\` -- a workflow gap noticed during real work. Triage during the next recurring self-audit (see CONTRIBUTING.md) to decide if/how to build it.*
EOF
  )

  local issue_url
  if ! issue_url=$(gh issue create --repo "$UPSTREAM_REPO_PATH" \
    --title "[Workflow Gap] ${description}" \
    --body "$body" \
    --label "$label" \
    --label "workflow-gap" 2>&1); then
    echo -e "${CB_RED}❌ Failed to file the issue:${C_RESET}"
    echo "$issue_url"
    return 1
  fi

  echo -e "${CB_GREEN}✅ Logged to the backlog:${C_RESET} ${issue_url}"
}
```
