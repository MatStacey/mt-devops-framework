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
  local log_dir="${LOG_DIR:-$HOME/.bash.d/data/logs}"
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

    local log_file="${log_dir}/docker-reboot_${project}_${timestamp}.log"
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
