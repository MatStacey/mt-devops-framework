# shellcheck shell=bash
# ------------------------------------------
# Git: Bulk Repository Updates
# ------------------------------------------
# ~/.bash.d/20-vcs/55-bulk-update.sh

#######################################
# Git: Pull-only update of one repo's local default branch (main/master)
# from its remote, never pushing and never discarding local work. If the
# repo is currently on its default branch, that branch is fast-forwarded
# in place (auto-stashing first only if it has uncommitted changes, then
# restoring them immediately after). If it's on any other branch --
# or in detached HEAD -- the local default-branch ref is updated
# directly via a fetch refspec instead, which git only ever applies as a
# fast-forward and never touches the working tree, so the repo is never
# checked out anywhere else and there's nothing to restore. Either way,
# if the default branch has diverged such that a fast-forward isn't
# possible, the repo is left untouched and reported as DIVERGED rather
# than force-merged or reset.
# Arguments:
#   $1 - Absolute repo path
#   $2 - Path to the results file to append this repo's row to
#######################################
__mt_bulk_update_repo() {
  local repo_path="$1" results_file="$2"
  local vcs_root="${VCS_ROOT:-$HOME/vcs}"
  local rel_path="${repo_path#"$vcs_root"/}"

  local original_branch
  original_branch=$(git -C "$repo_path" branch --show-current 2> /dev/null)
  local branch_display="${original_branch:-(detached)}"

  if ! git -C "$repo_path" remote get-url origin > /dev/null 2>&1; then
    echo "${rel_path}|${branch_display}|NO REMOTE|--|--|--" >> "$results_file"
    return 0
  fi

  if ! git -C "$repo_path" fetch origin --prune --quiet 2> /dev/null; then
    mt-log ERROR "mt-bulk-update: fetch failed for ${repo_path}"
    echo "${rel_path}|${branch_display}|FETCH FAILED|--|--|--" >> "$results_file"
    return 0
  fi

  local default_branch
  default_branch=$(__mt_git_default_branch "$repo_path")
  default_branch="${default_branch:-main}"

  local update_status="UNCHANGED"

  if [ "$original_branch" = "$default_branch" ]; then
    local stashed=false
    if [ -n "$(git -C "$repo_path" status --porcelain 2> /dev/null)" ]; then
      git -C "$repo_path" stash push --include-untracked -m "mt-bulk-update auto-stash" --quiet 2> /dev/null && stashed=true
    fi

    local before_sha after_sha
    before_sha=$(git -C "$repo_path" rev-parse HEAD 2> /dev/null)
    if git -C "$repo_path" merge --ff-only "origin/${default_branch}" --quiet 2> /dev/null; then
      after_sha=$(git -C "$repo_path" rev-parse HEAD 2> /dev/null)
      [ "$before_sha" != "$after_sha" ] && update_status="UPDATED"
    else
      update_status="DIVERGED"
    fi

    if [ "$stashed" = true ] && ! git -C "$repo_path" stash pop --quiet 2> /dev/null; then
      # The fast-forward touched the same lines as the stashed changes.
      # git already keeps the stash entry itself on a failed pop, but
      # leaves conflict markers in the working tree from the attempt --
      # clear those (the stash is the only copy of the edits we need to
      # preserve) and flag it loudly rather than leaving an unattended
      # bulk job's conflict markers sitting in the working tree unseen.
      git -C "$repo_path" reset --hard HEAD --quiet 2> /dev/null
      update_status="STASH CONFLICT"
    fi
  elif git -C "$repo_path" show-ref --verify --quiet "refs/heads/${default_branch}"; then
    local before_sha after_sha
    before_sha=$(git -C "$repo_path" rev-parse "refs/heads/${default_branch}" 2> /dev/null)
    if git -C "$repo_path" fetch origin "${default_branch}:${default_branch}" --quiet 2> /dev/null; then
      after_sha=$(git -C "$repo_path" rev-parse "refs/heads/${default_branch}" 2> /dev/null)
      [ "$before_sha" != "$after_sha" ] && update_status="UPDATED"
    else
      update_status="DIVERGED"
    fi
  else
    if git -C "$repo_path" fetch origin "${default_branch}:${default_branch}" --quiet 2> /dev/null; then
      update_status="CREATED"
    else
      update_status="UNAVAILABLE"
    fi
  fi

  local final_branch
  final_branch=$(git -C "$repo_path" branch --show-current 2> /dev/null)

  local pushed="No" ahead=0 behind=0
  if [ -z "$final_branch" ]; then
    final_branch="(detached)"
    pushed="--"
  else
    git -C "$repo_path" rev-parse --verify --quiet "origin/${final_branch}" > /dev/null 2>&1 && pushed="Yes"

    if git -C "$repo_path" show-ref --verify --quiet "refs/heads/${default_branch}"; then
      local counts
      counts=$(git -C "$repo_path" rev-list --left-right --count "${default_branch}...HEAD" 2> /dev/null)
      behind=$(awk '{print $1}' <<< "$counts")
      ahead=$(awk '{print $2}' <<< "$counts")
    fi
  fi

  echo "${rel_path}|${final_branch}|${update_status}|${pushed}|${ahead:-0}|${behind:-0}" >> "$results_file"
}

#######################################
# Git: Render mt-bulk-update's collected per-repo results into the final
# colored summary table
# Arguments:
#   $1 - Path to the pipe-delimited results file
#######################################
__mt_bulk_update_render_table() {
  local results_file="$1"
  local awk_script="$HOME/.bash.d/lib/awk/bulk_update_table.awk"
  sort -t'|' -k1,1 "$results_file" | awk -F'|' -v blue="$CB_BLUE" -v green="$CB_GREEN" -v yellow="$CB_YELLOW" -v red="$CB_RED" -v dim="$C_DIM" -v rst="$C_RESET" -v cyan="$CB_CYAN" -f "$awk_script"
}

#######################################
# Git: Walk VCS_ROOT, apply the given filters, and pull-update every
# matching repo's default branch -- the worker mt-bulk-update runs
# either inline or, via __mt_bg_run, as a background job.
# Arguments:
#   $1 - Scope filter (work|personal|"")
#   $2 - Provider filter ("" or exact name)
#   $3 - Workspace filter ("" or exact name)
#   $4 - Project filter ("" or exact repo folder name)
# Globals:
#   VCS_ROOT
#######################################
__mt_bulk_update_run() {
  local scope="$1" provider="$2" workspace="$3" project="$4"
  local vcs_root="${VCS_ROOT:-$HOME/vcs}"

  if [ ! -d "$vcs_root" ]; then
    echo -e "${CB_RED}🚨 Error: VCS root directory '${vcs_root}' not found.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}🔄 Bulk-updating repositories under ${vcs_root} (pull-only, never pushes)...${C_RESET}"

  local results_file
  results_file=$(mktemp)

  local repo_path
  local total=0 matched=0
  while IFS= read -r repo_path; do
    [ -z "$repo_path" ] && continue
    ((++total))
    __mt_vcs_matches_filter "$repo_path" "$scope" "$provider" "$workspace" "$project" || continue
    ((++matched))
    echo -e "${C_DIM}  Checking ${repo_path#"$vcs_root"/}...${C_RESET}"
    __mt_bulk_update_repo "$repo_path" "$results_file"
  done < <(__mt_vcs_find_repos "$vcs_root")

  if [ "$matched" -eq 0 ]; then
    echo -e "${CB_YELLOW}⚠️  No repositories matched the given filters (${total} scanned).${C_RESET}"
    rm -f "$results_file"
    return 0
  fi

  echo
  __mt_bulk_update_render_table "$results_file"
  rm -f "$results_file"
}

#######################################
# Git: Bulk-update every local repository under VCS_ROOT -- fetches each
# repo's remote and fast-forwards its local main/master branch to match.
# Pull-only: this never pushes anything, to any branch, ever. A repo
# sitting on a local branch other than its default is left exactly
# where it is -- its uncommitted changes are never touched and it's
# never checked out anywhere else -- and a repo whose default branch has
# diverged from its remote is skipped and reported rather than
# force-merged. Prints a summary table of every repo checked: its
# current branch, whether its default branch was updated, whether that
# current branch has ever been pushed to its remote, and how far ahead/
# behind it is of the (now-updated) default branch.
# Usage: mt-bulk-update [-s work|personal] [-p provider] [-w workspace]
#                       [-pr project] [-b|--bg|--background]
# Options:
#   -s, --scope <work|personal>   Only update repos under this scope
#   -p, --provider <name>         Only update repos under this provider (work scope only, e.g. bitbucket)
#   -w, --workspace <name>        Only update repos under this workspace (work scope only, e.g. rentokilinitial)
#   -pr, --project <name>         Only update repos under this project (work scope; e.g. cloudconnect groups many repos) or this exact repo (personal scope)
#   -b, --bg, --background        Run as a background job -- see 'mt-jobs' to monitor/view its log
#   -h, --help                    Show this help
# Globals:
#   VCS_ROOT
#######################################
mt-bulk-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local scope="" provider="" workspace="" project="" run_bg=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -s | --scope)
        scope="${2,,}"
        if [[ "$scope" != "work" && "$scope" != "personal" ]]; then
          echo "mt-bulk-update: --scope must be 'work' or 'personal'" >&2
          return 1
        fi
        shift 2
        ;;
      -p | --provider)
        provider="$2"
        shift 2
        ;;
      -w | --workspace)
        workspace="$2"
        shift 2
        ;;
      -pr | --project)
        project="$2"
        shift 2
        ;;
      -b | --bg | --background)
        run_bg=true
        shift
        ;;
      *)
        echo "Usage: mt-bulk-update [-s work|personal] [-p provider] [-w workspace] [-pr project] [-b|--background]" >&2
        return 1
        ;;
    esac
  done

  if [ "$run_bg" = true ]; then
    local log_out
    log_out="${LOG_DIR:-$HOME/.bash.d/data/logs}/bulk_update_$(date +%s).log"
    local cmd_str="__mt_bulk_update_run \"$scope\" \"$provider\" \"$workspace\" \"$project\""
    __mt_bg_run "mt-bulk-update" "$log_out" "$cmd_str"
  else
    __mt_bulk_update_run "$scope" "$provider" "$workspace" "$project"
  fi
}
