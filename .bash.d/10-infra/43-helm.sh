# shellcheck shell=bash
# ------------------------------------------
# Helm (Kubernetes Package Manager) Tools
# ------------------------------------------
# ~/.bash.d/10-infra/43-helm.sh

#######################################
# Helm: Shared guard for every helm-* command -- checks the helm binary
# is present, then defers to __k8s_ensure_context (42-kubectl.sh) since
# helm operates against the same active kubectl context.
# Returns:
#   0 if helm is installed and a kubectl context is set, 1 otherwise
#######################################
__helm_ensure_ready() {
  if ! command -v helm > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 helm is not installed.${C_RESET}"
    return 1
  fi
  __k8s_ensure_context
}

#######################################
# Helm: Dashboard summarizing helm's view of the active context -- CLI
# version, release count across all namespaces, and configured repo
# count.
# Usage: helm-status
#######################################
helm-status() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local ctx version releases repos
  ctx=$(kubectl config current-context 2> /dev/null)
  version=$(helm version --short 2> /dev/null)
  releases=$(helm list -A --short 2> /dev/null | wc -l | tr -d ' ')
  repos=$(helm repo list -o json 2> /dev/null | jq 'length' 2> /dev/null)

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_BLUE}              HELM STATUS                                  ${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_CYAN}Context   :${C_RESET} ${ctx}"
  echo -e "${CB_CYAN}Version   :${C_RESET} ${version:-unknown}"
  echo -e "${CB_CYAN}Releases  :${C_RESET} ${releases:-0} (all namespaces)"
  echo -e "${CB_CYAN}Repos     :${C_RESET} ${repos:-0}"
}

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

#######################################
# Helm: List releases in a clean table
# Usage: helm-list [-A]
# Options:
#   -A  Show releases across all namespaces
#######################################
helm-list() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  if [[ "$1" == "-A" ]]; then
    helm list --all-namespaces
  else
    helm list
  fi
}

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

#######################################
# Helm: Uninstall a release, always confirmed via the destructive-op
# guard first -- the one genuinely irreversible action in this file.
# Usage: helm-uninstall
#######################################
helm-uninstall() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __helm_ensure_ready || return 1

  local release
  release=$(helm list --short 2> /dev/null | fzf --prompt="⎈  Select Release to Uninstall > " --height=~10 --layout=reverse --border)
  if [ -z "$release" ]; then
    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"
    return 0
  fi

  __k8s_confirm_destructive "About to uninstall release ${release}." || {
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 1
  }

  helm uninstall "$release" && echo -e "${CB_GREEN}✅ Uninstalled ${release}.${C_RESET}"
}

# Load helm's own bash completion for release/repo/chart names.
if command -v helm > /dev/null 2>&1; then
  source <(helm completion bash 2> /dev/null)
fi
