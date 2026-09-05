# shellcheck shell=bash
# ------------------------------------------
# Docker: Container Management Utilities
# ------------------------------------------
# ~/.bash.d/02-utilities/30-docker.sh

#######################################
# Docker: Check whether the Docker daemon is reachable
# Returns:
#   0 if 'docker info' succeeds, 1 otherwise
#######################################
__docker_is_running() {
  docker info > /dev/null 2>&1
}

#######################################
# Docker: Start the Docker daemon via systemd and wait until it's
# actually ready to accept commands, not just until systemctl returns --
# dockerd can take a few seconds to finish initializing after the unit
# reports active, and callers need a real answer, not an optimistic one.
# Returns:
#   0 once 'docker info' succeeds, 1 on failure or timeout
#######################################
__docker_daemon_start() {
  if ! command -v systemctl > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 systemctl not found -- don't know how to start the Docker daemon on this system.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}🐳 Starting Docker daemon...${C_RESET}"
  if ! sudo systemctl start docker; then
    echo -e "${CB_RED}🚨 Failed to start the Docker daemon.${C_RESET}"
    return 1
  fi

  local waited=0
  while ! __docker_is_running; do
    sleep 1
    ((waited++))
    if [ "$waited" -ge 30 ]; then
      echo -e "${CB_RED}🚨 Docker daemon started but isn't responding after 30s.${C_RESET}"
      return 1
    fi
  done

  echo -e "${CB_GREEN}✅ Docker daemon is running.${C_RESET}"
}

#######################################
# Docker: Shared guard for every docker-* command that needs a live
# daemon -- if it's not running, offers to start it instead of letting
# the underlying docker CLI fail with a raw connection error.
# Returns:
#   0 if Docker ends up running (already was, or was just started), 1 if
#   the user declined or the start failed
#######################################
__docker_ensure_running() {
  __docker_is_running && return 0

  echo -e "${CB_YELLOW}⚠️  Docker daemon is not running.${C_RESET}"
  local reply
  read -r -p "Start it now? [Y/n] " -n 1 reply < /dev/tty
  echo
  if [[ -n "$reply" && ! "$reply" =~ ^[Yy]$ ]]; then
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 1
  fi

  __docker_daemon_start
}

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

#######################################
# Docker: Report whether a container is ready to be considered "up" --
# running, and either healthy or has no healthcheck configured at all.
# Arguments:
#   $1 - Container name or ID
# Returns:
#   0 if ready, 1 otherwise (including if the container doesn't exist)
#######################################
__docker_reboot_container_ready() {
  local container="$1"
  local state health
  state=$(docker inspect --format '{{.State.Status}}' "$container" 2> /dev/null) || return 1
  [ "$state" = "running" ] || return 1

  health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2> /dev/null) || return 1
  [ "$health" = "healthy" ] || [ "$health" = "none" ]
}

#######################################
# Docker: Resolve the Compose project name and config file a running
# container belongs to, from its own labels. Fails for a container that
# wasn't started by Docker Compose (no such labels), or whose config
# file no longer exists on disk.
# Arguments:
#   $1 - Container name or ID
#   $2 - Name of the caller's variable to receive the project name
#   $3 - Name of the caller's variable to receive the compose file path
# Returns:
#   0 on success, 1 if the container isn't Compose-managed
#######################################
__docker_reboot_compose_metadata() {
  local container="$1" project_var="$2" compose_var="$3"
  local compose_project compose_files compose_path

  compose_project=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$container" 2> /dev/null) || return 1
  compose_files=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}' "$container" 2> /dev/null) || return 1
  [ -n "$compose_project" ] && [ -n "$compose_files" ] || return 1

  compose_path="${compose_files%%,*}"
  [ -f "$compose_path" ] || return 1

  printf -v "$project_var" '%s' "$compose_project"
  printf -v "$compose_var" '%s' "$compose_path"
}

#######################################
# Docker: Poll a just-recreated Compose project until every one of its
# containers reports ready (see __docker_reboot_container_ready), up to
# a fixed timeout.
# Arguments:
#   $1 - Path to the project's compose file
# Returns:
#   0 once every container is ready, 1 on timeout
#######################################
__docker_reboot_wait_for_project() {
  local compose_file="$1"
  local timeout=120 interval=2

  while ((timeout > 0)); do
    local containers
    containers=$(docker compose -f "$compose_file" ps -aq 2> /dev/null)

    if [ -n "$containers" ]; then
      local all_ready=true container
      while read -r container; do
        [ -z "$container" ] && continue
        __docker_reboot_container_ready "$container" || {
          all_ready=false
          break
        }
      done <<< "$containers"
      [ "$all_ready" = true ] && return 0
    fi

    sleep "$interval"
    ((timeout -= interval))
  done
  return 1
}

#######################################
# Docker: Extract the repository portion from an image reference.
#
# Examples:
#   redis:7                    -> redis
#   ghcr.io/example/app:latest -> ghcr.io/example/app
#   registry:5000/app:stable   -> registry:5000/app
#   image@sha256:...            -> image
#######################################
__docker_update_image_repo() {
  local image="$1"
  local ref="${image%@*}"
  local last_component="${ref##*/}"

  if [[ "$last_component" == *:* ]]; then
    printf '%s\n' "${ref%:*}"
  else
    printf '%s\n' "$ref"
  fi
}

#######################################
# Docker: Extract the tag from an image reference.
# Returns empty output for digest-pinned images.
#######################################
__docker_update_image_tag() {
  local image="$1"

  [[ "$image" == *@* ]] && return 0

  local last_component="${image##*/}"

  if [[ "$last_component" == *:* ]]; then
    printf '%s\n' "${last_component##*:}"
  else
    printf '%s\n' "latest"
  fi
}

#######################################
# Docker: Return the registry digest for an image reference without
# pulling the image.
#
# Uses Docker Buildx's registry manifest inspection and jq to extract
# the manifest digest.
#
# Arguments:
#   $1 - Image reference
# Returns:
#   0 and digest on success, 1 if the registry cannot be queried
#######################################
__docker_update_remote_digest() {
  local image="$1"
  local manifest

  manifest=$(docker buildx imagetools inspect "$image" --format '{{json .Manifest}}' 2> /dev/null) || return 1
  [ -n "$manifest" ] || return 1

  jq -r '.digest // empty' <<< "$manifest"
}

#######################################
# Docker: Return the registry digest associated with the image currently
# used by a container.
#
# Arguments:
#   $1 - Container name or ID
# Returns:
#   0 and digest on success, 1 if no RepoDigest is available
#######################################
__docker_update_local_digest() {
  local container="$1"
  local image_id digest_ref

  image_id=$(docker inspect --format '{{.Image}}' "$container" 2> /dev/null) || return 1
  digest_ref=$(docker image inspect "$image_id" --format '{{json .RepoDigests}}' 2> /dev/null | jq -r '.[0] // empty') || return 1

  [ -n "$digest_ref" ] || return 1
  [[ "$digest_ref" == *@* ]] || return 1

  printf '%s\n' "${digest_ref##*@}"
}

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

#######################################
# Docker: List all running containers in a clean table format
# Usage: docker-ls
#######################################
docker-ls() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __docker_ensure_running || return 1
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

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

#######################################
# Docker: Stop a running container
# Arguments:
#   $1 - Container name or ID
#######################################
__docker_container_stop() {
  local target="$1"
  echo -e "${CB_YELLOW}🛑 Stopping ${target}...${C_RESET}"
  if docker stop "$target" > /dev/null; then
    echo -e "${CB_GREEN}✅ Stopped: ${target}${C_RESET}"
  else
    echo -e "${CB_RED}❌ Failed to stop: ${target}${C_RESET}"
  fi
}

#######################################
# Docker: Start a stopped container
# Arguments:
#   $1 - Container name or ID
#######################################
__docker_container_start() {
  local target="$1"
  echo -e "${CB_BLUE}🚀 Starting ${target}...${C_RESET}"
  if docker start "$target" > /dev/null; then
    echo -e "${CB_GREEN}✅ Started: ${target}${C_RESET}"
  else
    echo -e "${CB_RED}❌ Failed to start: ${target}${C_RESET}"
  fi
}

#######################################
# Docker: Restart a single container in place via 'docker restart' --
# a lightweight, container-level bounce, distinct from docker-reboot's
# Compose-level down/up of an entire project.
# Arguments:
#   $1 - Container name or ID
#######################################
__docker_container_restart() {
  local target="$1"
  echo -e "${CB_BLUE}🔄 Restarting ${target}...${C_RESET}"
  if docker restart "$target" > /dev/null; then
    echo -e "${CB_GREEN}✅ Restarted: ${target}${C_RESET}"
  else
    echo -e "${CB_RED}❌ Failed to restart: ${target}${C_RESET}"
  fi
}

#######################################
# Docker: Exec an interactive shell into a container, falling back to
# sh if bash isn't installed
# Arguments:
#   $1 - Container name or ID
#######################################
__docker_container_shell() {
  local target="$1"
  echo -e "${CB_GREEN}🚀 Entering shell for: ${target}...${C_RESET}"
  docker exec -it "$target" /bin/bash || docker exec -it "$target" /bin/sh
}

#######################################
# Docker: Follow a single container's logs until interrupted
# Arguments:
#   $1 - Container name or ID
#######################################
__docker_container_logs() {
  local target="$1"
  echo -e "${C_DIM}(Press Ctrl+C to stop)${C_RESET}\n"
  docker logs -f --tail 100 "$target"
}

#######################################
# Docker: Show a live, single-sample resource usage snapshot for a
# container -- CPU, memory, network and block I/O
# Arguments:
#   $1 - Container name or ID
#######################################
__docker_container_stats() {
  local target="$1"
  docker stats --no-stream "$target"
}

#######################################
# Docker: Page through the full 'docker inspect' output for a container
# Arguments:
#   $1 - Container name or ID
#######################################
__docker_container_inspect() {
  local target="$1"
  docker inspect "$target" | less
}

#######################################
# Docker: Permanently remove a container after confirmation
# (force-removes if it's still running)
# Arguments:
#   $1 - Container name or ID
#######################################
__docker_container_remove() {
  local target="$1"
  echo -e "${CB_RED}⚠️  This will permanently remove container: ${target}${C_RESET}"
  local reply
  read -r -p "Proceed? [y/N] " -n 1 reply < /dev/tty
  echo
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
    return 0
  fi
  if docker rm -f "$target" > /dev/null; then
    echo -e "${CB_GREEN}✅ Removed: ${target}${C_RESET}"
  else
    echo -e "${CB_RED}❌ Failed to remove: ${target}${C_RESET}"
  fi
}

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

#######################################
# Docker: Kill every backgrounded 'docker logs' stream started by
# docker-tail and clear its interrupt trap
# Globals (read):
#   pids
#######################################
__docker_tail_cleanup() {
  echo -e "\n${CB_YELLOW}🛑 Stopping all log streams...${C_RESET}"
  kill "${pids[@]}" 2> /dev/null || true
}

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
