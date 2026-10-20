# shellcheck shell=bash
# ------------------------------------------
# Version Control: Bitbucket Cloud API Helpers
# ------------------------------------------
# ~/.bash.d/25-atlassian/10-bitbucket.sh

BITBUCKET_API_BASE="https://api.bitbucket.org/2.0"
BITBUCKET_PAGE_LENGTH=100
BITBUCKET_MAX_PAGES=20
BITBUCKET_JQ_DIR="$HOME/.bash.d/lib/jq"

#######################################
# Bitbucket: Print "workspace/repo" for the current directory's Bitbucket
# remote (SSH or HTTPS), or for an explicitly supplied value.
# Arguments:
#   $1 - Optional explicit "workspace/repo"
# Returns:
#   0 on success, 1 if no Bitbucket repository can be determined
# Outputs:
#   workspace/repo on stdout
#######################################
__mt_bb_resolve_repo() {
  local explicit="${1:-}" origin_url repo_path
  if [ -n "$explicit" ]; then
    if [[ "$explicit" != */* ]]; then
      echo -e "${CB_RED}🚨 Repository must be given as workspace/repo.${C_RESET}" >&2
      return 1
    fi
    echo "$explicit"
    return 0
  fi

  origin_url=$(git remote get-url origin 2> /dev/null)
  if [[ "$origin_url" != *bitbucket.org* ]]; then
    echo -e "${CB_RED}🚨 Not in a Bitbucket repository. Pass -r workspace/repo.${C_RESET}" >&2
    return 1
  fi
  repo_path=$(sed -E 's#^.*bitbucket\.org[:/]+##; s#\.git$##' <<< "$origin_url")
  echo "$repo_path"
}

#######################################
# Bitbucket: Call the Bitbucket Cloud API through mt-http using the stored
# credentials, and record the secret as used on success.
# Arguments:
#   $1 - API path relative to the 2.0 base, or a full https:// URL
#   $@ - Further mt-http options (e.g. --raw, -X POST, -d <body>)
# Returns:
#   mt-http's exit code; 1 when credentials are not configured
# Globals:
#   BITBUCKET_EMAIL, BITBUCKET_API_KEY, SECRETS_MANAGER
#######################################
__mt_bb_api() {
  local target="$1"
  shift
  if [ -z "${BITBUCKET_EMAIL:-}" ] || [ -z "${BITBUCKET_API_KEY:-}" ]; then
    echo -e "${CB_RED}🚨 Bitbucket credentials are not configured. Run 'mt-add-bitbucket-secret' first.${C_RESET}" >&2
    return 1
  fi
  [[ "$target" == https://* ]] || target="${BITBUCKET_API_BASE}/${target}"

  local rc=0
  mt-http -u "${BITBUCKET_EMAIL}:${BITBUCKET_API_KEY}" "$@" "$target" || rc=$?
  [ "$rc" -eq 0 ] && python3 "$SECRETS_MANAGER" touch "BITBUCKET_API_KEY" 2> /dev/null
  return "$rc"
}

#######################################
# Bitbucket: Fetch every page of a paginated collection and print the
# combined "values" as one JSON array.
# Arguments:
#   $1 - API path of the collection (query string allowed)
# Returns:
#   0 on success, non-zero if any page request fails
# Outputs:
#   JSON array on stdout
#######################################
__mt_bb_collect() {
  local url="${BITBUCKET_API_BASE}/$1" separator="?" pages=0 page combined="[]"
  [[ "$1" == *\?* ]] && separator="&"
  url="${url}${separator}pagelen=${BITBUCKET_PAGE_LENGTH}"

  while [ -n "$url" ] && [ "$pages" -lt "$BITBUCKET_MAX_PAGES" ]; do
    page=$(__mt_bb_api "$url" --raw) || return $?
    combined=$(jq -c --argjson more "$(jq -c '.values // []' <<< "$page")" '. + $more' <<< "$combined")
    url=$(jq -r '.next // empty' <<< "$page")
    pages=$((pages + 1))
    if [ -n "$url" ] && [[ "$url" != "${BITBUCKET_API_BASE}/"* ]]; then
      echo -e "${CB_RED}🚨 Refusing to follow a pagination link outside ${BITBUCKET_API_BASE}.${C_RESET}" >&2
      return 1
    fi
  done
  if [ -n "$url" ]; then
    echo -e "${CB_YELLOW}⚠️  Results truncated after ${BITBUCKET_MAX_PAGES} pages.${C_RESET}" >&2
  fi
  echo "$combined"
}

#######################################
# Bitbucket: Show a pull request's metadata, diff, diffstat or comments
# Usage: bb-pr [-r <workspace/repo>] [--diff|--diffstat|--comments] <pr-number>
# Arguments:
#   <pr-number>          Pull request number
# Options:
#   -r, --repo <w/r>     Repository (default: the current directory's Bitbucket remote)
#   --diff               Print the full unified diff
#   --diffstat           Print status, lines added/removed and path per file
#   --comments           Print every comment with its file and line
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on bad usage or missing credentials, mt-http's code on API failure
# Outputs:
#   Summary, diff, diffstat or comments on stdout, with terminal control
#   characters removed
#######################################
bb-pr() {
  local repo="" mode="summary" pr_number=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -r | --repo)
        repo="${2:-}"
        shift
        ;;
      --diff) mode="diff" ;;
      --diffstat) mode="diffstat" ;;
      --comments) mode="comments" ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) pr_number="$1" ;;
    esac
    shift
  done

  if [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
    echo "Usage: bb-pr [-r <workspace/repo>] [--diff|--diffstat|--comments] <pr-number>" >&2
    return 1
  fi
  repo=$(__mt_bb_resolve_repo "$repo") || return 1
  local pr_path="repositories/${repo}/pullrequests/${pr_number}"

  local data
  case "$mode" in
    summary)
      data=$(__mt_bb_api "$pr_path" --raw) || return $?
      jq -r -f "$BITBUCKET_JQ_DIR/bb_pr_summary.jq" <<< "$data" | __mt_strip_control_chars
      ;;
    diff)
      data=$(__mt_bb_api "${pr_path}/diff" --raw) || return $?
      __mt_strip_control_chars <<< "$data"
      ;;
    diffstat)
      data=$(__mt_bb_collect "${pr_path}/diffstat") || return $?
      jq -r -f "$BITBUCKET_JQ_DIR/bb_pr_diffstat.jq" <<< "$data" | __mt_strip_control_chars
      ;;
    comments)
      data=$(__mt_bb_collect "${pr_path}/comments") || return $?
      jq -r -f "$BITBUCKET_JQ_DIR/bb_pr_comments.jq" <<< "$data" | __mt_strip_control_chars
      ;;
  esac
}
