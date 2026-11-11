# shellcheck shell=bash
# ------------------------------------------
# Version Control (Git) - Retired-Branch Audit
# ------------------------------------------
# ~/.bash.d/20-vcs/61-branch-audit.sh

MT_BRANCH_AUDIT_DEFAULT_REGEX='^(master|develop|development|dev|test|testing|qa|uat|staging|stage|preprod|pre-prod|prod|production|release)$'
MT_BRANCH_AUDIT_NO_BRANCH="-"
MT_BRANCH_AUDIT_FETCH_REFSPEC="+refs/heads/*:refs/remotes/origin/*"
MT_BRANCH_AUDIT_REGEX_INVALID_STATUS=2

#######################################
# Git: Audit one repository's retired-name branches against its live
# default branch. The branch list comes from the live remote, and the fetch
# covers every branch whatever the clone's refspec is. Read-only apart from
# the optional fetch.
# Arguments:
#   $1 - Repository path
#   $2 - Path shown in the output (relative to the VCS root)
#   $3 - Extended regex of branch names to audit
#   $4 - "fetch" to run 'git fetch --prune' first, anything else to skip it
# Returns:
#   0 if the repository was audited or skipped (no origin), 1 if an ERROR row was printed
#   (including shallow clones, whose commit counts are unreliable)
# Outputs:
#   Tab-separated audit rows on stdout; skips and stale-origin/HEAD warnings on stderr
#######################################
__mt_branch_audit_repo() {
  local repo_path="$1" display_path="$2" branch_regex="$3" fetch_mode="$4"

  if ! git -C "$repo_path" remote get-url origin > /dev/null 2>&1; then
    echo -e "${CB_YELLOW}⚠️  ${display_path}: no origin remote, skipped.${C_RESET}" >&2
    return 0
  fi
  if [ "$(git -C "$repo_path" rev-parse --is-shallow-repository 2> /dev/null)" = "true" ]; then
    printf '%s\t-\t-\t-\t-\tERROR (shallow clone)\n' "$display_path"
    return 1
  fi
  if [ "$fetch_mode" = "fetch" ] && ! GIT_TERMINAL_PROMPT=0 git -C "$repo_path" fetch --prune --quiet origin "$MT_BRANCH_AUDIT_FETCH_REFSPEC" 2> /dev/null; then
    printf '%s\t-\t-\t-\t-\tERROR (fetch failed)\n' "$display_path"
    return 1
  fi

  local remote_refs default_branch
  remote_refs=$(GIT_TERMINAL_PROMPT=0 git -C "$repo_path" ls-remote --symref origin HEAD 'refs/heads/*' 2> /dev/null)
  default_branch=$(sed -n 's#^ref: refs/heads/\([^[:space:]]*\)[[:space:]]HEAD$#\1#p' <<< "$remote_refs")
  if [ -z "$default_branch" ]; then
    printf '%s\t-\t-\t-\t-\tERROR (ls-remote failed)\n' "$display_path"
    return 1
  fi
  if ! git -C "$repo_path" rev-parse --verify --quiet "refs/remotes/origin/${default_branch}" > /dev/null; then
    printf '%s\t%s\t-\t-\t-\tERROR (default branch not fetched)\n' "$display_path" "$default_branch"
    return 1
  fi

  local local_head
  local_head=$(git -C "$repo_path" symbolic-ref --short refs/remotes/origin/HEAD 2> /dev/null)
  local_head="${local_head#origin/}"
  if [ -n "$local_head" ] && [ "$local_head" != "$default_branch" ]; then
    echo -e "${CB_YELLOW}⚠️  ${display_path}: local origin/HEAD is ${local_head} but the remote default is ${default_branch} (git remote set-head origin -a)${C_RESET}" >&2
  fi

  local branch unique last_commit_date found=0 exit_code=0
  while IFS= read -r branch; do
    [ "$branch" = "HEAD" ] && continue
    [ "$branch" = "$default_branch" ] && continue
    grep -qE -- "$branch_regex" <<< "$branch" || continue
    found=1
    if ! git -C "$repo_path" rev-parse --verify --quiet "refs/remotes/origin/${branch}" > /dev/null; then
      printf '%s\t%s\t%s\t-\t-\tERROR (not fetched)\n' "$display_path" "$default_branch" "$branch"
      exit_code=1
      continue
    fi
    unique=$(git -C "$repo_path" rev-list --count "refs/remotes/origin/${default_branch}..refs/remotes/origin/${branch}")
    last_commit_date=$(git -C "$repo_path" log -1 --format=%cs "refs/remotes/origin/${branch}")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$display_path" "$default_branch" "$branch" "$unique" "$last_commit_date" \
      "$([ "$unique" -eq 0 ] && echo SAFE || echo UNSAFE)"
  done < <(sed -n 's#^[0-9a-f]\{40,64\}[[:space:]]refs/heads/\(.*\)$#\1#p' <<< "$remote_refs")

  if [ "$found" -eq 0 ]; then
    printf '%s\t%s\t%s\t0\t%s\tCLEAN\n' "$display_path" "$default_branch" "$MT_BRANCH_AUDIT_NO_BRANCH" "$MT_BRANCH_AUDIT_NO_BRANCH"
  fi
  return "$exit_code"
}

#######################################
# Git: Audit branches with retired names (master, develop, qa, ...) across
# every local repo matching mt-repos' scope/provider/workspace/project
# filters, before they are deleted. For each repo it asks the remote for the
# live default branch ('git ls-remote --symref'), then counts the commits on
# each matching branch that the default branch cannot reach. Never deletes or
# changes anything (apart from the 'git fetch --prune' of origin, which
# --no-fetch skips). Shallow clones are reported as errors. UNSAFE means the
# branch has commits unreachable from the default branch; a squash- or
# rebase-merged branch also shows as UNSAFE even though its changes landed, so
# treat UNSAFE as "review before deleting", not as proof of unmerged work.
# Usage: mt-branch-audit [-s work|personal] [-p provider] [-w workspace] [-pr project] [--pattern <regex>] [--no-fetch]
# Options:
#   -s, --scope <work|personal>   Only audit repos under this scope
#   -p, --provider <name>         Only audit repos under this provider (work scope only)
#   -w, --workspace <name>        Only audit repos under this workspace (work scope only)
#   -pr, --project <name>         Only audit repos under this project (work scope) or this exact repo (personal scope)
#   --pattern <regex>             Extended regex of branch names to audit (default: git.retired_branch_regex)
#   --no-fetch                    Use the remote-tracking refs as they are; do not fetch first
#   -h, --help                    Show this help
# Returns:
#   0 when every repo was audited, 1 on bad usage, a missing VCS root, an invalid
#   regex or any ERROR row
# Outputs:
#   "repo<TAB>default<TAB>branch<TAB>unique commits<TAB>last commit date<TAB>SAFE|UNSAFE" per branch;
#   "repo<TAB>default<TAB>-<TAB>0<TAB>-<TAB>CLEAN" when nothing matches;
#   "repo<TAB>default or -<TAB>branch or -<TAB>-<TAB>-<TAB>ERROR (reason)" when a repo or branch could not
#   be audited. Reasons: fetch failed, ls-remote failed, shallow clone, default branch not fetched,
#   not fetched (--no-fetch and a live branch with no local remote-tracking ref)
# Globals:
#   VCS_ROOT, GIT_RETIRED_BRANCH_REGEX
# Example: mt-branch-audit -s work -w platform --pattern '^(develop|qa)$'
#######################################
mt-branch-audit() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local usage="Usage: mt-branch-audit [-s work|personal] [-p provider] [-w workspace] [-pr project] [--pattern <regex>] [--no-fetch]"
  local scope="" provider="" workspace="" project="" fetch_mode="fetch"
  local branch_regex="${GIT_RETIRED_BRANCH_REGEX:-$MT_BRANCH_AUDIT_DEFAULT_REGEX}"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s | --scope)
        scope="${2,,}"
        if [[ "$scope" != "work" && "$scope" != "personal" ]]; then
          echo "mt-branch-audit: --scope must be 'work' or 'personal'" >&2
          return 1
        fi
        shift 2 || shift
        ;;
      -p | --provider)
        provider="${2:-}"
        shift 2 || shift
        ;;
      -w | --workspace)
        workspace="${2:-}"
        shift 2 || shift
        ;;
      -pr | --project)
        project="${2:-}"
        shift 2 || shift
        ;;
      --pattern)
        branch_regex="${2:-}"
        shift 2 || shift
        ;;
      --no-fetch)
        fetch_mode="skip"
        shift
        ;;
      *)
        echo "$usage" >&2
        return 1
        ;;
    esac
  done

  local regex_status=0
  grep -qE -- "$branch_regex" <<< "" 2> /dev/null || regex_status=$?
  if [ -z "$branch_regex" ] || [ "$regex_status" -eq "$MT_BRANCH_AUDIT_REGEX_INVALID_STATUS" ]; then
    echo -e "${CB_RED}❌ Invalid --pattern regex: '${branch_regex}'${C_RESET}" >&2
    return 1
  fi

  local search_dir="${VCS_ROOT:-$HOME/vcs}"
  if [ ! -d "$search_dir" ]; then
    echo -e "${CB_RED}🚨 Error: VCS root directory '$search_dir' not found.${C_RESET}" >&2
    return 1
  fi

  local repo_path matched=0 exit_code=0
  while IFS= read -r repo_path; do
    [ -z "$repo_path" ] && continue
    __mt_vcs_matches_filter "$repo_path" "$scope" "$provider" "$workspace" "$project" || continue
    ((++matched))
    __mt_branch_audit_repo "$repo_path" "${repo_path#"$search_dir"/}" "$branch_regex" "$fetch_mode" || exit_code=1
  done < <(__mt_vcs_find_repos "$search_dir")

  if [ "$matched" -eq 0 ]; then
    echo -e "${CB_YELLOW}⚠️  No repositories matched the given filters.${C_RESET}"
  fi
  return "$exit_code"
}
