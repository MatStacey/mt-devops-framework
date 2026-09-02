# shellcheck shell=bash
# ==========================================
# Workflow Gap / Backlog Capture
# ==========================================
# ~/.bash.d/03-mytools/10-backlog.sh

#######################################
# System: Quickly file a lightweight "workflow gap" issue against the
# framework's own repo (UPSTREAM_REPO_PATH) -- the low-friction capture
# mechanism for "I couldn't do this with an mt- command" or "this could
# be smoother" moments noticed while doing real work, from inside ANY
# project directory, not just this one. Prompts interactively for
# anything not given on the command line, so it works equally well as
# a fast one-liner or from the mt-menu. Filed with the workflow-gap
# label (plus bug or enhancement) so it surfaces separately from
# fully-written issues during the next recurring self-audit (see
# CONTRIBUTING.md).
# Usage: mt-suggest [-b|--bug] [--context <text>] ["<description>"]
# Options:
#   -b, --bug             File as a bug (something broken) instead of an enhancement (something missing)
#   --context <text>      What you were doing / what you did instead -- omit to be prompted
#   -h, --help             Show this help menu
# Arguments:
#   <description>          Short summary of the gap or idea (becomes the issue title) -- omit to be prompted
# Returns:
#   1 if gh issue creation fails
# Outputs:
#   The created issue's URL
#######################################
mt-suggest() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local is_bug=""
  local bug_given=""
  local context=""
  local context_given=""
  local -a description_words=()

  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -b | --bug)
        is_bug="1"
        bug_given="1"
        ;;
      --context)
        context="$2"
        context_given="1"
        shift
        ;;
      *) description_words+=("$1") ;;
    esac
    shift
  done

  local description="${description_words[*]}"
  while [[ -z "$description" ]]; do
    read -r -p "📝 Short description (becomes the issue title): " description < /dev/tty
  done

  if [[ -z "$bug_given" ]]; then
    local bug_reply
    read -r -p "🐛 Is this a bug (something broken), rather than a missing feature? [y/N] " bug_reply < /dev/tty
    [[ "$bug_reply" =~ ^[Yy] ]] && is_bug="1"
  fi

  if [[ -z "$context_given" ]]; then
    read -r -p "📎 Any extra context (what you were doing / worked around with)? [optional] " context < /dev/tty
  fi

  local label="enhancement"
  [[ -n "$is_bug" ]] && label="bug"

  local version="unknown"
  [[ -f "$VERSION_FILE" ]] && version=$(command cat "$VERSION_FILE")

  local body
  body=$(
    cat << EOF
## Discovered while
${context:-Not specified}

## Captured from
- Working directory: $(pwd)
- Framework version: ${version}
- Captured: $(date '+%Y-%m-%d %H:%M:%S')

---
*Filed via \`mt-suggest\` -- a workflow gap noticed during real work. Triage during the next recurring self-audit (see CONTRIBUTING.md) to decide if/how to build it.*
EOF
  )

  local issue_url
  if ! issue_url=$(gh issue create --repo "$UPSTREAM_REPO_PATH" \
    --title "[Workflow Gap] ${description}" \
    --body "$body" \
    --label "$label" \
    --label "workflow-gap" 2>&1); then
    echo -e "${CB_RED}❌ Failed to file the issue:${C_RESET}"
    echo "$issue_url"
    return 1
  fi

  echo -e "${CB_GREEN}✅ Logged to the backlog:${C_RESET} ${issue_url}"
}
