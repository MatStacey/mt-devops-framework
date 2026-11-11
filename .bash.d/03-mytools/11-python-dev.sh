# shellcheck shell=bash
# ------------------------------------------
# Python Development Helpers
# ------------------------------------------
# ~/.bash.d/03-mytools/11-python-dev.sh

UV_LOCKFILE="uv.lock"
PY_VENV_PYTHON=".venv/bin/python"
PY_HERMETIC_ENV_ALLOWLIST=(PATH LANG TERM PYTHONPATH)
PY_HERMETIC_ENV_FORBIDDEN_KEYS=(HOME CLOUDSDK_CONFIG GOOGLE_APPLICATION_CREDENTIALS)
PY_WSL_INTEROP_FILE="/proc/sys/fs/binfmt_misc/WSLInterop"
PY_HERMETIC_ENV_LINE_REGEX='^[A-Za-z_][A-Za-z0-9_]*=.*$'

#######################################
# Dev: Python - Run a uv project's pytest suite with coverage from the
# locked environment (uv sync --frozen, then pytest --cov).
# Usage: uv-pytest [pytest-args...]
# Arguments:
#   pytest-args   Extra arguments passed straight to pytest
# Options:
#   -h, --help    Show this help menu
# Returns:
#   pytest's exit code; 1 if uv is missing, there is no uv.lock in the
#   current directory, or the environment sync fails
# Outputs:
#   pytest and coverage output on STDOUT
#######################################
uv-pytest() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if ! command -v uv > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 uv is not installed (https://docs.astral.sh/uv/).${C_RESET}"
    return 1
  fi
  if [ ! -f "$UV_LOCKFILE" ]; then
    echo -e "${CB_RED}🚨 No ${UV_LOCKFILE} in $(pwd). Run from a uv project root.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}📦 Syncing locked environment...${C_RESET}"
  if ! uv sync --frozen; then
    echo -e "${CB_RED}🚨 uv sync --frozen failed.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}🧪 Running pytest with coverage...${C_RESET}"
  uv run --frozen pytest --cov "$@"
}

#######################################
# Dev: Python - Run an ad-hoc script or module with the repo's interpreter with
# a cleared environment (only PATH, LANG, TERM and PYTHONPATH survive), an empty
# temporary HOME and gcloud config, no Google credential variables (so ADC
# lookups through the environment fail closed), and -- unless --allow-network --
# a network namespace with no connectivity. Meant for repro scripts, especially
# agent-written ones, run against repos wired to real cloud projects.
# This is NOT a filesystem sandbox: a script that opens an absolute path (for
# example the real ~/.config/gcloud) can still read it, local Unix sockets (such
# as the Docker socket) stay reachable, and on WSL with interop enabled it can
# still start Windows programs that are not network-isolated. Review the script,
# or use a container or VM when that matters.
# Uses ./.venv/bin/python, else `uv run --no-sync python` (needs uv.lock).
# Env-file values appear in the process list, so keep real secrets out of them.
# Usage: py-hermetic-run [--env-file <file>] [--allow-network] (<script.py> | -m <module>) [args...]
# Arguments:
#   <script.py>              Script to run
#   -m <module>              Module to run instead of a script
#   args                     Passed to the script or module
# Options:
#   --env-file <file>        Extra KEY=VALUE lines to set (blank lines and # comments allowed;
#                            HOME, CLOUDSDK_CONFIG and GOOGLE_APPLICATION_CREDENTIALS are refused)
#   --allow-network          Do not isolate the network (required where `unshare -rn` is unavailable)
#   -h, --help               Show this help menu
# Returns:
#   The script's exit code; 1 on bad usage, an invalid env file, no interpreter, or when network
#   isolation is unavailable and --allow-network was not given
# Outputs:
#   The script's output
#######################################
py-hermetic-run() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local env_file="" allow_network="" target_flag=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --env-file)
        env_file="${2:-}"
        shift
        ;;
      --allow-network) allow_network="1" ;;
      -m)
        target_flag="-m"
        shift
        break
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) break ;;
    esac
    shift
  done
  if [ "$#" -eq 0 ]; then
    echo "Usage: py-hermetic-run [--env-file <file>] [--allow-network] (<script.py> | -m <module>) [args...]" >&2
    return 1
  fi
  if [ -z "$target_flag" ] && [ ! -f "$1" ]; then
    echo -e "${CB_RED}❌ Script not found: $1${C_RESET}" >&2
    return 1
  fi

  local -a interpreter
  if [ -x "$PY_VENV_PYTHON" ]; then
    interpreter=("$(pwd)/${PY_VENV_PYTHON}")
  elif [ -f "$UV_LOCKFILE" ] && command -v uv > /dev/null 2>&1; then
    interpreter=(uv run --no-sync python)
  else
    echo -e "${CB_RED}🚨 No ${PY_VENV_PYTHON} here, and no ${UV_LOCKFILE} with uv installed to fall back on.${C_RESET}" >&2
    return 1
  fi

  local -a extra_env=()
  local line key
  if [ -n "$env_file" ]; then
    [ -r "$env_file" ] || {
      echo -e "${CB_RED}❌ Cannot read ${env_file}.${C_RESET}" >&2
      return 1
    }
    while IFS= read -r line || [ -n "$line" ]; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      key="${line%%=*}"
      if [[ ! "$line" =~ $PY_HERMETIC_ENV_LINE_REGEX ]] || [[ " ${PY_HERMETIC_ENV_FORBIDDEN_KEYS[*]} " == *" ${key} "* ]]; then
        echo -e "${CB_RED}❌ ${env_file}: only KEY=VALUE lines are accepted (not ${PY_HERMETIC_ENV_FORBIDDEN_KEYS[*]}): ${key}${C_RESET}" >&2
        return 1
      fi
      extra_env+=("$line")
    done < "$env_file"
  fi

  local -a isolate=()
  if [ -z "$allow_network" ]; then
    if ! unshare -rn true 2> /dev/null; then
      echo -e "${CB_RED}🚫 Network isolation (unshare -rn) is unavailable here; pass --allow-network to run without it.${C_RESET}" >&2
      return 1
    fi
    isolate=(unshare -rn)
  fi

  if [ "${#isolate[@]}" -gt 0 ] && [ -e "$PY_WSL_INTEROP_FILE" ]; then
    echo -e "${CB_YELLOW}⚠️  WSL interop is enabled: the script can still start Windows programs, which are not network-isolated.${C_RESET}" >&2
  fi
  local -a sealed_env=()
  local name
  for name in "${PY_HERMETIC_ENV_ALLOWLIST[@]}"; do
    [ -n "${!name:-}" ] && sealed_env+=("${name}=${!name}")
  done
  (
    home_dir=$(mktemp -d)
    config_dir=$(mktemp -d)
    trap 'rm -rf "$home_dir" "$config_dir"' EXIT
    "${isolate[@]}" env -i "${sealed_env[@]}" "HOME=${home_dir}" "CLOUDSDK_CONFIG=${config_dir}" "${extra_env[@]}" \
      "${interpreter[@]}" ${target_flag:+"$target_flag"} "$@"
  )
}
