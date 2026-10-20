# shellcheck shell=bash
# ------------------------------------------
# Utilities: HTML Structure Checker
# ------------------------------------------
# ~/.bash.d/02-utilities/38-html-check.sh

HTML_CHECK_SCRIPT="$HOME/.bash.d/lib/python/html_check.py"

#######################################
# HTML: Validate a local HTML file for unbalanced tags and broken
# internal anchors (href="#id" with no matching id/name).
# Usage: mt-html-check <file.html>...
# Arguments:
#   <file.html>   One or more HTML files to check
# Options:
#   -h, --help    Show this help
# Returns:
#   0 if every file is clean, 1 if any problem was found
# Outputs:
#   One "file:line: problem" line per issue
#######################################
mt-html-check() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [ "$#" -eq 0 ]; then
    echo "Usage: mt-html-check <file.html>..." >&2
    return 1
  fi

  local html_file failed=0
  for html_file in "$@"; do
    python3 "$HTML_CHECK_SCRIPT" "$html_file" || failed=1
  done

  if [ "$failed" -eq 1 ]; then
    echo -e "${CB_RED}❌ HTML problems found.${C_RESET}"
    return 1
  fi
  echo -e "${CB_GREEN}✅ HTML structure OK.${C_RESET}"
}
