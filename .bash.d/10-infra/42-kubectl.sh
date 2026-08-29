# shellcheck shell=bash
# ------------------------------------------
# Container Orchestration (Kubernetes) Tools
# ------------------------------------------
# ~/.bash.d/10-infra/42-kubectl.sh

#######################################
# Kubernetes: Shared guard for every k8s-* command that needs a working
# kubectl context -- fails fast with a clear message instead of letting
# raw kubectl produce a cryptic connection-refused error.
# Returns:
#   0 if kubectl is installed and a context is set, 1 otherwise
#######################################
__k8s_ensure_context() {
  if ! command -v kubectl > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 kubectl is not installed.${C_RESET}"
    return 1
  fi
  if ! kubectl config current-context > /dev/null 2>&1; then
    echo -e "${CB_YELLOW}⚠️  No active kubectl context. Run 'k8s-ctx' or 'k8s-gke-connect' first.${C_RESET}"
    return 1
  fi
}

#######################################
# Kubernetes: Confirm before a destructive operation (delete, scale to
# zero) -- always shows the exact context/namespace being affected
# first, then a single-keystroke [y/N] confirmation for a normal-looking
# namespace, escalating to a typed "yes" (mirrors mt-uninstall's own
# most-destructive-step confirmation) when the current context or
# namespace name looks production-like, since that's exactly the case
# where a fat-fingered [y] is most expensive.
# Arguments:
#   $1 - Prompt text describing the action about to happen
# Returns:
#   0 if confirmed, 1 if declined
#######################################
__k8s_confirm_destructive() {
  local prompt="$1"
  local ctx ns
  ctx=$(kubectl config current-context 2> /dev/null)
  ns=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2> /dev/null)
  ns="${ns:-default}"

  echo -e "${CB_YELLOW}⚠️  ${prompt}${C_RESET}"
  echo -e "${CB_CYAN}Context:${C_RESET} ${ctx}   ${CB_CYAN}Namespace:${C_RESET} ${ns}"

  if [[ "${ctx,,}" == *prod* || "${ns,,}" == *prod* ]]; then
    echo -e "${CB_RED}🚨 This looks like a production context/namespace.${C_RESET}"
    local reply
    read -r -p 'Type "yes" to confirm: ' reply < /dev/tty
    [ "${reply,,}" = "yes" ]
    return
  fi

  read -r -p "Proceed? [y/N] " -n 1 < /dev/tty || REPLY="n"
  echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

#######################################
# Kubernetes: Dashboard summarizing the active context -- cluster,
# namespace, server version, node and pod counts.
# Usage: k8s-status
#######################################
k8s-status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1

  local ctx ns version nodes pods
  ctx=$(kubectl config current-context)
  ns=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2> /dev/null)
  ns="${ns:-default}"
  version=$(kubectl get --raw /version 2> /dev/null | jq -r '.gitVersion // "unknown"' 2> /dev/null)
  nodes=$(kubectl get nodes --no-headers 2> /dev/null | wc -l | tr -d ' ')
  pods=$(kubectl get pods -n "$ns" --no-headers 2> /dev/null | wc -l | tr -d ' ')

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}              KUBERNETES STATUS                            ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_CYAN}Context   :${C_RESET} ${ctx}"
  echo -e "${CB_CYAN}Namespace :${C_RESET} ${ns}"
  echo -e "${CB_CYAN}Server    :${C_RESET} ${version:-unknown}"
  echo -e "${CB_CYAN}Nodes     :${C_RESET} ${nodes:-0}"
  echo -e "${CB_CYAN}Pods      :${C_RESET} ${pods:-0} (in ${ns})"
}

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

_k8s_ctx_completions() {
  mapfile -t COMPREPLY < <(compgen -W "$(kubectl config get-contexts -o name 2> /dev/null)" -- "${COMP_WORDS[COMP_CWORD]}")
}
complete -F _k8s_ctx_completions k8s-ctx

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

_k8s_ns_completions() {
  mapfile -t COMPREPLY < <(compgen -W "$(kubectl get namespaces -o=jsonpath='{.items[*].metadata.name}' 2> /dev/null)" -- "${COMP_WORDS[COMP_CWORD]}")
}
complete -F _k8s_ns_completions k8s-ns

#######################################
# Kubernetes: List pods in a clean table
# Usage: k8s-pods [-A]
# Options:
#   -A  Show pods across all namespaces
#######################################
k8s-pods() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __k8s_ensure_context || return 1

  if [[ "$1" == "-A" ]]; then
    kubectl get pods --all-namespaces -o wide
  else
    kubectl get pods -o wide
  fi
}

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

#######################################
# Kubernetes: Kill every backgrounded 'kubectl logs' stream started by
# k8s-tail and clear its interrupt trap
# Globals (read):
#   pids
#######################################
__k8s_tail_cleanup() {
  echo -e "\n${CB_YELLOW}🛑 Stopping all log streams...${C_RESET}"
  kill "${pids[@]}" 2> /dev/null || true
}

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

# Load kubectl's own bash completion for resource types and names -- this
# is what actually replaces the old alias file's static resource
# shortcuts (kgpo, kgdep, kgsvc, ...); native completion covers every
# resource type kubectl knows about, not just the handful a hand-written
# alias list happened to include.
if command -v kubectl > /dev/null 2>&1; then
  source <(kubectl completion bash 2> /dev/null)
fi
