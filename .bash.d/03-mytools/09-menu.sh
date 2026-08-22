# shellcheck shell=bash
# ------------------------------------------
# System: Interactive Master Menu
# ------------------------------------------
# ~/.bash.d/03-mytools/09-menu.sh

#######################################
# System: Generic fzf submenu loop -- shows a numbered list of labeled
# actions, runs the selected one, and redisplays the same list until the
# user backs out (empty selection or the trailing "Back" entry)
# Arguments:
#   $1   - Submenu title, shown as the fzf prompt
#   $@   - Remaining args: alternating "label" "command" pairs. Each
#          command is a single already-defined command/function name
#          (no inline arguments) -- anything needing flags or prompted
#          input should be wrapped in its own tiny __mt_menu_* function
#          first, matching the pattern used elsewhere in this file.
#######################################
__mt_menu_submenu() {
  local title="$1"
  shift
  local -a labels=() commands=()
  while [ "$#" -gt 0 ]; do
    labels+=("$1")
    commands+=("$2")
    shift 2
  done
  local back_idx=$((${#labels[@]} + 1))

  while true; do
    local -a options=()
    local i
    for i in "${!labels[@]}"; do
      options+=("$((i + 1)). ${labels[$i]}")
    done
    options+=("${back_idx}. ⬅  Back")

    local choice
    choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="${title} > " --height=~15 --layout=reverse --border)
    [ -z "$choice" ] && return 0

    local idx="${choice%%.*}"
    [ "$idx" -eq "$back_idx" ] && return 0

    "${commands[$((idx - 1))]}"

    echo -e "\n${C_DIM}Press Enter to continue...${C_RESET}"
    read -r < /dev/tty
  done
}

#######################################
# System: Prompt for a single value and pass it as one argument to a
# target command -- the shared building block for any menu item wrapping
# a command whose one required argument is a whole string (a message, a
# URL, a path) rather than multiple separate tokens
# Arguments:
#   $1 - Prompt label
#   $2 - Target command/function name
#######################################
__mt_menu_prompt_arg() {
  local prompt_label="$1" target_func="$2"
  local value
  read -r -p "${prompt_label}: " value < /dev/tty
  if [ -z "$value" ]; then
    echo -e "${CB_YELLOW}⚠️  Cancelled.${C_RESET}"
    return 0
  fi
  "$target_func" "$value"
}

#######################################
# System: fzf-pick one value from a fixed set and pass it as one argument
# to a target command -- the shared building block for menu items that
# set a small-enum config value (default AI, default IDE, CI/CD provider)
# Arguments:
#   $1   - fzf prompt label
#   $2   - Target command/function name
#   $@   - The fixed set of valid choices
#######################################
__mt_menu_pick_enum() {
  local prompt_label="$1" target_func="$2"
  shift 2
  local choice
  choice=$(printf '%s\n' "$@" | fzf --prompt="${prompt_label} > " --height=~10 --layout=reverse --border)
  if [ -z "$choice" ]; then
    echo -e "${CB_YELLOW}⚠️  Cancelled.${C_RESET}"
    return 0
  fi
  "$target_func" "$choice"
}

#######################################
# System: Prompt for a target path and copy it to the clipboard, since
# mt-copy itself takes a positional argument rather than prompting
#######################################
__mt_menu_copy_prompt() {
  local target
  read -r -p "Target path to copy [.]: " target < /dev/tty
  mt-copy "${target:-.}"
}

#######################################
# System: fzf-pick an installed theme and apply it via mt-set-theme
#######################################
__mt_menu_pick_theme() {
  local theme
  theme=$(find "$HOME/.bash.d/config/themes" -maxdepth 1 -name "*.sh" -exec basename {} .sh \; | fzf --prompt="🎨 Select Theme > " --height=~10 --layout=reverse --border)
  if [ -z "$theme" ]; then
    echo -e "${CB_YELLOW}⚠️  Theme selection cancelled.${C_RESET}"
    return 0
  fi
  mt-set-theme "$theme"
}

#######################################
# System: Prompt for freeform gcloud command args and run them via
# gcl-as-json, since gcloud subcommands are multiple separate tokens
# (e.g. "compute instances list") rather than one single argument
#######################################
__mt_menu_gcl_as_json() {
  local args_str
  read -r -p "gcloud command args (e.g. compute instances list): " args_str < /dev/tty
  if [ -z "$args_str" ]; then
    echo -e "${CB_YELLOW}⚠️  Cancelled.${C_RESET}"
    return 0
  fi
  local -a args
  read -ra args <<< "$args_str"
  gcl-as-json "${args[@]}"
}

__mt_menu_export_interactive() { mt-export -i; }
__mt_menu_export_cleanup_interactive() { mt-export-cleanup -i; }
__mt_menu_search_interactive() { mt-search -i; }
__mt_menu_list_func() { mt-list --func; }
__mt_menu_list_alias() { mt-list --alias; }

__mt_menu_ai_query() { __mt_menu_prompt_arg "Prompt for AI" ai; }
__mt_menu_ai_explain() { __mt_menu_prompt_arg "Command to explain" ai-explain; }

__mt_menu_pick_default_ai() { __mt_menu_pick_enum "🤖 Default AI Provider" mt-set-default-ai gemini claude local; }
__mt_menu_pick_default_ide() { __mt_menu_pick_enum "💻 Default IDE" mt-set-default-ide vscode intellij; }
__mt_menu_pick_cicd() { __mt_menu_pick_enum "⚙️  CI/CD Provider" mt-set-cicd github bitbucket gitlab azure jenkins; }
__mt_menu_add_sync_url() { __mt_menu_prompt_arg "Git sync repository URL" mt-add-sync-url; }
__mt_menu_set_upstream_path() { __mt_menu_prompt_arg "Upstream framework repo path" mt-set-upstream-path; }

__mt_menu_bq_query() { __mt_menu_prompt_arg "BigQuery SQL" bq-query; }
__mt_menu_gcp_crf_logs() { __mt_menu_prompt_arg "Cloud Run Function name" gcp-crf-logs; }
__mt_menu_gcp_gar_docker() { __mt_menu_prompt_arg "Artifact Registry region" gcp-gar-docker; }
__mt_menu_gcp_get_secret() { __mt_menu_prompt_arg "Secret Manager secret name" gcp-get-secret; }
__mt_menu_gcp_ps_pull() { __mt_menu_prompt_arg "Pub/Sub subscription name" gcp-ps-pull; }

__mt_menu_tf_replace() { __mt_menu_prompt_arg "Terraform resource address" tf-replace; }
__mt_menu_tf_yaml() { __mt_menu_prompt_arg "YAML var file path" tf-yaml; }

__mt_menu_git_new_feature() { __mt_menu_prompt_arg "Ticket/branch suffix" git-new-feature; }
__mt_menu_git_push_all() { __mt_menu_prompt_arg "Commit message" git-push-all; }
__mt_menu_git_clone_ide() { __mt_menu_prompt_arg "Repository URL" git-clone-ide; }

__mt_menu_base64_encode() { __mt_menu_prompt_arg "Text to encode" base64-enc; }
__mt_menu_base64_decode() { __mt_menu_prompt_arg "Base64 text to decode" base64-dec; }

#######################################
# System: "Setup & Config" submenu
#######################################
__mt_menu_setup() {
  __mt_menu_submenu "⚙️  Setup & Config" \
    "System Configuration (mt-wizard-system)" mt-wizard-system \
    "AI Provider Configuration (mt-wizard-ai)" mt-wizard-ai \
    "Git Configuration (mt-wizard-git)" mt-wizard-git \
    "CI/CD Configuration (mt-wizard-cicd)" mt-wizard-cicd \
    "Docker Configuration (mt-wizard-docker)" mt-wizard-docker \
    "Exports Configuration (mt-wizard-exports)" mt-wizard-exports \
    "Paths Configuration (mt-wizard-paths)" mt-wizard-paths \
    "Add Gemini API Key (mt-add-gemini-key)" mt-add-gemini-key \
    "Add Claude API Key (mt-add-claude-key)" mt-add-claude-key \
    "Set Default AI Provider (mt-set-default-ai)" __mt_menu_pick_default_ai \
    "Set Default IDE (mt-set-default-ide)" __mt_menu_pick_default_ide \
    "Set CI/CD Provider (mt-set-cicd)" __mt_menu_pick_cicd \
    "Toggle AI Integration (mt-toggle-ai)" mt-toggle-ai \
    "Toggle Format-on-Push (mt-toggle-format-on-push)" mt-toggle-format-on-push \
    "Set Git Sync URL (mt-add-sync-url)" __mt_menu_add_sync_url \
    "Set Upstream Repo Path (mt-set-upstream-path)" __mt_menu_set_upstream_path \
    "Reload Config from Disk (mt-load-config)" mt-load-config \
    "Open config.yaml in IDE (mt-open-config)" mt-open-config \
    "View Active Configuration (mt-config)" mt-config
}

#######################################
# System: "AI Workflows" submenu
#######################################
__mt_menu_ai() {
  __mt_menu_submenu "🤖 AI Workflows" \
    "Query AI (ai)" __mt_menu_ai_query \
    "Explain a Command (ai-explain)" __mt_menu_ai_explain \
    "Debug Last Failed Command (mt-ai-debug)" mt-ai-debug \
    "Check AI Quota (mt-ai-quota)" mt-ai-quota
}

#######################################
# System: "Code Exports" submenu
#######################################
__mt_menu_exports() {
  __mt_menu_submenu "📦 Code Exports" \
    "Interactive Export (mt-export -i)" __mt_menu_export_interactive \
    "Copy to Clipboard (mt-copy)" __mt_menu_copy_prompt \
    "Interactive Export Cleanup (mt-export-cleanup -i)" __mt_menu_export_cleanup_interactive
}

#######################################
# System: "Terminal UI" submenu
#######################################
__mt_menu_ui() {
  __mt_menu_submenu "🎨 Terminal UI" \
    "Change Theme (mt-set-theme)" __mt_menu_pick_theme \
    "Gemini Status (mt-get-gemini-status)" mt-get-gemini-status
}

#######################################
# System: "Search & Docs" submenu
#######################################
__mt_menu_docs() {
  __mt_menu_submenu "🔍 Search & Docs" \
    "Search Commands (mt-search -i)" __mt_menu_search_interactive \
    "Run a Command (mt-run)" mt-run \
    "Fuzzy-Find Any Tool (mt-fzf)" mt-fzf \
    "List Functions (mt-list --func)" __mt_menu_list_func \
    "List Aliases (mt-list --alias)" __mt_menu_list_alias \
    "Browse Categories (mt-cats)" mt-cats \
    "Refresh Docs & Caches (mt-refresh-caches)" mt-refresh-caches
}

#######################################
# System: "Docker Tools" submenu
#######################################
__mt_menu_docker() {
  __mt_menu_submenu "🐳 Docker Tools" \
    "List Containers (docker-ls)" docker-ls \
    "Shell into Container (docker-shell)" docker-shell \
    "Launch Throwaway Sandbox (docker-sandbox)" docker-sandbox \
    "Tail Container Logs (docker-tail)" docker-tail \
    "Restart All Running Containers (docker-reboot-all)" docker-reboot-all \
    "Nuke Unused Resources (docker-nuke)" docker-nuke
}

#######################################
# System: "GCP & Kubernetes" submenu
#######################################
__mt_menu_gcp() {
  __mt_menu_submenu "☁️  GCP & Kubernetes" \
    "Switch GCP Project (gcp-set-project)" gcp-set-project \
    "Get/Set Kube Namespace (kns)" kns \
    "List gcloud Config (gcl-config)" gcl-config \
    "Export Project Vars (gcl-export-vars)" gcl-export-vars \
    "Show Active Project (gcl-get-project)" gcl-get-project \
    "Show Project Number (gcl-get-project-number)" gcl-get-project-number \
    "Show Active Region (gcl-get-region)" gcl-get-region \
    "Show Active User (gcl-get-user)" gcl-get-user \
    "Show Active Zone (gcl-get-zone)" gcl-get-zone \
    "List Org Policies (gcl-org-policies)" gcl-org-policies \
    "Update gcloud CLI (gcl-update)" gcl-update \
    "gcloud Auth Login (gcp-login)" gcp-login \
    "gcloud ADC Login (gcp-login-adc)" gcp-login-adc \
    "Show IAM Bindings (gcp-iam-show)" gcp-iam-show \
    "Run BigQuery SQL (bq-query)" __mt_menu_bq_query \
    "Run gcloud as JSON (gcl-as-json)" __mt_menu_gcl_as_json \
    "Tail Cloud Run Function Logs (gcp-crf-logs)" __mt_menu_gcp_crf_logs \
    "Configure Artifact Registry Auth (gcp-gar-docker)" __mt_menu_gcp_gar_docker \
    "Read Secret Manager Secret (gcp-get-secret)" __mt_menu_gcp_get_secret \
    "Pull Pub/Sub Message (gcp-ps-pull)" __mt_menu_gcp_ps_pull
}

#######################################
# System: "Terraform" submenu
#######################################
__mt_menu_terraform() {
  __mt_menu_submenu "🏔️  Terraform" \
    "Validate All Terraform (tf-val-all)" tf-val-all \
    "Clean Terraform Caches (tf-clean)" tf-clean \
    "Generate IAM Bindings (tf-iam)" tf-iam \
    "Plan Resource Replacement (tf-replace)" __mt_menu_tf_replace \
    "Run with YAML Var File (tf-yaml)" __mt_menu_tf_yaml
}

#######################################
# System: "Git Workflows" submenu
#######################################
__mt_menu_git() {
  __mt_menu_submenu "🌿 Git Workflows" \
    "Raise a Pull Request (git-raise-pr)" git-raise-pr \
    "Clean Merged Branches (git-clean-merged)" git-clean-merged \
    "AI-Grouped Push (git-ai-push-all)" git-ai-push-all \
    "Rebase onto Default Branch (git-default-rebase)" git-default-rebase \
    "Hard-Reset to Upstream (git-nuke)" git-nuke \
    "Show Pretty Log Graph (git-pretty-log)" git-pretty-log \
    "Open Remote URL (git-view-remote)" git-view-remote \
    "New Feature Branch (git-new-feature)" __mt_menu_git_new_feature \
    "Stage, Commit & Push All (git-push-all)" __mt_menu_git_push_all \
    "Clone & Open in IDE (git-clone-ide)" __mt_menu_git_clone_ide \
    "List Local Repos (mt-repos)" mt-repos \
    "AI-Generate .gitignore (mt-ai-gitignore)" mt-ai-gitignore \
    "AI-Generate README (mt-ai-readme)" mt-ai-readme
}

#######################################
# System: "General Utilities" submenu
#######################################
__mt_menu_utilities() {
  __mt_menu_submenu "🛠️  General Utilities" \
    "Serve Current Directory over HTTP (mt-serve)" mt-serve \
    "Scaffold Repo from Blueprint (mt-blueprint)" mt-blueprint \
    "Encode Text to Base64 (base64-enc)" __mt_menu_base64_encode \
    "Decode Base64 Text (base64-dec)" __mt_menu_base64_decode \
    "Format Code to Google Style (google-fmt)" google-fmt \
    "List Largest Files (mt-top-files)" mt-top-files \
    "Audit VCS Root (mt-vcs-audit)" mt-vcs-audit \
    "Run/Save Clipboard Code (mt-apply)" mt-apply \
    "Show Command History (mt-cmd-history)" mt-cmd-history \
    "List Background Jobs (mt-jobs)" mt-jobs \
    "Backup Current Directory (mt-backup)" mt-backup \
    "Restore from Backup (mt-restore)" mt-restore
}

#######################################
# System: "System & Bootstrap" submenu
#######################################
__mt_menu_system() {
  __mt_menu_submenu "⚡ System & Bootstrap" \
    "Install Missing Dependencies (bootstrap)" bootstrap \
    "Install Pending Packages (sys-install)" sys-install \
    "Update System Packages (sys-update)" sys-update \
    "Framework Health Dashboard (mt-status)" mt-status \
    "Show Profile Version (mt-get-version)" mt-get-version \
    "View Framework Logs (mt-logs)" mt-logs \
    "Download Release Zip (mt-download-release)" mt-download-release
}

#######################################
# System: "Launchers" submenu
#######################################
__mt_menu_launchers() {
  __mt_menu_submenu "🚀 Launchers" \
    "cd to AI Workspace (cd-ai-workspace)" cd-ai-workspace \
    "cd to Docker Dir + Explorer (cd-win-docker)" cd-win-docker \
    "Open Current Dir in IDE (ide)" ide \
    "cd to Dotfiles Repo (mt-dotfiles)" mt-dotfiles \
    "Open Dotfiles Homepage (mt-open-homepage)" mt-open-homepage \
    "Open AI Workspace in File Manager (win-ai-workspace)" win-ai-workspace \
    "Open Docker Root in File Manager (win-docker)" win-docker \
    "Open Sync Repo in File Manager (win-sync)" win-sync \
    "Open Exports Dir in File Manager (win-export)" win-export \
    "Open VCS Root in File Manager (win-vcs)" win-vcs \
    "Open Current Dir in File Manager (win)" win
}

#######################################
# System: Launch the interactive master router for the entire framework
# Usage: mt-menu
#######################################
mt-menu() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  while true; do
    echo -e "${CB_BLUE}==========================================================${C_RESET}"
    echo -e "${CB_BLUE}              MT DEVOPS FRAMEWORK - MASTER MENU            ${C_RESET}"
    echo -e "${CB_BLUE}==========================================================${C_RESET}\n"

    local options=(
      "1. ⚙️  Setup & Config"
      "2. 🤖 AI Workflows"
      "3. 📦 Code Exports"
      "4. 🎨 Terminal UI"
      "5. 🔍 Search & Docs"
      "6. 🐳 Docker Tools"
      "7. ☁️  GCP & Kubernetes"
      "8. 🏔️  Terraform"
      "9. 🌿 Git Workflows"
      "10. 🛠️  General Utilities"
      "11. ⚡ System & Bootstrap"
      "12. 🚀 Launchers"
      "13. 🚪 Exit"
    )

    local choice
    choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="🚀 Select a category > " --height=~20 --layout=reverse --border)

    case "$choice" in
      1.*) __mt_menu_setup ;;
      2.*) __mt_menu_ai ;;
      3.*) __mt_menu_exports ;;
      4.*) __mt_menu_ui ;;
      5.*) __mt_menu_docs ;;
      6.*) __mt_menu_docker ;;
      7.*) __mt_menu_gcp ;;
      8.*) __mt_menu_terraform ;;
      9.*) __mt_menu_git ;;
      10.*) __mt_menu_utilities ;;
      11.*) __mt_menu_system ;;
      12.*) __mt_menu_launchers ;;
      *) return 0 ;;
    esac
  done
}
