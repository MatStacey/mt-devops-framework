# shellcheck shell=bash
# ------------------------------------------
# Docker: Image Build, Versioning & Registry Push
# ------------------------------------------
# ~/.bash.d/02-utilities/36-docker-registry.sh

DOCKER_VERSIONS="$HOME/.bash.d/lib/python/docker_versions.py"

#######################################
# Docker: Compute the next auto-incremented semver for an image. Thin
# wrapper over lib/python/docker_versions.py -- version bookkeeping is
# pure data-shape logic with no need to touch the calling shell's
# state, so it lives in Python (like config_manager.py/secrets_manager.py)
# rather than as bash/awk.
# Arguments:
#   $1 - Image name
# Outputs:
#   Prints the next version (e.g. v0.1.0 for a never-built image, or
#   v1.2.4 following a recorded v1.2.3) to stdout
#######################################
__docker_next_version() {
  python3 "$DOCKER_VERSIONS" next-version "$1"
}

#######################################
# Docker: Look up the most recently built version recorded for an image
# (see __docker_record_version). Used by docker-tag/docker-push/
# docker-deploy to act on whatever was last actually built, as opposed
# to __docker_next_version's forward-looking increment.
# Arguments:
#   $1 - Image name
# Outputs:
#   Prints the last recorded version, or nothing if the image has never
#   been built via docker-build
#######################################
__docker_last_version() {
  python3 "$DOCKER_VERSIONS" last-version "$1"
}

#######################################
# Docker: Persist the version just built for an image, so the next
# 'docker-build' auto-increments from it. Only ever called after a
# successful build (see docker-build), so a failed build never burns a
# version number.
# Arguments:
#   $1 - Image name
#   $2 - Version that was just built (e.g. v0.1.0)
#######################################
__docker_record_version() {
  python3 "$DOCKER_VERSIONS" record-version "$1" "$2"
}

#######################################
# Docker: Build the fully-qualified image reference for a registry.
# Arguments:
#   $1 - Image name
#   $2 - Version tag
#   $3 - Registry: gar or dockerhub
# Globals:
#   DOCKER_GAR_REGION, DOCKER_GAR_REPO, DOCKER_DOCKERHUB_NAMESPACE
# Outputs:
#   Prints the fully-qualified reference to stdout, or an error to
#   stderr and returns 1 if the registry isn't configured
#######################################
__docker_registry_ref() {
  local image="$1" version="$2" registry="$3"

  case "$registry" in
    gar)
      if [ -z "$DOCKER_GAR_REPO" ]; then
        echo -e "${CB_RED}🚨 GAR repository not configured. Run 'mt-wizard-docker' first.${C_RESET}" >&2
        return 1
      fi
      local project
      project=$(gcl-get-project)
      if [ -z "$project" ]; then
        echo -e "${CB_RED}🚨 No active gcloud project. Run 'gcp-set-project' first.${C_RESET}" >&2
        return 1
      fi
      echo "${DOCKER_GAR_REGION}-docker.pkg.dev/${project}/${DOCKER_GAR_REPO}/${image}:${version}"
      ;;
    dockerhub)
      if [ -z "$DOCKER_DOCKERHUB_NAMESPACE" ]; then
        echo -e "${CB_RED}🚨 Docker Hub namespace not configured. Run 'mt-wizard-docker' first.${C_RESET}" >&2
        return 1
      fi
      echo "${DOCKER_DOCKERHUB_NAMESPACE}/${image}:${version}"
      ;;
    *)
      echo -e "${CB_RED}🚨 Unknown registry: '${registry}' (expected gar or dockerhub).${C_RESET}" >&2
      return 1
      ;;
  esac
}

#######################################
# Docker: Authenticate the local docker CLI against a registry.
# Arguments:
#   $1 - Registry: gar or dockerhub
# Globals:
#   DOCKER_GAR_REGION, DOCKERHUB_USERNAME, DOCKERHUB_TOKEN
#######################################
__docker_registry_login() {
  local registry="$1"

  case "$registry" in
    gar)
      gcp-gar-docker "${DOCKER_GAR_REGION}"
      ;;
    dockerhub)
      if [ -z "$DOCKERHUB_USERNAME" ] || [ -z "$DOCKERHUB_TOKEN" ]; then
        echo -e "${CB_RED}🚨 Docker Hub credentials not configured. Run 'mt-add-dockerhub-secret' first.${C_RESET}"
        return 1
      fi
      docker login -u "$DOCKERHUB_USERNAME" --password-stdin <<< "$DOCKERHUB_TOKEN"
      ;;
    *)
      echo -e "${CB_RED}🚨 Unknown registry: '${registry}' (expected gar or dockerhub).${C_RESET}"
      return 1
      ;;
  esac
}

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
