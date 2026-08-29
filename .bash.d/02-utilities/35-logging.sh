# shellcheck shell=bash
# ------------------------------------------
# Utilities: Centralized Framework Logging
# ------------------------------------------
# ~/.bash.d/02-utilities/35-logging.sh

#######################################
# System: Centralized logging for MyTools
# Arguments:
#   $1 - Log level (INFO, SUCCESS, WARN, ERROR)
#   $2 - Message
#######################################
mt-log() {
  local level="$1"
  local msg="$2"
  local log_file="$LOG_DIR/framework.log"

  # Console Output
  case "$level" in
    INFO) echo -e "${CB_BLUE}ℹ️ ${msg}${C_RESET}" ;;
    SUCCESS) echo -e "${CB_GREEN}✅ ${msg}${C_RESET}" ;;
    WARN) echo -e "${CB_YELLOW}⚠️ ${msg}${C_RESET}" ;;
    ERROR) echo -e "${CB_RED}🚨 ${msg}${C_RESET}" >&2 ;;
    *) echo "$msg" ;;
  esac

  # File Logging (with 1MB basic rotation)
  mkdir -p "$LOG_DIR" 2> /dev/null
  if [ -f "$log_file" ]; then
    local size
    size=$(wc -c < "$log_file" 2> /dev/null || echo 0)
    if [ "$size" -gt "${LOG_ROTATE_BYTES:-1048576}" ]; then
      mv "$log_file" "${log_file}.old" 2> /dev/null
    fi
  fi

  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$ts] [$level] $msg" >> "$log_file" 2> /dev/null
}

#######################################
# System: Pass stdin through unchanged, or through a literal-string level
# filter if one is given -- one leg of mt-logs' filter pipeline, kept as
# a real command rather than a string handed to eval so a level value
# can never be interpreted as shell syntax.
# Arguments:
#   $1 - Level to filter on (e.g. "ERROR"), or empty to pass through
#######################################
__mt_logs_filter_level() {
  if [ -n "$1" ]; then
    grep -F "[$1]"
  else
    cat
  fi
}

#######################################
# System: Pass stdin through unchanged, or through a case-insensitive
# search filter if one is given -- the other leg of mt-logs' filter
# pipeline. See __mt_logs_filter_level for why this is a real command
# rather than an eval'd string: a search term is arbitrary user input,
# and building it into a shell string before executing it is exactly
# how mt-logs used to be vulnerable to command injection.
# Arguments:
#   $1 - Search term, or empty to pass through
#######################################
__mt_logs_filter_search() {
  if [ -n "$1" ]; then
    grep -i -- "$1"
  else
    cat
  fi
}

#######################################
# System: View, filter, and manage framework logs
# Usage: mt-logs [-n lines] [-l level] [-s keyword] [-o] [-f] [-c]
# Options:
#   -n, --lines <num>     Number of lines to display (default: 50)
#   -l, --level <level>   Filter by severity (INFO, SUCCESS, WARN, ERROR)
#   -s, --search <term>   Search for a specific keyword
#   -o, --open            Open the log file in your default IDE
#   -f, --follow          Tail the logs live
#   -c, --clear           Clear the log file
#######################################
mt-logs() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local log_file="$LOG_DIR/framework.log"
  local lines=50
  local level_filter=""
  local search_term=""
  local do_open=false
  local do_follow=false
  local do_clear=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -n | --lines)
        lines="$2"
        shift
        ;;
      -l | --level)
        level_filter="${2^^}"
        shift
        ;;
      -s | --search)
        search_term="$2"
        shift
        ;;
      -o | --open) do_open=true ;;
      -f | --follow) do_follow=true ;;
      -c | --clear) do_clear=true ;;
      -*)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
    shift
  done

  if [ ! -f "$log_file" ]; then
    echo -e "${CB_YELLOW}⚠️ No log file found at $log_file${C_RESET}"
    return 0
  fi

  if [ "$do_clear" = true ]; then
    true > "$log_file"
    echo -e "${CB_GREEN}✅ Log file cleared.${C_RESET}"
    return 0
  fi

  if [ "$do_open" = true ]; then
    echo -e "${CB_BLUE}📂 Opening $log_file in ${DEFAULT_IDE:-vscode}...${C_RESET}"
    if [ "${DEFAULT_IDE:-vscode}" = "intellij" ]; then
      idea "$log_file" 2> /dev/null || cat "$log_file"
    else
      code "$log_file" 2> /dev/null || cat "$log_file"
    fi
    return 0
  fi

  if [ "$do_follow" = true ]; then
    tail -f "$log_file"
    return 0
  fi

  echo -e "${CB_CYAN}📜 Showing last $lines lines of framework logs...${C_RESET}"
  [ -n "$level_filter" ] && echo -e "${C_DIM}   Level: $level_filter${C_RESET}"
  [ -n "$search_term" ] && echo -e "${C_DIM}   Search: $search_term${C_RESET}"
  echo -e "${CB_BLUE}----------------------------------------------------------${C_RESET}"

  __mt_logs_filter_level "$level_filter" < "$log_file" | __mt_logs_filter_search "$search_term" | tail -n "$lines"
}
