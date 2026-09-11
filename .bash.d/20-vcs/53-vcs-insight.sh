# shellcheck shell=bash
# ------------------------------------------
# MT Repo Hub - AI & Heuristic Metadata Dashboard
# ------------------------------------------

#######################################
# Repo Hub: Find every git repository under a search root -- test -e
# (not -d) on ".git" so this also catches worktree checkouts, where
# ".git" is a plain file ("gitdir: ...") rather than a directory
# Arguments:
#   $1 - Root directory to search
# Outputs:
#   Prints one repository's absolute path per line
#######################################
__mt_hub_find_repos() {
  local search_dir="$1"
  find "$search_dir" -type d -exec test -e "{}/.git" \; -prune -print
}

#######################################
# Repo Hub: Detect a repo's CI/CD provider from known config files
# Arguments:
#   $1 - Repository path
# Outputs:
#   Prints the detected provider name, or "None"
#######################################
__mt_hub_detect_cicd() {
  local repo_path="$1"
  local cicd="None"
  [ -f "$repo_path/bitbucket-pipelines.yml" ] && cicd="Bitbucket Pipelines"
  [ -d "$repo_path/.github/workflows" ] && cicd="GitHub Actions"
  [ -f "$repo_path/.gitlab-ci.yml" ] && cicd="GitLab CI"
  [ -f "$repo_path/Jenkinsfile" ] && cicd="Jenkins"
  [ -f "$repo_path/azure-pipelines.yml" ] && cicd="Azure DevOps"
  echo "$cicd"
}

#######################################
# Repo Hub: Detect a repo's build tool from known manifest files
# Arguments:
#   $1 - Repository path
# Outputs:
#   Prints the detected build tool name, or "None"
#######################################
__mt_hub_detect_build_tool() {
  local repo_path="$1"
  local build="None"
  [ -f "$repo_path/pom.xml" ] && build="Maven"
  [ -f "$repo_path/build.gradle" ] && build="Gradle"
  [ -f "$repo_path/package.json" ] && build="NPM/Yarn"
  if [ -f "$repo_path/requirements.txt" ] || [ -f "$repo_path/Pipfile" ] || [ -f "$repo_path/pyproject.toml" ]; then
    build="Pip/Poetry"
  fi
  [ -f "$repo_path/go.mod" ] && build="Go Modules"
  [ -f "$repo_path/Cargo.toml" ] && build="Cargo"
  [ -f "$repo_path/Gemfile" ] && build="Bundler"
  [ -f "$repo_path/composer.json" ] && build="Composer"
  if compgen -G "$repo_path/*.csproj" > /dev/null 2>&1 || compgen -G "$repo_path/*.sln" > /dev/null 2>&1; then
    build="MSBuild/.NET"
  fi
  echo "$build"
}

#######################################
# Repo Hub: Detect a repo's test framework from known conventions
# Arguments:
#   $1 - Repository path
# Outputs:
#   Prints the detected test framework name, or "None"
#######################################
__mt_hub_detect_test_framework() {
  local repo_path="$1"
  local testing="None"
  if [ -d "$repo_path/tests" ] || [ -d "$repo_path/src/test" ] || [ -d "$repo_path/spec" ]; then
    testing="Standard Dirs"
  fi
  grep -qi "pytest" "$repo_path/requirements.txt" 2> /dev/null && testing="PyTest"
  grep -qi "jest" "$repo_path/package.json" 2> /dev/null && testing="Jest"
  grep -qi "junit" "$repo_path/pom.xml" 2> /dev/null && testing="JUnit"
  grep -qiE "nunit|xunit" "$repo_path"/*.csproj 2> /dev/null && testing="NUnit/xUnit"
  grep -qi "rspec" "$repo_path/Gemfile" 2> /dev/null && testing="RSpec"
  echo "$testing"
}

#######################################
# Repo Hub: Detect a repo's primary language/stack by the most common file
# extension among its top-level files
# Arguments:
#   $1 - Repository path
# Outputs:
#   Prints the detected stack name, or "Unknown"
#######################################
__mt_hub_detect_stack() {
  local repo_path="$1"
  local top_ext
  top_ext=$(find "$repo_path" -maxdepth 3 -type f -not -path "*/\.git/*" -not -path "*/node_modules/*" -not -path "*/venv/*" 2> /dev/null | rev | cut -d. -f1 | rev | grep -E "^(py|java|js|ts|tf|go|sh|cpp|c|html|css|cs|rb|php|rs)$" | sort | uniq -c | sort -rn | head -n1 | awk '{print $2}')

  local stack="Unknown"
  case "$top_ext" in
    py) stack="Python" ;;
    java) stack="Java" ;;
    tf) stack="Terraform" ;;
    js) stack="JavaScript" ;;
    ts) stack="TypeScript" ;;
    go) stack="Go" ;;
    sh) stack="Bash/Shell" ;;
    html) stack="HTML/Web" ;;
    cs) stack="C#" ;;
    rb) stack="Ruby" ;;
    php) stack="PHP" ;;
    rs) stack="Rust" ;;
  esac
  echo "$stack"
}

#######################################
# Repo Hub: Override the extension-histogram stack guess with a
# manifest-derived language when the build tool detected is an
# unambiguous 1:1 signal for one -- a real manifest file is stronger
# evidence than a raw file-count histogram, which a large but secondary
# subdirectory (e.g. a Java repo's bundled frontend/) can otherwise
# dominate. Left alone for NPM/Yarn, since that maps ambiguously to
# either JavaScript or TypeScript and the histogram already disambiguates
# those correctly.
# Arguments:
#   $1 - Detected build tool (from __mt_hub_detect_build_tool)
#   $2 - Detected stack (from __mt_hub_detect_stack)
# Outputs:
#   Prints the (possibly overridden) stack name
#######################################
__mt_hub_reconcile_stack() {
  local build="$1" stack="$2"
  case "$build" in
    Maven | Gradle) stack="Java" ;;
    MSBuild/.NET) stack="C#" ;;
    Cargo) stack="Rust" ;;
    Bundler) stack="Ruby" ;;
    Composer) stack="PHP" ;;
    "Go Modules") stack="Go" ;;
    Pip/Poetry) stack="Python" ;;
  esac
  echo "$stack"
}

#######################################
# Repo Hub: Ask the configured AI to produce a 1-sentence description and
# category for a repository, based on its README and directory tree.
# Calls __ai_query_provider directly instead of the public 'ai' command
# -- 'ai' always pipes its response through __ai_parse_response, which
# treats any non-empty, non-"chat" "category" field as generated code to
# save to a file, printing only "Saved to: <path>" instead of the JSON
# text. Since this function's own prompt asks for a "category" field
# with a completely different vocabulary ("Application"/"Tooling"/...),
# that collision meant this never returned usable JSON at all -- for any
# provider whose response happened to get wrapped in that envelope
# shape. Bypassing 'ai' entirely for this call is the fix. Diagnostics
# (rate limits, retries, errors) are also left on stderr here rather
# than discarded, so a bulk '--index' run's failures are visible instead
# of silently producing "Unknown" everywhere.
# Arguments:
#   $1 - Repository path
#   $2 - Provider override (gemini, claude, claude-code, local); empty
#        falls back to DEFAULT_AI
# Globals:
#   DEFAULT_AI
# Globals (shadowed): AI_SYSTEM_PROMPT is locally blanked for this call
#   and everything it calls -- the framework's ambient system prompt
#   (config/ai/system_prompt.md) hard-instructs every model to respond
#   with a "category" restricted to "gcloud"|"script"|"project"|"chat".
#   That directly competes with this function's own "category" field
#   (a completely different vocabulary), and having both instructions
#   present made the model's choice of which schema to honor
#   non-deterministic -- confirmed by reproducing both a clean JSON
#   response and a "category": "chat" envelope-leak from the exact same
#   prompt on different runs. The prompt below already states the full
#   schema explicitly, so no system prompt is needed here at all.
# Globals (written, expected pre-declared local by the caller):
#   ai_description, ai_category
#######################################
__mt_hub_summarize_repo() {
  local repo_path="$1" provider="${2:-${DEFAULT_AI:-gemini}}"
  # shellcheck disable=SC2034  # read via dynamic scope by __ai_query_* in 60-ai.sh
  local AI_SYSTEM_PROMPT=""
  local ai_prompt="Analyze this repository structure and README. Return ONLY a valid JSON object matching exactly this schema: {\"description\": \"A highly concise 1-sentence description of what this project does\", \"category\": \"Application\" | \"Infrastructure\" | \"CI/CD\" | \"Tooling\" | \"Library\" | \"Dotfiles\" | \"Other\"}"

  local ctx_file
  ctx_file=$(mktemp)
  [ -f "$repo_path/README.md" ] && head -c 2000 "$repo_path/README.md" > "$ctx_file"
  echo -e "\n\nDIRECTORY TREE:\n" >> "$ctx_file"
  find "$repo_path" -maxdepth 2 -not -path "*/\.git/*" -not -path "*/node_modules/*" >> "$ctx_file"

  local ai_res
  ai_res=$(__ai_query_provider "$provider" "$ai_prompt" "" "$ctx_file" "" false)
  rm -f "$ctx_file"

  ai_description="No description available."
  ai_category="Unknown"
  [ -z "$ai_res" ] && return 0

  local clean_json
  # shellcheck disable=SC2016
  clean_json=$(echo "$ai_res" | sed 's/```json//gi; s/```//g')
  if ! echo "$clean_json" | jq -e . > /dev/null 2>&1; then
    mt-log WARN "AI summary for $(basename "$repo_path") wasn't valid JSON -- leaving it as Unknown."
    return 0
  fi

  ai_description=$(echo "$clean_json" | jq -r '.description // "No description available."')
  ai_category=$(echo "$clean_json" | jq -r '.category // "Unknown"')
}

#######################################
# Repo Hub: Decide whether a repo should be indexed given the active
# type/name filters and cache/force-reindex/update-missing state. Takes
# the set of already-cached repo paths, and the subset of those whose
# cached entry has a gap, as associative arrays (built once by the
# caller via __mt_hub_load_existing_keys) rather than re-reading and
# re-parsing the whole cache file with a fresh jq process on every single
# repo -- the latter is what this used to do, and it's pure repeated work
# since the answer can't change mid-loop.
# Arguments:
#   $1 - Repository path
#   $2 - VCS search root (used to derive the repo's type from its
#        relative path)
#   $3 - Type filter (lowercased; empty = no filter)
#   $4 - Name filter (empty = no filter)
#   $5 - force_reindex (true/false)
#   $6 - update_missing (true/false) -- re-index an already-cached repo
#        anyway if its entry has a gap (see __mt_hub_load_existing_keys)
# Globals (read):
#   __mt_hub_existing_keys -- associative array of cache_file keys,
#     pre-populated by the caller via __mt_hub_load_existing_keys
#   __mt_hub_needs_update -- associative array of cache_file keys whose
#     entry has a gap, pre-populated by the same call
# Returns:
#   0 if the repo should be indexed, 1 if it should be skipped
#######################################
__mt_hub_should_index() {
  local repo_path="$1" search_dir="$2" filter_type="$3" filter_repo="$4" force_reindex="$5" update_missing="$6"
  local repo_name
  repo_name=$(basename "$repo_path")

  local rel_path="${repo_path#"$search_dir"/}"
  local repo_type="Root"
  [[ "$rel_path" == */* ]] && repo_type="${rel_path%%/*}"

  [ -n "$filter_type" ] && [ "${repo_type,,}" != "$filter_type" ] && return 1
  [ -n "$filter_repo" ] && [ "$repo_name" != "$filter_repo" ] && return 1

  if [ -n "${__mt_hub_existing_keys[$repo_path]:-}" ] && [ "$force_reindex" != "true" ]; then
    if [ "$update_missing" = "true" ] && [ -n "${__mt_hub_needs_update[$repo_path]:-}" ]; then
      echo -e "${C_DIM}🔄 Re-indexing $repo_name (filling in missing data)${C_RESET}"
      return 0
    fi
    echo -e "${C_DIM}⏭️  Skipping $repo_name (already indexed)${C_RESET}"
    return 1
  fi
  return 0
}

#######################################
# Repo Hub: Populate two associative arrays from a single read of the
# cache file: every already-cached repo path, and the subset of those
# whose entry has a gap -- category/description never came back from the
# AI (still sitting at their failure-mode defaults), or the stack
# heuristic found nothing recognizable. build/cicd/testing being "None"
# is deliberately NOT treated as a gap here: unlike the AI-derived
# fields (which the model is always instructed to fill in) and stack
# (an extension histogram that should almost always match something),
# "None" is frequently the correct, heuristically-detected answer for a
# repo that genuinely has no CI/build tool/test framework -- flagging it
# as "missing" would re-run (and re-bill) AI summarization for most
# simple repos for no real gain.
# Arguments:
#   $1 - Path to the JSON cache file
# Globals (written, must be declared by the caller as
#   `declare -A __mt_hub_existing_keys` and
#   `declare -A __mt_hub_needs_update` before calling this):
#   __mt_hub_existing_keys, __mt_hub_needs_update
#######################################
__mt_hub_load_existing_keys() {
  local cache_file="$1"
  __mt_hub_existing_keys=()
  __mt_hub_needs_update=()
  [ -f "$cache_file" ] || return 0

  local key
  while IFS= read -r key; do
    [ -n "$key" ] && __mt_hub_existing_keys["$key"]=1
  done < <(jq -r 'keys[]' "$cache_file" 2> /dev/null)

  while IFS= read -r key; do
    [ -n "$key" ] && __mt_hub_needs_update["$key"]=1
  done < <(jq -r 'to_entries[] | select(.value.category == "Unknown" or .value.description == "No description available." or .value.stack == "Unknown") | .key' "$cache_file" 2> /dev/null)
}

#######################################
# Repo Hub: Write one repo's metadata into the JSON cache under an
# exclusive file lock, so a background '--index -b' run and a concurrent
# foreground run (or two overlapping filtered runs) can't interleave
# their read-modify-write cycles and silently drop each other's updates.
# Arguments:
#   $1 - Path to the JSON cache file
#   $2 - Repository path (becomes the cache key)
#   $3 - Category (AI-derived)
#   $4 - Description (AI-derived)
#   $5 - Stack
#   $6 - Build tool
#   $7 - CI/CD provider
#   $8 - Test framework
#######################################
__mt_hub_write_cache_entry() {
  local cache_file="$1" repo_path="$2" category="$3" description="$4" stack="$5" build="$6" cicd="$7" testing="$8"
  local lock_file="${cache_file}.lock"

  (
    flock -x 200
    local tmp_cache
    tmp_cache=$(mktemp)
    jq --arg r "$repo_path" \
      --arg c "$category" \
      --arg d "$description" \
      --arg s "$stack" \
      --arg b "$build" \
      --arg ci "$cicd" \
      --arg t "$testing" \
      --argjson ts "$(date +%s)" \
      '.[$r] = {"category": $c, "description": $d, "stack": $s, "build": $b, "cicd": $ci, "testing": $t, "last_indexed": $ts}' \
      "$cache_file" > "$tmp_cache" && mv "$tmp_cache" "$cache_file"
  ) 200> "$lock_file"
}

#######################################
# Repo Hub: Run all heuristics and AI summarization for one repo and
# persist the result into the JSON cache
# Arguments:
#   $1 - Repository path
#   $2 - Path to the JSON cache file
#   $3 - Provider override (gemini, claude, claude-code, local); empty
#        falls back to DEFAULT_AI
#######################################
__mt_hub_index_one_repo() {
  local repo_path="$1" cache_file="$2" provider="$3"
  local repo_name
  repo_name=$(basename "$repo_path")

  echo -e "${CB_YELLOW}⚙️  Indexing $repo_name...${C_RESET}"

  local cicd build testing stack
  cicd=$(__mt_hub_detect_cicd "$repo_path")
  build=$(__mt_hub_detect_build_tool "$repo_path")
  testing=$(__mt_hub_detect_test_framework "$repo_path")
  stack=$(__mt_hub_detect_stack "$repo_path")
  stack=$(__mt_hub_reconcile_stack "$build" "$stack")

  local ai_description="" ai_category=""
  __mt_hub_summarize_repo "$repo_path" "$provider"

  __mt_hub_write_cache_entry "$cache_file" "$repo_path" "$ai_category" "$ai_description" "$stack" "$build" "$cicd" "$testing"

  echo -e "${CB_GREEN}✅ Indexed $repo_name${C_RESET}"
}

#######################################
# Repo Hub: Remove cache entries for repos no longer found on disk (moved,
# renamed, or deleted). Only called from an unfiltered index run ('-t'/'-r'
# not given) -- a filtered scan only sees a subset of repos, so pruning
# against that subset would wrongly delete every entry outside the
# filter. Also skipped if the scan found zero repos at all, since that's
# almost certainly a transient scan failure (VCS_ROOT briefly
# inaccessible, a permissions glitch) rather than genuinely nothing to
# index, and pruning on it would wipe the entire cache.
# Arguments:
#   $1   - Path to the JSON cache file
#   $@   - Every currently-live repo path from this run's full scan
#######################################
__mt_hub_prune_stale_entries() {
  local cache_file="$1"
  shift
  [ -f "$cache_file" ] || return 0
  [ "$#" -eq 0 ] && return 0

  local live_json
  live_json=$(printf '%s\n' "$@" | jq -R . | jq -s .)

  local lock_file="${cache_file}.lock"
  (
    flock -x 200
    local before after
    before=$(jq 'keys | length' "$cache_file" 2> /dev/null || echo 0)
    local tmp_cache
    tmp_cache=$(mktemp)
    jq --argjson live "$live_json" 'with_entries(select(.key as $k | $live | index($k)))' "$cache_file" > "$tmp_cache" && mv "$tmp_cache" "$cache_file"
    after=$(jq 'keys | length' "$cache_file" 2> /dev/null || echo 0)
    local removed=$((before - after))
    if [ "$removed" -gt 0 ]; then
      local plural="ies"
      [ "$removed" -eq 1 ] && plural="y"
      echo -e "${C_DIM}🧹 Pruned ${removed} stale cache entr${plural} for repos no longer on disk.${C_RESET}"
    fi
  ) 200> "$lock_file"
}

#######################################
# Repo Hub: Index every discovered repository under VCS_ROOT into the
# heuristic/AI metadata cache. Prunes stale entries first (unfiltered
# runs only -- see __mt_hub_prune_stale_entries), then loads the set of
# already-cached keys once for the whole run rather than re-reading the
# cache file per repo.
# Usage: __mt_hub_index <cache_file> <filter_type> <filter_repo> <force_reindex> <provider> <update_missing>
# Globals:
#   VCS_ROOT
# Arguments:
#   $1 - Path to the JSON cache file
#   $2 - Type filter (empty = no filter)
#   $3 - Name filter (empty = no filter)
#   $4 - force_reindex (true/false)
#   $5 - Provider override (gemini, claude, claude-code, local); empty
#        falls back to DEFAULT_AI
#   $6 - update_missing (true/false) -- re-index an already-cached repo
#        anyway if its entry has a gap (see __mt_hub_load_existing_keys)
#######################################
__mt_hub_index() {
  local cache_file="$1"
  local filter_type="${2,,}"
  local filter_repo="$3"
  local force_reindex="$4"
  local provider="$5"
  local update_missing="$6"
  local search_dir="${VCS_ROOT:-$HOME/vcs}"

  local msg_suffix=""
  [ -n "$filter_type" ] && msg_suffix=" of type '${filter_type}'"
  [ -n "$filter_repo" ] && msg_suffix="${msg_suffix} matching repo '${filter_repo}'"
  echo -e "${CB_BLUE}🔍 Scanning for repositories to index${msg_suffix}...${C_RESET}"
  echo -e "${C_DIM}🤖 Using AI provider: ${provider:-${DEFAULT_AI:-gemini}}${C_RESET}"

  local repos=()
  local repo_path
  while IFS= read -r repo_path; do repos+=("$repo_path"); done < <(__mt_hub_find_repos "$search_dir")

  if [ -z "$filter_type" ] && [ -z "$filter_repo" ]; then
    __mt_hub_prune_stale_entries "$cache_file" "${repos[@]}"
  fi

  local -A __mt_hub_existing_keys
  local -A __mt_hub_needs_update
  __mt_hub_load_existing_keys "$cache_file"

  local processed=0
  for repo_path in "${repos[@]}"; do
    __mt_hub_should_index "$repo_path" "$search_dir" "$filter_type" "$filter_repo" "$force_reindex" "$update_missing" || continue
    processed=$((processed + 1))
    __mt_hub_index_one_repo "$repo_path" "$cache_file" "$provider"
  done

  if [ "$processed" -eq 0 ]; then
    mt-log WARN "No repositories matched your filter criteria."
  else
    echo -e "\n${CB_GREEN}🎉 Indexing complete! Run 'mt-hub' to view the dashboard.${C_RESET}"
  fi
}

#######################################
# Repo Hub: Print one repo's cached metadata plus its 3 most recent
# commits -- used both as fzf's live preview pane (called with the
# hidden absolute-path field) and directly via `mt-hub --preview <repo>`.
# Accepts either form: an exact cache key (an absolute path) or a bare
# repo name, resolved by matching cache keys' basenames.
# Arguments:
#   $1 - Repo identifier: an absolute path (exact cache key) or a bare
#        repo name
#   $2 - Path to the JSON cache file
#######################################
__mt_hub_preview() {
  local repo="$1"
  local cache_file="$2"

  local repo_name
  repo_name=$(basename "$repo")
  echo -e "${CB_CYAN}============================================================${C_RESET}"
  echo -e "${CB_BLUE} 📦 ${repo_name}${C_RESET}"
  echo -e "${CB_CYAN}============================================================${C_RESET}\n"

  local meta
  meta=$(jq -r --arg r "$repo" '.[$r] // empty' "$cache_file" 2> /dev/null)

  if [ -z "$meta" ]; then
    local resolved
    resolved=$(jq -r --arg name "$repo" 'to_entries[] | select((.key | split("/") | last) == $name) | .key' "$cache_file" 2> /dev/null | head -n1)
    if [ -n "$resolved" ]; then
      repo="$resolved"
      meta=$(jq -r --arg r "$repo" '.[$r] // empty' "$cache_file" 2> /dev/null)
    fi
  fi

  if [ -z "$meta" ] || [ "$meta" == "null" ]; then
    echo -e "${CB_YELLOW}⚠️ No metadata found.${C_RESET}\n"
    echo -e "Run ${CB_GREEN}mt-hub --index${C_RESET} to generate AI insights and heuristics for this repository."
    return 0
  fi

  local cat
  cat=$(echo "$meta" | jq -r '.category')
  local desc
  desc=$(echo "$meta" | jq -r '.description')
  local stack
  stack=$(echo "$meta" | jq -r '.stack')
  local build
  build=$(echo "$meta" | jq -r '.build')
  local cicd
  cicd=$(echo "$meta" | jq -r '.cicd')
  local test_fw
  test_fw=$(echo "$meta" | jq -r '.testing')
  local last_indexed
  last_indexed=$(echo "$meta" | jq -r '.last_indexed // empty')

  echo -e "${CB_MAGENTA}▶ OVERVIEW${C_RESET}"
  echo -e "${C_RESET}${desc}${C_RESET}\n"

  echo -e "${CB_MAGENTA}▶ ARCHITECTURE METADATA${C_RESET}"
  echo -e " ${CB_CYAN}Category    :${C_RESET} ${cat}"
  echo -e " ${CB_CYAN}Tech Stack  :${C_RESET} ${stack}"
  echo -e " ${CB_CYAN}Build Tools :${C_RESET} ${build}"
  echo -e " ${CB_CYAN}CI/CD       :${C_RESET} ${cicd}"
  echo -e " ${CB_CYAN}Testing     :${C_RESET} ${test_fw}"
  if [ -n "$last_indexed" ]; then
    local last_indexed_human
    last_indexed_human=$(date -d "@$last_indexed" '+%Y-%m-%d %H:%M' 2> /dev/null || date -r "$last_indexed" '+%Y-%m-%d %H:%M' 2> /dev/null || echo "$last_indexed")
    echo -e " ${CB_CYAN}Last Indexed:${C_RESET} ${last_indexed_human}"
  fi

  echo -e "\n${CB_MAGENTA}▶ RECENT COMMITS${C_RESET}"
  git -C "$repo" log -3 --format="%C(yellow)%h%Creset - %s %Cgreen(%cr)%Creset" 2> /dev/null || echo "No commits yet."
}

#######################################
# System: Interactive AI-powered Repository Dashboard. An unfiltered
# --index run also prunes cache entries for repos no longer found on
# disk (moved, renamed, or deleted) before indexing.
# Usage: mt-hub [--index [-b] [-f] [-u] [-t <type>] [-r <name>] [-p <provider>]] [--preview <repo>]
# Options:
#   --index                    Scan and build the AI metadata cache
#   -b, --bg, --background     Run the index scan as a background job (with --index)
#   -f, --force                Force reindex even if a repo is already cached (with --index)
#   -u, --update               Re-index an already-cached repo anyway if its entry has a
#                              gap (AI category/description never came back, or the stack
#                              heuristic found nothing) -- unlike -f, repos with a complete
#                              entry are still skipped. Ignored if -f is also given.
#   -t, --type <name>          Filter indexing to a specific folder (e.g. personal, work) --
#                              also disables stale-entry pruning for this run
#   -r, --repo <name>          Filter indexing to a specific repository name --
#                              also disables stale-entry pruning for this run
#   -p, --provider <name>      Override DEFAULT_AI for this indexing run only
#                              (gemini, claude, claude-code, local) -- e.g. to
#                              save Claude usage by indexing with Gemini instead
#                              without changing your actual default provider
#   --preview <repo>           Show cached metadata for one repo (by absolute path or
#                              bare repo name) and exit
#   -h, --help                 Show this help menu
#######################################
mt-hub() {
  local cache_file="$CACHE_DIR/.vcs_hub.json"
  mkdir -p "$(dirname "$cache_file")"
  [ ! -f "$cache_file" ] && echo "{}" > "$cache_file"

  local do_index=false
  local run_bg=false
  local force_index=false
  local update_missing=false
  local filter_type=""
  local filter_repo=""
  local provider_override=""

  # Argument parsing
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --index) do_index=true ;;
      -b | --bg | --background) run_bg=true ;;
      -f | --force) force_index=true ;;
      -u | --update) update_missing=true ;;
      -t | --type)
        filter_type="$2"
        shift
        ;;
      -r | --repo)
        filter_repo="$2"
        shift
        ;;
      -p | --provider)
        provider_override="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
        if [[ "$provider_override" != "gemini" && "$provider_override" != "claude" && "$provider_override" != "claude-code" && "$provider_override" != "local" ]]; then
          echo -e "${CB_RED}🚨 Invalid provider '$2'. Use gemini, claude, claude-code, or local.${C_RESET}"
          return 1
        fi
        shift
        ;;
      --preview)
        __mt_hub_preview "$2" "$cache_file"
        return 0
        ;;
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      *)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
    shift
  done

  if [ "$do_index" = true ]; then
    if [ "$run_bg" = true ]; then
      local log_out
      log_out="$LOG_DIR/indexer_$(date +%s).log"
      local cmd_str="__mt_hub_index \"$cache_file\" \"$filter_type\" \"$filter_repo\" \"$force_index\" \"$provider_override\" \"$update_missing\""
      __mt_bg_run "mt-hub-indexer" "$log_out" "$cmd_str"
    else
      __mt_hub_index "$cache_file" "$filter_type" "$filter_repo" "$force_index" "$provider_override" "$update_missing"
    fi
    return 0
  fi

  local search_dir="${VCS_ROOT:-$HOME/vcs}"
  local tmp_out
  tmp_out=$(mktemp)

  while IFS= read -r repo_path; do
    [ -z "$repo_path" ] && continue
    local repo_name
    repo_name=$(basename "$repo_path")

    local rel_path="${repo_path#"$search_dir"/}"
    local repo_type="Root"
    if [[ "$rel_path" == */* ]]; then
      repo_type="${rel_path%%/*}"
    fi
    repo_type="$(tr '[:lower:]' '[:upper:]' <<< "${repo_type:0:1}")${repo_type:1}"

    local branch
    branch=$(git -C "$repo_path" branch --show-current 2> /dev/null || echo "HEAD detached")
    [ -z "$branch" ] && branch="No commits"

    echo "${repo_type}|${repo_name}|${branch}|${repo_path}" >> "$tmp_out"
  done < <(__mt_hub_find_repos "$search_dir")

  sort -t'|' -k1,1 -k2,2 "$tmp_out" -o "$tmp_out"

  # See vcs_hub_table.awk for why the raw path rides along as a hidden
  # tab-delimited first field, recovered below via fzf's {1}.
  local awk_script="$HOME/.bash.d/lib/awk/vcs_hub_table.awk"
  local selected
  selected=$(awk -f "$awk_script" "$tmp_out" | fzf --ansi --delimiter=$'\t' --with-nth=2 --prompt="VCS Hub > " --header="TYPE            │ REPOSITORY                          │ BRANCH               " --preview="bash -c 'source ~/.bash.d/01-ui/01-colors.sh; source ~/.bash.d/20-vcs/53-vcs-insight.sh; __mt_hub_preview \"{1}\" \"$cache_file\"'")

  rm -f "$tmp_out"

  if [ -n "$selected" ]; then
    local target_path
    target_path=$(awk -F'\t' '{print $1}' <<< "$selected")
    echo -e "${CB_GREEN}📂 Navigating to: $target_path${C_RESET}"
    cd "$target_path" || true
  fi
}
