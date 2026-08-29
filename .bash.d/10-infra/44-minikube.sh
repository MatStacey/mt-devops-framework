# shellcheck shell=bash
# ------------------------------------------
# Minikube (Local Kubernetes Cluster) Tools
# ------------------------------------------
# ~/.bash.d/10-infra/44-minikube.sh

#######################################
# Minikube: Shared guard for every mk-* command -- fails fast with a
# clear message instead of letting a raw minikube invocation error out.
# Returns:
#   0 if minikube is installed, 1 otherwise
#######################################
__mk_ensure_installed() {
  if ! command -v minikube > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 minikube is not installed.${C_RESET}"
    return 1
  fi
}

#######################################
# Minikube: Resolve which profile to act on -- returns the sole existing
# profile (or the "minikube" default if none exist yet) without
# prompting, and only opens an fzf picker when there's a genuine choice
# to make. Shared by mk-stop/mk-delete since both take an optional
# profile argument with identical fallback behavior.
# Arguments:
#   $1 - fzf prompt label to show when more than one profile exists
# Outputs:
#   Prints the chosen profile name to stdout, or nothing if cancelled
#######################################
__mk_pick_profile() {
  local prompt_label="$1"
  local -a profiles
  mapfile -t profiles < <(minikube profile list -o json 2> /dev/null | jq -r '.valid[]?.Name' 2> /dev/null)
  if [ "${#profiles[@]}" -le 1 ]; then
    echo "${profiles[0]:-minikube}"
    return 0
  fi
  printf '%s\n' "${profiles[@]}" | fzf --prompt="${prompt_label} > " --height=~10 --layout=reverse --border
}

#######################################
# Minikube: Dashboard summarizing a local cluster's lifecycle state --
# profile, driver, and Host/Kubelet/APIServer status.
# Usage: mk-status [profile]
# Arguments:
#   $1 - (Optional) Profile name. Defaults to "minikube".
#######################################
mk-status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __mk_ensure_installed || return 1

  local profile="${1:-minikube}"
  local status_json
  status_json=$(minikube status -p "$profile" -o json 2> /dev/null)
  if [ -z "$status_json" ]; then
    echo -e "${CB_YELLOW}⚠️  No minikube cluster found for profile '${profile}'. Run 'mk-start' first.${C_RESET}"
    return 1
  fi

  local host kubelet apiserver driver
  host=$(echo "$status_json" | jq -r '.Host // "unknown"')
  kubelet=$(echo "$status_json" | jq -r '.Kubelet // "unknown"')
  apiserver=$(echo "$status_json" | jq -r '.APIServer // "unknown"')
  driver=$(minikube profile list -o json 2> /dev/null | jq -r --arg p "$profile" '.valid[]? | select(.Name==$p) | .Config.Driver // "unknown"')

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}              MINIKUBE STATUS                              ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_CYAN}Profile   :${C_RESET} ${profile}"
  echo -e "${CB_CYAN}Driver    :${C_RESET} ${driver:-unknown}"
  echo -e "${CB_CYAN}Host      :${C_RESET} ${host}"
  echo -e "${CB_CYAN}Kubelet   :${C_RESET} ${kubelet}"
  echo -e "${CB_CYAN}APIServer :${C_RESET} ${apiserver}"
}

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
  local log_dir="${LOG_DIR:-$HOME/.bash.d/data/logs}"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local log_file="${log_dir}/minikube-dashboard_${timestamp}.log"

  __mt_bg_run "minikube-dashboard: ${profile}" "$log_file" "minikube dashboard -p '${profile}'"
}

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

# Load minikube's own bash completion for profile/addon names.
if command -v minikube > /dev/null 2>&1; then
  source <(minikube completion bash 2> /dev/null)
fi
