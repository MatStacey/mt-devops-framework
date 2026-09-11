# shellcheck shell=bash
# ------------------------------------------
# AI Workflows & LLM API Integration
# ------------------------------------------
# ~/.bash.d/30-ai/60-ai.sh

if [[ -z "${URI_GEMINI_MODELS:-}" ]]; then readonly URI_GEMINI_MODELS="https://generativelanguage.googleapis.com/v1beta/models"; fi
if [[ -z "${URI_CLAUDE_MESSAGES:-}" ]]; then readonly URI_CLAUDE_MESSAGES="https://api.anthropic.com/v1/messages"; fi
if [[ -z "${URI_CLAUDE_MODELS:-}" ]]; then readonly URI_CLAUDE_MODELS="https://api.anthropic.com/v1/models"; fi

#######################################
# AI: Calculate next available minor patch version for a generated file
# Arguments:
#   $1 - Base file path without extension
#   $2 - File extension
# Outputs:
#   Prints semantic version string (e.g. v1.0.3) to STDOUT
#######################################
_ai_get_next_version() {
  local base_path="$1" ext="$2" major=1 minor=0 patch=0
  while [[ -f "${base_path}-v${major}.${minor}.${patch}.${ext}" ]]; do patch=$((patch + 1)); done
  echo "v${major}.${minor}.${patch}"
}

#######################################
# AI: Compile local codebase files into a single context payload
# Globals:
#   EXPORT_BLOCKLIST
# Arguments:
#   $1 - Explicit target file to serialize
#   $2 - Boolean flag to serialize entire active directory
# Outputs:
#   Prints temporary context file path to STDOUT
# Returns:
#   0 on success, 1 on error or user abort
#######################################
__ai_build_context() {
  local target_file="$1" export_context="$2" context_file=""

  if [ -n "$target_file" ]; then
    [ ! -f "$target_file" ] && {
      echo "🚨 Error: Target context file '$target_file' not found." >&2
      return 1
    }
    echo "📦 Compiling target file '$target_file' for context..." >&2
    context_file=$(mktemp)
    echo "==> ./$target_file <==" >> "$context_file"
    command cat "$target_file" >> "$context_file"
    echo "✅ File context attached." >&2
    echo "$context_file"
    return 0
  fi

  [ "$export_context" != true ] && return 0

  local max_context_files="${AI_MAX_CONTEXT_FILES:-1000}"
  local file_count
  file_count=$(find . -type f -not -path "*/\.git/*" -not -path "*/node_modules/*" -not -path "*/venv/*" -not -path "*/\.terraform/*" 2> /dev/null | head -n "$max_context_files" | wc -l)
  if [ "$file_count" -ge "$max_context_files" ]; then
    echo -e "\n${C_YELLOW}⚠️  Warning: This directory contains ${max_context_files}+ files. AI context may exceed limits.${C_RESET}" >&2
    read -p "Proceed anyway? [y/N] " -n 1 -r < /dev/tty
    echo > /dev/tty
    [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ] && {
      echo "🛑 Aborted." >&2
      return 1
    }
  fi

  echo "📦 Compiling local directory codebase for context..." >&2
  context_file=$(mktemp)
  local blocklist="${EXPORT_BLOCKLIST:-(secret|token|credential|password|passwd|id_rsa|id_ed25519|\.pem$|\.p12$|\.pfx$|\.npmrc$|\.netrc$|kubeconfig|service.?account.*\.json$|.*-key.*\.json$|\.tfvars(\.json)?$|(^|/)\.env(\..+)?$|lock\.hcl|__pycache__)}"
  find . -type f -not -path "*/\.git/*" -not -path "*/node_modules/*" -not -path "*/venv/*" -not -path "*/\.terraform/*" -print0 | while IFS= read -r -d '' file; do
    local clean_file="${file#./}"
    local lower_file="${clean_file,,}"
    [[ "$lower_file" =~ \.(png|jpe?g|gif|ico|pdf|zip|tar|gz|mp4|mp3|wav|exe|dll|so|class|jar|bin|o|pyc|tfstate)$ ]] && continue
    [[ "$lower_file" =~ $blocklist ]] && continue

    {
      echo "==> ./$clean_file <=="
      command cat "$file"
      echo -e "\n"
    } >> "$context_file"
  done
  echo "✅ Codebase context attached." >&2
  echo "$context_file"
}

#######################################
# AI: Detect a rate-limit error in a provider's response, run the shared
# bypass/skip/retry prompt, and sleep for the appropriate cooldown. Shared
# by every __ai_query_* provider function so the retry UX stays identical
# across providers.
# Arguments:
#   $1 - API error message text
#   $2 - Original user prompt (checked for the git-diff commit-message flow)
#   $3 - Current attempt number
#   $4 - Max retry attempts
#   $5 - ERE alternation of substrings that indicate a rate-limit error
#   $6 - Default cooldown in seconds if the error carries no retry hint
# Returns:
#   0  - rate limit handled and cooldown slept; caller should retry
#   1  - not a rate-limit error; caller should stop retrying
#   99 - user chose to bypass/skip; caller should return 99 immediately
#######################################
__ai_handle_rate_limit() {
  local err_msg="$1" prompt="$2" attempt="$3" max_retries="$4" quota_pattern="$5" wait_time="$6"

  [[ "$err_msg" =~ $quota_pattern ]] || return 1

  if [[ "$err_msg" =~ retry[[:space:]]in[[:space:]]([0-9]+) ]]; then
    wait_time=$((BASH_REMATCH[1] + 2))
  fi

  echo -e "\n${CB_YELLOW}⏳ AI Rate limit hit! Required cooldown: ${wait_time}s (Attempt $attempt/$max_retries)${C_RESET}" >&2
  local user_input=""

  if [[ "$prompt" == "Analyze this git diff and group the changes"* ]]; then
    read -r -p "   Enter a commit message to bypass AI and push now (or press Enter to wait & retry): " user_input < /dev/tty
    if [ -n "$user_input" ]; then
      echo -e "${CB_GREEN}💡 Bypassing AI and committing manually...${C_RESET}" >&2
      git add . > /dev/null 2>&1
      git commit -m "$user_input" > /dev/null 2>&1
      return 99
    fi
  else
    read -r -p "   Press Enter to wait & retry, or type 'skip' to abort this specific AI task: " user_input < /dev/tty
    if [[ "${user_input,,}" == "skip" ]]; then
      echo -e "${CB_GREEN}💡 Skipping AI task...${C_RESET}" >&2
      return 99
    fi
  fi

  echo "⏳ Waiting ${wait_time}s..." >&2
  sleep "$wait_time"
  return 0
}

#######################################
# AI: Query Google Gemini API with retries and rate-limit handling
# Globals:
#   GEMINI_API_KEY, GEMINI_VERSION, GEMINI_EXTENDED, URI_GEMINI_MODELS,
#   AI_SYSTEM_PROMPT, SECRETS_MANAGER
# Arguments:
#   $1 - User prompt string
#   $2 - Output title context
#   $3 - Path to compiled context file
#   $4 - Override model version
#   $5 - Boolean flag to force extended reasoning model
# Outputs:
#   Prints API text response to STDOUT
# Returns:
#   0 on success, 99 on user skip, 100 on hard failure
#######################################
__ai_query_gemini() {
  local prompt="$1" title="$2" context_file="$3" req_version="$4" req_extended="$5"
  [ -z "${GEMINI_API_KEY}" ] && {
    echo "🚨 Error: GEMINI_API_KEY is not set. Run 'mt-add-gemini-key'." >&2
    return 1
  }

  local default_model="gemini-3.6-flash"
  local final_model="${GEMINI_VERSION:-$default_model}"
  local is_extended="${GEMINI_EXTENDED:-false}"
  [ "$req_extended" = true ] && is_extended="true"

  if [ -n "$req_version" ]; then
    local base_prefix="${default_model%-flash}"
    [[ "$final_model" =~ ^(gemini-[0-9]+\.[0-9]+) ]] && base_prefix="${BASH_REMATCH[1]}"
    final_model="${base_prefix}-${req_version}"
  fi

  if [ "$is_extended" = "true" ]; then
    [[ "$final_model" == *-flash ]] && final_model="${final_model%-flash}-pro"
    [[ "$final_model" == *-flash-lite ]] && final_model="${final_model%-flash-lite}-pro"
  fi

  local api_url="${URI_GEMINI_MODELS}/${final_model}:generateContent"

  local tmp_prompt
  tmp_prompt=$(mktemp)
  echo -n "$prompt" > "$tmp_prompt"

  local prompt_json
  if [ -f "$context_file" ]; then
    prompt_json=$(jq -n --arg t "${title}" --rawfile p "$tmp_prompt" --rawfile ctx "$context_file" '{ contents: [{ parts: [{ text: (if $t != "" then "Requested Title: " + $t + "\n" else "" end + "Prompt: " + $p + "\n\n=== LOCAL DIRECTORY CONTEXT ===\n" + $ctx) }] }] }')
  else
    prompt_json=$(jq -n --arg t "${title}" --rawfile p "$tmp_prompt" '{ contents: [{ parts: [{ text: (if $t != "" then "Requested Title: " + $t + "\n" else "" end + "Prompt: " + $p) }] }] }')
  fi
  rm -f "$tmp_prompt"

  local tmp_sys
  tmp_sys=$(mktemp)
  echo -n "${AI_SYSTEM_PROMPT}" > "$tmp_sys"
  local system_json
  system_json=$(jq -n --rawfile sp "$tmp_sys" '{ systemInstruction: { parts: [{ text: $sp }] } }')
  rm -f "$tmp_sys"

  local payload_file
  payload_file=$(mktemp)
  jq -s '.[0] * .[1] * .[2]' "$HOME/.bash.d/config/ai/gemini-config.json" <(echo "$system_json") <(echo "$prompt_json") > "$payload_file"

  echo "⏳ Querying Gemini ($final_model)..." >&2
  local response="" content=""
  local attempt=1 max_retries="${AI_MAX_RETRIES:-3}"

  while [ "$attempt" -le "$max_retries" ]; do
    response=$(curl -s -X POST "${api_url}" -H "x-goog-api-key: ${GEMINI_API_KEY}" -H 'Content-Type: application/json' -d @"$payload_file")
    content=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty')

    [ -n "$content" ] && break

    local err_msg
    err_msg=$(echo "$response" | jq -r '.error.message // "Unknown error"')

    __ai_handle_rate_limit "$err_msg" "$prompt" "$attempt" "$max_retries" "Quota exceeded|429" 25
    case $? in
      0) ((attempt++)) ;;
      99) return 99 ;;
      *) break ;;
    esac
  done

  rm -f "$payload_file"

  [ -z "$content" ] && {
    echo -e "\n${CB_RED}🚨 Error: AI failed after $max_retries retries. Aborting process.${C_RESET}" >&2
    return 100
  }
  python3 "$SECRETS_MANAGER" touch "GEMINI_API_KEY"
  echo "$content"
}

#######################################
# AI: Query Anthropic Claude API with retries and rate-limit handling
# Globals:
#   CLAUDE_API_KEY, CLAUDE_VERSION, URI_CLAUDE_MESSAGES, AI_SYSTEM_PROMPT,
#   SECRETS_MANAGER
# Arguments:
#   $1 - User prompt string
#   $2 - Output title context
#   $3 - Path to compiled context file
#   $4 - Override model version
# Outputs:
#   Prints API text response to STDOUT
# Returns:
#   0 on success, 99 on user skip, 100 on hard failure
#######################################
__ai_query_claude() {
  local prompt="$1" title="$2" context_file="$3" req_version="$4"
  [ -z "${CLAUDE_API_KEY}" ] && {
    echo "🚨 Error: CLAUDE_API_KEY is not set. Run 'mt-add-claude-key'." >&2
    return 1
  }

  local final_model="${req_version:-${CLAUDE_VERSION:-claude-sonnet-5}}"
  local api_url="${URI_CLAUDE_MESSAGES}"

  local tmp_prompt
  tmp_prompt=$(mktemp)
  echo -n "$prompt" > "$tmp_prompt"

  local prompt_json
  if [ -f "$context_file" ]; then
    prompt_json=$(jq -n --arg t "${title}" --rawfile p "$tmp_prompt" --rawfile ctx "$context_file" '{ messages: [{ role: "user", content: (if $t != "" then "Requested Title: " + $t + "\n" else "" end + "Prompt: " + $p + "\n\n=== LOCAL DIRECTORY CONTEXT ===\n" + $ctx) }] }')
  else
    prompt_json=$(jq -n --arg t "${title}" --rawfile p "$tmp_prompt" '{ messages: [{ role: "user", content: (if $t != "" then "Requested Title: " + $t + "\n" else "" end + "Prompt: " + $p) }] }')
  fi
  rm -f "$tmp_prompt"

  local tmp_sys
  tmp_sys=$(mktemp)
  echo -n "${AI_SYSTEM_PROMPT}" > "$tmp_sys"
  local system_json
  system_json=$(jq -n --rawfile sp "$tmp_sys" '{ system: $sp }')
  rm -f "$tmp_sys"

  local payload_file
  payload_file=$(mktemp)
  jq -s '.[0] * .[1] * .[2] * {model: $model}' "$HOME/.bash.d/config/ai/claude-config.json" <(echo "$system_json") <(echo "$prompt_json") --arg model "$final_model" > "$payload_file"

  echo "⏳ Querying Claude ($final_model)..." >&2
  local response="" content=""
  local attempt=1 max_retries="${AI_MAX_RETRIES:-3}"

  while [ "$attempt" -le "$max_retries" ]; do
    response=$(curl -s -X POST "${api_url}" -H "x-api-key: ${CLAUDE_API_KEY}" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" -d @"$payload_file")
    content=$(echo "$response" | jq -r '.content[0].text // empty')

    [ -n "$content" ] && break

    local err_msg
    err_msg=$(echo "$response" | jq -r '.error.message // "Unknown error"')

    __ai_handle_rate_limit "$err_msg" "$prompt" "$attempt" "$max_retries" "rate_limit_error|429|Overloaded" 20
    case $? in
      0) ((attempt++)) ;;
      99) return 99 ;;
      *) break ;;
    esac
  done

  rm -f "$payload_file"

  [ -z "$content" ] && {
    echo -e "\n${CB_RED}🚨 Error: AI failed after $max_retries retries. Aborting process.${C_RESET}" >&2
    return 100
  }
  python3 "$SECRETS_MANAGER" touch "CLAUDE_API_KEY"
  echo "$content"
}

#######################################
# AI: Query Claude via a headless, non-interactive Claude Code invocation
# ('claude -p') instead of the raw Messages API -- uses whichever account
# Claude Code itself is logged into (a personal Claude.ai subscription,
# not just a metered Console API key), and needs no CLAUDE_API_KEY at
# all. Run with --restricted (strips Bash/code-execution tools) and
# --permission-prompts none (deny anything that would otherwise prompt)
# since this is meant to be a plain text-in/text-out completion, not an
# agentic session that can act on the caller's filesystem.
# Globals:
#   CLAUDE_CODE_VERSION, AI_SYSTEM_PROMPT
# Arguments:
#   $1 - User prompt string
#   $2 - Output title context
#   $3 - Path to compiled context file
#   $4 - Override model alias/name (e.g. "sonnet", "opus", or a full model ID)
# Outputs:
#   Prints response text to STDOUT
# Returns:
#   0 on success, 1 if the 'claude' CLI isn't installed, 100 on hard failure
#######################################
__ai_query_claude_code() {
  local prompt="$1" title="$2" context_file="$3" req_version="$4"

  if ! command -v claude > /dev/null 2>&1; then
    echo "🚨 Error: The 'claude' CLI is not installed or not on PATH." >&2
    return 1
  fi

  local final_model="${req_version:-${CLAUDE_CODE_VERSION:-}}"

  local full_prompt="Prompt: ${prompt}"
  [ -n "$title" ] && full_prompt="Requested Title: ${title}"$'\n'"${full_prompt}"
  if [ -f "$context_file" ]; then
    full_prompt="${full_prompt}"$'\n\n=== LOCAL DIRECTORY CONTEXT ===\n'"$(command cat "$context_file")"
  fi

  local -a claude_cli_args=(-p "$full_prompt" --output-format json --restricted --permission-prompts none)
  [ -n "$final_model" ] && claude_cli_args+=(--model "$final_model")
  [ -n "${AI_SYSTEM_PROMPT:-}" ] && claude_cli_args+=(--system-prompt "$AI_SYSTEM_PROMPT")

  echo "⏳ Querying Claude Code (${final_model:-default model})..." >&2

  local response is_error content
  response=$(claude "${claude_cli_args[@]}" 2>&1)
  is_error=$(echo "$response" | jq -r '.is_error' 2> /dev/null)
  content=$(echo "$response" | jq -r '.result // empty' 2> /dev/null)

  if [ "$is_error" != "false" ] || [ -z "$content" ]; then
    echo -e "\n${CB_RED}🚨 Error: Claude Code query failed.${C_RESET}" >&2
    echo "$response" >&2
    return 100
  fi

  echo "$content"
}

#######################################
# AI: Save generated LLM code payloads into structured directory trees
# Globals:
#   AI_WORKSPACE_DIR
# Arguments:
#   $1 - Explicit out file path
#   $2 - JSON category field
#   $3 - JSON language field
#   $4 - JSON extension field
#   $5 - Kebab-case title string
#   $6 - Raw code payload
# Outputs:
#   Prints final saved file path to STDOUT
#######################################
__ai_save_output() {
  local explicit_out_file="$1" category="$2" lang="$3" ext="$4" final_title="$5" code="$6" target_file_path=""

  if [ -n "$explicit_out_file" ]; then
    mkdir -p "$(dirname "$explicit_out_file")"
    target_file_path="$explicit_out_file"
  else
    local target_dir="" base_name=""
    case "$category" in
      gcloud)
        target_dir="${AI_WORKSPACE_DIR}/generated/gcloud"
        base_name="${target_dir}/${final_title}"
        ;;
      script)
        target_dir="${AI_WORKSPACE_DIR}/generated/scripts/${lang}"
        base_name="${target_dir}/${final_title}"
        ;;
      project | *)
        target_dir="${AI_WORKSPACE_DIR}/generated/projects"
        base_name="${target_dir}/${final_title}-${lang}"
        ;;
    esac

    mkdir -p "$target_dir"
    local version
    version=$(_ai_get_next_version "$base_name" "$ext")
    target_file_path="${base_name}-${version}.${ext}"
  fi

  echo "$code" > "$target_file_path"
  echo "$target_file_path"
}

#######################################
# AI: Parse standard single JSON object response and save if required
# Arguments:
#   $1 - Content string
#   $2 - Provider name
#   $3 - Original title
#   $4 - Explicit out file
#######################################
__ai_parse_response() {
  local content="$1" provider="$2" title="$3" explicit_out_file="$4"

  local clean_content
  clean_content=$(echo "$content" | python3 "$HOME/.bash.d/lib/python/ai_parse_response.py" 2> /dev/null)

  local category lang ext code msg gen_title
  category=$(echo "$clean_content" | jq -r '.category // empty')
  lang=$(echo "$clean_content" | jq -r '.language // empty')
  ext=$(echo "$clean_content" | jq -r '.extension // empty')
  code=$(echo "$clean_content" | jq -r '.code // empty')
  msg=$(echo "$clean_content" | jq -r '.message // empty')
  gen_title=$(echo "$clean_content" | jq -r '.title // empty')

  local final_title="${title:-$gen_title}"
  final_title="${final_title:-untitled}"

  if [[ -z "$category" || "$category" == "chat" || "$category" == "null" ]]; then
    [[ "$msg" == "No IAM implementations required"* ]] &&
      echo -e "${CB_ORANGE}${provider^}:${C_RESET} No IAM implementations required" ||
      echo -e "${CB_ORANGE}${provider^}:${C_RESET} ${msg:-$content}"
    return 0
  fi

  local saved_path
  saved_path=$(__ai_save_output "$explicit_out_file" "$category" "$lang" "$ext" "$final_title" "$code")

  echo -e "${CB_ORANGE}${provider^}:${C_RESET} $msg"
  echo -e "${C_GREEN}Saved to:${C_RESET} $saved_path"
}

#######################################
# AI: Extract a JSON array from raw LLM output text
# Arguments:
#   $1 - Raw LLM text payload
# Outputs:
#   Prints parsed JSON array string to STDOUT
#######################################
__ai_extract_json_array() {
  echo "$1" | python3 "$HOME/.bash.d/lib/python/ai_extract_json_array.py" 2> /dev/null
}

#######################################
# AI: Dispatch a query to the given provider's own query function and
# return its raw text response -- no save-to-file/category
# post-processing. Shared by 'ai' (which pipes this through
# __ai_parse_response afterwards) and any caller that needs the model's
# literal text back untouched (e.g. mt-hub's repo summarizer), since
# routing through the public 'ai' command itself would collide with its
# save-generated-code branch whenever the caller's own prompt asks for a
# JSON schema that happens to include a non-"chat" "category" field --
# __ai_parse_response would intercept it as generated code, write it to
# a file, and return only "Saved to: <path>" instead of the JSON text.
# Arguments:
#   $1 - Provider name (gemini, claude, claude-code, local)
#   $2 - User prompt string
#   $3 - Output title context
#   $4 - Path to compiled context file
#   $5 - Override model version/alias
#   $6 - Boolean flag to force extended reasoning mode (gemini only)
# Outputs:
#   Prints the provider's raw text response to STDOUT
# Returns:
#   0 on success, or the failing provider function's own non-zero code
#######################################
__ai_query_provider() {
  local provider="$1" prompt="$2" title="$3" context_file="$4" req_version="$5" req_extended="$6"
  case "$provider" in
    gemini) __ai_query_gemini "$prompt" "$title" "$context_file" "$req_version" "$req_extended" ;;
    claude) __ai_query_claude "$prompt" "$title" "$context_file" "$req_version" ;;
    claude-code) __ai_query_claude_code "$prompt" "$title" "$context_file" "$req_version" ;;
    local) __ai_query_local "$prompt" "$title" "$context_file" "$req_version" ;;
    *)
      echo "🚨 Error: Invalid provider '$provider'." >&2
      return 1
      ;;
  esac
}

#######################################
# AI: Query configured LLM with prompt and optional context
# Globals:
#   DEFAULT_AI
# Usage: ai [OPTIONS] <prompt>
# Options:
#   -m <model>     Override provider model (gemini, claude, claude-code, local)
#   -t <title>     Set context title
#   -e             Attach entire active directory as context
#   -f <file>      Attach a single file as context
#   -o <out_file>  Save output directly to specified file
#   -v <version>   Override model version
#   -x             Force extended reasoning mode
#   -h, --help     Show this help menu
#######################################
ai() {
  [[ "$1" == "-h" || "$1" == "--help" ]] && {
    mt-help "${FUNCNAME[0]}"
    return 0
  }

  local title="" export_context=false target_file="" explicit_out_file="" req_version="" req_extended=false
  local provider="${DEFAULT_AI:-gemini}" prompt=""

  OPTIND=1
  while getopts "m:t:ef:o:v:x" opt; do
    case ${opt} in
      m) provider="$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')" ;;
      t) title=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]' | tr ' ' '-') ;;
      e) export_context=true ;;
      f) target_file="$OPTARG" ;;
      o) explicit_out_file="$OPTARG" ;;
      v) req_version="$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')" ;;
      x) req_extended=true ;;
      \?)
        echo "Usage: ai [-m gemini|claude|claude-code|local] [-t title] [-e] [-f file] [-o out_file] [-v version] [-x] <prompt>" >&2
        return 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
  prompt="$*"

  [ -z "${prompt}" ] && {
    echo "Usage: ai [-m gemini|claude|claude-code|local] [-t title] [-e] [-f file] [-o out_file] [-v version] [-x] <your question>" >&2
    return 1
  }

  local context_file
  if ! context_file=$(__ai_build_context "$target_file" "$export_context"); then
    return 1
  fi

  local content=""
  if ! content=$(__ai_query_provider "$provider" "$prompt" "$title" "$context_file" "$req_version" "$req_extended"); then
    return 1
  fi

  [ -f "$context_file" ] && rm -f "$context_file"

  __ai_parse_response "$content" "$provider" "$title" "$explicit_out_file"
}

#######################################
# AI: Query local LLM endpoint (OpenAI-compatible)
# Globals:
#   LOCAL_AI_BASE_URL, LOCAL_AI_API_KEY, LOCAL_AI_MODEL, AI_SYSTEM_PROMPT
# Arguments:
#   $1 - User prompt string
#   $2 - Output title context
#   $3 - Path to compiled context file
#   $4 - Override model version
# Outputs:
#   Prints API text response to STDOUT
# Returns:
#   0 on success, 1 on curl failure or timeout
#######################################
__ai_query_local() {
  local prompt="$1" title="$2" context_file="$3" req_version="$4"
  local base_url="${LOCAL_AI_BASE_URL:-http://localhost:11434/v1}"
  local api_key="${LOCAL_AI_API_KEY:-ollama}"
  local final_model="${req_version:-${LOCAL_AI_MODEL:-llama3.2}}"

  local system_prompt="${AI_SYSTEM_PROMPT:-You are a helpful assistant.}"

  local tmp_prompt
  tmp_prompt=$(mktemp)
  echo -n "$prompt" > "$tmp_prompt"

  local tmp_sys
  tmp_sys=$(mktemp)
  echo -n "$system_prompt" > "$tmp_sys"

  local payload_file
  payload_file=$(mktemp)

  if [ -f "$context_file" ]; then
    jq -n \
      --arg model "$final_model" \
      --rawfile sys "$tmp_sys" \
      --arg t "$title" \
      --rawfile p "$tmp_prompt" \
      --rawfile ctx "$context_file" \
      '{
        model: $model,
        messages: [
          {role: "system", content: $sys},
          {role: "user", content: (if $t != "" then "Requested Title: " + $t + "\n" else "" end + "Prompt: " + $p + "\n\n=== LOCAL DIRECTORY CONTEXT ===\n" + $ctx)}
        ]
      }' > "$payload_file"
  else
    jq -n \
      --arg model "$final_model" \
      --rawfile sys "$tmp_sys" \
      --arg t "$title" \
      --rawfile p "$tmp_prompt" \
      '{
        model: $model,
        messages: [
          {role: "system", content: $sys},
          {role: "user", content: (if $t != "" then "Requested Title: " + $t + "\n" else "" end + "Prompt: " + $p)}
        ]
      }' > "$payload_file"
  fi

  rm -f "$tmp_prompt" "$tmp_sys"

  echo "⏳ Querying Local LLM ($final_model at $base_url)..." >&2
  local response
  response=$(curl -s -X POST "${base_url}/chat/completions" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d @"$payload_file")

  rm -f "$payload_file"
  local content
  content=$(echo "$response" | jq -r '.choices[0].message.content // empty')

  [ -z "$content" ] && {
    echo "🚨 Error: Failed to get a valid response from Local LLM." >&2
    echo "$response" | jq -r '.error.message // "Unknown error"' >&2
    return 1
  }
  echo "$content"
}

#######################################
# AI: Find local implementation of a shell function
# Arguments:
#   $1 - Command/function name
# Outputs:
#   Prints source file path
#######################################
__ai_find_command_source() {
  local cmd="$1"

  grep -R "^[[:space:]]*${cmd}()" \
    "$HOME/.bash.d" \
    2> /dev/null |
    head -n1 |
    cut -d: -f1
}

#######################################
# AI: Explain a terminal command in detail, grounding the explanation in
# its actual local implementation when one is found under ~/.bash.d
# Usage: ai-explain "<command>"
# Arguments:
#   $1 - Command string to explain
#######################################
ai-explain() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [ -z "$1" ]; then
    echo "Usage: ai-explain \"<command>\""
    return 1
  fi

  local cmd="$1"
  local source_file

  mt-log INFO "Looking up implementation: $cmd..."

  source_file=$(__ai_find_command_source "$cmd")

  if [ -n "$source_file" ]; then
    mt-log INFO "Found implementation: $source_file"

    ai \
      -t "command-explanation" \
      -f "$source_file" \
      "Explain the command '$cmd' from the supplied implementation.

Cover:
- purpose of the command
- arguments and flags
- variables used
- helper functions called
- side effects
- examples of usage"
  else
    mt-log INFO "No local implementation found, explaining command syntax only..."

    ai \
      -t "command-explanation" \
      "Explain this terminal command in detail, breaking down what each flag and argument does: $cmd"
  fi
}

#######################################
# AI: Debug and explain the last failed terminal command
#######################################
mt-ai-debug() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local last_cmd
  last_cmd=$(fc -ln -2 | head -n 1 | xargs)

  mt-log INFO "Re-running and debugging: $last_cmd..."
  local err_out
  err_out=$(eval "$last_cmd" 2>&1 > /dev/null)

  if [ -z "$err_out" ]; then
    mt-log SUCCESS "Command executed successfully. No errors to debug!"
  else
    ai -t "debug-error" "The command \`$last_cmd\` failed with this stderr output:\n\n$err_out\n\nPlease explain why it failed and provide the exact command to fix it."
  fi
}

#######################################
# AI: Extract one rate-limit header field from a curl-dumped headers file
# Arguments:
#   $1 - Path to the headers file
#   $2 - Header name to extract (e.g. anthropic-ratelimit-requests-limit)
# Outputs:
#   Prints the header's value, or empty if not present
#######################################
__mt_ai_quota_extract_header() {
  local headers_file="$1" header_name="$2"
  grep -i "${header_name}:" "$headers_file" | awk '{print $2}' | tr -d '\r'
}

#######################################
# AI: Print Claude's rate-limit header table from a headers file
# Arguments:
#   $1 - Path to the curl-dumped headers file
#######################################
__mt_ai_quota_print_claude_headers() {
  local headers_file="$1"
  local req_limit req_rem in_tok_limit in_tok_rem out_tok_limit out_tok_rem
  req_limit=$(__mt_ai_quota_extract_header "$headers_file" "anthropic-ratelimit-requests-limit")
  req_rem=$(__mt_ai_quota_extract_header "$headers_file" "anthropic-ratelimit-requests-remaining")
  in_tok_limit=$(__mt_ai_quota_extract_header "$headers_file" "anthropic-ratelimit-input-tokens-limit")
  in_tok_rem=$(__mt_ai_quota_extract_header "$headers_file" "anthropic-ratelimit-input-tokens-remaining")
  out_tok_limit=$(__mt_ai_quota_extract_header "$headers_file" "anthropic-ratelimit-output-tokens-limit")
  out_tok_rem=$(__mt_ai_quota_extract_header "$headers_file" "anthropic-ratelimit-output-tokens-remaining")

  echo -e "  ${CB_YELLOW}| Metric               | Limit         | Remaining      |${C_RESET}"
  echo -e "  ${CB_BLUE}|----------------------|---------------|----------------|${C_RESET}"
  echo -e "  | Requests (RPM)       | $(printf '%-13s' "${req_limit:-Unknown}") | $(printf '%-14s' "${req_rem:-Unknown}") |"
  echo -e "  | Input Tokens (TPM)   | $(printf '%-13s' "${in_tok_limit:-Unknown}") | $(printf '%-14s' "${in_tok_rem:-Unknown}") |"
  echo -e "  | Output Tokens (TPM)  | $(printf '%-13s' "${out_tok_limit:-Unknown}") | $(printf '%-14s' "${out_tok_rem:-Unknown}") |"
}

#######################################
# AI: Ping the Claude API and report its rate-limit status
# Globals:
#   CLAUDE_API_KEY, CLAUDE_VERSION, URI_CLAUDE_MESSAGES
# Returns:
#   0 on success, 1 if the API key is missing
#######################################
__mt_ai_quota_check_claude() {
  if [ -z "${CLAUDE_API_KEY}" ] || [ "${CLAUDE_API_KEY}" = "YOUR_CLAUDE_API_KEY" ]; then
    mt-log ERROR "CLAUDE_API_KEY is not configured."
    return 1
  fi
  echo -e "⏳ Pinging Anthropic Claude API for rate limit headers...\n"

  local headers_file
  headers_file=$(mktemp)
  # Minimal dummy payload to trigger a response and grab headers
  local dummy_payload='{"model": "'"${CLAUDE_VERSION:-claude-sonnet-5}"'", "max_tokens": 1, "messages": [{"role": "user", "content": "ping"}]}'

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -D "$headers_file" -X POST "${URI_CLAUDE_MESSAGES}" \
    -H "x-api-key: ${CLAUDE_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$dummy_payload")

  if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 429 ]; then
    __mt_ai_quota_print_claude_headers "$headers_file"
    [ "$http_code" -eq 429 ] && mt-log ERROR "RATE LIMIT EXCEEDED (HTTP 429) - You are currently blocked."
  else
    mt-log ERROR "Failed to connect to Claude API. HTTP Status: $http_code"
  fi
  rm -f "$headers_file"
}

#######################################
# AI: Ping the Gemini API and report its reachability/quota status
# Globals:
#   GEMINI_API_KEY, URI_GEMINI_MODELS
# Returns:
#   0 on success, 1 if the API key is missing
#######################################
__mt_ai_quota_check_gemini() {
  if [ -z "${GEMINI_API_KEY}" ] || [ "${GEMINI_API_KEY}" = "YOUR_GEMINI_API_KEY" ]; then
    mt-log ERROR "GEMINI_API_KEY is not configured."
    return 1
  fi
  echo -e "⏳ Pinging Gemini API Studio...\n"

  local response
  response=$(curl -s -w "\n%{http_code}" -X GET "${URI_GEMINI_MODELS}?key=${GEMINI_API_KEY}")
  local http_code
  http_code=$(echo "$response" | tail -n1)

  if [ "$http_code" -eq 200 ]; then
    echo -e "${CB_GREEN}✅ Gemini API is active and reachable.${C_RESET}\n"
    echo -e "${C_DIM}Note: Google's AI Studio (generativelanguage.googleapis.com) does not currently expose remaining token/request quotas via standard API headers.${C_RESET}"
  elif [ "$http_code" -eq 429 ]; then
    mt-log ERROR "QUOTA EXCEEDED (HTTP 429) - You have hit your Gemini rate limit."
  else
    mt-log ERROR "Failed to connect to Gemini API. HTTP Status: $http_code"
  fi
}

#######################################
# AI: Check API quota and rate limits for the active AI provider
# Usage: mt-ai-quota
# Globals:
#   DEFAULT_AI
#######################################
mt-ai-quota() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local provider="${DEFAULT_AI:-gemini}"

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
  echo -e "${CB_CYAN} 📊 AI Provider Quota Check (${provider^})${C_RESET}"
  echo -e "${CB_BLUE}==========================================================${C_RESET}"

  case "$provider" in
    claude) __mt_ai_quota_check_claude ;;
    gemini) __mt_ai_quota_check_gemini ;;
    claude-code)
      echo -e "  ${CB_GREEN}✅ Claude Code (headless) selected -- no Console API key involved.${C_RESET}"
      echo -e "  ${C_DIM}Usage is tracked against whatever account 'claude' is logged into. Run 'claude' and check '/status', or your Anthropic Console usage page, for limits.${C_RESET}"
      ;;
    local)
      echo -e "  ${CB_GREEN}✅ Local LLM selected.${C_RESET}"
      echo -e "  ${C_DIM}No cloud quotas apply to localhost environments! Run indefinitely.${C_RESET}"
      ;;
  esac

  echo -e "${CB_BLUE}==========================================================${C_RESET}"
}

#######################################
# AI: Fetch Anthropic's live model catalog (GET /v1/models) and cache it
# to disk as a minified [{id, display_name}, ...] array, alongside a
# timestamp file recording when the fetch succeeded. Real API data, not a
# hand-maintained list, so 'mt-ai-models' and the background freshness
# check below never rely on model IDs baked into this file going stale.
# Arguments:
#   $1 - Destination path for the cached model list (JSON)
#   $2 - Destination path for the last-successful-fetch timestamp
# Globals:
#   CLAUDE_API_KEY, URI_CLAUDE_MODELS
# Returns:
#   0 on success (both files written), 1 on missing key or HTTP/parse failure
#######################################
__ai_fetch_models_claude() {
  local data_file="$1" ts_file="$2"
  if [ -z "${CLAUDE_API_KEY:-}" ] || [ "${CLAUDE_API_KEY}" = "YOUR_CLAUDE_API_KEY" ]; then
    return 1
  fi

  local response http_code body
  response=$(curl -s -w "\n%{http_code}" -X GET "${URI_CLAUDE_MODELS}?limit=1000" \
    -H "x-api-key: ${CLAUDE_API_KEY}" \
    -H "anthropic-version: 2023-06-01")
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | head -n -1)

  [ "$http_code" -eq 200 ] || return 1

  echo "$body" | jq '[.data[] | {id: .id, display_name: .display_name}]' > "$data_file" 2> /dev/null || return 1
  date +%s > "$ts_file"
}

#######################################
# AI: Fetch Google's live Gemini model catalog (GET /v1beta/models) and
# cache it to disk in the same shape as __ai_fetch_models_claude --
# {id, display_name} pairs, filtered to models that actually support
# generateContent (the API also lists embedding/vision-only models this
# framework never calls).
# Arguments:
#   $1 - Destination path for the cached model list (JSON)
#   $2 - Destination path for the last-successful-fetch timestamp
# Globals:
#   GEMINI_API_KEY, URI_GEMINI_MODELS
# Returns:
#   0 on success (both files written), 1 on missing key or HTTP/parse failure
#######################################
__ai_fetch_models_gemini() {
  local data_file="$1" ts_file="$2"
  if [ -z "${GEMINI_API_KEY:-}" ] || [ "${GEMINI_API_KEY}" = "YOUR_GEMINI_API_KEY" ]; then
    return 1
  fi

  local response http_code body
  response=$(curl -s -w "\n%{http_code}" -X GET "${URI_GEMINI_MODELS}?key=${GEMINI_API_KEY}&pageSize=1000")
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | head -n -1)

  [ "$http_code" -eq 200 ] || return 1

  echo "$body" | jq '[.models[] | select(.supportedGenerationMethods // [] | index("generateContent")) | {id: (.name | sub("^models/"; "")), display_name: .displayName}]' > "$data_file" 2> /dev/null || return 1
  date +%s > "$ts_file"
}

#######################################
# AI: Print the live model catalog for one or both cloud providers,
# refreshing the cache first when it's missing, stale (past
# AI_MODEL_CHECK_TTL_SEC), or -r/--refresh was passed. Backs both direct
# use and the interactive picker in mt-set-claude-model/mt-set-gemini-model,
# so a provider is only ever queried once per refresh window.
# Usage: mt-ai-models [-p|--provider gemini|claude|all] [-r|--refresh] [-j|--json]
# Options:
#   -p, --provider <gemini|claude|all>   Which provider's catalog to show (default: all)
#   -r, --refresh                        Force a live refresh instead of using the cache
#   -j, --json                           Print raw JSON instead of a formatted table
#   -h, --help                           Show this help menu
# Returns:
#   0 if at least one provider's catalog was shown, 1 if every requested
#   provider failed to refresh and had no prior cache to fall back on
# Globals:
#   CACHE_DIR, AI_MODEL_CHECK_TTL_SEC
#######################################
mt-ai-models() {
  local provider="all" refresh=false as_json=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -p | --provider)
        provider="$2"
        shift 2
        ;;
      -r | --refresh)
        refresh=true
        shift
        ;;
      -j | --json)
        as_json=true
        shift
        ;;
      *)
        echo "Usage: mt-ai-models [-p gemini|claude|all] [-r|--refresh] [-j|--json]" >&2
        return 1
        ;;
    esac
  done

  local -a providers=()
  case "$provider" in
    all) providers=(claude gemini) ;;
    claude | gemini) providers=("$provider") ;;
    *)
      echo "🚨 Error: Invalid provider '$provider'. Use claude, gemini, or all." >&2
      return 1
      ;;
  esac

  mkdir -p "$CACHE_DIR"
  local ttl="${AI_MODEL_CHECK_TTL_SEC:-86400}"
  local now
  now=$(date +%s)

  local p had_output=false
  for p in "${providers[@]}"; do
    local data_file="$CACHE_DIR/.ai_models_${p}.json"
    local ts_file="$CACHE_DIR/.ai_models_${p}_cache"
    local last_check=0
    [ -f "$ts_file" ] && last_check=$(command cat "$ts_file")

    if [ "$refresh" = true ] || [ ! -f "$data_file" ] || ((now - last_check >= ttl)); then
      if [ "$p" = "claude" ]; then
        __ai_fetch_models_claude "$data_file" "$ts_file" || echo "🚨 Error: Could not refresh Claude's model catalog (check CLAUDE_API_KEY)." >&2
      else
        __ai_fetch_models_gemini "$data_file" "$ts_file" || echo "🚨 Error: Could not refresh Gemini's model catalog (check GEMINI_API_KEY)." >&2
      fi
    fi

    [ -f "$data_file" ] || continue
    had_output=true

    if [ "$as_json" = true ]; then
      jq --arg provider "$p" '{provider: $provider, models: .}' "$data_file"
    else
      echo -e "${CB_BLUE}🤖 ${p^} models:${C_RESET}"
      jq -r '.[] | .id + "\t" + .display_name' "$data_file" | column -t -s $'\t'
      echo
    fi
  done

  [ "$had_output" = true ]
}

#######################################
# AI: Shared implementation for mt-set-claude-model/mt-set-gemini-model.
# With an explicit model ID, writes it straight to config.yaml -- no
# network call needed. With no argument, refreshes that provider's live
# catalog and lets the user fzf-pick from it. Either way, clears the
# background staleness warning once it's confirmed to be about this same
# provider (never someone else's still-unresolved warning).
# Arguments:
#   $1 - Provider: "claude" or "gemini"
#   $2 - (Optional) Explicit model ID to set
# Globals:
#   CACHE_DIR, CONFIG_MANAGER
# Returns:
#   0 on success or user cancellation, 1 on failed catalog fetch
#######################################
__ai_set_model() {
  local provider="$1" model="$2"
  local data_file="$CACHE_DIR/.ai_models_${provider}.json"
  local ts_file="$CACHE_DIR/.ai_models_${provider}_cache"
  local env_var="CLAUDE_VERSION"
  [ "$provider" = "gemini" ] && env_var="GEMINI_VERSION"

  if [ -z "$model" ]; then
    mkdir -p "$CACHE_DIR"
    echo "🔄 Refreshing ${provider^}'s model catalog..." >&2
    if [ "$provider" = "claude" ]; then
      __ai_fetch_models_claude "$data_file" "$ts_file"
    else
      __ai_fetch_models_gemini "$data_file" "$ts_file"
    fi

    if [ ! -f "$data_file" ]; then
      echo "🚨 Error: Could not fetch ${provider^}'s model catalog. Pass a model ID directly instead, e.g. 'mt-set-${provider}-model <model-id>'." >&2
      return 1
    fi

    model=$(jq -r '.[] | .id + "\t" + .display_name' "$data_file" | column -t -s $'\t' | fzf --prompt="${provider^} model > " --height=~15 --layout=reverse --border | awk '{print $1}')
    if [ -z "$model" ]; then
      echo -e "${CB_YELLOW}⚠️  Cancelled.${C_RESET}"
      return 0
    fi
  fi

  python3 "$CONFIG_MANAGER" update "ai.providers.${provider}" "model" "$model"
  export "${env_var}=${model}"

  local pending_file="$CACHE_DIR/.ai_model_stale_pending"
  if [ -f "$pending_file" ] && [ "$(jq -r '.provider // empty' "$pending_file" 2> /dev/null)" = "$provider" ]; then
    rm -f "$pending_file"
  fi

  echo "✅ ${provider^} model set to ${model}."
}

#######################################
# AI: Set which Claude model 'ai'/'ai-explain'/'tf-ai-iam' use when
# Claude is the active provider.
# Usage: mt-set-claude-model [<model-id>]
# Arguments:
#   $1 - (Optional) Exact model ID (e.g. claude-sonnet-5). Omit to
#        refresh Anthropic's live catalog and fzf-pick from it.
# Options:
#   -h, --help   Show this help menu
# Globals:
#   CACHE_DIR, CONFIG_MANAGER, CLAUDE_API_KEY
#######################################
mt-set-claude-model() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __ai_set_model claude "$1"
}

#######################################
# AI: Set which Gemini model 'ai'/'ai-explain'/'tf-ai-iam' use when
# Gemini is the active provider.
# Usage: mt-set-gemini-model [<model-id>]
# Arguments:
#   $1 - (Optional) Exact model ID (e.g. gemini-3.6-flash). Omit to
#        refresh Google's live catalog and fzf-pick from it.
# Options:
#   -h, --help   Show this help menu
# Globals:
#   CACHE_DIR, CONFIG_MANAGER, GEMINI_API_KEY
#######################################
mt-set-gemini-model() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  __ai_set_model gemini "$1"
}

#######################################
# AI: Asynchronously check whether the active AI provider's configured
# model still appears in that provider's live catalog. Anthropic and
# Google both retire model IDs on their own schedule, and a
# silently-retired ID means 'ai'/'ai-explain'/'tf-ai-iam' start failing
# with an opaque API error instead of a clear "go update your model"
# prompt -- this surfaces that before it turns into a support puzzle.
# Skipped entirely when AI is disabled, the active provider is "local"
# or "claude-code" (neither has a fetchable model catalog on our side --
# a local endpoint's models are the user's own, and Claude Code resolves
# its own model aliases), or no API key is configured for it (a missing
# key is __ai_query_claude/gemini's problem to report, not this check's).
# Defined here rather than alongside the framework's other
# periodic background checks (.bash.d/00-system/02-update-check.sh)
# because 00-system loads before this file -- calling
# __ai_fetch_models_claude/gemini from there would hit them before
# they're defined.
# Globals:
#   AI_ENABLED, DEFAULT_AI, CLAUDE_VERSION, GEMINI_VERSION,
#   CLAUDE_API_KEY, GEMINI_API_KEY, AI_MODEL_CHECK_TTL_SEC, CACHE_DIR
#######################################
__check_ai_model_freshness() {
  if [[ $- != *i* ]]; then return; fi
  [ "${AI_ENABLED:-true}" = "true" ] || return

  local provider="${DEFAULT_AI:-gemini}"
  case "$provider" in
    local | claude-code) return ;;
  esac

  local pending_file="$CACHE_DIR/.ai_model_stale_pending"
  mkdir -p "$CACHE_DIR" 2> /dev/null

  if [ -f "$pending_file" ]; then
    local stale_provider stale_model
    stale_provider=$(jq -r '.provider' "$pending_file" 2> /dev/null)
    stale_model=$(jq -r '.model' "$pending_file" 2> /dev/null)
    echo -e "\n${C_YELLOW}🤖 Your configured ${stale_provider^} model (${stale_model}) is no longer listed by its provider's API -- it may have been retired. Run ${C_BOLD}mt-set-${stale_provider}-model${C_UNBOLD}${C_YELLOW} to pick a current one.${C_RESET}"
    return
  fi

  local ts_file="$CACHE_DIR/.ai_models_${provider}_cache"
  local current_time
  current_time=$(date +%s)
  local last_check=0
  [ -f "$ts_file" ] && last_check=$(command cat "$ts_file")

  local ttl="${AI_MODEL_CHECK_TTL_SEC:-86400}"

  if ((current_time - last_check >= ttl)); then
    (
      local model data_file has_key=true
      if [ "$provider" = "claude" ]; then
        model="${CLAUDE_VERSION:-claude-sonnet-5}"
        data_file="$CACHE_DIR/.ai_models_claude.json"
        if [ -z "${CLAUDE_API_KEY:-}" ] || [ "${CLAUDE_API_KEY}" = "YOUR_CLAUDE_API_KEY" ]; then
          has_key=false
        fi
        [ "$has_key" = true ] && __ai_fetch_models_claude "$data_file" "$ts_file"
      else
        model="${GEMINI_VERSION:-gemini-3.6-flash}"
        data_file="$CACHE_DIR/.ai_models_gemini.json"
        if [ -z "${GEMINI_API_KEY:-}" ] || [ "${GEMINI_API_KEY}" = "YOUR_GEMINI_API_KEY" ]; then
          has_key=false
        fi
        [ "$has_key" = true ] && __ai_fetch_models_gemini "$data_file" "$ts_file"
      fi

      if [ "$has_key" != true ] || [ ! -f "$data_file" ]; then
        date +%s > "$ts_file"
      elif jq -e --arg id "$model" '.[] | select(.id == $id)' "$data_file" > /dev/null 2>&1; then
        : # Fetch functions already refreshed $ts_file on success -- nothing else to do.
      else
        jq -nc --arg provider "$provider" --arg model "$model" '{provider: $provider, model: $model}' > "$pending_file"
      fi
    ) &
    disown
  fi
}

__check_ai_model_freshness
