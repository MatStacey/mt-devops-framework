# shellcheck shell=bash
# ------------------------------------------
# Networking: Speed Test Utility
# ------------------------------------------
# ~/.bash.d/02-utilities/32-speedtest.sh

#######################################
# Networking: Run an internet speed test via the Ookla Speedtest CLI,
# offering to install it first (via bootstrap's __install_speedtest) if
# it isn't already present
# Usage: mt-speedtest [-j]
# Options:
#   -j, --json  Output raw JSON instead of the formatted report
#######################################
mt-speedtest() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local json_output=false
  case "$1" in
    -j | --json) json_output=true ;;
    -*)
      echo "Usage: mt-speedtest [-j|--json]" >&2
      return 1
      ;;
  esac

  if ! command -v speedtest > /dev/null 2>&1; then
    echo -e "${CB_YELLOW}⚠️  Ookla Speedtest CLI is not installed.${C_RESET}"
    local reply
    if ! read -r -p "Install it now? [Y/n] " -n 1 reply < /dev/tty; then
      reply="n"
    fi
    echo
    if [[ ! $reply =~ ^[Yy]$ ]] && [ -n "$reply" ]; then
      echo -e "${CB_YELLOW}🛑 Aborted. Run 'bootstrap' anytime to install it.${C_RESET}"
      return 1
    fi
    __install_speedtest || return 1
  fi

  echo -e "${CB_BLUE}🌐 Running internet speed test...${C_RESET}"
  if [ "$json_output" = true ]; then
    speedtest --accept-license --accept-gdpr -f json
  else
    speedtest --accept-license --accept-gdpr
  fi
}
