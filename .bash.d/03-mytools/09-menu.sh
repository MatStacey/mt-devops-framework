# shellcheck shell=bash
# ------------------------------------------
# System: Interactive Master Menu
# ------------------------------------------
# ~/.bash.d/03-mytools/09-menu.sh

#######################################
# System: Generic fzf submenu loop -- shows a list of labeled actions,
# runs the selected one, and redisplays the same list until the user
# backs out (empty selection or the trailing "Back" entry). Dispatch is
# by exact label match rather than a numeric index, since fzf's fuzzy
# search matches selected TEXT, not a position -- a numbered prefix here
# would be a false affordance (typing "1" fuzzy-matches every label
# containing that digit, not just item 1). A pair whose command is the
# empty string ("") renders as a non-actionable section-header row --
# selecting one just redisplays the menu, used to visually group related
# items in a long submenu.
# Arguments:
#   $1   - Submenu title, shown as the fzf prompt
#   $@   - Remaining args: alternating "label" "command" pairs. Each
#          command is a single already-defined command/function name
#          (no inline arguments) -- anything needing flags or prompted
#          input should be wrapped in its own tiny __mt_menu_* function
#          first, matching the pattern used elsewhere in this file. Pass
#          "" as the command for a section-header label.
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

  while true; do
    local -a options=("${labels[@]}" "⬅  Back")

    local choice
    choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="${title} > " --height=~20 --layout=reverse --border)
    [ -z "$choice" ] && return 0
    [ "$choice" = "⬅  Back" ] && return 0

    local i
    for i in "${!labels[@]}"; do
      if [ "${labels[$i]}" = "$choice" ]; then
        if [ -n "${commands[$i]}" ]; then
          "${commands[$i]}"
          echo -e "\n${C_DIM}Press Enter to continue...${C_RESET}"
          read -r < /dev/tty
        fi
        break
      fi
    done
  done
}

#######################################
# System: Generic fzf category-picker loop -- identical to
# __mt_menu_submenu except it never shows "Press Enter to continue..."
# after dispatching, since every entry here is itself another
# interactive submenu loop (not a one-shot action), and that submenu's
# own "⬅  Back" already returns control here cleanly.
# Arguments:
#   $1   - Category menu title, shown as the fzf prompt
#   $@   - Remaining args: alternating "label" "submenu function" pairs
#######################################
__mt_menu_category() {
  local title="$1"
  shift
  local -a labels=() commands=()
  while [ "$#" -gt 0 ]; do
    labels+=("$1")
    commands+=("$2")
    shift 2
  done

  while true; do
    local -a options=("${labels[@]}" "⬅  Back")

    local choice
    choice=$(printf '%s\n' "${options[@]}" | fzf --prompt="${title} > " --height=~20 --layout=reverse --border)
    [ -z "$choice" ] && return 0
    [ "$choice" = "⬅  Back" ] && return 0

    local i
    for i in "${!labels[@]}"; do
      if [ "${labels[$i]}" = "$choice" ]; then
        "${commands[$i]}"
        break
      fi
    done
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
# System: fzf-pick a prompt segment (git/gcp/ai/k8s) and toggle its
# visibility via mt-toggle-display
#######################################
__mt_menu_toggle_display_element() {
  local element
  element=$(printf '%s\n' git gcp ai k8s | fzf --prompt="🎨 Toggle Prompt Element > " --height=~10 --layout=reverse --border)
  if [ -z "$element" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi
  mt-toggle-display --element "$element"
}

#######################################
# System: fzf-pick which GCP identity field(s) the prompt's GCP segment
# shows, and apply it via mt-toggle-display --gcp-mode
#######################################
__mt_menu_pick_gcp_display_mode() {
  local mode
  mode=$(printf '%s\n' project account both | fzf --prompt="☁️  GCP Display Mode > " --height=~10 --layout=reverse --border)
  if [ -z "$mode" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi
  mt-toggle-display --gcp-mode "$mode"
}

#######################################
# System: Toggle the AI segment's model/version parenthetical via
# mt-toggle-display --ai-model -- wrapped since __mt_menu_submenu
# commands can't take inline arguments
#######################################
__mt_menu_toggle_ai_model() {
  mt-toggle-display --ai-model
}

#######################################
# System: Toggle compact icon labels for prompt segments via
# mt-toggle-display --compact -- wrapped since __mt_menu_submenu
# commands can't take inline arguments
#######################################
__mt_menu_toggle_compact_labels() {
  mt-toggle-display --compact
}

#######################################
# System: Prompt for a max Git branch name length and apply it via
# mt-toggle-display --git-branch-len
#######################################
__mt_menu_set_git_branch_len() {
  local len
  read -r -p "Max Git branch name length before truncation, 0 = unlimited [30]: " len < /dev/tty
  mt-toggle-display --git-branch-len "${len:-30}"
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
__mt_menu_docker_start() { docker-daemon start; }
__mt_menu_docker_stop() { docker-daemon stop; }

__mt_menu_ai_query() { __mt_menu_prompt_arg "Prompt for AI" ai; }
__mt_menu_ai_explain() { __mt_menu_prompt_arg "Command to explain" ai-explain; }

__mt_menu_pick_default_ai() { __mt_menu_pick_enum "🤖 Default AI Provider" mt-set-default-ai gemini claude local; }
__mt_menu_pick_default_ide() { __mt_menu_pick_enum "💻 Default IDE" mt-set-default-ide vscode intellij; }
__mt_menu_pick_cicd() { __mt_menu_pick_enum "⚙️  CI/CD Provider" mt-set-cicd github bitbucket gitlab azure jenkins; }
__mt_menu_add_sync_url() { __mt_menu_prompt_arg "Git sync repository URL" mt-add-sync-url; }

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
__mt_menu_clone_wizard() { mt-clone -i; }
__mt_menu_bulk_update() { mt-bulk-update; }
__mt_menu_bulk_update_bg() { mt-bulk-update -b; }

__mt_menu_base64_encode() { __mt_menu_prompt_arg "Text to encode" base64-enc; }
__mt_menu_base64_decode() { __mt_menu_prompt_arg "Base64 text to decode" base64-dec; }

#######################################
# System: Prompt for a repo name then a repo URL and pass both to
# helm-repo add -- wrapped since __mt_menu_submenu commands can't take
# inline arguments and this one needs two separate prompted values
#######################################
__mt_menu_helm_repo_add() {
  local name url
  read -r -p "Repo name: " name < /dev/tty
  if [ -z "$name" ]; then
    echo -e "${CB_YELLOW}⚠️  Cancelled.${C_RESET}"
    return 0
  fi
  read -r -p "Repo URL: " url < /dev/tty
  if [ -z "$url" ]; then
    echo -e "${CB_YELLOW}⚠️  Cancelled.${C_RESET}"
    return 0
  fi
  helm-repo add "$name" "$url"
}

#######################################
# System: "Setup & Config" -> "Guided Wizards" submenu -- full
# multi-question configuration flows
#######################################
__mt_menu_setup_wizards() {
  __mt_menu_submenu "🧙 Guided Wizards" \
    "System Configuration (mt-wizard-system)" mt-wizard-system \
    "AI Provider Configuration (mt-wizard-ai)" mt-wizard-ai \
    "Git Configuration (mt-wizard-git)" mt-wizard-git \
    "CI/CD Configuration (mt-wizard-cicd)" mt-wizard-cicd \
    "Docker Configuration (mt-wizard-docker)" mt-wizard-docker \
    "Minikube Configuration (mt-wizard-minikube)" mt-wizard-minikube \
    "Exports Configuration (mt-wizard-exports)" mt-wizard-exports \
    "Paths Configuration (mt-wizard-paths)" mt-wizard-paths
}

#######################################
# System: "Setup & Config" -> "Quick Setters & Toggles" submenu --
# single-value changes for when you don't want to walk through an
# unrelated wizard question
#######################################
__mt_menu_setup_quick() {
  __mt_menu_submenu "⚡ Quick Setters & Toggles" \
    "Set Default AI Provider (mt-set-default-ai)" __mt_menu_pick_default_ai \
    "Set Default IDE (mt-set-default-ide)" __mt_menu_pick_default_ide \
    "Set CI/CD Provider (mt-set-cicd)" __mt_menu_pick_cicd \
    "Toggle AI Integration (mt-toggle-ai)" mt-toggle-ai \
    "Toggle Format-on-Push (mt-toggle-format-on-push)" mt-toggle-format-on-push \
    "Toggle Update-Divergence Confirmation (mt-toggle-update-confirm)" mt-toggle-update-confirm \
    "Set Git Sync URL (mt-add-sync-url)" __mt_menu_add_sync_url
}

#######################################
# System: "Setup & Config" -> "Secrets & Collaboration" submenu
#######################################
__mt_menu_setup_secrets() {
  __mt_menu_submenu "🔐 Secrets & Collaboration" \
    "Add Gemini API Key (mt-add-gemini-key)" mt-add-gemini-key \
    "Add Claude API Key (mt-add-claude-key)" mt-add-claude-key \
    "Add Bitbucket API Token (mt-add-bitbucket-secret)" mt-add-bitbucket-secret \
    "Add Docker Hub Credentials (mt-add-dockerhub-secret)" mt-add-dockerhub-secret \
    "Become a Collaborator / Fork Setup (mt-become-collaborator)" mt-become-collaborator
}

#######################################
# System: "Setup & Config" -> "Terminal & Display" submenu
#######################################
__mt_menu_setup_terminal() {
  __mt_menu_submenu "🎨 Terminal & Display" \
    "Change Theme (mt-set-theme)" __mt_menu_pick_theme \
    "Gemini Status (mt-get-gemini-status)" mt-get-gemini-status \
    "View Prompt Display Settings (mt-toggle-display)" mt-toggle-display \
    "Toggle a Prompt Element -- Git/GCP/AI/K8s (mt-toggle-display)" __mt_menu_toggle_display_element \
    "Set GCP Display Mode (mt-toggle-display)" __mt_menu_pick_gcp_display_mode \
    "Toggle AI Model/Version Detail (mt-toggle-display)" __mt_menu_toggle_ai_model \
    "Toggle Compact Icon Labels (mt-toggle-display)" __mt_menu_toggle_compact_labels \
    "Set Max Git Branch Name Length (mt-toggle-display)" __mt_menu_set_git_branch_len
}

#######################################
# System: "Setup & Config" -> "Maintenance & View" submenu
#######################################
__mt_menu_setup_maintenance() {
  __mt_menu_submenu "🔧 Maintenance & View" \
    "Run Diagnostics (mt-doctor)" mt-doctor \
    "Symlink ~/.bash.d Into Sync Repo (mt-migrate-symlink)" mt-migrate-symlink \
    "Reload Config from Disk (mt-load-config)" mt-load-config \
    "Clean Up Legacy config.yaml Keys (mt-migrate-config)" mt-migrate-config \
    "Open config.yaml in IDE (mt-open-config)" mt-open-config \
    "View Active Configuration (mt-config)" mt-config \
    "⚠️  Uninstall Framework (mt-uninstall)" mt-uninstall
}

#######################################
# System: "Setup & Config" category picker -- routes to the Guided
# Wizards, Quick Setters & Toggles, Secrets & Collaboration, Terminal &
# Display, and Maintenance & View submenus
#######################################
__mt_menu_setup() {
  __mt_menu_category "⚙️  Setup & Config" \
    "🧙 Guided Wizards" __mt_menu_setup_wizards \
    "⚡ Quick Setters & Toggles" __mt_menu_setup_quick \
    "🔐 Secrets & Collaboration" __mt_menu_setup_secrets \
    "🎨 Terminal & Display" __mt_menu_setup_terminal \
    "🔧 Maintenance & View" __mt_menu_setup_maintenance
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
    "Refresh Docs & Caches (mt-refresh-caches)" mt-refresh-caches \
    "💡 Suggest a Backlog Idea/Gap (mt-suggest)" mt-suggest
}

#######################################
# System: "Docker Tools" submenu -- daemon controls come first since
# everything below them needs the daemon running, followed by everyday
# usage, then broad-impact actions (restart-all, nuke) flagged with a
# ⚠️ label prefix so the warning is visible before the item is even
# selected, not just after.
#######################################
__mt_menu_docker() {
  __mt_menu_submenu "🐳 Docker Tools" \
    "🟢 Start Docker Daemon (docker-daemon start)" __mt_menu_docker_start \
    "🔴 Stop Docker Daemon (docker-daemon stop)" __mt_menu_docker_stop \
    "List Containers (docker-ls)" docker-ls \
    "Shell into Container (docker-shell)" docker-shell \
    "Launch Throwaway Sandbox (docker-sandbox)" docker-sandbox \
    "Tail Container Logs (docker-tail)" docker-tail \
    "Build Image (docker-build)" docker-build \
    "Tag Image for Registry (docker-tag)" docker-tag \
    "Push Image (docker-push)" docker-push \
    "Build + Push Release (docker-release)" docker-release \
    "Deploy via Helm (docker-deploy)" docker-deploy \
    "⚠️  Restart All Running Containers (docker-reboot-all)" docker-reboot-all \
    "⚠️  Nuke Unused Resources (docker-nuke)" docker-nuke
}

#######################################
# System: "Kubernetes Tools" submenu -- status/context come first since
# everything below them needs a working context, followed by everyday
# usage, then broad-impact/irreversible actions (scale, delete) flagged
# with a ⚠️ label prefix so the warning is visible before the item is
# even selected, not just after. Mirrors __mt_menu_docker's structure.
#######################################
__mt_menu_k8s() {
  __mt_menu_submenu "⎈  Kubernetes Tools" \
    "Show Status (k8s-status)" k8s-status \
    "Switch Context (k8s-ctx)" k8s-ctx \
    "Connect to GKE Cluster (k8s-gke-connect)" k8s-gke-connect \
    "Get/Set Namespace (k8s-ns)" k8s-ns \
    "List Pods (k8s-pods)" k8s-pods \
    "Shell into Pod (k8s-shell)" k8s-shell \
    "Tail Pod Logs (k8s-tail)" k8s-tail \
    "Restart Deployment (k8s-restart)" k8s-restart \
    "⚠️  Scale Deployment (k8s-scale)" k8s-scale \
    "⚠️  Delete Resource (k8s-delete)" k8s-delete
}

#######################################
# System: "Helm Tools" submenu -- status/repos/search come first as
# read-only lookups, then the release lifecycle in the order you'd
# actually use it (install -> upgrade -> inspect), with rollback/
# uninstall flagged with a ⚠️ label prefix since both are routed through
# the destructive-op guard. Mirrors __mt_menu_k8s's structure.
#######################################
__mt_menu_helm() {
  __mt_menu_submenu "⛵ Helm Tools" \
    "Show Status (helm-status)" helm-status \
    "List Repos (helm-repo)" helm-repo \
    "Add Repo (helm-repo add)" __mt_menu_helm_repo_add \
    "Search Charts (helm-search)" helm-search \
    "List Releases (helm-list)" helm-list \
    "Install Chart (helm-install)" helm-install \
    "Upgrade Release (helm-upgrade)" helm-upgrade \
    "View Release Values (helm-values)" helm-values \
    "⚠️  Roll Back Release (helm-rollback)" helm-rollback \
    "⚠️  Uninstall Release (helm-uninstall)" helm-uninstall
}

#######################################
# System: "Minikube (Local Cluster)" submenu -- status/start come first
# since everything below needs a running cluster, followed by everyday
# usage, then the irreversible delete flagged with a ⚠️ label prefix.
# Mirrors __mt_menu_k8s's structure.
#######################################
__mt_menu_minikube() {
  __mt_menu_submenu "🧪 Minikube (Local Cluster)" \
    "Show Status (mk-status)" mk-status \
    "Start Cluster (mk-start)" mk-start \
    "Stop Cluster (mk-stop)" mk-stop \
    "Open Dashboard (mk-dashboard)" mk-dashboard \
    "Shell into Node (mk-ssh)" mk-ssh \
    "Start Tunnel (mk-tunnel)" mk-tunnel \
    "Toggle Addon (mk-addons)" mk-addons \
    "Load Local Image (mk-load-image)" mk-load-image \
    "⚠️  Delete Cluster (mk-delete)" mk-delete
}

#######################################
# System: "GCP" submenu -- the individual "show active
# project/region/zone/user" one-liners were removed since 'gcl-config'
# (gcloud config list) already prints all of them together in one view;
# 'gcl-get-project-number' is kept since it makes its own distinct API
# call for data 'config list' doesn't have. Kubernetes now has its own
# "Kubernetes Tools" submenu (see __mt_menu_k8s).
#######################################
__mt_menu_gcp() {
  __mt_menu_submenu "☁️  GCP" \
    "Switch GCP Project (gcp-set-project)" gcp-set-project \
    "List gcloud Config (gcl-config)" gcl-config \
    "Export Project Vars (gcl-export-vars)" gcl-export-vars \
    "Show Project Number (gcl-get-project-number)" gcl-get-project-number \
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
    "Generate IAM Bindings (tf-ai-iam)" tf-ai-iam \
    "Plan Resource Replacement (tf-replace)" __mt_menu_tf_replace \
    "Run with YAML Var File (tf-yaml)" __mt_menu_tf_yaml
}

#######################################
# System: "Git Workflows" submenu -- ordered to match how a workflow
# actually unfolds (start a branch/bring repos in -> do the work ->
# finish with a PR -> maintenance -> read-only utilities), with the
# destructive hard-reset flagged and pushed to the very end.
#######################################
__mt_menu_git() {
  __mt_menu_submenu "🌿 Git Workflows" \
    "New Feature Branch (git-new-feature)" __mt_menu_git_new_feature \
    "List Local Repos (mt-repos)" mt-repos \
    "Clone & Open in IDE (git-clone-ide)" __mt_menu_git_clone_ide \
    "Bulk-Clone a Project (mt-clone -i)" __mt_menu_clone_wizard \
    "Bulk-Update All Repos (mt-bulk-update)" __mt_menu_bulk_update \
    "Bulk-Update All Repos in Background (mt-bulk-update -b)" __mt_menu_bulk_update_bg \
    "AI-Generate .gitignore (mt-ai-gitignore)" mt-ai-gitignore \
    "Stage, Commit & Push All (git-push-all)" __mt_menu_git_push_all \
    "AI-Grouped Push (git-ai-push-all)" git-ai-push-all \
    "Raise a Pull Request (git-raise-pr)" git-raise-pr \
    "AI-Generate README (mt-ai-readme)" mt-ai-readme \
    "Rebase onto Default Branch (git-default-rebase)" git-default-rebase \
    "Clean Merged Branches (git-clean-merged)" git-clean-merged \
    "Show Pretty Log Graph (git-pretty-log)" git-pretty-log \
    "Open Remote URL (git-view-remote)" git-view-remote \
    "⚠️  Hard-Reset to Upstream (git-nuke)" git-nuke
}

#######################################
# System: "General Utilities" -> "Networking & Serving" submenu
#######################################
__mt_menu_utilities_networking() {
  __mt_menu_submenu "🌐 Networking & Serving" \
    "Serve Current Directory over HTTP (mt-http-server)" mt-http-server \
    "HTTP Server Manager (mt-server-manager)" mt-server-manager \
    "Run Internet Speed Test (mt-speedtest)" mt-speedtest
}

#######################################
# System: "General Utilities" -> "Scaffolding & Formatting" submenu
#######################################
__mt_menu_utilities_scaffolding() {
  __mt_menu_submenu "🏗️  Scaffolding & Formatting" \
    "Scaffold Repo from Blueprint (mt-blueprint)" mt-blueprint \
    "Format Code to Google Style (google-fmt)" google-fmt
}

#######################################
# System: "General Utilities" -> "Encoding" submenu
#######################################
__mt_menu_utilities_encoding() {
  __mt_menu_submenu "🔢 Encoding" \
    "Encode Text to Base64 (base64-enc)" __mt_menu_base64_encode \
    "Decode Base64 Text (base64-dec)" __mt_menu_base64_decode
}

#######################################
# System: "General Utilities" -> "Inspection & History" submenu
#######################################
__mt_menu_utilities_inspection() {
  __mt_menu_submenu "📊 Inspection & History" \
    "List Largest Files (mt-top-files)" mt-top-files \
    "Audit VCS Root (mt-vcs-audit)" mt-vcs-audit \
    "Show Command History (mt-cmd-history)" mt-cmd-history \
    "Run/Save Clipboard Code (mt-apply)" mt-apply
}

#######################################
# System: "General Utilities" -> "Backup & Jobs" submenu
#######################################
__mt_menu_utilities_backup() {
  __mt_menu_submenu "💾 Backup & Jobs" \
    "List Background Jobs (mt-jobs)" mt-jobs \
    "Backup Current Directory (mt-backup)" mt-backup \
    "Restore from Backup (mt-restore)" mt-restore
}

#######################################
# System: "General Utilities" category picker -- routes to Networking &
# Serving, Scaffolding & Formatting, Encoding, Inspection & History, and
# Backup & Jobs submenus instead of one flat undifferentiated list.
#######################################
__mt_menu_utilities() {
  __mt_menu_category "🛠️  General Utilities" \
    "🌐 Networking & Serving" __mt_menu_utilities_networking \
    "🏗️  Scaffolding & Formatting" __mt_menu_utilities_scaffolding \
    "🔢 Encoding" __mt_menu_utilities_encoding \
    "📊 Inspection & History" __mt_menu_utilities_inspection \
    "💾 Backup & Jobs" __mt_menu_utilities_backup
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
# System: "Launchers" -> "Navigate (cd)" submenu
#######################################
__mt_menu_launchers_navigate() {
  __mt_menu_submenu "📂 Navigate (cd)" \
    "cd to AI Workspace (cd-ai-workspace)" cd-ai-workspace \
    "cd to Dotfiles Repo (mt-dotfiles)" mt-dotfiles \
    "cd to Docker Dir + Explorer (cd-win-docker)" cd-win-docker \
    "cd to Current Repo's Root (cd-repo-root)" cd-repo-root
}

#######################################
# System: "Launchers" -> "IDE & Homepage" submenu
#######################################
__mt_menu_launchers_ide() {
  __mt_menu_submenu "💻 IDE & Homepage" \
    "Open Current Dir in IDE (ide)" ide \
    "Open Dotfiles Homepage (mt-open-homepage)" mt-open-homepage
}

#######################################
# System: "Launchers" -> "Open in File Manager" submenu
#######################################
__mt_menu_launchers_filemanager() {
  __mt_menu_submenu "🗂️  Open in File Manager" \
    "Open Current Dir in File Manager (win)" win \
    "Open AI Workspace in File Manager (win-ai-workspace)" win-ai-workspace \
    "Open Docker Root in File Manager (win-docker)" win-docker \
    "Open Sync Repo in File Manager (win-sync)" win-sync \
    "Open Exports Dir in File Manager (win-export)" win-export \
    "Open VCS Root in File Manager (win-vcs)" win-vcs
}

#######################################
# System: "Launchers" category picker -- routes to Navigate (cd), IDE &
# Homepage, and Open in File Manager submenus instead of interleaving
# all three action types in one flat list.
#######################################
__mt_menu_launchers() {
  __mt_menu_category "🚀 Launchers" \
    "📂 Navigate (cd)" __mt_menu_launchers_navigate \
    "💻 IDE & Homepage" __mt_menu_launchers_ide \
    "🗂️  Open in File Manager" __mt_menu_launchers_filemanager
}

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
