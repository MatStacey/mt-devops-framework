# shellcheck shell=bash
# ------------------------------------------
# Git: Dependency Vulnerability Audit
# ------------------------------------------
# ~/.bash.d/20-vcs/56-audit.sh

#######################################
# Repo: Run a dependency vulnerability audit for the current directory's
# project, dispatching to the right tool based on its manifest files --
# npm audit for a package.json, pip-audit for a Python project. Anything
# else reports as unsupported rather than guessing wrong, since there's
# no single audit tool that covers every build ecosystem the way
# __mt_hub_detect_build_tool's file-presence checks do for detection
# alone. On-demand only (not part of mt-hub --index) since a real audit
# hits a registry/database and can take several seconds -- too slow to
# run automatically for every repo on every index pass.
# Usage: mt-audit-deps [-j|--json]
# Options:
#   -j, --json   Print the result as a single JSON object instead of a
#                colorized summary
#######################################
mt-audit-deps() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local json_mode=false
  [[ "$1" == "-j" || "$1" == "--json" ]] && json_mode=true

  local tool="" status="unsupported" message="" vulns="null"

  if [ -f "package.json" ]; then
    tool="npm audit"
    if ! command -v npm > /dev/null 2>&1; then
      status="tool-missing"
      message="npm is not installed."
    else
      local raw
      raw=$(npm audit --json 2> /dev/null)
      if echo "$raw" | jq -e '.metadata.vulnerabilities' > /dev/null 2>&1; then
        status="ok"
        vulns=$(echo "$raw" | jq -c '.metadata.vulnerabilities')
      else
        status="error"
        message="npm audit did not return the expected JSON shape."
      fi
    fi
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    tool="pip-audit"
    if ! command -v pip-audit > /dev/null 2>&1; then
      status="tool-missing"
      message="pip-audit is not installed (pip install pip-audit)."
    else
      local raw
      raw=$(pip-audit -f json 2> /dev/null)
      if echo "$raw" | jq -e 'type == "array"' > /dev/null 2>&1; then
        status="ok"
        # pip-audit doesn't categorize findings by severity the way npm
        # audit does -- total is the only honest number to report here.
        local total
        total=$(echo "$raw" | jq '[.[].vulns[]?] | length')
        vulns=$(jq -n --argjson total "$total" '{critical: null, high: null, moderate: null, low: null, info: null, total: $total}')
      else
        status="error"
        message="pip-audit did not return the expected JSON shape."
      fi
    fi
  else
    message="No supported manifest found in this directory (npm/pip projects only, for now)."
  fi

  if [ "$json_mode" = true ]; then
    jq -n --arg status "$status" --arg tool "$tool" --arg message "$message" --argjson vulns "$vulns" \
      '{status: $status, tool: (if $tool == "" then null else $tool end), message: (if $message == "" then null else $message end), vulnerabilities: $vulns}'
    return 0
  fi

  case "$status" in
    ok)
      echo -e "${CB_BLUE}🔍 ${tool} results:${C_RESET}"
      echo "$vulns" | jq -r 'to_entries[] | "  \(.key): \(.value // "n/a")"'
      ;;
    tool-missing | unsupported)
      echo -e "${CB_YELLOW}⚠️  ${message}${C_RESET}"
      ;;
    error)
      echo -e "${CB_RED}🚨 ${message}${C_RESET}"
      ;;
  esac
}
