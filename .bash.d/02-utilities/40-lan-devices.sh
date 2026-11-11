# shellcheck shell=bash
# ------------------------------------------
# Utilities: Local-Network Device Discovery
# ------------------------------------------
# ~/.bash.d/02-utilities/40-lan-devices.sh

NET_SSDP_DEFAULT_TIMEOUT=3
NET_SSDP_ADDRESS="239.255.255.250"
NET_SSDP_PORT=1900
NET_LAN_NEIGHBOURS_AWK="$HOME/.bash.d/lib/awk/lan_neighbours.awk"
NET_SSDP_PYTHON="$HOME/.bash.d/lib/python/ssdp_discover.py"
NET_SSDP_POWERSHELL="$HOME/.bash.d/lib/windows/win_ssdp_discover.ps1"
NET_IP_SORT_KEYS=("-t." "-k1,1n" "-k2,2n" "-k3,3n" "-k4,4n")

#######################################
# Network: Print the local ARP/neighbour table as normalised rows. On WSL it
# reads the Windows host's table (WSL's own sees only the virtual switch).
# Returns:
#   0 on success, 1 if the platform's tool is missing or fails
# Outputs:
#   "ip<TAB>mac<TAB>neighbour" rows sorted by IP
#######################################
__mt_lan_neighbours() {
  local format table
  case "${OS_FAMILY:-linux}" in
    wsl)
      format="windows"
      if ! command -v arp.exe > /dev/null 2>&1; then
        echo -e "${CB_RED}❌ arp.exe not found: the LAN neighbour list on WSL comes from the Windows host.${C_RESET}" >&2
        return 1
      fi
      table=$(arp.exe -a) || return 1
      table="${table//$'\r'/}"
      ;;
    macos)
      format="macos"
      if ! command -v arp > /dev/null 2>&1; then
        echo -e "${CB_RED}❌ arp not found.${C_RESET}" >&2
        return 1
      fi
      table=$(arp -an) || return 1
      ;;
    *)
      format="linux"
      if ! command -v ip > /dev/null 2>&1; then
        echo -e "${CB_RED}❌ ip not found.${C_RESET}" >&2
        return 1
      fi
      table=$(ip -4 neigh show) || return 1
      ;;
  esac
  awk -v format="$format" -f "$NET_LAN_NEIGHBOURS_AWK" <<< "$table" | sort "${NET_IP_SORT_KEYS[@]}" | uniq
}

#######################################
# Network: Send one SSDP M-SEARCH and print the replies. On WSL it runs
# through the Windows host, because multicast from WSL's NAT network never
# reaches the real LAN.
# Arguments:
#   $1 - Timeout in seconds
# Returns:
#   0 on success, 1 if the tool is missing or discovery fails
# Outputs:
#   "ip<TAB>server<TAB>st<TAB>location" rows sorted by IP
#######################################
__mt_lan_ssdp() {
  local timeout="$1" replies
  if [ "${OS_FAMILY:-linux}" = "wsl" ]; then
    if ! command -v powershell.exe > /dev/null 2>&1; then
      echo -e "${CB_RED}❌ powershell.exe not found: SSDP discovery from WSL runs through the Windows host.${C_RESET}" >&2
      return 1
    fi
    replies=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$NET_SSDP_POWERSHELL")" \
      -Address "$NET_SSDP_ADDRESS" -Port "$NET_SSDP_PORT" -TimeoutSeconds "$timeout" | tr -d '\r') || {
      echo -e "${CB_RED}❌ SSDP discovery failed.${C_RESET}" >&2
      return 1
    }
  else
    replies=$(python3 "$NET_SSDP_PYTHON" --address "$NET_SSDP_ADDRESS" --port "$NET_SSDP_PORT" --timeout "$timeout") || {
      echo -e "${CB_RED}❌ SSDP discovery failed.${C_RESET}" >&2
      return 1
    }
  fi
  [ -z "$replies" ] && return 0
  __mt_strip_control_chars <<< "$replies" | sort "${NET_IP_SORT_KEYS[@]}" | uniq
}

#######################################
# Network: List the devices on the local network -- the ARP/neighbour table
# (multicast, broadcast and incomplete entries dropped) and, with --ssdp,
# the devices that answer an SSDP/UPnP search. On WSL both lookups run
# through the Windows host, because WSL's own neighbour table and multicast
# only see its virtual network. Read-only; replies are untrusted, so control
# characters are stripped.
# Usage: net-lan-devices [--ssdp] [--timeout <seconds>]
# Options:
#   --ssdp               Also send one SSDP M-SEARCH and list the replies
#   --timeout <seconds>  How long to listen for SSDP replies (default: 3)
#   -h, --help           Show this help
# Returns:
#   0 on success, 1 on bad usage, a missing tool (arp.exe, powershell.exe, ip, arp) or a failed discovery
# Outputs:
#   "ip<TAB>mac<TAB>neighbour" rows, then with --ssdp "ip<TAB>server<TAB>st<TAB>location" rows
# Globals:
#   OS_FAMILY
# Example: net-lan-devices --ssdp --timeout 5
#######################################
net-lan-devices() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local use_ssdp="" timeout="$NET_SSDP_DEFAULT_TIMEOUT"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --ssdp) use_ssdp="1" ;;
      --timeout)
        timeout="${2:-}"
        shift
        ;;
      *)
        echo "Usage: net-lan-devices [--ssdp] [--timeout <seconds>]" >&2
        return 1
        ;;
    esac
    shift
  done
  if [[ ! "$timeout" =~ ^[1-9][0-9]*$ ]]; then
    echo -e "${CB_RED}❌ --timeout must be a positive whole number of seconds.${C_RESET}" >&2
    return 1
  fi

  local neighbours ssdp_replies=""
  neighbours=$(__mt_lan_neighbours) || return 1
  if [ -n "$use_ssdp" ]; then
    ssdp_replies=$(__mt_lan_ssdp "$timeout") || return 1
  fi

  echo -e "${CB_BLUE}📡 Neighbours${C_RESET}"
  echo "${neighbours:-ℹ️  none}"
  if [ -n "$use_ssdp" ]; then
    echo -e "${CB_BLUE}🔊 SSDP replies${C_RESET}"
    echo "${ssdp_replies:-ℹ️  none}"
  fi
}
