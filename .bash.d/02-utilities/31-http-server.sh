# shellcheck shell=bash
# ------------------------------------------
# Utilities: Temporary HTTP File Server
# ------------------------------------------
# ~/.bash.d/02-utilities/31-http-server.sh

#######################################
# System: Add or remove the WSL LAN-exposure bridge (Windows portproxy +
# firewall rule) for mt-http-server's -w flag, via an elevated PowerShell
# process. Values are passed to PowerShell as positional args bound by the
# script's own param() block -- never interpolated into a -Command string
# -- so no bash-side value can be misparsed as PowerShell syntax.
# Arguments:
#   $1 - "Add" or "Remove"
#   $2 - Port number
# Returns:
#   0 on success, 1 if powershell.exe is unavailable or the elevated
#   process reports a non-zero exit code (e.g. UAC was declined)
#######################################
__mt_http_server_wsl_bridge() {
  local action="$1" port="$2"

  if ! command -v powershell.exe > /dev/null 2>&1; then
    return 1
  fi

  local ps_script="$HOME/.bash.d/lib/windows/win_portproxy.ps1"
  if [ ! -f "$ps_script" ]; then
    return 1
  fi

  local wsl_ip=""
  [ "$action" = "Add" ] && wsl_ip=$(hostname -I | awk '{print $1}')

  powershell.exe -NoProfile -Command '
    $act = $args[0]; $prt = $args[1]; $ip = $args[2]; $scr = $args[3]
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scr, "-Action", $act, "-Port", $prt)
    if ($ip) { $argList += @("-ConnectAddress", $ip) }
    $p = Start-Process powershell -WindowStyle Hidden -Verb RunAs -Wait -PassThru -ArgumentList $argList
    exit $p.ExitCode
  ' -- "$action" "$port" "$wsl_ip" "$(wslpath -w "$ps_script")" > /dev/null 2>&1
}

#######################################
# System: Tear down the WSL LAN-exposure bridge if the bridge-state file
# says one is active, then remove that state file. A no-op if no bridge
# was ever established. Called both from the foreground Ctrl+C trap and
# appended to the background command string, so it also runs when a
# backgrounded server exits on its own via idle-timeout auto-shutdown --
# nothing else would ever notice that happened otherwise.
#######################################
__mt_http_server_teardown_bridge_if_active() {
  local bridge_state_file="$CACHE_DIR/.mt_http_server_bridge_port"
  [ -f "$bridge_state_file" ] || return 0

  local bridge_port
  bridge_port=$(command cat "$bridge_state_file")
  echo -e "${CB_YELLOW}🧹 Removing Windows portproxy and firewall rule for port ${bridge_port}...${C_RESET}"
  if __mt_http_server_wsl_bridge "Remove" "$bridge_port"; then
    mt-log INFO "mt-http-server: WSL bridge for port ${bridge_port} removed."
  else
    mt-log ERROR "mt-http-server: failed to remove WSL bridge for port ${bridge_port} -- clean up manually via 'netsh interface portproxy show v4tov4' and Windows Firewall if needed."
  fi
  rm -f "$bridge_state_file"
}

#######################################
# System: Look up a currently-running mt-http-server background job in the
# shared mt-jobs registry, verifying the PID is actually alive rather than
# trusting a possibly-stale RUNNING status (e.g. after a crash that never
# updated its own registry row). This is the wrapper's PID, not
# necessarily the real server process -- see __mt_http_server_pid for that.
# Outputs:
#   Prints the PID to STDOUT if one is genuinely running; nothing otherwise
#######################################
__mt_http_server_running_job() {
  local jobs_file="$CACHE_DIR/.mt_jobs.tsv"
  [ -f "$jobs_file" ] || return 0

  local pid
  while IFS= read -r pid; do
    if kill -0 "$pid" 2> /dev/null; then
      echo "$pid"
      return 0
    fi
  done < <(awk -F'|' '$3 == "mt-http-server" && $6 == "RUNNING" { print $2 }' "$jobs_file")
}

#######################################
# System: Read the real server process's PID from its own pidfile
# (written by mt_http_server.py on startup), verifying it's actually
# alive. This is deliberately not the same PID mt-jobs tracks -- the
# server always runs as a child of the mt-jobs wrapper subshell (never
# execed into it), so that wrapper can run bridge cleanup after the
# server exits, for any reason. --stop needs the real PID to target the
# actual server.
# Outputs:
#   Prints the PID to STDOUT if alive; nothing otherwise
#######################################
__mt_http_server_pid() {
  local pid_file="$CACHE_DIR/.mt_http_server.pid"
  [ -f "$pid_file" ] || return 0
  local pid
  pid=$(command cat "$pid_file")
  [ -n "$pid" ] && kill -0 "$pid" 2> /dev/null && echo "$pid"
}

#######################################
# System: Host the current directory over a temporary HTTP server. Only
# one instance is supported at a time -- -b refuses to start a second one
# rather than running multiple concurrent servers. Binds to 127.0.0.1 only
# unless -w/LAN bridge is explicitly confirmed -- plain `mt-http-server`
# with no flags is never reachable from your network.
# Usage: mt-http-server [-p port] [-w|--no-wsl-bridge] [-a|--no-auth] [-t seconds|--no-idle-timeout] [-b] [--stop] [-l] [-i]
# Options:
#   -p, --port <port>          Specify custom port (default: config server.default_port, else 8000)
#   -w, --wsl-bridge            Prompt to expose the server to your LAN. On WSL this
#                               also adds a Windows portproxy + firewall rule (requires
#                               Admin elevation); on macOS/Linux it just binds every
#                               network interface instead of loopback-only. Default
#                               comes from config server.enable_lan_bridge.
#   --no-wsl-bridge             Force the LAN bridge off for this run, overriding a
#                               config default of true
#   -a, --auth                  Require HTTP Basic Auth -- generates a random
#                               password each run and prints it once. Default
#                               comes from config server.enable_auth.
#   --no-auth                   Force auth off for this run, overriding a config
#                               default of true
#   -t, --idle-timeout <secs>   Auto-shutdown after this many seconds with no
#                               requests. Default comes from config
#                               server.idle_timeout_sec (1800 = 30 minutes).
#   --no-idle-timeout           Disable auto-shutdown for this run
#   -b, --background            Run detached via the mt-jobs background registry
#                               instead of blocking the terminal. Refuses to start
#                               if an instance is already running.
#   --stop                      Stop the running background instance, if any, and
#                               tear down its LAN bridge if it had one
#   -l, --status                Show whether a background instance is running
#   -i, --wizard                Interactively set the config defaults above
#   -h, --help                  Show this help menu
# Globals:
#   OS_FAMILY, HTTP_SERVER_DEFAULT_PORT, HTTP_SERVER_ENABLE_AUTH,
#   HTTP_SERVER_ENABLE_LAN_BRIDGE, HTTP_SERVER_IDLE_TIMEOUT_SEC
#######################################
mt-http-server() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local port="${HTTP_SERVER_DEFAULT_PORT:-8000}"
  local expose_wsl="${HTTP_SERVER_ENABLE_LAN_BRIDGE:-false}"
  local require_auth="${HTTP_SERVER_ENABLE_AUTH:-false}"
  local idle_timeout="${HTTP_SERVER_IDLE_TIMEOUT_SEC:-1800}"
  local run_background=false do_stop=false do_status=false do_wizard=false
  local bridge_state_file="$CACHE_DIR/.mt_http_server_bridge_port"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --port)
        if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
          echo "mt-http-server: --port requires an integer between 1 and 65535" >&2
          return 1
        fi
        port="$2"
        shift 2
        ;;
      -w | --wsl-bridge)
        expose_wsl=true
        shift
        ;;
      --no-wsl-bridge)
        expose_wsl=false
        shift
        ;;
      -a | --auth)
        require_auth=true
        shift
        ;;
      --no-auth)
        require_auth=false
        shift
        ;;
      -t | --idle-timeout)
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          echo "mt-http-server: --idle-timeout requires a non-negative integer (seconds)" >&2
          return 1
        fi
        idle_timeout="$2"
        shift 2
        ;;
      --no-idle-timeout)
        idle_timeout=0
        shift
        ;;
      -b | --background)
        run_background=true
        shift
        ;;
      --stop)
        do_stop=true
        shift
        ;;
      -l | --status)
        do_status=true
        shift
        ;;
      -i | --wizard)
        do_wizard=true
        shift
        ;;
      *)
        echo "Usage: mt-http-server [-p port] [-w|--no-wsl-bridge] [-a|--no-auth] [-t seconds|--no-idle-timeout] [-b] [--stop] [-l] [-i]" >&2
        return 1
        ;;
    esac
  done

  if [ "$do_wizard" = true ]; then
    echo -e "${CB_BLUE}--- HTTP Server Configuration ---${C_RESET}"
    local val
    read -r -p "Default Port [${HTTP_SERVER_DEFAULT_PORT:-8000}]: " val
    [ -n "$val" ] && python3 "$CONFIG_MANAGER" update "server" "default_port" "$val"

    read -r -p "Require Auth by default? (true/false) [${HTTP_SERVER_ENABLE_AUTH:-false}]: " val
    [ -n "$val" ] && python3 "$CONFIG_MANAGER" update "server" "enable_auth" "$val"

    read -r -p "Expose to your LAN by default? (true/false) [${HTTP_SERVER_ENABLE_LAN_BRIDGE:-false}]: " val
    [ -n "$val" ] && python3 "$CONFIG_MANAGER" update "server" "enable_lan_bridge" "$val"

    read -r -p "Idle Timeout in seconds, 0 to disable [${HTTP_SERVER_IDLE_TIMEOUT_SEC:-1800}]: " val
    [ -n "$val" ] && python3 "$CONFIG_MANAGER" update "server" "idle_timeout_sec" "$val"

    echo -e "${CB_GREEN}✅ HTTP server config updated.${C_RESET}"
    return 0
  fi

  if [ "$do_status" = true ]; then
    local status_pid
    status_pid=$(__mt_http_server_running_job)
    if [ -n "$status_pid" ]; then
      echo -e "${CB_GREEN}✅ Running in background (PID ${status_pid}).${C_RESET}"
      [ -f "$bridge_state_file" ] && echo -e "${CB_CYAN}   LAN bridge active on port $(command cat "$bridge_state_file").${C_RESET}"
    else
      echo -e "${CB_YELLOW}⚠️  No background instance is running.${C_RESET}"
      if [ -f "$bridge_state_file" ]; then
        echo -e "${CB_RED}🚨 But a LAN bridge state file for port $(command cat "$bridge_state_file") still exists -- the Windows firewall rule/portproxy may still be open even though no server is running (likely left behind by an unclean shutdown). Run 'mt-http-server --stop' to clean it up.${C_RESET}"
      fi
    fi
    return 0
  fi

  if [ "$do_stop" = true ]; then
    local wrapper_pid
    wrapper_pid=$(__mt_http_server_running_job)
    if [ -z "$wrapper_pid" ]; then
      if [ -f "$bridge_state_file" ]; then
        echo -e "${CB_YELLOW}⚠️  No background instance is running, but a LAN bridge state file was left behind -- cleaning it up.${C_RESET}"
        __mt_http_server_teardown_bridge_if_active
      else
        echo -e "${CB_YELLOW}⚠️  No background instance is running.${C_RESET}"
      fi
      return 0
    fi

    local server_pid
    server_pid=$(__mt_http_server_pid)
    [ -n "$server_pid" ] && kill "$server_pid" 2> /dev/null

    echo -e "${CB_YELLOW}⏳ Stopping (may take a moment if a LAN bridge needs to be torn down)...${C_RESET}"
    local waited=0
    while kill -0 "$wrapper_pid" 2> /dev/null && [ "$waited" -lt 30 ]; do
      sleep 0.5
      waited=$((waited + 1))
    done

    if kill -0 "$wrapper_pid" 2> /dev/null; then
      echo -e "${CB_YELLOW}⚠️  Still shutting down in the background -- check 'mt-http-server -l' shortly.${C_RESET}"
    else
      echo -e "${CB_GREEN}✅ Background mt-http-server stopped.${C_RESET}"
    fi
    return 0
  fi

  if [ "$run_background" = true ]; then
    local existing_pid
    existing_pid=$(__mt_http_server_running_job)
    if [ -n "$existing_pid" ]; then
      echo -e "${CB_RED}🚨 A background mt-http-server is already running (PID ${existing_pid}).${C_RESET}"
      echo -e "${C_DIM}Only one instance is supported at a time. Run 'mt-http-server --stop' to stop it, or 'mt-jobs -i' to inspect it.${C_RESET}"
      return 1
    fi
  fi

  if [ "$require_auth" = true ] && ! command -v openssl > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 openssl is required for -a but was not found.${C_RESET}"
    return 1
  fi

  local -x MT_SERVE_BIND_ALL=""

  if [ "$expose_wsl" = true ]; then
    echo -e "${CB_YELLOW}⚠️  This will expose port ${port} to every device on your current network -- including public/untrusted Wi-Fi, not just a trusted home network.${C_RESET}"
    [ "${OS_FAMILY}" = "wsl" ] && echo -e "${CB_YELLOW}   On WSL this also opens a Windows firewall rule and requests Admin elevation.${C_RESET}"
    if [ "$require_auth" = true ]; then
      echo -e "${CB_CYAN}   Basic Auth will be required to connect.${C_RESET}"
    else
      echo -e "${CB_RED}   No authentication -- anyone who can reach this port can browse and download every file here.${C_RESET}"
    fi
    local reply
    read -r -p "Proceed? [y/N] " -n 1 reply < /dev/tty || reply="n"
    echo
    if [[ ! $reply =~ ^[Yy]$ ]]; then
      echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
      return 0
    fi
    MT_SERVE_BIND_ALL=1
  fi

  local cleaned_up=false
  __mt_http_server_cleanup() {
    [ "$cleaned_up" = true ] && return 0
    cleaned_up=true
    echo -e "\n${CB_YELLOW}🛑 Stopping server...${C_RESET}"
    __mt_http_server_teardown_bridge_if_active
    rm -f "$CACHE_DIR/.mt_http_server.pid"
  }

  echo -e "${CB_BLUE}🚀 Starting temporary HTTP server on port ${port}...${C_RESET}"

  if [ "$expose_wsl" = true ] && [ "${OS_FAMILY}" = "wsl" ]; then
    echo -e "${CB_YELLOW}⚠️  Requesting Windows Admin elevation to bridge the connection...${C_RESET}"
    if __mt_http_server_wsl_bridge "Add" "$port"; then
      echo -e "${CB_GREEN}✅ Portproxy established. LAN devices can connect!${C_RESET}"
      mt-log INFO "mt-http-server: WSL bridge for port ${port} established."
      echo "$port" > "$bridge_state_file"
    else
      echo -e "${CB_RED}🚨 Failed to establish the LAN bridge (elevation declined or unavailable). Continuing with local-only access.${C_RESET}"
      mt-log ERROR "mt-http-server: failed to establish the WSL portproxy/firewall bridge for port ${port}."
      expose_wsl=false
      MT_SERVE_BIND_ALL=""
    fi
  fi

  local -a serve_cmd=(python3 -m http.server "$port" --bind "$([ "$MT_SERVE_BIND_ALL" = 1 ] && echo "0.0.0.0" || echo "127.0.0.1")")
  local -x MT_SERVE_PORT="$port"
  local -x MT_SERVE_IDLE_TIMEOUT="$idle_timeout"
  # -b needs the custom script regardless of auth/idle-timeout, since
  # --stop targets the PID it writes to a pidfile -- plain
  # `python3 -m http.server` writes no such file, leaving --stop with
  # nothing to kill.
  local use_custom_script=false
  [ "$idle_timeout" -gt 0 ] && use_custom_script=true
  [ "$run_background" = true ] && use_custom_script=true

  if [ "$require_auth" = true ]; then
    local -x MT_SERVE_USER="mtserve"
    local -x MT_SERVE_PASSWORD
    MT_SERVE_PASSWORD=$(openssl rand -hex 8)
    use_custom_script=true

    echo -e "${CB_CYAN}🔐 Basic Auth enabled:${C_RESET}"
    echo -e "   ${CB_CYAN}Username:${C_RESET} ${MT_SERVE_USER}"
    echo -e "   ${CB_CYAN}Password:${C_RESET} ${MT_SERVE_PASSWORD}"
    echo -e "${C_DIM}(Sent as HTTP Basic Auth -- keeps casual LAN users out, not a substitute for TLS)${C_RESET}\n"
  fi

  if [ "$idle_timeout" -gt 0 ]; then
    echo -e "${CB_CYAN}⏱️  Auto-shutdown after ${idle_timeout}s of inactivity.${C_RESET}"
  fi

  [ "$use_custom_script" = true ] && serve_cmd=(python3 "$HOME/.bash.d/lib/python/mt_http_server.py")

  echo -e "${CB_CYAN}📡 Listening on:${C_RESET}"
  if [ "$MT_SERVE_BIND_ALL" = 1 ] && command -v ip > /dev/null 2>&1; then
    ip -4 addr show | grep inet | awk '{print "   http://" $2}' | sed 's|/.*||' | sed "s|$|:${port}|"
  else
    echo "   http://127.0.0.1:${port}"
  fi

  if [ "$run_background" = true ]; then
    echo "$port" > "$CACHE_DIR/.mt_http_server_port"

    local log_file
    log_file="$LOG_DIR/http_server_$(date +%s).log"

    # Deliberately NOT execed -- this wrapper subshell needs to stay alive
    # after the server process exits (whether via --stop or the server's
    # own idle-timeout auto-shutdown) so the cleanup steps below actually
    # run. --stop targets the server's own PID (from its pidfile, see
    # __mt_http_server_pid), not this wrapper's PID.
    local cmd_string part
    printf -v cmd_string '%q' "${serve_cmd[0]}"
    for part in "${serve_cmd[@]:1}"; do
      printf -v part '%q' "$part"
      cmd_string="$cmd_string $part"
    done
    # The pidfile removal is guarded by __mt_http_server_pid's own liveness
    # check rather than an unconditional rm -f: if two `-b` invocations
    # raced past the single-instance check before either registered, the
    # loser reaches this tail too, and an unconditional rm here would
    # delete the winner's still-valid pidfile out from under it.
    cmd_string="$cmd_string; __mt_http_server_teardown_bridge_if_active; rm -f '$CACHE_DIR/.mt_http_server_port'; [ -z \"\$(__mt_http_server_pid)\" ] && rm -f '$CACHE_DIR/.mt_http_server.pid'"

    __mt_bg_run "mt-http-server" "$log_file" "$cmd_string"
    echo -e "${C_DIM}Stop with: mt-http-server --stop${C_RESET}"
    return 0
  fi

  echo -e "${C_DIM}(Press Ctrl+C to stop)${C_RESET}\n"

  trap __mt_http_server_cleanup SIGINT
  "${serve_cmd[@]}"
  __mt_http_server_cleanup
  trap - SIGINT
}

#######################################
# System: Print the port of the currently-running background instance, or
# nothing if none is running -- verifies via the mt-jobs registry (PID
# liveness) rather than trusting the port-tracking file alone, since that
# file could in principle be stale.
#######################################
__mt_server_manager_active_port() {
  [ -n "$(__mt_http_server_running_job)" ] || return 0
  local port_file="$CACHE_DIR/.mt_http_server_port"
  [ -f "$port_file" ] && command cat "$port_file"
}

#######################################
# System: Print the log file path for the currently-running background
# instance, or nothing if none is running
#######################################
__mt_server_manager_log_path() {
  local jobs_file="$CACHE_DIR/.mt_jobs.tsv"
  [ -f "$jobs_file" ] || return 0
  awk -F'|' '$3 == "mt-http-server" && $6 == "RUNNING" { print $7 }' "$jobs_file" | tail -n 1
}

__mt_server_manager_start() { mt-http-server -b; }
__mt_server_manager_stop() { mt-http-server --stop; }
__mt_server_manager_status() { mt-http-server -l; }
__mt_server_manager_options() { mt-http-server -i; }
__mt_server_manager_jobs() { mt-jobs -i; }

#######################################
# System: Stop the running instance (if any) and start a fresh one --
# also rotates the Basic Auth password, since a new instance always
# generates a new one
#######################################
__mt_server_manager_restart() {
  mt-http-server --stop
  mt-http-server -b
}

#######################################
# System: Open the running instance in the default browser via the
# framework's existing cross-platform __open_url helper
#######################################
__mt_server_manager_open() {
  local port
  port=$(__mt_server_manager_active_port)
  if [ -z "$port" ]; then
    echo -e "${CB_YELLOW}⚠️  No background instance is running.${C_RESET}"
    return 0
  fi
  __open_url "http://127.0.0.1:${port}"
}

#######################################
# System: curl the running instance and report its HTTP status
#######################################
__mt_server_manager_test() {
  local port
  port=$(__mt_server_manager_active_port)
  if [ -z "$port" ]; then
    echo -e "${CB_YELLOW}⚠️  No background instance is running.${C_RESET}"
    return 0
  fi
  echo -e "${CB_CYAN}Testing connection to http://127.0.0.1:${port}/ ...${C_RESET}"
  curl -sS -o /dev/null -w "HTTP status: %{http_code}\n" --max-time 5 "http://127.0.0.1:${port}/"
}

__mt_server_manager_view_logs() {
  local log_path
  log_path=$(__mt_server_manager_log_path)
  if [ -z "$log_path" ] || [ ! -f "$log_path" ]; then
    echo -e "${CB_YELLOW}⚠️  No log file found for a running instance.${C_RESET}"
    return 0
  fi
  echo -e "${CB_CYAN}--- LOGS ($log_path) ---${C_RESET}"
  cat "$log_path"
}

__mt_server_manager_tail_logs() {
  local log_path
  log_path=$(__mt_server_manager_log_path)
  if [ -z "$log_path" ] || [ ! -f "$log_path" ]; then
    echo -e "${CB_YELLOW}⚠️  No log file found for a running instance.${C_RESET}"
    return 0
  fi
  echo -e "${C_DIM}(Press Ctrl+C to stop tailing)${C_RESET}"
  tail -f "$log_path"
}

#######################################
# Utilities: Interactive menu to manage the single mt-http-server
# background instance -- narrowly scoped to genuinely server-specific
# actions (credentials, connection testing, browser launch); broader job
# management (cancel, restart, history) is delegated to the existing
# mt-jobs -i rather than rebuilt here.
# Usage: mt-server-manager
#######################################
mt-server-manager() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  __mt_menu_submenu "🌐 HTTP Server Manager" \
    "Start Server (background)" __mt_server_manager_start \
    "Stop Server" __mt_server_manager_stop \
    "Restart Server" __mt_server_manager_restart \
    "Status" __mt_server_manager_status \
    "Open in Web Browser" __mt_server_manager_open \
    "Test Connection (curl)" __mt_server_manager_test \
    "View Logs" __mt_server_manager_view_logs \
    "Tail Logs (live)" __mt_server_manager_tail_logs \
    "Server Options (wizard)" __mt_server_manager_options \
    "Manage via mt-jobs" __mt_server_manager_jobs
}

#######################################
# Utilities: Host the current directory over a temporary HTTP server
# (deprecated alias)
# Deprecated: use mt-http-server instead.
#######################################
mt-serve() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  mt-http-server "$@"
}
