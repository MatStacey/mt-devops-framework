# shellcheck shell=bash
# ------------------------------------------
# Infrastructure: Conftest (OPA Policy Testing)
# ------------------------------------------
# ~/.bash.d/10-infra/46-conftest.sh

CONFTEST_DEFAULT_POLICY_DIR="policy"

#######################################
# Conftest: Test files against OPA/Rego policies, or run the policies'
# own unit tests with -v.
# Usage: mt-conftest [-p <policy_dir>] [-n <namespace>] [-v] [<file>...]
# Arguments:
#   <file>...                  Files to test (required unless -v)
# Options:
#   -p, --policy <dir>         Policy directory (default: policy)
#   -n, --namespace <name>     Only evaluate this Rego namespace
#   -v, --verify               Run 'conftest verify' (policy unit tests)
#   -h, --help                 Show this help
# Returns:
#   conftest's exit code
#######################################
mt-conftest() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local policy_dir="$CONFTEST_DEFAULT_POLICY_DIR" namespace="" verify=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --policy)
        policy_dir="$2"
        shift 2
        ;;
      -n | --namespace)
        namespace="$2"
        shift 2
        ;;
      -v | --verify)
        verify=1
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  if ! command -v conftest > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 conftest is not installed.${C_RESET}"
    return 1
  fi
  if [ ! -d "$policy_dir" ]; then
    echo -e "${CB_RED}🚨 Policy directory '$policy_dir' not found.${C_RESET}"
    return 1
  fi

  if [ "$verify" -eq 1 ]; then
    conftest verify --policy "$policy_dir"
    return $?
  fi

  if [ "$#" -eq 0 ]; then
    echo "Usage: mt-conftest [-p <policy_dir>] [-n <namespace>] [-v] <file>..." >&2
    return 1
  fi

  local -a namespace_args=()
  [ -n "$namespace" ] && namespace_args=(--namespace "$namespace")
  conftest test --policy "$policy_dir" "${namespace_args[@]}" "$@"
}
