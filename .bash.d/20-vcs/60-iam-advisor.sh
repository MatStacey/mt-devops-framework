# shellcheck shell=bash
# ------------------------------------------
# Repo Radar: IAM Recommendation Advisor (Terraform + AI)
# ------------------------------------------
# ~/.bash.d/20-vcs/60-iam-advisor.sh
# Cache-backed counterpart to tf-ai-iam (.bash.d/10-infra/43-terraform-ai.sh)
# for one-click use from mt-radar/the VS Code companion, in the same
# generate-then-cache shape as 57-infra.sh's infrastructure overview. Unlike
# that overview, this always calls an AI provider (real cost/latency), so
# it's on-demand per repo only -- never run automatically by --index/--infra,
# same as __mt_radar_gcp_scan_repo in 58-infra-gcp-scan.sh.

#######################################
# Repo Radar: Analyze a repo's Terraform for required GCP service accounts
# and least-privilege IAM roles via the configured AI provider, reusing the
# same prompts as tf-ai-iam's chat mode. No Terraform found short-circuits
# without an AI call.
# Arguments:
#   $1 - Repository path
#   $2 - AI provider override (empty = DEFAULT_AI)
# Globals:
#   DEFAULT_AI
# Outputs:
#   Prints a JSON object:
#   {status: "ok"|"no-terraform"|"error", analyzed_at: <epoch>|null,
#    provider: <name>|null, analysis: <text>|null}
# Returns:
#   0 on "ok"/"no-terraform", 1 on "error" (AI query failed)
#######################################
__mt_radar_iam_analyze_repo() {
  local repo_path="$1" provider_override="$2"

  local tf_count
  tf_count=$(find "$repo_path" -maxdepth 3 -name "*.tf" -not -path "*/.terraform/*" 2> /dev/null | wc -l)
  if [ "$tf_count" -eq 0 ]; then
    jq -n '{status: "no-terraform", analyzed_at: null, provider: null, analysis: null}'
    return 0
  fi

  local prompt base_prompt chat_prompt
  base_prompt=$(__get_prompt "tf_iam_base")
  chat_prompt=$(__get_prompt "tf_iam_chat")
  prompt="${base_prompt}"$'\n\n'"${chat_prompt}"

  local provider="${provider_override:-${DEFAULT_AI:-gemini}}"

  local context_file
  context_file=$(cd "$repo_path" && __ai_build_context "" true)

  local content
  content=$(cd "$repo_path" && __ai_query_provider "$provider" "$prompt" "" "$context_file" "" false)
  local query_status=$?
  [ -f "$context_file" ] && rm -f "$context_file"

  if [ "$query_status" -ne 0 ] || [ -z "$content" ]; then
    jq -n --arg provider "$provider" '{status: "error", analyzed_at: null, provider: $provider, analysis: null}'
    return 1
  fi

  jq -n \
    --arg provider "$provider" \
    --arg analysis "$content" \
    --argjson analyzed_at "$(date +%s)" \
    '{status: "ok", analyzed_at: $analyzed_at, provider: $provider, analysis: $analysis}'
}

#######################################
# Repo Radar: Write one repo's IAM analysis into its own JSON cache
# (.vcs_iam.json), under the same exclusive-lock pattern as
# __mt_radar_infra_write_cache_entry.
# Arguments:
#   $1 - Path to the IAM JSON cache file
#   $2 - Repository path (becomes the cache key)
#   $3 - IAM analysis JSON (from __mt_radar_iam_analyze_repo)
#######################################
__mt_radar_iam_write_cache_entry() {
  local cache_file="$1" repo_path="$2" iam_json="$3"
  local lock_file="${cache_file}.lock"

  (
    flock -x 200
    local tmp_cache
    tmp_cache=$(mktemp)
    jq --arg r "$repo_path" --argjson i "$iam_json" '.[$r] = $i' "$cache_file" > "$tmp_cache" && mv "$tmp_cache" "$cache_file"
  ) 200> "$lock_file"
}

#######################################
# Repo Radar: Print one repo's cached IAM analysis (by absolute path or bare
# repo name, same resolution as __mt_radar_preview), as rendered text or
# (with json_mode) the raw cached JSON object.
# Arguments:
#   $1 - Repo identifier: an absolute path (exact cache key) or a bare
#        repo name
#   $2 - Path to the IAM JSON cache file
#   $3 - "true" to print the raw JSON instead of the rendered analysis
#######################################
__mt_radar_iam_show() {
  local repo="$1" cache_file="$2" json_mode="$3"
  [ -f "$cache_file" ] || echo "{}" > "$cache_file"

  local iam
  iam=$(jq -r --arg r "$repo" '.[$r] // empty' "$cache_file" 2> /dev/null)

  if [ -z "$iam" ]; then
    local resolved
    resolved=$(jq -r --arg name "$repo" 'to_entries[] | select((.key | split("/") | last) == $name) | .key' "$cache_file" 2> /dev/null | head -n1)
    if [ -n "$resolved" ]; then
      iam=$(jq -r --arg r "$resolved" '.[$r] // empty' "$cache_file" 2> /dev/null)
    fi
  fi

  if [ -z "$iam" ] || [ "$iam" == "null" ]; then
    if [ "$json_mode" = true ]; then
      jq -n '{status: "not-analyzed"}'
    else
      echo -e "${CB_YELLOW}⚠️  No IAM analysis found for \"${repo}\".${C_RESET}"
      echo -e "Run ${CB_GREEN}mt-radar --iam -r ${repo}${C_RESET} to generate one (requires Terraform in the repo)."
    fi
    return 0
  fi

  if [ "$json_mode" = true ]; then
    echo "$iam"
    return 0
  fi

  echo -e "${CB_MAGENTA}▶ IAM RECOMMENDATIONS${C_RESET}"
  echo -e " ${CB_CYAN}Provider:${C_RESET} $(echo "$iam" | jq -r '.provider // "Unknown"')"
  echo ""
  echo "$iam" | jq -r '.analysis // "No analysis available."'
}
