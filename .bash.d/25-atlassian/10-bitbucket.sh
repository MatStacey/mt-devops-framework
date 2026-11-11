# shellcheck shell=bash
# ------------------------------------------
# Version Control: Bitbucket Cloud API Helpers
# ------------------------------------------
# ~/.bash.d/25-atlassian/10-bitbucket.sh

BITBUCKET_API_BASE="https://api.bitbucket.org/2.0"
BITBUCKET_PAGE_LENGTH=100
BITBUCKET_MAX_PAGES=20
BITBUCKET_JQ_DIR="$HOME/.bash.d/lib/jq"
BITBUCKET_PR_STATES=(OPEN MERGED DECLINED SUPERSEDED)
BITBUCKET_PR_DEFAULT_STATE="OPEN"
BITBUCKET_PR_TITLE_MAX=250
BITBUCKET_MERGE_STRATEGIES=(merge_commit squash fast_forward)
BITBUCKET_PR_USAGE="Usage: bb-pr [-r <workspace/repo>] (--list [--state OPEN|MERGED|DECLINED|SUPERSEDED] | [--diff|--diffstat|--comments] <pr-number>)
       bb-pr [-r <workspace/repo>] <pr-number> [--set-title <text>] [--set-description <@file|->]
       bb-pr [-r <workspace/repo>] --merge <pr-number> [--strategy merge_commit|squash|fast_forward] [--keep-branch] [--yes]"

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
# Bitbucket: Print a JSON request body to a private temp file, so secret
# values never appear on a command line. The caller removes the directory.
# Arguments:
#   $1 - JSON text
# Outputs:
#   Path of the body file on stdout
#######################################
__mt_bb_body_file() {
  local dir
  dir=$(mktemp -d) || return 1
  printf '%s' "$1" > "$dir/body.json"
  echo "$dir/body.json"
}

#######################################
# Bitbucket: Print the pull requests of a repository in a given state.
# Arguments:
#   $1 - Optional explicit "workspace/repo"
#   $2 - Optional state (default OPEN), case-insensitive
# Returns:
#   0 on success (including no results), 1 on an invalid state or repository,
#   mt-http's code on API failure
# Outputs:
#   One tab-separated line per pull request on stdout
#######################################
__mt_bb_list_prs() {
  local repo="$1" state="${2:-$BITBUCKET_PR_DEFAULT_STATE}"
  state="${state^^}"
  local valid=false candidate
  for candidate in "${BITBUCKET_PR_STATES[@]}"; do
    [ "$candidate" = "$state" ] && valid=true
  done
  if [ "$valid" = false ]; then
    echo -e "${CB_RED}❌ Invalid state '$state'. Allowed: ${BITBUCKET_PR_STATES[*]}${C_RESET}" >&2
    return 1
  fi
  repo=$(__mt_bb_resolve_repo "$repo") || return 1

  local data
  data=$(__mt_bb_collect "repositories/${repo}/pullrequests?state=${state}") || return $?
  if [ "$(jq 'length' <<< "$data")" -eq 0 ]; then
    echo -e "ℹ️  No ${state} pull requests in ${repo}." >&2
    return 0
  fi
  jq -r -f "$BITBUCKET_JQ_DIR/bb_pr_list.jq" <<< "$data" | __mt_strip_control_chars
}

#######################################
# Bitbucket: Change the title and/or description of an open pull request.
# Arguments:
#   $1 - Optional explicit "workspace/repo"
#   $2 - Pull request number
#   $3 - New title (empty to leave unchanged)
#   $4 - Description source: "@<file>" or "-" for stdin (empty to leave unchanged)
# Returns:
#   0 on success, 1 on invalid input, a closed pull request or a pipe-less "-",
#   mt-http's code on API failure
# Outputs:
#   Confirmation with the pull request URL on stdout
#######################################
__mt_bb_edit_pr() {
  local repo="$1" pr_number="$2" title="$3" description_source="$4"
  local description_file="" scratch_dir="" changed=()

  if [ -n "$title" ] && [ "${#title}" -gt "$BITBUCKET_PR_TITLE_MAX" ]; then
    echo -e "${CB_RED}🚨 Title is longer than ${BITBUCKET_PR_TITLE_MAX} characters.${C_RESET}" >&2
    return 1
  fi
  if [ -n "$description_source" ]; then
    if [ "$description_source" = "-" ]; then
      if [ -t 0 ]; then
        echo -e "${CB_RED}🚨 Pipe the description in, or use @file.${C_RESET}" >&2
        return 1
      fi
      scratch_dir=$(mktemp -d) || return 1
      description_file="$scratch_dir/description.md"
      cat > "$description_file"
    elif [[ "$description_source" == @* ]]; then
      description_file="${description_source#@}"
      if [ ! -f "$description_file" ] || [ ! -r "$description_file" ]; then
        echo -e "${CB_RED}🚨 Cannot read description file: ${description_file}${C_RESET}" >&2
        return 1
      fi
    else
      echo -e "${CB_RED}🚨 --set-description takes @<file> or - (stdin), not literal text.${C_RESET}" >&2
      return 1
    fi
    if [ ! -s "$description_file" ]; then
      echo -e "${CB_RED}🚨 The description is empty; refusing to wipe it.${C_RESET}" >&2
      [ -n "$scratch_dir" ] && rm -rf "$scratch_dir"
      return 1
    fi
  fi

  local resolve_rc=0
  repo=$(__mt_bb_resolve_repo "$repo") || resolve_rc=$?
  if [ "$resolve_rc" -ne 0 ]; then
    [ -n "$scratch_dir" ] && rm -rf "$scratch_dir"
    return 1
  fi
  local pr_path="repositories/${repo}/pullrequests/${pr_number}" pr state reviewers fetch_rc=0
  pr=$(__mt_bb_api "$pr_path" --raw) || fetch_rc=$?
  if [ "$fetch_rc" -ne 0 ]; then
    [ -n "$scratch_dir" ] && rm -rf "$scratch_dir"
    return "$fetch_rc"
  fi
  state=$(jq -r '.state // "UNKNOWN"' <<< "$pr")
  if [ "$state" != "OPEN" ]; then
    echo -e "${CB_RED}🚫 PR #${pr_number} is ${state}; only open pull requests can be edited.${C_RESET}" >&2
    [ -n "$scratch_dir" ] && rm -rf "$scratch_dir"
    return 1
  fi

  reviewers=$(jq -c '[.reviewers[]? | {uuid}]' <<< "$pr")
  [ -n "$title" ] && changed+=("title")
  [ -n "$description_file" ] && changed+=("description")
  local body body_file response rc=0
  body=$(jq -nc --argjson reviewers "$reviewers" --arg title "$title" --rawfile description "${description_file:-/dev/null}" \
    '{reviewers: $reviewers}
     + (if $title != "" then {title: $title} else {} end)
     + (if $description != "" then {description: $description} else {} end)')
  [ -n "$scratch_dir" ] && rm -rf "$scratch_dir"
  body_file=$(__mt_bb_body_file "$body") || return 1
  response=$(__mt_bb_api "$pr_path" -X PUT -H "Content-Type: application/json" -d "@${body_file}" --raw) || rc=$?
  rm -rf "$(dirname "$body_file")"
  [ "$rc" -ne 0 ] && return "$rc"

  local changed_list
  changed_list=$(IFS=,; echo "${changed[*]}")
  echo -e "${CB_GREEN}✅ Updated PR #${pr_number} (${changed_list//,/, }): $(jq -r '.links.html.href // ""' <<< "$response" | __mt_strip_control_chars)${C_RESET}"
}

#######################################
# Bitbucket: Merge an open pull request whose build statuses are all green.
# Arguments:
#   $1 - Optional explicit "workspace/repo"
#   $2 - Pull request number
#   $3 - Merge strategy (empty for the repository default)
#   $4 - "1" to keep the source branch
#   $5 - "1" to skip the confirmation
# Returns:
#   0 on success or an accepted asynchronous merge, 1 on refusal (no terminal
#   without --yes, not open, statuses not green, cancelled), mt-http's code on API failure
# Outputs:
#   All build statuses as "key<TAB>state<TAB>name" when any is not successful,
#   then the result line
#######################################
__mt_bb_merge_pr() {
  local repo="$1" pr_number="$2" strategy="$3" keep_branch="$4" assume_yes="$5"
  if [ -z "$assume_yes" ] && [ ! -t 0 ]; then
    echo -e "${CB_RED}🚫 Merging can deploy; pass --yes when there is no terminal to confirm on.${C_RESET}" >&2
    return 1
  fi
  repo=$(__mt_bb_resolve_repo "$repo") || return 1
  local pr_path="repositories/${repo}/pullrequests/${pr_number}" pr state statuses
  pr=$(__mt_bb_api "$pr_path" --raw) || return $?
  state=$(jq -r '.state // "UNKNOWN"' <<< "$pr")
  if [ "$state" != "OPEN" ]; then
    echo -e "${CB_RED}🚫 PR #${pr_number} is ${state}; only open pull requests can be merged.${C_RESET}" >&2
    return 1
  fi

  statuses=$(__mt_bb_collect "${pr_path}/statuses") || return $?
  if [ "$(jq 'length' <<< "$statuses")" -eq 0 ]; then
    echo -e "${CB_YELLOW}⚠️  PR #${pr_number} has no build statuses.${C_RESET}" >&2
  elif [ "$(jq '[.[] | select(.state != "SUCCESSFUL")] | length' <<< "$statuses")" -gt 0 ]; then
    jq -r -f "$BITBUCKET_JQ_DIR/bb_pr_statuses.jq" <<< "$statuses" | __mt_strip_control_chars
    echo -e "${CB_RED}🚫 Not merging: build statuses are not all successful.${C_RESET}" >&2
    return 1
  fi

  local close_source="true" branch_action="deleting"
  if [ -n "$keep_branch" ]; then
    close_source="false"
    branch_action="keeping"
  fi
  if [ -z "$assume_yes" ]; then
    local reply summary
    summary=$(jq -r '"\"\(.title)\" (\(.source.branch.name) -> \(.destination.branch.name))"' <<< "$pr" | __mt_strip_control_chars)
    read -r -p "Merge PR #${pr_number} ${summary} in ${repo} using ${strategy:-the repository default}, ${branch_action} the source branch? [y/N] " reply
    [[ "$reply" =~ ^[Yy] ]] || {
      echo "Cancelled."
      return 1
    }
  fi

  local body body_file response rc=0 merged_state
  body=$(jq -nc --argjson close "$close_source" --arg strategy "$strategy" \
    '{close_source_branch: $close} + (if $strategy != "" then {merge_strategy: $strategy} else {} end)')
  body_file=$(__mt_bb_body_file "$body") || return 1
  response=$(__mt_bb_api "${pr_path}/merge" -X POST -H "Content-Type: application/json" -d "@${body_file}" --raw) || rc=$?
  rm -rf "$(dirname "$body_file")"
  [ "$rc" -ne 0 ] && return "$rc"

  merged_state=$(jq -r '.state // empty' <<< "$response" 2> /dev/null)
  if [ "$merged_state" = "MERGED" ]; then
    echo -e "${CB_GREEN}✅ Merged PR #${pr_number} ($(jq -r '.merge_commit.hash // "" | .[:7]' <<< "$response"))${C_RESET}"
    return 0
  fi
  echo -e "${CB_YELLOW}⏳ Merge accepted and still running; check with bb-pr ${pr_number}.${C_RESET}"
}

#######################################
# Bitbucket: List a repository's pull requests, show one pull request's
# metadata, diff, diffstat or comments, edit its title/description, or merge it
# Usage: bb-pr [-r <workspace/repo>] (--list [--state OPEN|MERGED|DECLINED|SUPERSEDED] | [--diff|--diffstat|--comments] <pr-number>)
# Usage: bb-pr [-r <workspace/repo>] <pr-number> [--set-title <text>] [--set-description <@file|->]
# Usage: bb-pr [-r <workspace/repo>] --merge <pr-number> [--strategy merge_commit|squash|fast_forward] [--keep-branch] [--yes]
# Arguments:
#   <pr-number>          Pull request number (not accepted with --list)
# Options:
#   -r, --repo <w/r>     Repository (default: the current directory's Bitbucket remote)
#   --list               List pull requests, one per line
#   --state <state>      With --list: OPEN (default), MERGED, DECLINED or SUPERSEDED (case-insensitive)
#   --diff               Print the full unified diff
#   --diffstat           Print status, lines added/removed and path per file
#   --comments           Print every comment with its file and line
#   --set-title <text>   Set the title of an open pull request (max 250 characters)
#   --set-description <@file|->
#                        Set the description from a file (@path) or stdin (-); literal text is
#                        rejected and an empty description is refused
#   --merge              Merge an open pull request whose build statuses are all successful
#   --strategy <s>       With --merge: merge_commit, squash or fast_forward (default: the repository's)
#   --keep-branch        With --merge: keep the source branch (default: delete it)
#   --yes                With --merge: skip the confirmation (required without a terminal)
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on bad usage, missing credentials or a refusal (PR not open, build statuses
#   not all successful, no confirmation), mt-http's code on API failure
# Outputs:
#   Summary, diff, diffstat, comments or list on stdout, with terminal control
#   characters removed. --list prints: #<id> <title> <source -> destination>
#   <author> <updated date>, tab-separated; an empty result is reported on stderr.
#   --set-* and --merge print a one-line result.
#######################################
bb-pr() {
  local repo="" mode="summary" pr_number="" list_mode=0 state=""
  local merge_mode=0 strategy="" keep_branch="" assume_yes="" set_title="" set_description=""
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
      --list) list_mode=1 ;;
      --merge) merge_mode=1 ;;
      --keep-branch) keep_branch="1" ;;
      --yes) assume_yes="1" ;;
      --state | --strategy | --set-title | --set-description)
        if [ -z "${2:-}" ]; then
          echo "$BITBUCKET_PR_USAGE" >&2
          return 1
        fi
        case "$1" in
          --state) state="$2" ;;
          --strategy) strategy="$2" ;;
          --set-title) set_title="$2" ;;
          --set-description) set_description="$2" ;;
        esac
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) pr_number="$1" ;;
    esac
    shift
  done

  local edit_mode=0 read_mode_given=0
  { [ -n "$set_title" ] || [ -n "$set_description" ]; } && edit_mode=1
  [ "$mode" != "summary" ] && read_mode_given=1
  if [ "$list_mode" -eq 1 ]; then
    if [ -n "$pr_number" ] || [ "$read_mode_given" -eq 1 ] || [ "$merge_mode" -eq 1 ] || [ "$edit_mode" -eq 1 ]; then
      echo "$BITBUCKET_PR_USAGE" >&2
      return 1
    fi
    __mt_bb_list_prs "$repo" "$state"
    return $?
  fi
  if [ -n "$state" ] || [[ ! "$pr_number" =~ ^[0-9]+$ ]]; then
    echo "$BITBUCKET_PR_USAGE" >&2
    return 1
  fi
  if [ "$merge_mode" -eq 1 ] && { [ "$edit_mode" -eq 1 ] || [ "$read_mode_given" -eq 1 ]; }; then
    echo "$BITBUCKET_PR_USAGE" >&2
    return 1
  fi
  if [ "$edit_mode" -eq 1 ] && [ "$read_mode_given" -eq 1 ]; then
    echo "$BITBUCKET_PR_USAGE" >&2
    return 1
  fi
  if [ "$merge_mode" -eq 0 ] && { [ -n "$strategy" ] || [ -n "$keep_branch" ] || [ -n "$assume_yes" ]; }; then
    echo "$BITBUCKET_PR_USAGE" >&2
    return 1
  fi
  if [ -n "$strategy" ]; then
    local valid=false candidate
    for candidate in "${BITBUCKET_MERGE_STRATEGIES[@]}"; do
      [ "$candidate" = "$strategy" ] && valid=true
    done
    if [ "$valid" = false ]; then
      echo -e "${CB_RED}❌ Invalid strategy '$strategy'. Allowed: ${BITBUCKET_MERGE_STRATEGIES[*]}${C_RESET}" >&2
      return 1
    fi
  fi
  if [ "$merge_mode" -eq 1 ]; then
    __mt_bb_merge_pr "$repo" "$pr_number" "$strategy" "$keep_branch" "$assume_yes"
    return $?
  fi
  if [ "$edit_mode" -eq 1 ]; then
    __mt_bb_edit_pr "$repo" "$pr_number" "$set_title" "$set_description"
    return $?
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
