# shellcheck shell=bash
# ------------------------------------------
# Version Control (Git) - Profile Synchronization
# ------------------------------------------
# ~/.bash.d/20-vcs/52-git-sync.sh

#######################################
# Git: Clone and initialize the sync repository directory, or reconcile
# an already-existing checkout's origin to match SYNC_REPO_URL.
# The origin reconciliation always runs, even when repo_dir was already
# a git checkout -- e.g. a collaborator who manually cloned the upstream
# repo before ever running mt-become-collaborator, or whose fork URL
# changed since. Without this, origin silently keeps pointing at
# whatever it was first cloned from forever, and every future
# 'mt-push-update' push fails with a 403 against the wrong remote no
# matter how correctly SYNC_REPO_URL is configured.
#
# If repo_dir already has files in it but no .git (e.g. an older manual
# setup that extracted a release zip instead of cloning), a direct 'git
# clone' into it fails -- not because the remote is empty, but because
# git refuses to clone into a non-empty directory. Cloning into a
# scratch directory and moving just the .git history into place (then
# checking out HEAD on top of whatever's already there) connects that
# directory to real history instead of the old fallback, which
# misdiagnosed this exact case as "an empty remote" and papered over it
# with a brand-new orphaned local repo disconnected from the actual
# remote's history entirely.
# Arguments:
#   $1 - Target repository directory path
#   $2 - Remote origin URL (SYNC_REPO_URL)
#######################################
__git_sync_init_repo() {
  local repo_dir="$1" remote_url="$2"

  if [ ! -d "$repo_dir/.git" ]; then
    echo "📥 Local sync directory not found or not initialized."
    mkdir -p "$repo_dir"

    if [ -n "$(ls -A "$repo_dir" 2> /dev/null)" ]; then
      echo "📁 Existing files found in ${repo_dir} -- connecting them to the real remote history."
      local tmp_clone
      tmp_clone=$(mktemp -d)
      if git clone "$remote_url" "$tmp_clone" 2> /dev/null; then
        mv "$tmp_clone/.git" "$repo_dir/.git"
        rm -rf "$tmp_clone"
        (cd "$repo_dir" && git checkout -f HEAD > /dev/null 2>&1)
      else
        rm -rf "$tmp_clone"
        echo "⚠️ Clone failed (likely an empty or unreachable remote). Initializing local repository..."
        git -C "$repo_dir" init
        git -C "$repo_dir" remote add origin "$remote_url"
      fi
    elif ! git clone "$remote_url" "$repo_dir" 2> /dev/null; then
      echo "⚠️ Clone failed (likely an empty remote). Initializing local repository..."
      git -C "$repo_dir" init
      git -C "$repo_dir" remote add origin "$remote_url"
    fi
  fi

  if [ "$(git -C "$repo_dir" remote get-url origin 2> /dev/null)" != "$remote_url" ]; then
    git -C "$repo_dir" remote set-url origin "$remote_url" 2> /dev/null || git -C "$repo_dir" remote add origin "$remote_url"
  fi
}

#######################################
# Git: Append any pattern from a template ignore-file that a target
# ignore-file doesn't already contain, verbatim and in template order.
# Creates the target if missing. Lets a deployed .syncignore or a synced
# repo's .gitignore pick up new default patterns added to their .tpl on
# every sync run, instead of staying frozen at whatever they first
# scaffolded from -- a plain first-run 'cp' only ever helps a brand-new
# user, never an existing one whose file predates the template change.
# Arguments:
#   $1 - Path to the template file (source of truth for default patterns)
#   $2 - Path to the target ignore-style file to reconcile
#######################################
__mt_reconcile_ignore_patterns() {
  local template="$1" target="$2"
  [ -f "$template" ] || return 0
  touch "$target"

  local pattern
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue
    grep -qxF "$pattern" "$target" || echo "$pattern" >> "$target"
  done < "$template"
}

#######################################
# Git: Report whether ~/.bash.d is already a symlink resolving into the
# sync repo's own .bash.d subtree -- i.e. whether this machine has been
# cut over via mt-migrate-symlink, so there's only one physical copy of
# the framework left and any deployed<->repo copy step would just be a
# (harmless but pointless, and with --delete active, needlessly risky)
# self-copy. Used to guard those copy steps in __git_sync_copy_files,
# mt-get-update, and mt-restore.
# Arguments:
#   $1 - Sync repo directory path (DOTFILES_DIR/SYNC_REPO_DIR)
# Returns:
#   0 if migrated (symlinked), 1 otherwise
#######################################
__mt_bashd_is_symlinked_into_repo() {
  local repo_dir="$1"
  [ -L "$HOME/.bash.d" ] || return 1
  [ "$(readlink -f "$HOME/.bash.d" 2> /dev/null)" = "$(readlink -f "$repo_dir/.bash.d" 2> /dev/null)" ]
}

#######################################
# Git: Synchronize active bash configuration files into dotfiles repository
# Arguments:
#   $1 - Target repository directory path
#######################################
__git_sync_copy_files() {
  local repo_dir="$1"

  mkdir -p "$repo_dir/.bash.d"

  if __mt_bashd_is_symlinked_into_repo "$repo_dir"; then
    echo -e "${C_DIM}↪️  ~/.bash.d is already a symlink into ${repo_dir}/.bash.d -- skipping the copy, they're the same directory.${C_RESET}"
  else
    local syncignore="$CONFIG_DIR/.syncignore"
    local syncignore_tpl="$HOME/.bash.d/lib/templates/syncignore.tpl"
    __mt_reconcile_ignore_patterns "$syncignore_tpl" "$syncignore"

    # SECURITY FIX: One-way sync ONLY. Local Home is the source of truth during a push.
    # No -u/--update: git checkout/pull (run on repo_dir moments earlier by
    # __mt_push_update_reconcile_branch, and always on a collaborator's first-ever
    # run via __git_sync_init_repo's fresh clone) stamps every file it writes with
    # the current time, which is virtually always newer than an edit saved earlier
    # in $HOME/.bash.d -- -u would then skip copying the real edit entirely,
    # silently discarding it before git ever sees a diff.
    rsync -a --delete --delete-excluded --exclude-from="$syncignore" "$HOME/.bash.d/" "$repo_dir/.bash.d/"
  fi

  if [ -f "$HOME/.bashrc" ]; then
    cp -f "$HOME/.bashrc" "$repo_dir/.bashrc"
  fi

  # No loop here for install.sh, README.md, .gitignore, .dockerignore,
  # Dockerfile, .gitleaks.toml, .github/, or .devcontainer/ -- there used
  # to be one, copying each from $HOME/.bash.d/<name> or (falling back)
  # loose $HOME/<name> into the repo. Removed entirely: none of these
  # repo-root items are ever actually deployed to either candidate path
  # by install.sh (it only ever populates $HOME/.bash.d/ from the repo's
  # own .bash.d/ subtree, and none of the eight live inside that
  # subtree), so both candidates were always either empty or -- worse --
  # populated by a stray/stale leftover from something unrelated (a
  # manual extraction, an old backup, ...) that got blindly trusted with
  # no diff or staleness check. A stray ~/install.sh confirmed this
  # happening for real, twice, silently reverting a genuinely-shipped
  # fix each time. README.md is already regenerated separately just
  # below (AI summary step) and .gitignore already has its own safe
  # reconciliation (see __mt_reconcile_ignore_patterns above) -- every
  # repo-root file or directory should be edited directly in the repo
  # checkout and shipped via a manual git flow (branch/commit/push/PR),
  # never through mt-push-update.

  (
    cd "$repo_dir" || exit 1

    __mt_reconcile_ignore_patterns "$HOME/.bash.d/lib/templates/gitignore.tpl" .gitignore

    git rm -r -q --cached . > /dev/null 2>&1
    git add --all
  )
}

#######################################
# System: Run the local ShellCheck gate used by mt-push-update -s
# 40-private/ and lib/private/ are excluded from the scan: they're
# local-only user content that never gets synced into the framework
# repo (see __git_sync_copy_files), so a lint issue in one of them would
# otherwise block every future push regardless of relevance to the
# actual framework code being shipped.
# Returns:
#   0 if ShellCheck passed or is unavailable, 1 if it found errors
#######################################
__mt_push_update_run_shellcheck() {
  echo -e "${CB_BLUE}🔍 Running local ShellCheck...${C_RESET}"
  if ! command -v shellcheck > /dev/null 2>&1; then
    echo -e "${CB_YELLOW}⚠️ ShellCheck is not installed locally. Skipping...${C_RESET}"
    return 0
  fi
  if ! find -L "$HOME/.bash.d" -type f -name "*.sh" -not -path "*/data/cache/*" -not -path "*/40-private/*" -not -path "*/lib/private/*" -print0 | xargs -0 shellcheck -e SC1090,SC1091,SC2119,SC2120,SC2207,SC2015,SC2317,SC2016,SC2129,SC2028,SC1003; then
    echo -e "${CB_RED}🚨 ShellCheck failed! Please fix the errors above before syncing.${C_RESET}"
    return 1
  fi
  echo -e "${CB_GREEN}✅ ShellCheck passed!${C_RESET}"
}

#######################################
# System: Create a pre-sync zip backup of .bash.d and .bashrc. Excludes
# config.yaml and any *_token.sh file so a plaintext copy of them never
# ends up sitting in an unencrypted zip under $BACKUP_DIR -- real secrets
# (API keys) already live entirely outside .bash.d in
# ~/secrets/secrets.sh and are never touched by this backup at all.
# Globals (read):
#   BACKUP_DIR
# Returns:
#   0 on success, 1 if the backup file was not created
#######################################
__mt_push_update_backup() {
  echo -e "${CB_BLUE}📦 Creating pre-sync backup of framework...${C_RESET}"
  local dest="${BACKUP_DIR:-~/backups}/framework-pre-sync"
  mkdir -p "$dest"
  local timestamp
  timestamp=$(date +"%Y%m%d_%H%M%S")
  local backup_file="${dest}/mt_framework_backup_${timestamp}.zip"

  (
    cd "$HOME" || exit 1
    zip -q -r "$backup_file" .bash.d .bashrc -x ".bash.d/.git/*" -x ".bash.d/data/cache/*" -x ".bash.d/node_modules/*" -x ".bash.d/**/__pycache__/*" -x ".bash.d/.terraform/*" -x ".bash.d/venv/*" -x ".bash.d/.venv/*" -x ".bash.d/config/config.yaml" -x ".bash.d/config/*_token.sh"
  )

  if [ -f "$backup_file" ]; then
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    echo -e "${CB_GREEN}✅ Pre-sync backup saved to ${backup_file} (${file_size})${C_RESET}"
  else
    echo -e "${CB_RED}🚨 Pre-sync backup failed. Aborting sync to prevent data loss.${C_RESET}"
    return 1
  fi
}

#######################################
# System: Pop the auto-stash __mt_push_update_reconcile_branch creates
# before resetting/merging against upstream, warning loudly instead of
# silently swallowing a failed pop. A pop can fail (typically a conflict
# between the stashed changes and the branch state just fetched), and
# discarding its exit status used to leave local changes sitting in the
# stash list with zero indication anything went wrong -- from the
# user's side that reads as "my changes just vanished", not as a
# conflict to resolve.
# Globals (read):
#   repo_dir
#######################################
__mt_push_update_restore_stash() {
  if ! git stash pop > /dev/null 2>&1; then
    echo -e "${CB_RED}🚨 Could not automatically reapply your stashed local changes (likely a conflict with the branch state just fetched).${C_RESET}"
    echo -e "${CB_YELLOW}Nothing was lost -- they're safe in the stash. Run 'git stash list' and 'git stash pop' manually in ${repo_dir} to recover them.${C_RESET}"
  fi
}

#######################################
# System: Best-effort push of the just-reconciled default branch to
# origin, so a collaborator's fork doesn't silently drift further and
# further behind real upstream on GitHub (forks are never auto-synced).
# Without this, mt-doctor's "N commits not yet pushed to origin/main"
# warning grows forever even though nothing is actually wrong -- local
# main only ever gets here by resetting onto true upstream, so this is
# always a plain fast-forward from origin's perspective. Never force,
# and never fatal: if it fails (no push access, or origin has genuinely
# diverged some other way), it just warns and lets the caller continue.
# Globals (read, set by mt-push-update):
#   repo_dir
# Arguments:
#   $1 - Branch name to push (the default branch)
#######################################
__mt_push_update_sync_origin_default_branch() {
  local branch="$1"
  git push origin "$branch" > /dev/null 2>&1 ||
    echo -e "${CB_YELLOW}⚠️  Could not push ${branch} to origin (non-fatal -- your fork's ${branch} may just be behind).${C_RESET}"
}

#######################################
# System: Reconcile the sync repo's local branch with the true upstream
# repository (UPSTREAM_REPO_PATH) before copying files -- deliberately
# NOT with 'origin', since for a collaborator origin is their own fork,
# and GitHub never auto-syncs a fork with the repo it was forked from.
# Reconciling against origin/main there just mirrors however stale the
# fork happens to be, so the collaborator's local default branch can
# silently drift arbitrarily far behind real upstream -- every future
# 'mt-push-update' run then rsyncs their fully-current ~/.bash.d
# (updated independently via 'mt-get-update', which always pulls the
# real latest release) over that stale checkout, and the entire gap
# gets staged and raised as a PR alongside whatever the collaborator
# actually meant to change. Fetching UPSTREAM_REPO_PATH directly instead
# closes that gap for maintainer and collaborator alike (for a
# maintainer, origin already IS upstream, so this is a harmless
# same-content re-fetch).
# Runs inside the caller's `( cd "$repo_dir"; ... )` subshell, so `cd`/`exit`
# here never affect the interactive shell.
# Globals (read, set by mt-push-update):
#   repo_dir
# Globals:
#   UPSTREAM_REPO_PATH
#######################################
__mt_push_update_reconcile_branch() {
  cd "$repo_dir" || exit 1

  local default_branch
  default_branch=$(__mt_git_default_branch)
  default_branch="${default_branch:-main}"

  local upstream_url="https://github.com/${UPSTREAM_REPO_PATH}.git"

  local current_branch
  current_branch=$(git branch --show-current)

  if [ "$current_branch" != "$default_branch" ] && command -v gh > /dev/null 2>&1; then
    local pr_state
    pr_state=$(gh pr view "$current_branch" --json state -q .state 2> /dev/null || echo "NONE")
    if [ "$pr_state" = "MERGED" ] || [ "$pr_state" = "CLOSED" ]; then
      echo -e "${CB_YELLOW}⚠️  Current branch '$current_branch' has a $pr_state PR and is considered dead.${C_RESET}"
      read -r -p "Delete '$current_branch' locally and checkout a new branch from $default_branch? [Y/n] " -n 1 < /dev/tty || REPLY="n"
      echo
      if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] || [ -z "$REPLY" ]; then
        read -r -p "Delete the remote branch 'origin/$current_branch' as well? [Y/n] " -n 1 < /dev/tty || REPLY="n"
        echo
        if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] || [ -z "$REPLY" ]; then
          echo -e "${CB_BLUE}🗑️  Deleting remote branch...${C_RESET}"
          git push origin --delete "$current_branch" 2> /dev/null || echo -e "${CB_YELLOW}⚠️  Remote branch already deleted or unreachable.${C_RESET}"
        fi
        local stashed=false
        if ! git diff --quiet || ! git diff --staged --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
          git stash push --include-untracked -m "mt-push auto stash" > /dev/null 2>&1
          stashed=true
        fi
        if git checkout "$default_branch" > /dev/null 2>&1; then
          git fetch "$upstream_url" "$default_branch" > /dev/null 2>&1 && git reset --hard FETCH_HEAD > /dev/null 2>&1
          __mt_push_update_sync_origin_default_branch "$default_branch"
          git branch -D "$current_branch" > /dev/null 2>&1
          current_branch="$default_branch"
        else
          echo -e "${CB_RED}🚨 Failed to checkout $default_branch. Please commit or stash changes manually.${C_RESET}"
          [ "$stashed" = true ] && __mt_push_update_restore_stash
          exit 1
        fi
        [ "$stashed" = true ] && __mt_push_update_restore_stash
      else
        echo -e "${CB_RED}🚨 Aborted profile sync.${C_RESET}"
        exit 1
      fi
    fi
  fi

  if [ "$current_branch" = "$default_branch" ]; then
    git checkout "$default_branch" > /dev/null 2>&1 || git checkout -b "$default_branch" > /dev/null 2>&1

    local stashed=false
    if ! git diff --quiet || ! git diff --staged --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
      git stash push --include-untracked -m "mt-push auto stash" > /dev/null 2>&1
      stashed=true
    fi
    git fetch "$upstream_url" "$default_branch" > /dev/null 2>&1 && git reset --hard FETCH_HEAD > /dev/null 2>&1
    __mt_push_update_sync_origin_default_branch "$default_branch"
    [ "$stashed" = true ] && __mt_push_update_restore_stash
  else
    echo -e "${CB_BLUE}🔄 Ensuring ${current_branch} is up to date with ${UPSTREAM_REPO_PATH}/${default_branch}...${C_RESET}"
    git fetch "$upstream_url" "$default_branch" > /dev/null 2>&1
    if ! git merge FETCH_HEAD --no-edit > /dev/null 2>&1; then
      echo -e "${CB_RED}💥 Merge conflict detected with ${UPSTREAM_REPO_PATH}/${default_branch}!${C_RESET}"
      echo -e "${CB_YELLOW}The sync automation has paused to protect your code. Please resolve conflicts manually in $repo_dir, commit, and run mt-push-update again.${C_RESET}"
      git merge --abort > /dev/null 2>&1
      exit 1
    fi
  fi
  return 0
}

#######################################
# System: Delete local (and optionally remote) branches merged into the default branch
# Runs inside the same subshell as __mt_push_update_commit_and_raise_pr.
# Globals (read, set by mt-push-update):
#   prompt_remote
#######################################
__mt_push_update_cleanup_merged_branches() {
  echo -e "${CB_BLUE}🧹 Pruning remote tracking references and deleting merged local branches...${C_RESET}"
  git fetch --prune > /dev/null 2>&1
  local main_b="main"
  git show-ref --verify --quiet refs/heads/master && main_b="master"

  local merged_b
  merged_b=$(git branch --merged "$main_b" | grep -v -E "^[*+]|\\b(main|master|dev|developer)\\b" | tr -d ' ' || true)

  if [ -z "$merged_b" ]; then
    echo -e "${C_DIM}No stale merged local branches found to delete.${C_RESET}"
    return 0
  fi

  echo "$merged_b" | xargs -r git branch -d
  echo -e "${CB_GREEN}✅ Merged local branches cleaned up successfully!${C_RESET}"

  if [ "$prompt_remote" = true ]; then
    echo -e "\n${CB_YELLOW}🔍 Checking corresponding remote branches on origin...${C_RESET}"
    for b_item in $merged_b; do
      if git ls-remote --exit-code --heads origin "$b_item" > /dev/null 2>&1; then
        read -r -p "Delete remote branch 'origin/$b_item'? [y/N] " -n 1 -r < /dev/tty
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          git push origin --delete "$b_item"
        fi
      fi
    done
  fi
}

#######################################
# System: Format, commit, and raise a PR for the synced dotfiles repo
# Runs inside the caller's `( cd "$repo_dir"; ... )` subshell, so `cd`/`exit`
# here never affect the interactive shell.
# Globals (read, set by mt-push-update):
#   repo_dir, skip_ai, user_msg, issue_num, delete_merged, auto_merge
#######################################
__mt_push_update_commit_and_raise_pr() {
  cd "$repo_dir" || exit 1

  if command -v shfmt > /dev/null 2>&1; then
    echo "🧹 Running Google Style code formatting before profile sync..."
    shfmt -i 2 -ci -sr -w . > /dev/null 2>&1 || true
  fi

  __git_sync_generate_commands_md "$repo_dir"

  if [ "$skip_ai" = true ]; then
    echo -e "${C_DIM}⏩ Skipping AI README summarization (-m active)...${C_RESET}"
  else
    __git_sync_ai_update_readme_summary "$repo_dir"
    if [ $? -eq 100 ]; then
      echo -e "${CB_YELLOW}⚠️  AI unavailable (quota/rate limit exhausted) -- continuing sync without a README summary this run.${C_RESET}"
    fi
  fi

  git add --all

  if git diff --staged --quiet; then
    echo "✅ Configurations are already up to date. No changes to commit."
    return 0
  fi

  local current_branch
  current_branch=$(git branch --show-current)
  local default_branch
  default_branch=$(__mt_git_default_branch)
  default_branch="${default_branch:-main}"

  local branch_name="$current_branch"
  local pr_title="$user_msg"

  if [ "$current_branch" = "$default_branch" ]; then
    if [ -n "$user_msg" ]; then
      local type
      type=$(echo "$user_msg" | grep -oE '^[a-zA-Z]+' || echo "chore")
      local slug
      slug=$(echo "$user_msg" | sed -E 's/^[a-zA-Z]+(\([^)]+\))?:[[:space:]]*//' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-|-$//g' | cut -c1-40)
      [ -z "$slug" ] && slug="update-$(date +%s)"
      branch_name="${type}/${slug}"
    else
      branch_name="chore/automated-sync-$(date +%Y%m%d-%H%M%S)"
      pr_title="chore: automated profile synchronization"
    fi

    # Similarly-worded commit messages (e.g. repeated AI-quota-fallback
    # README summaries) can generate the same slug run after run. GitHub
    # remembers a branch NAME's PR history even after the branch itself is
    # deleted (e.g. via --delete-branch on merge), so checking only
    # whether the ref still exists isn't enough -- a name whose ref is
    # long gone can still resolve to a merged/closed PR and make
    # git-raise-pr treat it as a dead branch and abort. Disambiguating up
    # front avoids that abort entirely instead of requiring manual
    # recovery after the fact.
    if git show-ref --verify --quiet "refs/heads/$branch_name" ||
      git ls-remote --exit-code --heads origin "$branch_name" > /dev/null 2>&1 ||
      { command -v gh > /dev/null 2>&1 && [ -n "$(gh pr view "$branch_name" --json state -q .state 2> /dev/null)" ]; }; then
      branch_name="${branch_name}-$(date +%s)"
    fi

    echo "🌿 Creating and checking out branch: $branch_name"
    git checkout -b "$branch_name" > /dev/null 2>&1
  else
    if [ -z "$pr_title" ]; then
      pr_title="chore: automated profile synchronization"
    fi
  fi

  local pr_body="Automated sync of terminal profile configurations."
  if [ -n "$issue_num" ]; then
    issue_num="${issue_num#\#}"
    pr_body="${pr_body}\n\nResolves #${issue_num}"
  fi

  if [ "$skip_ai" = true ]; then
    local commit_msg="${user_msg:-chore: automated profile synchronization}"
    echo "📦 Skipping AI commit generation. Batch committing with: \"$commit_msg\"..."
    git commit -m "$commit_msg" > /dev/null
  elif [ -z "$user_msg" ]; then
    __git_sync_ai_commit "$repo_dir"
    if [ $? -eq 100 ]; then
      echo -e "${CB_RED}🚨 Aborting profile sync.${C_RESET}"
      exit 1
    fi

    git add --all
    if ! git diff --staged --quiet; then
      echo "💡 Committing: chore: sync miscellaneous updates"
      git commit -m "chore: sync miscellaneous updates" > /dev/null
    fi
  else
    echo "📦 Committing all as a single batch..."
    git commit -m "$user_msg" > /dev/null
  fi

  if [ "$delete_merged" = true ]; then
    __mt_push_update_cleanup_merged_branches
  fi

  if ! git-raise-pr -b "$default_branch" -t "$pr_title" -m "$(echo -e "$pr_body")"; then
    echo -e "${CB_RED}🚨 git-raise-pr failed -- not attempting to auto-merge. Your commit is still on the local branch; resolve the issue above and push it manually.${C_RESET}"
    exit 1
  fi

  if [ "$auto_merge" = true ] && command -v gh > /dev/null 2>&1; then
    local current_b
    current_b=$(git branch --show-current)
    echo -e "${CB_BLUE}⚡ Auto-merging Pull Request via GitHub CLI...${C_RESET}"
    gh pr merge "$current_b" --admin --squash --delete-branch && echo -e "${CB_GREEN}✅ PR set to auto-merge on GitHub!${C_RESET}"
  fi
}

#######################################
# System: Warn and confirm before proceeding if the deployed ~/.bash.d
# tree is behind the latest published framework release.
# __git_sync_copy_files syncs deployed files INTO the repo as a blind,
# one-way copy -- if the local tree predates recent upstream changes to
# the same files, that copy silently reverts them, and the resulting PR
# either fails outright with a real git conflict or merges cleanly
# while quietly clobbering someone else's work. This is the confirmed
# root cause of a collaborator repeatedly hitting both outcomes (a
# closed, unmergeable PR and a merged PR that reverted recent docstring
# improvements) -- deliberately checked live here, right before the
# copy happens, rather than relying on mt-doctor's own version check,
# which reuses a cache that can be up to UPDATE_CHECK_TTL_SEC (default
# 12h) stale.
# Globals:
#   UPSTREAM_REPO_PATH
# Returns:
#   0 to proceed, 1 if the user declined (or non-interactively, always,
#   since there's no one to ask)
#######################################
__mt_push_update_check_staleness() {
  command -v gh > /dev/null 2>&1 || return 0

  local installed="Local"
  [ -f "$VERSION_FILE" ] && installed=$(command cat "$VERSION_FILE")

  local latest
  latest=$(gh release view --repo "$UPSTREAM_REPO_PATH" --json tagName -q .tagName 2> /dev/null)

  [ -z "$latest" ] && return 0
  [ "$installed" = "$latest" ] && return 0

  echo -e "${CB_YELLOW}⚠️  Your deployed ~/.bash.d is at ${installed}, but ${latest} has been published to ${UPSTREAM_REPO_PATH}.${C_RESET}"
  echo -e "${CB_YELLOW}   Pushing now risks silently reverting recent upstream changes in any file you haven't personally touched since. Run 'mt-get-update' first.${C_RESET}"
  read -p "🚀 Proceed anyway? [y/N] " -n 1 -r < /dev/tty
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${CB_RED}🛑 Aborted. Run 'mt-get-update', then re-run 'mt-push-update'.${C_RESET}"
    return 1
  fi
}

#######################################
# System: Sync local bash configs to terminal dotfiles repo and create a Pull Request
# Usage: mt-push-update [-i|--issue <num>] [-s|--shellcheck] [-b|--backup] [-m|--no-ai] [-d|--delete-merged] [--prompt-remote] [-g|--merge] [message]
# Options:
#   -i, --issue <num>    Optional issue number to link to the Pull Request
#   -s, --shellcheck     Run ShellCheck locally before pushing to catch errors early
#   -b, --backup         Create a zip backup of .bash.d and .bashrc before syncing
#   -m, --no-ai          Skip AI commit-grouping/README summarization; the next
#                        non-flag argument (if any) is used as the commit message
#   -d, --delete-merged  Clean up local branches already merged into the default branch
#   --prompt-remote      With -d, also prompt to delete the matching remote branches
#   -g, --merge          Auto-merge the created PR via 'gh pr merge --admin --squash'
#   $@                   Optional commit message string
#######################################
mt-push-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local issue_num=""
  local run_shellcheck=false
  local backup_before_sync=false
  local delete_merged=false
  local prompt_remote=false
  local auto_merge=false
  local skip_ai=false
  local user_msg=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -i | --issue)
        issue_num="$2"
        shift 2
        ;;
      -s | --shellcheck)
        run_shellcheck=true
        shift
        ;;
      -b | --backup)
        backup_before_sync=true
        shift
        ;;
      -m | --no-ai)
        skip_ai=true
        export SKIP_AI=true
        shift
        # Check if the next argument is a message string and not another flag
        if [[ "$#" -gt 0 && "$1" != -* ]]; then
          user_msg="$1"
          shift
        fi
        ;;
      -d | --delete-merged)
        delete_merged=true
        shift
        ;;
      --prompt-remote)
        prompt_remote=true
        shift
        ;;
      -g | --merge)
        auto_merge=true
        shift
        ;;
      -*)
        echo "Usage: mt-push-update [-i|--issue <num>] [-s|--shellcheck] [-b|--backup] [-m|--no-ai] [-d|--delete-merged] [--prompt-remote] [-g|--merge] [message]" >&2
        return 1
        ;;
      *)
        if [ -z "$user_msg" ]; then
          user_msg="$1"
        else
          user_msg="${user_msg} $1"
        fi
        shift
        ;;
    esac
  done

  user_msg=$(echo "$user_msg" | xargs)

  if [ "$run_shellcheck" = true ]; then
    __mt_push_update_run_shellcheck || return 1
  fi

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  local remote_url="${SYNC_REPO_URL:-}"

  if [[ -z "$remote_url" || "$remote_url" == "YOUR_SYNC_REPO_URL" || "$remote_url" == "null" ]]; then
    echo -e "${CB_YELLOW}⚠️  Profile Sync Not Configured${C_RESET}"
    echo -e "The ${C_BOLD}push-profile-update${C_RESET} feature automatically versions and pushes your terminal configuration to a remote Git repository."
    echo "If you don't want to sync this profile at all, you can safely ignore this command."
    echo -e "\nMost people should run:"
    echo -e "   ${CB_CYAN}mt-become-collaborator${C_RESET}   ${C_DIM}# forks ${UPSTREAM_REPO_PATH} and configures this automatically${C_RESET}"
    echo -e "\nIf you have direct write access to ${UPSTREAM_REPO_PATH}, or want to sync to your own separate repo instead, link it directly:"
    echo -e "   ${CB_CYAN}mt-add-sync-url \"git@github.com:username/my-terminal-repo.git\"${C_RESET}\n"
    return 1
  fi

  __mt_push_update_check_staleness || return 1

  if [ "$backup_before_sync" = true ]; then
    __mt_push_update_backup || return 1
  fi

  echo "🔄 Syncing bash configuration to $repo_dir..."
  __git_sync_init_repo "$repo_dir" "$remote_url"

  (__mt_push_update_reconcile_branch) || return 1

  __git_sync_copy_files "$repo_dir"

  (__mt_push_update_commit_and_raise_pr) || return 1
}
#######################################
# System: Resolve the latest (or a specific) GitHub release and report
# whether an update is actually needed
# Arguments:
#   $1 - Optional specific version tag to target (empty = latest)
# Globals:
#   UPSTREAM_REPO_PATH, DOTFILES_DIR, SYNC_REPO_DIR
# Globals (written, expected pre-declared local by the caller):
#   download_url, tag_name
# Returns:
#   0 if an update was resolved, 1 on error, 2 if already up to date
#######################################
__mt_get_update_resolve_release() {
  local target_version="$1"
  local repo_path="$UPSTREAM_REPO_PATH"

  local api_url="https://api.github.com/repos/${repo_path}/releases/latest"
  [ -n "$target_version" ] && api_url="https://api.github.com/repos/${repo_path}/releases/tags/${target_version}"

  local release_data
  release_data=$(curl -s "$api_url")

  download_url=$(echo "$release_data" | jq -r ".assets[0].browser_download_url // empty")
  tag_name=$(echo "$release_data" | jq -r ".tag_name // empty")

  local current_version="Local"
  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  if [ -f "$VERSION_FILE" ]; then
    current_version=$(command cat "$VERSION_FILE" | tr -d '\r\n ')
  elif [ -n "$repo_dir" ] && [ -d "$repo_dir/.git" ] && command -v git > /dev/null 2>&1; then
    current_version=$(git -C "$repo_dir" describe --tags --abbrev=0 2> /dev/null || echo "Local")
    current_version=$(echo "$current_version" | tr -d '\r\n ')
  fi

  local clean_tag
  clean_tag=$(echo "$tag_name" | tr -d '\r\n ')

  if [ "$clean_tag" = "$current_version" ] && [ -z "$target_version" ]; then
    echo -e "${CB_GREEN}✅ You are already running the latest version (${current_version}).${C_RESET}"
    return 2
  fi

  if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
    if [ -n "$target_version" ]; then
      mt-log ERROR "Could not find release assets for version ${target_version} in ${repo_path}."
    else
      mt-log ERROR "Could not find latest release assets for ${repo_path}."
    fi
    return 1
  fi
  return 0
}

#######################################
# System: Download a release zip and extract it, locating install.sh even
# if the archive nests everything inside a subdirectory
# Arguments:
#   $1 - Download URL for the release zip asset
#   $2 - Tag name (used only in progress messages)
# Globals (written, expected pre-declared local by the caller):
#   tmp_dir, ext_root
# Returns:
#   0 on success, 1 if the download failed
#######################################
__mt_get_update_download_and_extract() {
  local download_url="$1" tag_name="$2"
  echo -e "${CB_GREEN}📦 Found release ${tag_name}. Downloading...${C_RESET}"

  tmp_dir=$(mktemp -d)
  local zip_path="${tmp_dir}/update.zip"

  if ! curl -L -s --fail "$download_url" -o "$zip_path"; then
    mt-log ERROR "Failed to download release asset from ${download_url}."
    rm -rf "$tmp_dir"
    return 1
  fi

  echo -e "${CB_YELLOW}🔄 Extracting release package...${C_RESET}"
  unzip -q "$zip_path" -d "${tmp_dir}/extracted" > /dev/null 2>&1

  ext_root="${tmp_dir}/extracted"
  if [ ! -f "$ext_root/install.sh" ]; then
    local nested
    nested=$(find "$ext_root" -name "install.sh" -exec dirname {} \; | head -n 1)
    [ -n "$nested" ] && ext_root="$nested"
  fi
  return 0
}

#######################################
# System: Back up every locally-modified file mt-get-update is about to
# overwrite, before it does. CONFIRM_UPDATE_DIVERGENCE (off by default)
# only controls whether the user gets a chance to abort -- by default
# the update proceeds and silently discards any local edit to a
# deployed file (e.g. a hand-customized 30-ai/*.sh) with nothing to
# recover it from otherwise, which is exactly the gap that lost a real
# collaborator's edit during this framework's own development. Mirrors
# each diverging file's relative path under
# BACKUP_DIR/update-overwrites/<timestamp>/ so any one of them can be
# diffed or restored individually.
# Arguments:
#   $1 - Output of `diff -r -w -q "$HOME/.bash.d" <new>/.bash.d`, one
#        "Files X and Y differ" line per diverging file
# Globals:
#   BACKUP_DIR
#######################################
__mt_get_update_backup_diverging_files() {
  local diff_files="$1"
  local backup_dir
  backup_dir="${BACKUP_DIR:-$HOME/backups}/update-overwrites/$(date +%Y%m%d_%H%M%S)"

  local line rel_path dest_path
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    rel_path="${line#Files }"
    rel_path="${rel_path%% and *}"
    [ -f "$rel_path" ] || continue
    dest_path="${backup_dir}${rel_path#"$HOME"}"
    mkdir -p "$(dirname "$dest_path")"
    cp -p "$rel_path" "$dest_path"
  done <<< "$diff_files"

  if [ -d "$backup_dir" ]; then
    mt-log INFO "Backed up local modifications about to be overwritten to ${backup_dir}"
    echo -e "${CB_CYAN}📦 Your local edits were backed up to ${backup_dir} before being overwritten.${C_RESET}\n"
  fi
}

#######################################
# System: Warn about local ~/.bash.d modifications that diverge from the
# downloaded release before it gets installed, and back them up first
# (see __mt_get_update_backup_diverging_files) since by default this
# just warns and proceeds. Set CONFIRM_UPDATE_DIVERGENCE=true
# (mt-toggle-update-confirm) to also pause and require an explicit
# confirmation before overwriting.
# Arguments:
#   $1 - Path to the extracted release's root directory
# Globals:
#   CONFIRM_UPDATE_DIVERGENCE, BACKUP_DIR
# Returns:
#   0 to proceed with the update, 1 if the user declined (only possible
#   when CONFIRM_UPDATE_DIVERGENCE=true)
#######################################
__mt_get_update_check_divergence() {
  local ext_root="$1"
  [ -d "${ext_root}/.bash.d" ] || return 0

  local diff_files
  diff_files=$(diff -r -w -q "$HOME/.bash.d" "${ext_root}/.bash.d" 2> /dev/null | grep -v "Only in" || true)
  [ -z "$diff_files" ] && return 0

  mt-log WARN "Applying this update will overwrite local modifications in ~/.bash.d."
  echo -e "${CB_YELLOW}Modified files detected:${C_RESET}"
  diff -r -w -q "$HOME/.bash.d" "${ext_root}/.bash.d" 2> /dev/null | grep -v "Only in" | awk '{print "  • " $2 " " $4}'
  echo ""

  __mt_get_update_backup_diverging_files "$diff_files"

  if [ "${CONFIRM_UPDATE_DIVERGENCE:-false}" != "true" ]; then
    echo -e "${CB_YELLOW}⚠️  Proceeding and overwriting the files above. Run 'mt-toggle-update-confirm' to require confirmation here instead.${C_RESET}"
    return 0
  fi

  read -r -p "🔍 View detailed diff line-by-line before proceeding? [y/N] " -n 1 -r < /dev/tty
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    diff -u -r --color=always "$HOME/.bash.d" "${ext_root}/.bash.d" 2> /dev/null | less -R
  fi

  read -r -p "🚀 Proceed with update and overwrite local changes? [y/N] " -n 1 -r < /dev/tty
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${CB_YELLOW}💡 Update aborted. Run 'mt-push-update' first to save your local changes to a PR!${C_RESET}"
    return 1
  fi
  return 0
}

#######################################
# System: Run a downloaded release's install.sh, record its version, and
# reconcile any legacy config.yaml keys against the newly-installed
# schema. install.sh only ever deploys .bash.d/lib/templates/config.yaml.tpl
# -- it never touches an existing config.yaml -- so this is the one place
# a stale config.yaml (still holding keys from before a schema rename)
# reliably gets cleaned up, right as the release that changed the schema
# lands. See mt-migrate-config for the full explanation.
# Arguments:
#   $1 - Path to the extracted release's root directory
#   $2 - Tag name to record as the new current version
# Globals:
#   CONFIG_MANAGER, CONFIG_FILE
# Returns:
#   0 on success, 1 if install.sh is missing from the release
#######################################
__mt_get_update_install() {
  local ext_root="$1" tag_name="$2"
  if [ ! -f "$ext_root/install.sh" ]; then
    mt-log ERROR "install.sh missing from downloaded release."
    return 1
  fi
  (
    cd "$ext_root" || exit 1
    bash ./install.sh
  )
  mkdir -p "$CACHE_DIR" "$LOG_DIR" "$CONFIG_DIR"
  echo "$tag_name" > "$VERSION_FILE"

  if [ -f "$CONFIG_MANAGER" ] && [ -f "$CONFIG_FILE" ]; then
    python3 "$CONFIG_MANAGER" migrate
    __mt_report_runtime_dir_migration
  fi
}

#######################################
# System: Pull the latest framework code directly via git, for a machine
# already cut over by mt-migrate-symlink -- ~/.bash.d is the sync repo's
# .bash.d subtree, so there's a live working tree to update in place
# instead of a separate deployed copy to overwrite. Reuses
# __mt_push_update_reconcile_branch (the exact same fetch-from-upstream,
# stash-and-restore-dirty-changes logic mt-push-update already relies
# on) rather than duplicating that idiom here.
# Arguments:
#   $1 - Optional specific version tag to target (empty = latest via
#        the default branch; a specific tag checks out detached)
# Globals:
#   DOTFILES_DIR, SYNC_REPO_DIR, UPSTREAM_REPO_PATH, CONFIG_MANAGER,
#   CONFIG_FILE
# Returns:
#   0 on success, 1 on failure (dirty tree, fetch/merge conflict)
#######################################
__mt_get_update_git_pull() {
  local target_version="$1"
  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"

  echo -e "${CB_BLUE}⬇️ ~/.bash.d is symlinked into ${repo_dir} -- pulling directly from ${UPSTREAM_REPO_PATH} instead of downloading a release archive.${C_RESET}"

  (__mt_push_update_reconcile_branch) || return 1

  # __mt_push_update_reconcile_branch's fetch only follows the default
  # branch ref, never tags -- without this, local tags silently stop
  # advancing the moment reconcile starts using a fetch URL other than
  # 'origin' (a plain 'git fetch <url> <branch>' doesn't auto-follow
  # tags the way fetching a configured remote does), and 'git describe'
  # below would report a long-stale version.
  git -C "$repo_dir" fetch --tags "https://github.com/${UPSTREAM_REPO_PATH}.git" > /dev/null 2>&1

  if [ -n "$target_version" ]; then
    if ! git -C "$repo_dir" checkout "$target_version" > /dev/null 2>&1; then
      echo -e "${CB_RED}🚨 Could not check out tag ${target_version} in ${repo_dir}.${C_RESET}"
      return 1
    fi
  fi

  # Prefer the GitHub Release API's tag (the actual source of truth for
  # "what was published") over a local 'git describe', which can still
  # be wrong immediately after a release if the tag lands a moment after
  # the commit it points to.
  local tag_name="$target_version"
  if [ -z "$tag_name" ] && command -v gh > /dev/null 2>&1; then
    tag_name=$(gh release view --repo "$UPSTREAM_REPO_PATH" --json tagName -q .tagName 2> /dev/null)
  fi
  [ -z "$tag_name" ] && tag_name=$(git -C "$repo_dir" describe --tags --abbrev=0 2> /dev/null)
  [ -n "$tag_name" ] && echo "$tag_name" > "$VERSION_FILE"

  if [ -f "$CONFIG_MANAGER" ] && [ -f "$CONFIG_FILE" ]; then
    python3 "$CONFIG_MANAGER" migrate
    __mt_report_runtime_dir_migration
  fi

  echo -e "${CB_GREEN}✅ Updated to ${tag_name:-$(git -C "$repo_dir" rev-parse --short HEAD 2> /dev/null)}.${C_RESET}"
}

#######################################
# System: Download and install profile updates from GitHub releases --
# or, on a machine already cut over by mt-migrate-symlink, pull the
# latest code directly via git instead (see __mt_get_update_git_pull).
# Usage: mt-get-update [-v version]
# Options:
#   -v <version>  Specify a target release version (e.g., v1.1.0)
#######################################
mt-get-update() {
  local target_version=""
  local OPTIND opt
  while getopts "v:h" opt; do
    case ${opt} in
      v) target_version="$OPTARG" ;;
      h)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      ?)
        echo "Usage: mt-get-update [-v <version>]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  if __mt_bashd_is_symlinked_into_repo "$repo_dir"; then
    __mt_get_update_git_pull "$target_version"
    return $?
  fi

  echo -e "${CB_BLUE}⬇️ Fetching release information...${C_RESET}"

  local download_url="" tag_name=""
  __mt_get_update_resolve_release "$target_version"
  local resolve_status=$?
  [ "$resolve_status" -eq 2 ] && return 0
  [ "$resolve_status" -eq 1 ] && return 1

  local tmp_dir="" ext_root=""
  __mt_get_update_download_and_extract "$download_url" "$tag_name" || return 1

  if ! __mt_get_update_check_divergence "$ext_root"; then
    rm -rf "$tmp_dir"
    return 0
  fi

  __mt_get_update_install "$ext_root" "$tag_name"
  rm -rf "$tmp_dir"
}

#######################################
# Git: One-time, idempotent cutover that replaces ~/.bash.d as a
# standalone directory with a symlink into the sync repo's own
# .bash.d subtree, so there's exactly one physical copy of the
# framework on this machine instead of two kept in sync by
# mt-push-update/mt-get-update's copy steps. This is the fix for the
# collaborator merge-conflict root cause __mt_push_update_check_staleness
# only warns about: a deployed tree that's silently drifted from the
# checkout it gets pushed from becomes structurally impossible once
# there's nothing left to drift between. Once run,
# __mt_bashd_is_symlinked_into_repo starts returning true, which is
# what unlocks the faster git-based paths in __git_sync_copy_files,
# __mt_get_update_git_pull, and mt-restore.
# Refuses to run unless the sync repo checkout is clean, on its
# default branch, correctly pointed at SYNC_REPO_URL, and identical to
# ~/.bash.d already (i.e. right after a fresh 'mt-push-update') --
# anything else means there's real, uncopied local work that would be
# stranded the moment ~/.bash.d stops being its own directory. Safe to
# re-run: no-ops immediately if ~/.bash.d is already a symlink.
# Usage: mt-migrate-symlink
# Globals:
#   DOTFILES_DIR, SYNC_REPO_DIR, SYNC_REPO_URL
#######################################
mt-migrate-symlink() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [ -L "$HOME/.bash.d" ]; then
    echo -e "${CB_GREEN}✅ ~/.bash.d is already a symlink (-> $(readlink -f "$HOME/.bash.d")). Nothing to do.${C_RESET}"
    return 0
  fi

  local repo_dir="${DOTFILES_DIR:-$SYNC_REPO_DIR}"
  if [ ! -d "$repo_dir/.git" ]; then
    echo -e "${CB_RED}🚨 ${repo_dir} isn't a git checkout yet. Run 'mt-push-update' first.${C_RESET}"
    return 1
  fi

  local default_branch
  default_branch=$(__mt_git_default_branch "$repo_dir")
  default_branch="${default_branch:-main}"

  local current_branch
  current_branch=$(git -C "$repo_dir" branch --show-current)
  if [ "$current_branch" != "$default_branch" ]; then
    echo -e "${CB_RED}🚨 ${repo_dir} is on '${current_branch}', not '${default_branch}'. Run 'mt-push-update' to land or clean up that branch first.${C_RESET}"
    return 1
  fi

  if [ -n "$(git -C "$repo_dir" status --porcelain 2> /dev/null)" ]; then
    echo -e "${CB_RED}🚨 ${repo_dir} has uncommitted changes. Run 'mt-push-update' first.${C_RESET}"
    return 1
  fi

  local actual_origin
  actual_origin=$(git -C "$repo_dir" remote get-url origin 2> /dev/null)
  if [ -n "${SYNC_REPO_URL:-}" ] && [ "$actual_origin" != "$SYNC_REPO_URL" ]; then
    echo -e "${CB_RED}🚨 ${repo_dir}'s origin doesn't match SYNC_REPO_URL. Run 'mt-push-update' first -- it fixes this automatically.${C_RESET}"
    return 1
  fi

  echo -e "${CB_BLUE}🔍 Checking ~/.bash.d matches ${repo_dir}/.bash.d before cutover...${C_RESET}"
  local drift
  drift=$(diff -rq \
    --exclude='config.yaml' --exclude='.env.cache' --exclude='*_token.sh' \
    --exclude='secrets_metadata.yaml' --exclude='.vcs_hub.json' --exclude='.syncignore' \
    --exclude='data' --exclude='40-private' --exclude='private' \
    "$HOME/.bash.d" "$repo_dir/.bash.d" 2> /dev/null)
  if [ -n "$drift" ]; then
    echo -e "${CB_RED}🚨 ~/.bash.d and ${repo_dir}/.bash.d differ:${C_RESET}"
    echo "  ${drift//$'\n'/$'\n  '}"
    echo -e "${CB_YELLOW}Run 'mt-push-update' first so they match, then re-run 'mt-migrate-symlink'.${C_RESET}"
    return 1
  fi
  echo -e "${CB_GREEN}✅ Trees match.${C_RESET}"

  echo -e "${CB_BLUE}📦 Copying local-only files (config, secrets, cache, private content) into ${repo_dir}/.bash.d...${C_RESET}"
  local local_only_paths=(
    "config/config.yaml" "config/.env.cache" "config/secrets_metadata.yaml"
    "data/.current_version" "data/cache" "data/logs" "40-private" "lib/private"
  )
  local rel_path
  for rel_path in "${local_only_paths[@]}"; do
    [ -e "$HOME/.bash.d/$rel_path" ] || continue
    mkdir -p "$(dirname "$repo_dir/.bash.d/$rel_path")"
    cp -a "$HOME/.bash.d/$rel_path" "$repo_dir/.bash.d/$rel_path"
  done
  local token_file
  for token_file in "$HOME/.bash.d/config/"*_token.sh; do
    [ -f "$token_file" ] || continue
    cp -p "$token_file" "$repo_dir/.bash.d/config/$(basename "$token_file")"
  done

  local backup_dir
  backup_dir="$HOME/.bash.d.pre-symlink-backup-$(date +%Y%m%d%H%M%S)"
  mv "$HOME/.bash.d" "$backup_dir"
  ln -s "$repo_dir/.bash.d" "$HOME/.bash.d"

  echo -e "${CB_GREEN}✅ ~/.bash.d is now a symlink into ${repo_dir}/.bash.d.${C_RESET}"
  echo -e "${C_DIM}   Your previous deployed tree is safely kept at ${backup_dir} -- delete it once you're confident everything works.${C_RESET}"
  echo -e "${CB_YELLOW}Open a new terminal (or run 'source ~/.bashrc') and 'mt-doctor' to verify.${C_RESET}"
}

#######################################
# System: Download a release zip from the remote repository
# Usage: mt-download-release [-v version] [-d directory]
# Options:
#   -v <version>    Specify target release version (defaults to latest)
#   -d <directory>  Specify destination directory (defaults to current directory)
#######################################
mt-download-release() {
  local target_version=""
  local dest_dir="$PWD"
  local OPTIND opt

  while getopts "v:d:h" opt; do
    case ${opt} in
      v) target_version="$OPTARG" ;;
      d) dest_dir="$OPTARG" ;;
      h)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      \?)
        echo "Usage: mt-download-release [-v <version>] [-d <directory>]" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ ! -d "$dest_dir" ]; then
    echo -e "${CB_YELLOW}⚠️ Directory '${dest_dir}' does not exist. Creating it...${C_RESET}"
    mkdir -p "$dest_dir" || {
      echo -e "${CB_RED}🚨 Error: Failed to create directory '${dest_dir}'.${C_RESET}"
      return 1
    }
  fi

  echo -e "${CB_BLUE}⬇️ Fetching release information...${C_RESET}"

  local repo_path="$UPSTREAM_REPO_PATH"

  local api_url="https://api.github.com/repos/${repo_path}/releases/latest"
  if [ -n "$target_version" ]; then
    api_url="https://api.github.com/repos/${repo_path}/releases/tags/${target_version}"
  fi

  local release_data
  release_data=$(curl -s "$api_url")

  local download_url
  download_url=$(echo "$release_data" | jq -r ".assets[0].browser_download_url // empty")
  local asset_name
  asset_name=$(echo "$release_data" | jq -r ".assets[0].name // empty")
  local tag_name
  tag_name=$(echo "$release_data" | jq -r ".tag_name // empty")

  if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
    if [ -n "$target_version" ]; then
      echo -e "${CB_RED}🚨 Error: Could not find release assets for version ${target_version} in ${repo_path}.${C_RESET}"
    else
      echo -e "${CB_RED}🚨 Error: Could not find latest release assets for ${repo_path}.${C_RESET}"
    fi
    return 1
  fi

  [ -z "$asset_name" ] || [ "$asset_name" = "null" ] && asset_name="mt-devops-framework-${tag_name}.zip"

  local dest_file="${dest_dir}/${asset_name}"

  echo -e "${CB_GREEN}📦 Found release ${tag_name}. Downloading to ${dest_file}...${C_RESET}"

  if curl -L -# --fail "$download_url" -o "$dest_file"; then
    echo -e "${CB_GREEN}✅ Successfully downloaded release ${tag_name} to ${dest_file}${C_RESET}"
    if type __win_explorer_focus > /dev/null 2>&1; then
      __win_explorer_focus "$dest_dir" 2> /dev/null || true
    fi
  else
    echo -e "${CB_RED}🚨 Error: Failed to download release asset from ${download_url}.${C_RESET}"
    return 1
  fi
}
