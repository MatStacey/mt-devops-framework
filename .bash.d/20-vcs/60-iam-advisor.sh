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
# Repo Radar: Read a GCP project's IAM policy and reduce it to the
# user-created service accounts (and the roles each holds) -- Google-managed
# service agents (gcp-sa-*, *@developer/cloudservices/cloudbuild
# .gserviceaccount.com) are dropped as noise. Accounts from other projects
# that were granted roles here are kept: a pipeline account living in one
# project routinely holds roles in another.
# Arguments:
#   $1 - GCP project ID
# Outputs:
#   Prints a JSON array [{email, roles: [...]}] on success, or a
#   permission-denied/api-error reason string (via
#   __mt_radar_gcp_classify_error) on failure
# Returns:
#   0 on success, 1 on failure
#######################################
__mt_radar_iam_fetch_current() {
  local project="$1"
  local stderr_file policy
  stderr_file=$(mktemp)
  if ! policy=$(gcloud projects get-iam-policy "$project" --format=json --quiet 2> "$stderr_file"); then
    __mt_radar_gcp_classify_error "$(cat "$stderr_file")"
    rm -f "$stderr_file"
    return 1
  fi
  rm -f "$stderr_file"

  echo "$policy" | jq -c '[.bindings // [] | .[] | .role as $r | .members[] | select(startswith("serviceAccount:")) | sub("serviceAccount:"; "") | select(endswith(".iam.gserviceaccount.com") and (contains("@gcp-sa-") | not)) | {email: ., role: $r}] | group_by(.email) | map({email: .[0].email, roles: map(.role)})'
}

#######################################
# Repo Radar: Pull the structured {recommended, current} report out of an AI
# response. The response is either the report itself or (because
# AI_SYSTEM_PROMPT wraps every reply in a {category, message, ...} envelope)
# a JSON string inside that envelope's "message" -- both are tried.
# Arguments:
#   $1 - Raw provider response text
# Outputs:
#   Prints compact JSON {recommended: [...], current: [...]} on success
# Returns:
#   0 if a report was found, 1 otherwise
#######################################
__mt_radar_iam_extract_report() {
  local content="$1"
  local extractor="$HOME/.bash.d/lib/python/ai_parse_response.py"
  local message text clean
  message=$(python3 "$extractor" <<< "$content" 2> /dev/null | jq -r '.message // empty' 2> /dev/null)

  for text in "$content" "$message"; do
    [ -z "$text" ] && continue
    clean=$(python3 "$extractor" <<< "$text" 2> /dev/null)
    if jq -e '(.recommended | type) == "array"' <<< "$clean" > /dev/null 2>&1; then
      jq -c '{recommended: .recommended, current: (.current // [])}' <<< "$clean"
      return 0
    fi
  done
  return 1
}

#######################################
# Repo Radar: Analyze a repo's Terraform for required GCP service accounts
# and least-privilege IAM roles via the configured AI provider. With a GCP
# project, the project's live service-account role grants are read first and
# handed to the model, which then labels each granted role required /
# not-needed / excessive and says which existing account each recommended
# account replaces. No Terraform found short-circuits without an AI call.
# Arguments:
#   $1 - Repository path
#   $2 - AI provider override (empty = DEFAULT_AI)
#   $3 - GCP project to read current IAM from (empty = skip the current
#        configuration)
# Globals:
#   DEFAULT_AI
# Outputs:
#   Prints a JSON object:
#   {status: "ok"|"no-terraform"|"error", analyzed_at: <epoch>|null,
#    provider: <name>|null, gcp_project: <id>|null,
#    recommended: [{name, purpose, replaces, roles: [{role, reason}]}]|null,
#    current: [{email, roles: [{role, verdict, reason}]}]|null,
#    analysis: <text>|null (raw fallback when the reply wasn't a report),
#    message: <text> (only on "error")}
# Returns:
#   0 on "ok"/"no-terraform", 1 on "error"
#######################################
__mt_radar_iam_analyze_repo() {
  local repo_path="$1" provider_override="$2" gcp_project="${3:-}"

  # Unrestricted depth, matching __mt_radar_infra_analyze_repo
  # (57-infra.sh) rather than tf-ai-iam's own shallow -maxdepth 3 check --
  # a repo laid out as terraform/environments/<env>/<component>/*.tf (4
  # levels deep) has real Terraform that -maxdepth 3 would silently miss,
  # reporting "no-terraform" even though the Infrastructure Overview
  # panel, which scans the same repo unrestricted, finds it fine.
  local tf_count
  tf_count=$(find "$repo_path" -name "*.tf" -not -path "*/.terraform/*" 2> /dev/null | wc -l)
  if [ "$tf_count" -eq 0 ]; then
    jq -n '{status: "no-terraform", analyzed_at: null, provider: null, gcp_project: null, recommended: null, current: null, analysis: null}'
    return 0
  fi

  local provider="${provider_override:-${DEFAULT_AI:-gemini}}"

  local prompt current_json=""
  prompt=$(__get_prompt "tf_iam_report")
  if [ -n "$gcp_project" ]; then
    if ! current_json=$(__mt_radar_iam_fetch_current "$gcp_project"); then
      jq -n --arg provider "$provider" --arg message "Could not read the IAM policy of project '${gcp_project}' (${current_json}) -- check your active gcloud account and its access to that project." \
        '{status: "error", analyzed_at: null, provider: $provider, gcp_project: null, recommended: null, current: null, analysis: null, message: $message}'
      return 1
    fi
    prompt="${prompt}"$'\n\n'"CURRENT IAM BINDINGS (project ${gcp_project}), user-created service accounts only, as [{email, roles}]:"$'\n'"${current_json}"
  fi

  local context_file
  context_file=$(cd "$repo_path" && __ai_build_context "" true)

  local content
  content=$(cd "$repo_path" && __ai_query_provider "$provider" "$prompt" "" "$context_file" "" false)
  local query_status=$?
  [ -f "$context_file" ] && rm -f "$context_file"

  if [ "$query_status" -ne 0 ] || [ -z "$content" ]; then
    jq -n --arg provider "$provider" '{status: "error", analyzed_at: null, provider: $provider, gcp_project: null, recommended: null, current: null, analysis: null, message: "The AI query failed -- check your AI provider configuration (mt-ai-quota)."}'
    return 1
  fi

  # Structured report first; when the reply isn't one, keep the readable
  # text (AI_SYSTEM_PROMPT's {category, message} envelope unwrapped the same
  # way __ai_parse_response's chat branch does) so the panel can still show
  # something instead of an empty result.
  local report="" analysis_text=""
  report=$(__mt_radar_iam_extract_report "$content") || report=""
  if [ -z "$report" ]; then
    analysis_text=$(python3 "$HOME/.bash.d/lib/python/ai_parse_response.py" <<< "$content" 2> /dev/null | jq -r '.message // empty' 2> /dev/null)
    [ -z "$analysis_text" ] && analysis_text="$content"
  fi

  jq -n \
    --arg provider "$provider" \
    --arg project "$gcp_project" \
    --arg analysis "$analysis_text" \
    --argjson report "${report:-null}" \
    --argjson analyzed_at "$(date +%s)" \
    '{status: "ok", analyzed_at: $analyzed_at, provider: $provider,
      gcp_project: (if $project == "" then null else $project end),
      recommended: ($report.recommended // null),
      current: (if $project == "" then null else ($report.current // []) end),
      analysis: (if $analysis == "" then null else $analysis end)}'
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
  echo -e " ${CB_CYAN}Provider   :${C_RESET} $(echo "$iam" | jq -r '.provider // "Unknown"')"
  echo -e " ${CB_CYAN}GCP project:${C_RESET} $(echo "$iam" | jq -r '.gcp_project // "not scanned"')"

  if [ "$(echo "$iam" | jq -r '(.recommended | type)')" != "array" ]; then
    echo ""
    echo "$iam" | jq -r '.analysis // "No analysis available."'
    return 0
  fi

  echo -e "\n${CB_MAGENTA}▶ CURRENT IAM CONFIGURATION${C_RESET}"
  if [ "$(echo "$iam" | jq -r '.gcp_project // ""')" = "" ]; then
    echo "  Not scanned -- re-run with --gcp-project <id> to compare against live IAM."
  else
    echo "$iam" | jq -r '(.current // [])[] | "\n  \(.email)", (.roles[] | "    [\(.verdict)] \(.role) -- \(.reason)")'
  fi

  echo -e "\n${CB_MAGENTA}▶ RECOMMENDED IAM CONFIGURATION${C_RESET}"
  echo "$iam" | jq -r '.recommended[] | "\n  \(.name) -- \(.purpose)", "    replaces: \(.replaces // "nothing (new account)")", (.roles[] | "    - \(.role) -- \(.reason)")'
}
