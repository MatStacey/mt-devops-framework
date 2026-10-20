# shellcheck shell=bash
# ------------------------------------------
# Python Development Helpers
# ------------------------------------------
# ~/.bash.d/03-mytools/11-python-dev.sh

UV_LOCKFILE="uv.lock"

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
