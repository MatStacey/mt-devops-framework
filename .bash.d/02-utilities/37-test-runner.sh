# shellcheck shell=bash
# ------------------------------------------
# Utilities: Framework Test Runner
# ------------------------------------------
# ~/.bash.d/02-utilities/37-test-runner.sh

#######################################
# Testing: Run the framework's full test suite -- bats (tests/bash/)
# then pytest (tests/python/) -- from the repo root, and report a
# combined result. Both suites always run, even if the first fails.
# Usage: mt-test-all [-b] [-p]
# Options:
#   -b, --bats-only     Run only the bats suite
#   -p, --pytest-only   Run only the pytest suite
#   -h, --help          Show this help
# Returns:
#   0 if every selected suite passed, 1 otherwise
#######################################
mt-test-all() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local run_bats=1 run_pytest=1
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -b | --bats-only)
        run_pytest=0
        shift
        ;;
      -p | --pytest-only)
        run_bats=0
        shift
        ;;
      *)
        echo "Usage: mt-test-all [-b] [-p]" >&2
        return 1
        ;;
    esac
  done

  local repo_root
  repo_root=$(git -C "$(dirname "$(readlink -f "$HOME/.bash.d")")" rev-parse --show-toplevel 2> /dev/null)
  if [ -z "$repo_root" ] || [ ! -d "$repo_root/tests" ]; then
    echo -e "${CB_RED}🚨 Framework repo checkout with a tests/ directory not found.${C_RESET}"
    return 1
  fi

  local failed=0
  if [ "$run_bats" -eq 1 ]; then
    echo -e "${CB_BLUE}🧪 bats tests/bash/${C_RESET}"
    bats "$repo_root/tests/bash/" || failed=1
  fi
  if [ "$run_pytest" -eq 1 ]; then
    echo -e "${CB_BLUE}🧪 pytest tests/python/${C_RESET}"
    python3 -m pytest "$repo_root/tests/python/" -q || failed=1
  fi

  if [ "$failed" -eq 1 ]; then
    mt-log ERROR "mt-test-all: one or more suites failed"
    echo -e "${CB_RED}❌ Test suite failed.${C_RESET}"
    return 1
  fi
  echo -e "${CB_GREEN}✅ All selected suites passed.${C_RESET}"
}
