# shellcheck shell=bash
# ------------------------------------------
# Version Control (Git) - Pre-Publication Check
# ------------------------------------------
# ~/.bash.d/20-vcs/62-publish-check.sh

MT_PUBLISH_CHECK_DEFAULT_EMAIL_REGEX='@users\.noreply\.github\.com$'
MT_PUBLISH_CHECK_DEFAULT_AI_REGEX='(co-authored-by:.*(claude|copilot|chatgpt|openai|anthropic|gemini|cursor)|generated with \[?claude|claude-session:)'
MT_PUBLISH_CHECK_GITLEAKS_JQ="$HOME/.bash.d/lib/jq/gitleaks_findings.jq"
MT_PUBLISH_CHECK_ROTATE_HINT="Rotate the secret first; rewriting history does not un-leak it."
MT_PUBLISH_CHECK_FETCH_HINT="Fetch them first: git fetch origin '+refs/*:refs/remotes/origin-all/*'"
MT_PUBLISH_CHECK_EMAIL_HINT="Rewrite with: git filter-repo --mailmap <file>"
MT_PUBLISH_CHECK_AI_HINT="Rewrite with: git filter-repo --message-callback '<python that strips the trailer>'"

#######################################
# Git: List refs on origin (for example refs/pull/N/head) whose commits are
# not reachable from any local ref. Such commits become public with the
# repository but are invisible to the history checks below until fetched.
# Arguments:
#   $1 - Repository root
# Returns:
#   0 if every remote ref is reachable locally (or there is no origin), 1 on
#   unreachable refs or when origin's refs cannot be listed
# Outputs:
#   Header, then one ref per row
#######################################
__mt_publish_check_remote_refs() {
  local repo_root="$1" remote_refs scratch_dir sha ref findings=""
  echo -e "${CB_BLUE}📡 Remote refs not in local history${C_RESET}"
  if ! git -C "$repo_root" remote get-url origin > /dev/null 2>&1; then
    echo -e "${CB_YELLOW}⚠️  No origin remote: only local history was checked.${C_RESET}"
    return 0
  fi
  remote_refs=$(GIT_TERMINAL_PROMPT=0 git -C "$repo_root" ls-remote origin 2> /dev/null) || {
    echo -e "${CB_RED}❌ Could not list origin's refs.${C_RESET}"
    return 1
  }
  scratch_dir=$(mktemp -d) || return 1
  git -C "$repo_root" rev-list --all > "$scratch_dir/reachable"
  while read -r sha ref; do
    [ -z "$sha" ] && continue
    ref="${ref%^\{\}}"
    [ "$(git -C "$repo_root" cat-file -t "$sha" 2> /dev/null)" = "tag" ] && continue
    grep -qxF "$sha" "$scratch_dir/reachable" || findings+="${ref}"$'\n'
  done <<< "$remote_refs"
  rm -rf "$scratch_dir"
  if [ -z "$findings" ]; then
    echo -e "${CB_GREEN}✅ none${C_RESET}"
    return 0
  fi
  printf '%s' "$findings" | __mt_strip_control_chars
  echo -e "${CB_YELLOW}${MT_PUBLISH_CHECK_FETCH_HINT}${C_RESET}"
  return 1
}

#######################################
# Git: Scan the full history of a repository for secrets with gitleaks,
# printing rule, file, short commit and line (never the secret itself).
# Arguments:
#   $1 - Repository root
# Returns:
#   0 if gitleaks ran and found nothing, 1 on findings, a gitleaks failure or a missing gitleaks
# Outputs:
#   Header, then "RuleID<TAB>File<TAB>commit<TAB>line" rows or a status line
#######################################
__mt_publish_check_secrets() {
  local repo_root="$1" scratch_dir report findings rc=0
  echo -e "${CB_BLUE}🔑 Secrets in history${C_RESET}"
  if ! command -v gitleaks > /dev/null 2>&1; then
    echo -e "${CB_YELLOW}⚠️  SKIPPED: install gitleaks to scan history for secrets.${C_RESET}"
    return 1
  fi
  scratch_dir=$(mktemp -d) || return 1
  report="$scratch_dir/gitleaks.json"
  gitleaks detect --source "$repo_root" --log-opts=--all --redact --no-banner --exit-code 0 \
    --report-format json --report-path "$report" > /dev/null 2>&1 || rc=$?
  if [ "$rc" -ne 0 ] || [ ! -f "$report" ]; then
    echo -e "${CB_RED}❌ gitleaks failed to scan the history.${C_RESET}"
    rm -rf "$scratch_dir"
    return 1
  fi
  findings=$(jq -r -f "$MT_PUBLISH_CHECK_GITLEAKS_JQ" "$report" 2> /dev/null) || {
    echo -e "${CB_RED}❌ Could not read the gitleaks report.${C_RESET}"
    rm -rf "$scratch_dir"
    return 1
  }
  rm -rf "$scratch_dir"
  findings=$(__mt_strip_control_chars <<< "$findings")
  if [ -z "$findings" ]; then
    echo -e "${CB_GREEN}✅ none${C_RESET}"
    return 0
  fi
  echo "$findings"
  echo -e "${CB_YELLOW}${MT_PUBLISH_CHECK_ROTATE_HINT}${C_RESET}"
  return 1
}

#######################################
# Git: List author and committer email addresses in the full history that do
# not match the allowed public-email regex.
# Arguments:
#   $1 - Repository root, $2 - Extended regex of acceptable addresses
# Returns:
#   0 if every address is acceptable, 1 otherwise
# Outputs:
#   Header, then "email<TAB>commit count" rows
#######################################
__mt_publish_check_emails() {
  local repo_root="$1" allowed_regex="$2" count email findings=""
  echo -e "${CB_BLUE}📧 Personal email addresses${C_RESET}"
  while read -r count email; do
    [ -z "$email" ] && continue
    grep -qE -- "$allowed_regex" <<< "$email" && continue
    findings+="$(printf '%s\t%s' "$email" "$count")"$'\n'
  done < <({
    git -C "$repo_root" log --all --format='%H %ae'
    git -C "$repo_root" log --all --format='%H %ce'
  } | sort -u | awk '{print $2}' | sort | uniq -c)
  if [ -z "$findings" ]; then
    echo -e "${CB_GREEN}✅ none${C_RESET}"
    return 0
  fi
  printf '%s' "$findings" | __mt_strip_control_chars
  echo -e "${CB_YELLOW}${MT_PUBLISH_CHECK_EMAIL_HINT}${C_RESET}"
  return 1
}

#######################################
# Git: List commits in the full history whose message carries an AI
# attribution (matched case-insensitively against the whole message).
# Arguments:
#   $1 - Repository root, $2 - Extended regex of attribution text
# Returns:
#   0 if none found, 1 on findings or an invalid regex
# Outputs:
#   Header, then "short sha<TAB>subject" rows
#######################################
__mt_publish_check_ai_attribution() {
  local repo_root="$1" ai_regex="$2" findings rc=0
  echo -e "${CB_BLUE}🤖 AI attribution in commit messages${C_RESET}"
  findings=$(git -C "$repo_root" log --all -i -E --grep="$ai_regex" --format='%h%x09%s' 2> /dev/null) || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo -e "${CB_RED}❌ Could not search commit messages; check git.ai_attribution_regex.${C_RESET}"
    return 1
  fi
  if [ -z "$findings" ]; then
    echo -e "${CB_GREEN}✅ none${C_RESET}"
    return 0
  fi
  __mt_strip_control_chars <<< "$findings"
  echo -e "${CB_YELLOW}${MT_PUBLISH_CHECK_AI_HINT}${C_RESET}"
  return 1
}

#######################################
# Git: Make the current repository public on GitHub after confirmation.
# Always addresses origin by URL, never gh's default remote choice.
# Arguments:
#   $1 - Repository root, $2 - "1" to skip the confirmation
# Returns:
#   0 if the repository is now (or already was) public, 1 on failure or refusal
#######################################
__mt_publish_make_public() {
  local repo_root="$1" assume_yes="$2" origin_url repo_info repo_name visibility reply
  origin_url=$(git -C "$repo_root" remote get-url origin 2> /dev/null) || {
    echo -e "${CB_RED}🚨 No origin remote.${C_RESET}"
    return 1
  }
  repo_info=$(gh repo view "$origin_url" --json nameWithOwner,visibility 2> /dev/null) || {
    echo -e "${CB_RED}🚨 Could not read this repository from GitHub (is origin a GitHub repo and gh logged in?).${C_RESET}"
    return 1
  }
  repo_name=$(jq -r '.nameWithOwner // empty' <<< "$repo_info")
  visibility=$(jq -r '.visibility // empty' <<< "$repo_info")
  if [ -z "$repo_name" ]; then
    echo -e "${CB_RED}🚨 Could not read this repository from GitHub.${C_RESET}"
    return 1
  fi
  if [ "${visibility^^}" = "PUBLIC" ]; then
    echo -e "${CB_GREEN}✅ ${repo_name} is already public.${C_RESET}"
    return 0
  fi
  if [ -z "$assume_yes" ]; then
    if [ ! -t 0 ]; then
      echo -e "${CB_RED}🚫 Making a repository public cannot be undone in practice; pass --yes when there is no terminal to confirm on.${C_RESET}"
      return 1
    fi
    read -r -p "Make ${repo_name} public? This cannot be undone in practice. [y/N] " reply
    [[ "$reply" =~ ^[Yy] ]] || {
      echo "Cancelled."
      return 1
    }
  fi
  gh repo edit "$repo_name" --visibility public --accept-visibility-change-consequences || return 1
  echo -e "${CB_GREEN}✅ ${repo_name} is now public.${C_RESET}"
}

#######################################
# Git: Check a repository's whole history before it is made public --
# remote-only refs (such as refs/pull/N/head) missing from local history,
# secrets (gitleaks), personal email addresses in author/committer fields,
# and AI-attribution trailers in commit messages -- and optionally make it
# public. Fail-closed: a missing gitleaks counts as a blocking result.
# Rewriting history is never done here; findings name the tool to use
# (git filter-repo) and rewriting stays a manual step.
# Usage: git-publish-check [--make-public] [--yes]
# Options:
#   --make-public   After clean checks, make the GitHub repository public (asks first)
#   --yes           Skip the --make-public confirmation (required without a terminal)
#   -h, --help      Show this help
# Returns:
#   0 when every check ran and found nothing (and the visibility change, if requested,
#   succeeded), 1 on any finding, a skipped secrets check, bad usage or a gh failure
# Outputs:
#   One section per check; findings as tab-separated rows (secret values are never printed)
# Globals:
#   GIT_PUBLIC_EMAIL_REGEX, GIT_AI_ATTRIBUTION_REGEX
# Example: git-publish-check --make-public
#######################################
git-publish-check() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local make_public="" assume_yes=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --make-public) make_public="1" ;;
      --yes) assume_yes="1" ;;
      *)
        echo "Usage: git-publish-check [--make-public] [--yes]" >&2
        return 1
        ;;
    esac
    shift
  done

  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 Not inside a git repository.${C_RESET}"
    return 1
  fi
  local repo_root exit_code=0
  repo_root=$(git rev-parse --show-toplevel)

  __mt_publish_check_remote_refs "$repo_root" || exit_code=1
  __mt_publish_check_secrets "$repo_root" || exit_code=1
  __mt_publish_check_emails "$repo_root" "${GIT_PUBLIC_EMAIL_REGEX:-$MT_PUBLISH_CHECK_DEFAULT_EMAIL_REGEX}" || exit_code=1
  __mt_publish_check_ai_attribution "$repo_root" "${GIT_AI_ATTRIBUTION_REGEX:-$MT_PUBLISH_CHECK_DEFAULT_AI_REGEX}" || exit_code=1

  if [ -z "$make_public" ]; then
    return "$exit_code"
  fi
  if [ "$exit_code" -ne 0 ]; then
    echo -e "${CB_RED}🚫 Not changing visibility: resolve the findings above first.${C_RESET}"
    return 1
  fi
  __mt_publish_make_public "$repo_root" "$assume_yes"
}
