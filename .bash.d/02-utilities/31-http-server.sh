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
# System: Host the current directory over a temporary HTTP server
# Usage: mt-http-server [-p port] [-w|--no-wsl-bridge] [-a|--no-auth]
# Options:
#   -p, --port <port>   Specify custom port (default: config server.default_port, else 8000)
#   -w, --wsl-bridge     (WSL only) Prompt to bridge the server to your LAN via
#                        a Windows portproxy + firewall rule (requires Admin
#                        elevation). Default comes from config server.enable_lan_bridge.
#   --no-wsl-bridge      Force the LAN bridge off for this run, overriding a
#                        config default of true
#   -a, --auth           Require HTTP Basic Auth -- generates a random password
#                        each run and prints it once. Default comes from config
#                        server.enable_auth.
#   --no-auth            Force auth off for this run, overriding a config
#                        default of true
#   -h, --help           Show this help menu
# Globals:
#   OS_FAMILY, HTTP_SERVER_DEFAULT_PORT, HTTP_SERVER_ENABLE_AUTH,
#   HTTP_SERVER_ENABLE_LAN_BRIDGE
#######################################
mt-http-server() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local port="${HTTP_SERVER_DEFAULT_PORT:-8000}"
  local expose_wsl="${HTTP_SERVER_ENABLE_LAN_BRIDGE:-false}"
  local require_auth="${HTTP_SERVER_ENABLE_AUTH:-false}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --port)
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
      *)
        echo "Usage: mt-http-server [-p port] [-w|--no-wsl-bridge] [-a|--no-auth]" >&2
        return 1
        ;;
    esac
  done

  if [ "$require_auth" = true ] && ! command -v openssl > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 openssl is required for -a but was not found.${C_RESET}"
    return 1
  fi

  if [ "$expose_wsl" = true ]; then
    if [ "${OS_FAMILY}" != "wsl" ]; then
      mt-log WARN "mt-http-server: LAN bridge is only supported on WSL; ignoring."
      expose_wsl=false
    else
      echo -e "${CB_YELLOW}⚠️  This will open port ${port} to your LAN via a Windows firewall rule and request Admin elevation.${C_RESET}"
      local reply
      read -r -p "Proceed? [y/N] " -n 1 reply < /dev/tty || reply="n"
      echo
      if [[ ! $reply =~ ^[Yy]$ ]]; then
        echo -e "${CB_YELLOW}🛑 Aborted.${C_RESET}"
        return 0
      fi
    fi
  fi

  local cleaned_up=false
  __mt_http_server_cleanup() {
    [ "$cleaned_up" = true ] && return 0
    cleaned_up=true
    echo -e "\n${CB_YELLOW}🛑 Stopping server...${C_RESET}"
    if [ "$expose_wsl" = true ]; then
      echo -e "${CB_YELLOW}🧹 Removing Windows portproxy and firewall rule...${C_RESET}"
      if __mt_http_server_wsl_bridge "Remove" "$port"; then
        mt-log INFO "mt-http-server: WSL bridge for port ${port} removed."
      else
        mt-log ERROR "mt-http-server: failed to remove WSL bridge for port ${port} -- clean up manually via 'netsh interface portproxy show v4tov4' and Windows Firewall if needed."
      fi
    fi
  }

  echo -e "${CB_BLUE}🚀 Starting temporary HTTP server on port ${port}...${C_RESET}"

  if [ "$expose_wsl" = true ]; then
    echo -e "${CB_YELLOW}⚠️  Requesting Windows Admin elevation to bridge the connection...${C_RESET}"
    if __mt_http_server_wsl_bridge "Add" "$port"; then
      echo -e "${CB_GREEN}✅ Portproxy established. LAN devices can connect!${C_RESET}"
      mt-log INFO "mt-http-server: WSL bridge for port ${port} established."
    else
      echo -e "${CB_RED}🚨 Failed to establish the LAN bridge (elevation declined or unavailable). Continuing with local-only access.${C_RESET}"
      mt-log ERROR "mt-http-server: failed to establish the WSL portproxy/firewall bridge for port ${port}."
      expose_wsl=false
    fi
  fi

  local -a serve_cmd=(python3 -m http.server "$port")
  if [ "$require_auth" = true ]; then
    local -x MT_SERVE_USER="mtserve"
    local -x MT_SERVE_PASSWORD
    MT_SERVE_PASSWORD=$(openssl rand -hex 8)
    local -x MT_SERVE_PORT="$port"
    serve_cmd=(python3 "$HOME/.bash.d/lib/python/auth_http_server.py")

    echo -e "${CB_CYAN}🔐 Basic Auth enabled:${C_RESET}"
    echo -e "   ${CB_CYAN}Username:${C_RESET} ${MT_SERVE_USER}"
    echo -e "   ${CB_CYAN}Password:${C_RESET} ${MT_SERVE_PASSWORD}"
    echo -e "${C_DIM}(Sent as HTTP Basic Auth -- keeps casual LAN users out, not a substitute for TLS)${C_RESET}\n"
  fi

  echo -e "${CB_CYAN}📡 Listening on:${C_RESET}"
  if command -v ip > /dev/null 2>&1; then
    ip -4 addr show | grep inet | awk '{print "   http://" $2}' | sed 's|/.*||' | sed "s|$|:${port}|"
  fi
  echo -e "${C_DIM}(Press Ctrl+C to stop)${C_RESET}\n"

  trap __mt_http_server_cleanup SIGINT
  "${serve_cmd[@]}"
  __mt_http_server_cleanup
  trap - SIGINT
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
