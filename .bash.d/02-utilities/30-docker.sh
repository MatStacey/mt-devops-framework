# shellcheck shell=bash
# ------------------------------------------
# Docker: Container Management Utilities
# ------------------------------------------
# ~/.bash.d/02-utilities/30-docker.sh

#######################################
# Docker: Check whether the Docker daemon is reachable
#######################################
__docker_is_running() {
  docker info > /dev/null 2>&1
}

#######################################
# Docker: Start Docker daemon and wait until ready
#######################################
__docker_daemon_start() {
  if ! command -v systemctl > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 systemctl not found -- cannot start Docker daemon.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}🐳 Starting Docker daemon...${C_RESET}"

  if ! sudo systemctl start docker; then
    echo -e "${CB_RED}🚨 Failed to start Docker daemon.${C_RESET}"
    return 1
  fi

  local waited=0

  while ! __docker_is_running; do
    sleep 1
    ((waited++))

    if ((waited >= 30)); then
      echo -e "${CB_RED}🚨 Docker daemon started but is not responding after 30s.${C_RESET}"
      return 1
    fi
  done

  echo -e "${CB_GREEN}✅ Docker daemon is running.${C_RESET}"
}

#######################################
# Docker: Ensure daemon is running
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
# Docker: Start, stop, restart, status
#######################################
docker-daemon() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if ! command -v systemctl > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 systemctl not found.${C_RESET}"
    return 1
  fi

  local action="${1:-status}"

  case "$action" in

    start)
      if __docker_is_running; then
        echo -e "${CB_GREEN}✅ Docker daemon already running.${C_RESET}"
        return 0
      fi

      __docker_daemon_start
      ;;

    stop)
      if ! __docker_is_running; then
        echo -e "${CB_GREEN}✅ Docker daemon already stopped.${C_RESET}"
        return 0
      fi

      echo -e "${CB_BLUE}🐳 Stopping Docker daemon...${C_RESET}"
      sudo systemctl stop docker
      echo -e "${CB_GREEN}✅ Docker daemon stopped.${C_RESET}"
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
      echo "Usage: docker-daemon [start|stop|restart|status]"
      return 1
      ;;

  esac
}

#######################################
# Docker: Check container readiness
# Returns 0 when:
# - running + healthy
# - running + no healthcheck
#######################################
__docker_reboot_container_ready() {
  local container="$1"
  local state health

  state=$(docker inspect \
    --format '{{.State.Status}}' \
    "$container" 2> /dev/null) || return 1

  [[ "$state" == "running" ]] || return 1

  health=$(docker inspect \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
    "$container" 2> /dev/null) || return 1

  [[ "$health" == "healthy" || "$health" == "none" ]]
}

#######################################
# Docker: Wait for Compose project recovery
#######################################
__docker_reboot_wait_for_project() {
  local compose_file="$1"

  local timeout=120
  local interval=2
  local containers container

  while ((timeout > 0)); do

    containers=$(docker compose -f "$compose_file" ps -aq 2> /dev/null)

    if [[ -n "$containers" ]]; then

      local ready=1

      while read -r container; do
        [[ -z "$container" ]] && continue

        if ! __docker_reboot_container_ready "$container"; then
          ready=0
          break
        fi

      done <<< "$containers"

      ((ready)) && return 0
    fi

    sleep "$interval"
    ((timeout -= interval))

  done

  return 1
}

#######################################
# Docker: Get Compose metadata
# Outputs:
#   project name
#   compose file
#######################################
__docker_reboot_compose_metadata() {
  local container="$1"
  local project_var="$2"
  local compose_var="$3"

  local compose_project compose_files compose_path

  compose_project=$(docker inspect \
    --format '{{index .Config.Labels "com.docker.compose.project"}}' \
    "$container" 2> /dev/null) || return 1

  compose_files=$(docker inspect \
    --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}' \
    "$container" 2> /dev/null) || return 1

  [[ -n "$compose_project" && -n "$compose_files" ]] || return 1

  compose_path="${compose_files%%,*}"

  [[ -f "$compose_path" ]] || return 1

  printf -v "$project_var" '%s' "$compose_project"
  printf -v "$compose_var" '%s' "$compose_path"
}

#######################################
# Docker: Recreate all running Docker Compose projects
#
# Usage:
#   docker-reboot-all
#   docker-reboot-all -x container1,container2
#
# Behaviour:
#   - Detect running Compose projects
#   - Restart projects sequentially
#   - Wait for recovery
#   - Continue after failures
#   - Excluded containers skip their entire Compose project
#
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
  local OPTIND opt

  while getopts "x:" opt; do
    case "$opt" in
      x)
        manual_excludes="$OPTARG"
        ;;

      \?)
        echo "Usage: docker-reboot-all [-x container1,container2]"
        return 1
        ;;
    esac
  done

  local full_excludes="${DOCKER_BLOCKLIST:-}"

  if [[ -n "$manual_excludes" ]]; then
    full_excludes="${full_excludes:+${full_excludes},}${manual_excludes}"
  fi

  local exclude_pattern=""

  if [[ -n "$full_excludes" ]]; then
    exclude_pattern=$(echo "$full_excludes" | sed 's/,/|/g; s/ //g')
  fi

  local containers

  containers=$(docker ps --format "{{.Names}}")

  if [[ -z "$containers" ]]; then
    mt-log WARN "No running Docker containers found."
    return 0
  fi

  declare -A project_files=()
  declare -A project_seen=()
  declare -A project_excluded=()

  local project_order=()

  local container
  local project
  local compose_file

  while read -r container; do

    [[ -z "$container" ]] && continue

    if ! __docker_reboot_compose_metadata \
      "$container" project compose_file; then

      echo -e "${CB_YELLOW}⚠️  Skipping non-Compose container: ${container}${C_RESET}"
      continue
    fi

    if [[ -n "$exclude_pattern" &&
      "$container" =~ ^(${exclude_pattern})$ ]]; then

      project_excluded["$project"]=1
      continue
    fi

    if [[ -z "${project_seen[$project]:-}" ]]; then

      project_seen["$project"]=1
      project_files["$project"]="$compose_file"
      project_order+=("$project")

    fi

  done <<< "$containers"

  if ((${#project_order[@]} == 0)); then
    mt-log WARN "No Compose projects found."
    return 0
  fi

  echo "🔄 Restarting Docker Compose projects..."

  local failures=0
  local skipped=0

  for project in "${project_order[@]}"; do

    if [[ -n "${project_excluded[$project]:-}" ]]; then

      echo -e "${CB_YELLOW}⚠️  Skipping project: ${project} (excluded)${C_RESET}"

      ((skipped++))

      continue
    fi

    compose_file="${project_files[$project]}"

    echo
    echo "▶ Restarting project: ${project}"

    if ! docker compose -f "$compose_file" down > /dev/null 2>&1; then

      echo -e "${CB_RED}❌ Failed stopping: ${project}${C_RESET}"

      ((failures++))

      continue

    fi

    if ! docker compose -f "$compose_file" up -d > /dev/null 2>&1; then

      echo -e "${CB_RED}❌ Failed starting: ${project}${C_RESET}"

      ((failures++))

      continue

    fi

    if __docker_reboot_wait_for_project "$compose_file"; then

      echo -e "${CB_GREEN}✅ Project recreated: ${project}${C_RESET}"

    else

      echo -e "${CB_YELLOW}⚠️  Project did not become healthy: ${project} (continuing)${C_RESET}"

      ((failures++))

    fi

  done

  echo

  if ((skipped > 0)); then

    echo -e "${CB_YELLOW}⚠️  ${skipped} project(s) skipped due to exclusions.${C_RESET}"

  fi

  if ((failures > 0)); then

    echo -e "${CB_YELLOW}⚠️  Docker restart complete. ${failures} project(s) reported warnings.${C_RESET}"

    return 0

  fi

  echo -e "${CB_GREEN}✅ Docker restart complete.${C_RESET}"

}

#######################################
# Docker: List running containers
#
# Usage:
#   docker-ls
#######################################
docker-ls() {

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1

  docker ps \
    --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

#######################################
# Docker: Open shell inside container
#
# Usage:
#   docker-shell
#######################################
docker-shell() {

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1

  local target

  target=$(docker ps --format "{{.Names}}" |
    fzf \
      --prompt="🐳 Select Container > " \
      --height=~10 \
      --layout=reverse \
      --border)

  if [[ -z "$target" ]]; then

    echo -e "${CB_YELLOW}⚠️  Selection cancelled.${C_RESET}"

    return 0
  fi

  echo -e "${CB_GREEN}🚀 Entering sandbox for: ${target}${C_RESET}"

  docker exec -it "$target" /bin/bash ||
    docker exec -it "$target" /bin/sh
}

#######################################
# Docker: Remove unused Docker resources
#
# Usage:
#   docker-nuke
#   docker-nuke --dry-run
#######################################
docker-nuke() {

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1

  if [[ "$1" == "--dry-run" ]]; then

    echo "🔍 Simulating Docker cleanup..."

    docker system prune -a --volumes

    return 0
  fi

  echo -e "${CB_RED}⚠️  WARNING: This will remove unused Docker resources.${C_RESET}"

  read -r -p "Continue? [y/N] " -n 1 < /dev/tty

  echo

  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then

    echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"

    return 0
  fi

  echo "💥 Cleaning Docker resources..."

  docker system prune -a --volumes -f

  mt-log SUCCESS "Docker environment sanitized."
}

#######################################
# Docker: Launch temporary container
#
# Usage:
#   docker-sandbox [image]
#######################################
docker-sandbox() {

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1

  local image="${1:-debian}"

  echo -e "${CB_BLUE}🚀 Launching ${image} sandbox...${C_RESET}"

  docker run --rm -it "$image" /bin/bash ||
    docker run --rm -it "$image" /bin/sh
}

#######################################
# Docker: Cleanup docker-tail streams
#######################################
__docker_tail_cleanup() {

  echo -e "\n${CB_YELLOW}🛑 Stopping log streams...${C_RESET}"

  kill "${pids[@]}" 2> /dev/null || true
}

#######################################
# Docker: Tail multiple container logs
#
# Usage:
#   docker-tail
#######################################
docker-tail() {

  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __docker_ensure_running || return 1

  local selected

  selected=$(docker ps --format "{{.Names}}" |
    fzf \
      --multi \
      --prompt="🐳 Select Containers (TAB multi-select) > " \
      --height=~15 \
      --layout=reverse \
      --border)

  if [[ -z "$selected" ]]; then

    echo -e "${CB_YELLOW}⚠️  No containers selected.${C_RESET}"

    return 0
  fi

  echo -e "${CB_GREEN}🚀 Tailing logs:${C_RESET}"

  echo "$selected"

  local colors=(
    "$CB_CYAN"
    "$CB_GREEN"
    "$CB_YELLOW"
    "$CB_BLUE"
    "$CB_MAGENTA"
    "$CB_RED"
  )

  local pids=()

  trap __docker_tail_cleanup SIGINT

  local sed_buf="-u"

  [[ "$OS_FAMILY" == "macos" ]] &&
    sed_buf="-l"

  local i=0
  local container

  while read -r container; do

    [[ -z "$container" ]] && continue

    local color="${colors[$((i % ${#colors[@]}))]}"

    docker logs -f --tail 50 "$container" 2>&1 |
      sed "$sed_buf" \
        "s/^/${color}[$container]${C_RESET} /" &

    pids+=("$!")

    ((i++))

  done <<< "$selected"

  wait "${pids[@]}" 2> /dev/null || true

  trap - SIGINT
}
