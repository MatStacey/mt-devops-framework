# shellcheck shell=bash
# ------------------------------------------
# Docker -> Kubernetes/Helm/Minikube Bridge
# ------------------------------------------
# ~/.bash.d/10-infra/45-docker-deploy.sh

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
    local version_file="$HOME/.bash.d/data/cache/.docker_image_versions.tsv"
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
