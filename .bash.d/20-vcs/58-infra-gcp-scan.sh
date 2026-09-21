# shellcheck shell=bash
# ------------------------------------------
# Repo Radar: Live GCP Deployment Scanning
# ------------------------------------------
# ~/.bash.d/20-vcs/58-infra-gcp-scan.sh
#
# Cross-references a repo's already-analyzed Terraform resources
# (.vcs_infra.json, see 57-infra.sh) against what's actually live in a GCP
# project, via one `gcloud <service> list` (or `bq ls`) per resource type --
# which types are covered, and how each is listed, lives in
# lib/registry/gcp_scan_types.json, so adding one is a registry entry, not
# code. This is deliberately an EXISTENCE check, not a drift check: it
# answers "does a resource with this name exist in this project" for each google_* resource Terraform declares,
# not "does its live config match the Terraform source" (that needs a real
# `terraform plan` against the actual backend/state, with credentials and
# execution risk this on-demand, read-only heuristic is not meant to carry).
# On-demand only (`mt-radar --scan-gcp`), never wired into `--index`/`--infra`,
# since it makes live authenticated API calls and can be slow/rate-limited --
# same "on-demand only" precedent as mt-audit-deps.

#######################################
# Repo Radar: Check whether the gcloud CLI is installed and has at least one
# credentialed account, without making any network call.
# Outputs:
#   None
# Returns:
#   0 if gcloud is usable, 1 otherwise
#######################################
__mt_radar_gcp_available() {
  command -v gcloud > /dev/null 2>&1 || return 1
  gcloud auth list --filter=status:ACTIVE --format="value(account)" 2> /dev/null | grep -q . || return 1
}

#######################################
# Repo Radar: Turn a failed gcloud call's stderr into a specific reason
# string instead of the generic "api-error" every caller used to report
# regardless of cause -- distinguishes the common case (the active
# identity, per `gcloud config get-value account`, lacks the list
# permission on this project, e.g. a service account scoped to a
# different project than the one being scanned) from anything else, so
# the panel itself can point at "check your active gcloud account /IAM
# role" instead of a diagnostic dead end.
# Arguments:
#   $1 - The failed gcloud call's captured stderr text
# Outputs:
#   Prints "permission-denied" or "api-error"
#######################################
__mt_radar_gcp_classify_error() {
  local stderr_text="$1"
  if [[ "$stderr_text" =~ PERMISSION_DENIED ]]; then
    echo "permission-denied"
  else
    echo "api-error"
  fi
}

#######################################
# Repo Radar: Path to the registry describing how to look up each supported
# Terraform resource type live (lib/registry/gcp_scan_types.json).
# Outputs:
#   Prints the registry file path
#######################################
__mt_radar_gcp_registry_file() {
  echo "$HOME/.bash.d/lib/registry/gcp_scan_types.json"
}

#######################################
# Repo Radar: List every resource of one registry spec that exists in a live
# GCP project, normalised to [{name, region, live_url, id}]. One list call
# per spec (and per region in GCP_SCAN_REGIONS for a regional spec) rather
# than one lookup per Terraform resource -- a repo declaring 26 Pub/Sub
# topics costs a single call. Results (and failures) are cached under the
# given directory so every later resource of the same type in one scan
# reuses them. A regional spec succeeds if any region does.
# Arguments:
#   $1 - Spec id (a key of the registry's "specs")
#   $2 - GCP project ID
#   $3 - Cache directory (optional; empty = no caching)
# Globals:
#   GCP_SCAN_REGIONS
# Outputs:
#   Prints the normalised JSON array on success, or a reason string
#   ("permission-denied"/"api-error") on failure
# Returns:
#   0 on success, 1 on failure
#######################################
__mt_radar_gcp_list_resources() {
  local spec_id="$1" project="$2" cache_dir="${3:-}"
  local registry
  registry=$(__mt_radar_gcp_registry_file)

  if [ -n "$cache_dir" ]; then
    if [ -f "$cache_dir/$spec_id.json" ]; then
      cat "$cache_dir/$spec_id.json"
      return 0
    fi
    if [ -f "$cache_dir/$spec_id.err" ]; then
      cat "$cache_dir/$spec_id.err"
      return 1
    fi
  fi

  local spec regional name_jq region_jq live_url_jq id_jq
  spec=$(jq -c --arg s "$spec_id" '.specs[$s]' "$registry")
  regional=$(jq -r '.regional // false' <<< "$spec")
  name_jq=$(jq -r '.name_jq' <<< "$spec")
  region_jq=$(jq -r '.region_jq // "null"' <<< "$spec")
  live_url_jq=$(jq -r '.live_url_jq // "null"' <<< "$spec")
  id_jq=$(jq -r '.id_jq // "null"' <<< "$spec")

  local -a regions=("")
  [ "$regional" = true ] && read -ra regions <<< "${GCP_SCAN_REGIONS:-europe-west1 europe-west2}"

  local stderr_file combined="[]" any_ok=false last_reason="api-error"
  stderr_file=$(mktemp)
  local region raw items arg
  local -a cmd
  for region in "${regions[@]}"; do
    cmd=()
    while IFS= read -r arg; do
      arg="${arg//\{project\}/$project}"
      cmd+=("${arg//\{region\}/$region}")
    done < <(jq -r '.cmd[]' <<< "$spec")

    if ! raw=$("${cmd[@]}" 2> "$stderr_file"); then
      last_reason=$(__mt_radar_gcp_classify_error "$(cat "$stderr_file")")
      continue
    fi
    [ -z "${raw//[[:space:]]/}" ] && raw="[]"
    if ! items=$(jq -c "[.[]? | {name: (try (${name_jq}) catch null), region: (try (${region_jq}) catch null), live_url: (try (${live_url_jq}) catch null), id: (try (${id_jq}) catch null)} | select(.name != null)]" <<< "$raw" 2> /dev/null); then
      last_reason="api-error"
      continue
    fi
    any_ok=true
    combined=$(jq -c -n --argjson a "$combined" --argjson b "$items" '$a + $b')
  done
  rm -f "$stderr_file"

  if [ "$any_ok" = true ]; then
    [ -n "$cache_dir" ] && echo "$combined" > "$cache_dir/$spec_id.json"
    echo "$combined"
    return 0
  fi
  [ -n "$cache_dir" ] && echo "$last_reason" > "$cache_dir/$spec_id.err"
  echo "$last_reason"
  return 1
}

#######################################
# Repo Radar: Check whether one Terraform-declared google_* resource actually
# exists in a live GCP project, by looking its type up in the registry
# (lib/registry/gcp_scan_types.json) and matching against that type's live
# resource list (see __mt_radar_gcp_list_resources). A resource type absent
# from the registry is reported as unsupported rather than guessed at.
# Live-name candidates, tried in order: the Terraform attribute holding the
# real name when it's a plain literal (`name = "x"`, `account_id = "x"`),
# the Terraform label, the label with underscores turned into dashes
# (cp_update -> cp-update), then the fallback name -- real deployments
# overwhelmingly name a resource after the repo itself (`name =
# var.service_name`), which can't be evaluated from the Terraform.
# Arguments:
#   $1 - Terraform resource type (e.g. "google_cloud_run_v2_service")
#   $2 - Terraform resource label
#   $3 - GCP project ID to check against
#   $4 - Fallback candidate name (optional, e.g. the repo's own basename)
#   $5 - JSON object of the resource's literal attributes (optional, from
#        __mt_radar_infra_analyze_repo's "attrs")
#   $6 - Cache directory for list results (optional)
# Outputs:
#   Prints a JSON object: {type, name, group, supported: bool, deployed:
#   bool, region: string|null, console_url: string|null, live_url:
#   string|null, matched_name: string|null (the live name that matched,
#   only when it differs from the label), reason: string|null}. "group" is
#   the infra overview category (compute, networking, iam, ...), null when
#   unsupported.
#######################################
__mt_radar_gcp_check_resource() {
  local rtype="$1" rname="$2" project="$3" fallback_name="${4:-}" attrs_json="${5:-}" cache_dir="${6:-}"
  [ -z "$attrs_json" ] && attrs_json="{}"
  local registry
  registry=$(__mt_radar_gcp_registry_file)

  local spec_id attr_key
  spec_id=$(jq -r --arg t "$rtype" '.types[$t].spec // empty' "$registry")
  attr_key=$(jq -r --arg t "$rtype" '.types[$t].attr // "name"' "$registry")

  local supported=true deployed=false reason="" region="" console_url="" live_url="" matched_name="" group=""

  if [ -z "$spec_id" ]; then
    supported=false
    reason="unsupported-resource-type"
  else
    if declare -F __mt_radar_infra_categorize_resource > /dev/null; then
      group=$(__mt_radar_infra_categorize_resource "$rtype")
    else
      group="other"
    fi

    local literal_name
    literal_name=$(jq -r --arg k "$attr_key" '.[$k] // empty' <<< "$attrs_json")
    local -a candidates=()
    local candidate
    for candidate in "$literal_name" "$rname" "${rname//_/-}" "$fallback_name"; do
      [ -z "$candidate" ] && continue
      [[ " ${candidates[*]} " == *" $candidate "* ]] && continue
      candidates+=("$candidate")
    done

    local list_json
    if ! list_json=$(__mt_radar_gcp_list_resources "$spec_id" "$project" "$cache_dir"); then
      reason="$list_json"
    else
      local hit=""
      for candidate in "${candidates[@]}"; do
        hit=$(jq -c --arg c "$candidate" 'first(.[] | select(.name == $c)) // empty' <<< "$list_json")
        [ -n "$hit" ] && break
      done

      if [ -n "$hit" ]; then
        deployed=true
        [ "$candidate" != "$rname" ] && matched_name="$candidate"
        region=$(jq -r '.region // empty' <<< "$hit")
        live_url=$(jq -r '.live_url // empty' <<< "$hit")
        local resource_id
        resource_id=$(jq -r '.id // empty' <<< "$hit")
        console_url=$(jq -r --arg s "$spec_id" '.specs[$s].console // empty' "$registry")
        console_url="${console_url//\{project\}/$project}"
        console_url="${console_url//\{region\}/$region}"
        console_url="${console_url//\{name\}/$candidate}"
        console_url="${console_url//\{id\}/$resource_id}"
      fi
    fi
  fi

  jq -n \
    --arg t "$rtype" \
    --arg n "$rname" \
    --arg group "$group" \
    --argjson supported "$supported" \
    --argjson deployed "$deployed" \
    --arg region "$region" \
    --arg console_url "$console_url" \
    --arg live_url "$live_url" \
    --arg matched_name "$matched_name" \
    --arg reason "$reason" \
    'def nn($v): if $v == "" then null else $v end;
     {type: $t, name: $n, group: nn($group), supported: $supported, deployed: $deployed, region: nn($region), console_url: nn($console_url), live_url: nn($live_url), matched_name: nn($matched_name), reason: nn($reason)}'
}

#######################################
# Repo Radar: Scan every google_* resource in an already-analyzed Terraform
# infrastructure overview (see __mt_radar_infra_analyze_repo) against a live
# GCP project, and compute a red/amber/green sync status from the results:
# green = every checked resource is deployed, red = none are, amber =
# some but not all, unknown = nothing was checkable (no google_* resources,
# or none of their types are in the registry). This is a deployment-
# completeness signal, not a config/state drift check -- see this file's
# header comment. Live lists are fetched once per resource type and shared
# across the scan.
# Arguments:
#   $1 - Infra overview JSON (from __mt_radar_infra_analyze_repo /
#        .vcs_infra.json's cached entry)
#   $2 - GCP project ID to check against
#   $3 - Repo name (optional) -- passed through to __mt_radar_gcp_check_resource
#        as its fallback candidate name, for the very common case of a
#        resource named after the repo (`name = var.service_name`) rather
#        than its Terraform resource label.
# Outputs:
#   Prints a JSON object: {scanned_at, project, sync_status:
#   "green"|"amber"|"red"|"unknown", checked_count, deployed_count,
#   unsupported_count, resources: [<__mt_radar_gcp_check_resource results>]}
#######################################
__mt_radar_gcp_scan_repo() {
  local infra_json="$1" project="$2" repo_name="${3:-}"

  local -a google_resources=()
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    google_resources+=("$entry")
  done < <(echo "$infra_json" | jq -c '.resources // {} | to_entries[] | .value[] | select(.type | startswith("google_")) | [.type, .name, (.attrs // {})]')

  local results_tmp cache_dir
  results_tmp=$(mktemp)
  cache_dir=$(mktemp -d)
  echo "[]" > "$results_tmp"

  local entry rtype rname attrs result
  for entry in "${google_resources[@]}"; do
    rtype=$(jq -r '.[0]' <<< "$entry")
    rname=$(jq -r '.[1]' <<< "$entry")
    attrs=$(jq -c '.[2]' <<< "$entry")
    result=$(__mt_radar_gcp_check_resource "$rtype" "$rname" "$project" "$repo_name" "$attrs" "$cache_dir")
    jq --argjson r "$result" '. + [$r]' "$results_tmp" > "${results_tmp}.next" && mv "${results_tmp}.next" "$results_tmp"
  done
  rm -rf "$cache_dir"

  local checked_count deployed_count unsupported_count sync_status
  checked_count=$(jq '[.[] | select(.supported == true)] | length' "$results_tmp")
  deployed_count=$(jq '[.[] | select(.supported == true and .deployed == true)] | length' "$results_tmp")
  unsupported_count=$(jq '[.[] | select(.supported == false)] | length' "$results_tmp")

  if [ "$checked_count" -eq 0 ]; then
    sync_status="unknown"
  elif [ "$deployed_count" -eq "$checked_count" ]; then
    sync_status="green"
  elif [ "$deployed_count" -eq 0 ]; then
    sync_status="red"
  else
    sync_status="amber"
  fi

  jq -n \
    --argjson scanned_at "$(date +%s)" \
    --arg project "$project" \
    --arg sync_status "$sync_status" \
    --argjson checked_count "$checked_count" \
    --argjson deployed_count "$deployed_count" \
    --argjson unsupported_count "$unsupported_count" \
    --slurpfile resources "$results_tmp" \
    '{scanned_at: $scanned_at, project: $project, sync_status: $sync_status, checked_count: $checked_count, deployed_count: $deployed_count, unsupported_count: $unsupported_count, resources: $resources[0]}'
  rm -f "$results_tmp"
}

#######################################
# Repo Radar: Print a GCP scan result (from __mt_radar_gcp_scan_repo) as a
# colorized summary -- one line per checked/unsupported resource, plus the
# overall red/amber/green sync status.
# Arguments:
#   $1 - GCP scan JSON
# Outputs:
#   Colorized summary to stdout
#######################################
__mt_radar_gcp_scan_show() {
  local scan_json="$1"
  local sync_status project checked deployed unsupported
  sync_status=$(echo "$scan_json" | jq -r '.sync_status')
  project=$(echo "$scan_json" | jq -r '.project')
  checked=$(echo "$scan_json" | jq -r '.checked_count')
  deployed=$(echo "$scan_json" | jq -r '.deployed_count')
  unsupported=$(echo "$scan_json" | jq -r '.unsupported_count')

  local status_color status_icon
  case "$sync_status" in
    green)
      status_color="$CB_GREEN"
      status_icon="🟢"
      ;;
    amber)
      status_color="$CB_YELLOW"
      status_icon="🟡"
      ;;
    red)
      status_color="$CB_RED"
      status_icon="🔴"
      ;;
    *)
      status_color="$C_DIM"
      status_icon="⚪"
      ;;
  esac

  echo -e "${CB_MAGENTA}▶ GCP SYNC STATUS${C_RESET}"
  echo -e " ${CB_CYAN}Project        :${C_RESET} ${project}"
  echo -e " ${CB_CYAN}Status         :${C_RESET} ${status_color}${status_icon} ${sync_status}${C_RESET}"
  echo -e " ${CB_CYAN}Deployed       :${C_RESET} ${deployed}/${checked} checked google_* resources"
  [ "$unsupported" -gt 0 ] && echo -e " ${CB_CYAN}Unsupported    :${C_RESET} ${unsupported} resource type(s) not yet checkable"

  echo ""
  local line
  while IFS=$'\t' read -r rtype rname deployed_flag console_url matched_name reason; do
    [ -z "$rtype" ] && continue
    if [ "$reason" = "unsupported-resource-type" ]; then
      echo -e " ${C_DIM}⚪ ${rtype}.${rname} -- unsupported${C_RESET}"
    elif [ "$deployed_flag" = "true" ]; then
      line=" ${CB_GREEN}✅ ${rtype}.${rname}${C_RESET}"
      [ "$matched_name" != "null" ] && line="${line} ${C_DIM}(deployed as \"${matched_name}\", not the Terraform label)${C_RESET}"
      [ "$console_url" != "null" ] && line="${line} -- ${console_url}"
      echo -e "$line"
    else
      line=" ${CB_RED}❌ ${rtype}.${rname} -- not found in project${C_RESET}"
      [ "$reason" != "null" ] && line="${line} (${reason})"
      echo -e "$line"
    fi
  done < <(echo "$scan_json" | jq -r '.resources[] | [.type, .name, (.deployed|tostring), (.console_url // "null"), (.matched_name // "null"), (.reason // "null")] | @tsv')
}

#######################################
# Repo Radar: Merge a GCP scan result into a repo's existing .vcs_infra.json
# entry (as a "gcp_scan" field), preserving every other field already
# there -- unlike __mt_radar_infra_write_cache_entry, this must not replace
# the whole entry, since the Terraform overview it was computed from lives
# in the same cache record.
# Arguments:
#   $1 - Path to the infra JSON cache file
#   $2 - Repository path (the existing cache key)
#   $3 - GCP scan JSON (from __mt_radar_gcp_scan_repo)
#######################################
__mt_radar_infra_write_gcp_scan() {
  local cache_file="$1" repo_path="$2" scan_json="$3"
  local lock_file="${cache_file}.lock"

  (
    flock -x 200
    local tmp_cache
    tmp_cache=$(mktemp)
    jq --arg r "$repo_path" --argjson s "$scan_json" '.[$r].gcp_scan = $s' "$cache_file" > "$tmp_cache" && mv "$tmp_cache" "$cache_file"
  ) 200> "$lock_file"
}

#######################################
# Repo Radar: Suggest GCP projects a repo deploys to, mined from the repo's
# own files -- Terraform/tfvars/HCL (`project`, `project_id`, `project_name`),
# YAML/JSON config and CI pipelines (`project_id:`, `--project=`,
# `GCP_PROJECT`), and shell/package.json (`gcloud config set project`). Only
# literal, syntactically valid project IDs are reported; `= var.x` references
# are never resolved or guessed.
# Arguments:
#   $1 - Repository path
# Globals:
#   GCP_SUGGEST_MAX_SOURCES (default 3) - files listed per project
# Outputs:
#   Prints a JSON array [{project, environment, references, sources}],
#   ordered dev, stage, test, prod, then unclassified
#######################################
__mt_radar_gcp_suggest_projects() {
  local repo_path="$1"
  local project_id_pattern='[a-z][a-z0-9-]{4,28}[a-z0-9]'
  local assignment_pattern="(^|[^A-Za-z0-9_])(project(_id|_name)?|gcp_project(_id)?|GCP_PROJECT(_ID)?|PROJECT_ID|CLOUDSDK_CORE_PROJECT)[\"']?[[:space:]]*[=:][[:space:]]*[\"']?${project_id_pattern}[\"']?"
  local flag_pattern="(--project[= ]|set project )${project_id_pattern}"

  (
    cd "$repo_path" 2> /dev/null || exit 0
    grep -rHoE "(${assignment_pattern})|(${flag_pattern})" . \
      --include='*.tf' --include='*.tfvars' --include='*.hcl' \
      --include='*.yml' --include='*.yaml' --include='*.json' --include='*.sh' \
      --exclude='*lock*.json' --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.terraform 2> /dev/null |
      sed 's#^\./##' |
      awk -f "$HOME/.bash.d/lib/awk/gcp_project_refs.awk"
  ) | jq -R -s --argjson max_sources "${GCP_SUGGEST_MAX_SOURCES:-3}" -f "$HOME/.bash.d/lib/jq/gcp_project_suggestions.jq"
}
