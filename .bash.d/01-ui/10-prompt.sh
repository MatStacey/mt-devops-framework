# shellcheck shell=bash
# ------------------------------------------
# Dynamic Shell Prompt (PS1) Generation
# ------------------------------------------
# ~/.bash.d/01-ui/10-prompt.sh

#######################################
# UI: Extract active GCP project and account for the prompt
# Globals:
#   __prompt_gcp_proj (Output)
#   __prompt_gcp_acct (Output)
#   __prompt_gcp_color (Output)
#######################################
__prompt_gcp_info() {
  local gcp_active="default"
  [ -f "$HOME/.config/gcloud/active_config" ] && read -r gcp_active < "$HOME/.config/gcloud/active_config"

  local gcp_config_file="$HOME/.config/gcloud/configurations/config_${gcp_active}"
  if [ -f "$gcp_config_file" ]; then
    while read -r key _ val; do
      [ "$key" = "project" ] && __prompt_gcp_proj="$val"
      [ "$key" = "account" ] && __prompt_gcp_acct="$val"
    done < "$gcp_config_file"
  fi

  if [ -n "$__prompt_gcp_acct" ]; then
    [ -f "$HOME/.config/gcloud/application_default_credentials.json" ] &&
      __prompt_gcp_color="${CB_GREEN}" ||
      __prompt_gcp_color="${CB_YELLOW}"
  else
    __prompt_gcp_color="${CB_RED}"
  fi
}

#######################################
# UI: Extract active Kubernetes context for the prompt
# Globals:
#   __prompt_k8s_ctx (Output)
#######################################
__prompt_k8s_info() {
  local kube_cfg="${KUBECONFIG:-$HOME/.kube/config}"
  if [ -f "$kube_cfg" ]; then
    while read -r key val; do
      if [ "$key" = "current-context:" ]; then
        __prompt_k8s_ctx="$val"
        break
      fi
    done < "$kube_cfg"
  fi
}

#######################################
# UI: Extract Git branch, status color, and remote URL for the prompt
# Globals:
#   __prompt_git_branch, __prompt_git_color, __prompt_git_url (Outputs)
#   __prompt_git_last_pwd, __prompt_git_url_cache (Internal Cache)
#######################################
__prompt_git_info() {
  local git_stat
  # Early exit if not a git repository
  git_stat=$(git status --porcelain -b --untracked-files=no 2> /dev/null) || return 0

  local first_line
  read -r first_line <<< "$git_stat"

  __prompt_git_branch="${first_line#\#\# }"
  __prompt_git_branch="${__prompt_git_branch%%...*}"
  __prompt_git_branch="${__prompt_git_branch%% *}"

  if [[ "$first_line" == *"behind"* ]]; then
    __prompt_git_color="${CB_RED}"
  elif [[ "$first_line" == *"ahead"* ]]; then
    __prompt_git_color="${CB_YELLOW}"
  elif [[ "$first_line" == *"..."* ]]; then
    __prompt_git_color="${CB_GREEN}"
  else __prompt_git_color="${CB_BLUE}"; fi

  [[ "$git_stat" == *$'\n'* ]] && __prompt_git_color="${CB_YELLOW}"

  if [ "$PWD" != "$__prompt_git_last_pwd" ]; then
    __prompt_git_last_pwd="$PWD"
    __prompt_git_url_cache=$(git config --get remote.origin.url 2> /dev/null)
  fi

  # Early exit if no upstream origin
  [ -z "$__prompt_git_url_cache" ] && return 0

  local clean_url="${__prompt_git_url_cache#*@}"
  clean_url="${clean_url#*//}"
  clean_url="${clean_url//://}"
  clean_url="${clean_url%.git}"
  local branch_path="/src/${__prompt_git_branch}/"
  case "$clean_url" in
    github.com*) branch_path="/tree/${__prompt_git_branch}/" ;;
    gitlab.com*) branch_path="/-/tree/${__prompt_git_branch}/" ;;
  esac
  __prompt_git_url="https://${clean_url}${branch_path}"
}

#######################################
# UI: Generate dynamic zero-lag prompt with clickable links and Git status
# Globals:
#   DISPLAY_SHOW_GCP, DISPLAY_SHOW_GIT, DISPLAY_SHOW_AI, DISPLAY_SHOW_K8S
#     -- per-segment visibility toggles set via mt-toggle-display
#     (default: true)
#   DISPLAY_SHOW_AI_MODEL -- whether the AI segment's model/version
#     parenthetical is shown, e.g. "AI: Gemini (3.6-flash)" vs "AI:
#     Gemini" (default: true)
#   DISPLAY_GCP_MODE -- which GCP identity field(s) the GCP segment
#     shows: project, account, or both (default: both)
#   DISPLAY_COMPACT_LABELS -- swap "GCP:"/"K8s:"/"AI:"/"Git:" text
#     labels for single-character icons (default: false)
#   DISPLAY_GIT_BRANCH_MAX_LEN -- truncate a longer branch name with an
#     ellipsis in the visible text only, never in the segment's
#     hyperlink; 0 disables truncation (default: 30)
# Outputs:
#   Prints formatted prompt string to STDOUT
#######################################
__cloud_ps1() {
  local e=$'\e' np_start=$'\001' np_end=$'\002'
  local color_reset="${np_start}${C_RESET}${np_end}"

  local __prompt_gcp_proj="" __prompt_gcp_acct="" __prompt_gcp_color=""
  local __prompt_k8s_ctx="" __prompt_git_branch="" __prompt_git_color="" __prompt_git_url=""

  local show_gcp="${DISPLAY_SHOW_GCP:-true}" show_git="${DISPLAY_SHOW_GIT:-true}"
  local show_ai="${DISPLAY_SHOW_AI:-true}" show_k8s="${DISPLAY_SHOW_K8S:-true}"
  local compact="${DISPLAY_COMPACT_LABELS:-false}"

  local label_gcp="GCP: " label_k8s="K8s: " label_ai="AI: " label_git="Git: "
  if [ "$compact" = "true" ]; then
    label_gcp="☁️ "
    label_k8s="⎈ "
    label_ai="🤖 "
    label_git="🌿 "
  fi

  [ "$show_gcp" = "true" ] && __prompt_gcp_info
  [ "$show_k8s" = "true" ] && __prompt_k8s_info
  [ "$show_git" = "true" ] && __prompt_git_info

  local out=""

  # 1. Format GCP Segment -- gcp_display config (DISPLAY_GCP_MODE) picks
  # which identity field(s) show. "both" prefers the project (linking to
  # its console dashboard) and, when the account is also known, appends
  # just its local-part (before "@") rather than the full email -- the
  # domain rarely adds signal once a project is already shown, and full
  # emails are the single biggest contributor to prompt line length.
  # "account" alone keeps the full email, since there's nothing else to
  # disambiguate it from.
  if [ "$show_gcp" = "true" ]; then
    local gcp_mode="${DISPLAY_GCP_MODE:-both}"
    local gcp_text="" gcp_linkable=false

    if [ "$gcp_mode" != "account" ] && [ -n "$__prompt_gcp_proj" ]; then
      gcp_text="${label_gcp}${__prompt_gcp_proj}"
      gcp_linkable=true
      [ "$gcp_mode" = "both" ] && [ -n "$__prompt_gcp_acct" ] &&
        gcp_text="${gcp_text} (${__prompt_gcp_acct%%@*})"
    elif [ "$gcp_mode" != "project" ] && [ -n "$__prompt_gcp_acct" ]; then
      gcp_text="${label_gcp}${__prompt_gcp_acct}"
    fi

    if [ -n "$gcp_text" ]; then
      local color_code="${np_start}${__prompt_gcp_color}${np_end}"
      if [ "$gcp_linkable" = true ]; then
        local gcp_url="https://console.cloud.google.com/home/dashboard?project=${__prompt_gcp_proj}"
        local link_start="${np_start}${e}]8;;${gcp_url}${e}\\${np_end}"
        local link_end="${np_start}${e}]8;;${e}\\${np_end}"
        out="${link_start}${color_code}${gcp_text}${color_reset}${link_end}"
      else
        out="${color_code}${gcp_text}${color_reset}"
      fi
    fi
  fi

  # 2. Format Kubernetes Segment (Filtering out literal quotes)
  if [ "$show_k8s" = "true" ] && [ -n "$__prompt_k8s_ctx" ] && [ "$__prompt_k8s_ctx" != '""' ] && [ "$__prompt_k8s_ctx" != "''" ] && [ "$__prompt_k8s_ctx" != "null" ]; then
    [ -n "$out" ] && out="${out} | "
    out="${out}${label_k8s}${__prompt_k8s_ctx}"
  fi

  # 3. Format AI Configuration Segment -- show_ai_model (DISPLAY_SHOW_AI_MODEL)
  # picks whether the model/version parenthetical is appended, e.g.
  # "AI: Gemini (3.6-flash)" vs just "AI: Gemini". Colored red instead
  # of the default cyan when AI is enabled but the active provider has
  # no API key configured -- catches a broken setup (AI calls will fail)
  # at a glance instead of only on first use. "local" needs no key and
  # is never checked, since verifying it's actually reachable would mean
  # a network call on every prompt render.
  if [ "${AI_ENABLED:-true}" = "true" ] && [ "$show_ai" = "true" ]; then
    [ -n "$out" ] && out="${out} | "
    local provider="${DEFAULT_AI:-gemini}"
    local show_ai_model="${DISPLAY_SHOW_AI_MODEL:-true}"
    local ai_text="" ai_color="${CB_CYAN}"
    if [ "$provider" = "gemini" ]; then
      ai_text="${label_ai}Gemini"
      [ "$show_ai_model" = "true" ] && ai_text="${ai_text} (${GEMINI_VERSION#gemini-})"
      [ -z "$GEMINI_API_KEY" ] && ai_color="${CB_RED}"
    elif [ "$provider" = "claude" ]; then
      ai_text="${label_ai}Claude"
      [ "$show_ai_model" = "true" ] && ai_text="${ai_text} (${CLAUDE_VERSION#claude-})"
      [ -z "$CLAUDE_API_KEY" ] && ai_color="${CB_RED}"
    elif [ "$provider" = "local" ]; then
      ai_text="${label_ai}Local"
      [ "$show_ai_model" = "true" ] && ai_text="${ai_text} (${LOCAL_AI_MODEL})"
    fi
    out="${out}${np_start}${ai_color}${np_end}${ai_text}${color_reset}"
  fi

  # 4. Format Git Segment -- DISPLAY_GIT_BRANCH_MAX_LEN truncates only
  # the visible branch name; the hyperlink always targets the real,
  # untruncated branch.
  if [ "$show_git" = "true" ] && [ -n "$__prompt_git_branch" ]; then
    [ -n "$out" ] && out="${out} | "
    local branch_max_len="${DISPLAY_GIT_BRANCH_MAX_LEN:-30}"
    local git_display_branch="$__prompt_git_branch"
    if [ "$branch_max_len" -gt 0 ] 2> /dev/null && [ "${#git_display_branch}" -gt "$branch_max_len" ]; then
      git_display_branch="${git_display_branch:0:$((branch_max_len - 1))}…"
    fi
    local git_text="${label_git}${git_display_branch}"
    if [ -n "$__prompt_git_url" ]; then
      git_text="${np_start}${e}]8;;${__prompt_git_url}${e}\\${np_end}${git_text}${np_start}${e}]8;;${e}\\${np_end}"
    fi
    out="${out}${np_start}${__prompt_git_color}${np_end}${git_text}${color_reset}"
  fi

  [ -n "$out" ] && echo -n "[${out}] "
}
