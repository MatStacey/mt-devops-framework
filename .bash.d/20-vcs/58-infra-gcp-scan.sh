# shellcheck shell=bash
# ------------------------------------------
# Repo Hub: Live GCP Deployment Scanning
# ------------------------------------------
# ~/.bash.d/20-vcs/58-infra-gcp-scan.sh
#
# Cross-references a repo's already-analyzed Terraform resources
# (.vcs_infra.json, see 57-infra.sh) against what's actually live in a GCP
# project, via `gcloud <service> list`. This is deliberately an
# EXISTENCE check, not a drift check: it answers "does a resource with this
# name exist in this project" for each google_* resource Terraform declares,
# not "does its live config match the Terraform source" (that needs a real
# `terraform plan` against the actual backend/state, with credentials and
# execution risk this on-demand, read-only heuristic is not meant to carry).
# On-demand only (`mt-hub --scan-gcp`), never wired into `--index`/`--infra`,
# since it makes live authenticated API calls and can be slow/rate-limited --
# same "on-demand only" precedent as mt-audit-deps.

#######################################
# Repo Hub: Check whether the gcloud CLI is installed and has at least one
# credentialed account, without making any network call.
# Outputs:
#   None
# Returns:
#   0 if gcloud is usable, 1 otherwise
#######################################
__mt_hub_gcp_available() {
  command -v gcloud > /dev/null 2>&1 || return 1
  gcloud auth list --filter=status:ACTIVE --format="value(account)" 2> /dev/null | grep -q . || return 1
}

#######################################
# Repo Hub: Check whether one Terraform-declared google_* resource actually
# exists in a live GCP project, dispatching the `gcloud ... list` call by
# resource type. Every call is scoped with an explicit --project (never the
# ambient `gcloud config` project) and --quiet (never an interactive
# confirmation prompt). A resource type this framework doesn't yet know how
# to check is reported as unsupported rather than guessed at.
# Arguments:
#   $1 - Terraform resource type (e.g. "google_cloud_run_v2_service")
#   $2 - Terraform resource name (the Terraform resource label, used as the
#        expected live resource name -- real deployments name the resource
#        after this label far more often than not, but a repo that renames
#        resources via a `name = "..."` override will show a false negative
#        here; there's no way to resolve that without evaluating the
#        Terraform itself)
#   $3 - GCP project ID to check against
# Outputs:
#   Prints a JSON object: {type, name, supported: bool, deployed: bool,
#   region: string|null, console_url: string|null, live_url: string|null,
#   reason: string|null}
#######################################
__mt_hub_gcp_check_resource() {
  local rtype="$1" rname="$2" project="$3"
  local deployed=false region="null" console_url="null" live_url="null" reason="null" supported=true
  local raw

  # Every branch below captures stdout only (stderr discarded) and checks
  # the real exit code for success/failure -- gcloud often emits benign
  # warnings on stderr (e.g. deprecation notices) alongside perfectly valid
  # JSON on stdout, so merging the two streams would misparse a successful,
  # empty result as an API error.
  local rc
  case "$rtype" in
    google_cloud_run_service | google_cloud_run_v2_service | google_cloud_run_v2_job)
      raw=$(gcloud run services list --project="$project" --filter="metadata.name=$rname" --format=json --quiet 2> /dev/null)
      rc=$?
      if [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ]; then
        deployed=true
        region=$(echo "$raw" | jq -r '.[0].metadata.labels."cloud.googleapis.com/location" // .[0].region // empty')
        live_url=$(echo "$raw" | jq -r '.[0].status.url // empty')
        console_url="https://console.cloud.google.com/run/detail/${region}/${rname}/metrics?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason="api-error"
      fi
      ;;
    google_container_cluster | google_container_node_pool)
      raw=$(gcloud container clusters list --project="$project" --filter="name=$rname" --format=json --quiet 2> /dev/null)
      rc=$?
      if [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ]; then
        deployed=true
        region=$(echo "$raw" | jq -r '.[0].location // empty')
        console_url="https://console.cloud.google.com/kubernetes/clusters/details/${region}/${rname}/details?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason="api-error"
      fi
      ;;
    google_compute_instance | google_compute_instance_template | google_compute_instance_group*)
      raw=$(gcloud compute instances list --project="$project" --filter="name=$rname" --format=json --quiet 2> /dev/null)
      rc=$?
      if [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ]; then
        deployed=true
        region=$(echo "$raw" | jq -r '.[0].zone // empty' | sed -E 's#.*/##')
        console_url="https://console.cloud.google.com/compute/instancesDetail/zones/${region}/instances/${rname}?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason="api-error"
      fi
      ;;
    google_sql_database_instance)
      raw=$(gcloud sql instances list --project="$project" --filter="name=$rname" --format=json --quiet 2> /dev/null)
      rc=$?
      if [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ]; then
        deployed=true
        region=$(echo "$raw" | jq -r '.[0].region // empty')
        console_url="https://console.cloud.google.com/sql/instances/${rname}/overview?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason="api-error"
      fi
      ;;
    google_storage_bucket)
      raw=$(gcloud storage buckets describe "gs://${rname}" --project="$project" --format=json --quiet 2> /dev/null)
      rc=$?
      if [ "$rc" -eq 0 ] && [ -n "$(echo "$raw" | jq -r '.name // empty' 2> /dev/null)" ]; then
        deployed=true
        console_url="https://console.cloud.google.com/storage/browser/${rname}?project=${project}"
        live_url="https://storage.googleapis.com/${rname}"
      elif [ "$rc" -ne 0 ]; then
        reason="not-found-or-no-access"
      fi
      ;;
    google_dataflow_job)
      # Dataflow jobs are ephemeral executions, not persistent resources --
      # "deployed" here means "a job with this name has run/is running in
      # the default region" (DOCKER_GAR_REGION, this framework's one
      # existing GCP-region config value -- reused rather than adding a
      # second region setting), not that it's currently streaming.
      local dataflow_region="${DOCKER_GAR_REGION:-europe-west2}"
      raw=$(gcloud dataflow jobs list --project="$project" --region="$dataflow_region" --filter="name:$rname" --format=json --quiet 2> /dev/null)
      rc=$?
      if [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ]; then
        deployed=true
        region="$dataflow_region"
        local job_id
        job_id=$(echo "$raw" | jq -r '.[0].id // empty')
        console_url="https://console.cloud.google.com/dataflow/jobs/${dataflow_region}/${job_id}?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason="api-error"
      fi
      ;;
    *)
      supported=false
      reason="unsupported-resource-type"
      ;;
  esac

  [ "$region" != "null" ] && region="\"$region\""
  [ "$console_url" != "null" ] && console_url="\"$console_url\""
  [ "$live_url" != "null" ] && live_url="\"$live_url\""
  [ "$reason" != "null" ] && reason="\"$reason\""

  jq -n \
    --arg t "$rtype" \
    --arg n "$rname" \
    --argjson supported "$supported" \
    --argjson deployed "$deployed" \
    --argjson region "$region" \
    --argjson console_url "$console_url" \
    --argjson live_url "$live_url" \
    --argjson reason "$reason" \
    '{type: $t, name: $n, supported: $supported, deployed: $deployed, region: $region, console_url: $console_url, live_url: $live_url, reason: $reason}'
}

#######################################
# Repo Hub: Scan every google_* resource in an already-analyzed Terraform
# infrastructure overview (see __mt_hub_infra_analyze_repo) against a live
# GCP project, and compute a red/amber/green sync status from the results:
# green = every checked resource is deployed, red = none are, amber =
# some but not all, unknown = nothing was checkable (no google_* resources,
# or none of their types are supported yet). This is a deployment-
# completeness signal, not a config/state drift check -- see this file's
# header comment.
# Arguments:
#   $1 - Infra overview JSON (from __mt_hub_infra_analyze_repo /
#        .vcs_infra.json's cached entry)
#   $2 - GCP project ID to check against
# Outputs:
#   Prints a JSON object: {scanned_at, project, sync_status:
#   "green"|"amber"|"red"|"unknown", checked_count, deployed_count,
#   unsupported_count, resources: [<__mt_hub_gcp_check_resource results>]}
#######################################
__mt_hub_gcp_scan_repo() {
  local infra_json="$1" project="$2"

  local -a google_resources=()
  while IFS=$'\t' read -r rtype rname; do
    [ -z "$rtype" ] && continue
    google_resources+=("$rtype"$'\t'"$rname")
  done < <(echo "$infra_json" | jq -r '.resources // {} | to_entries[] | .value[] | select(.type | startswith("google_")) | "\(.type)\t\(.name)"')

  local results_tmp
  results_tmp=$(mktemp)
  echo "[]" > "$results_tmp"

  local entry rtype rname result
  for entry in "${google_resources[@]}"; do
    rtype="${entry%%$'\t'*}"
    rname="${entry#*$'\t'}"
    result=$(__mt_hub_gcp_check_resource "$rtype" "$rname" "$project")
    jq --argjson r "$result" '. + [$r]' "$results_tmp" > "${results_tmp}.next" && mv "${results_tmp}.next" "$results_tmp"
  done

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
# Repo Hub: Print a GCP scan result (from __mt_hub_gcp_scan_repo) as a
# colorized summary -- one line per checked/unsupported resource, plus the
# overall red/amber/green sync status.
# Arguments:
#   $1 - GCP scan JSON
# Outputs:
#   Colorized summary to stdout
#######################################
__mt_hub_gcp_scan_show() {
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
  while IFS=$'\t' read -r rtype rname deployed_flag console_url reason; do
    [ -z "$rtype" ] && continue
    if [ "$reason" = "unsupported-resource-type" ]; then
      echo -e " ${C_DIM}⚪ ${rtype}.${rname} -- unsupported${C_RESET}"
    elif [ "$deployed_flag" = "true" ]; then
      line=" ${CB_GREEN}✅ ${rtype}.${rname}${C_RESET}"
      [ "$console_url" != "null" ] && line="${line} -- ${console_url}"
      echo -e "$line"
    else
      line=" ${CB_RED}❌ ${rtype}.${rname} -- not found in project${C_RESET}"
      [ "$reason" != "null" ] && line="${line} (${reason})"
      echo -e "$line"
    fi
  done < <(echo "$scan_json" | jq -r '.resources[] | [.type, .name, (.deployed|tostring), (.console_url // "null"), (.reason // "null")] | @tsv')
}

#######################################
# Repo Hub: Merge a GCP scan result into a repo's existing .vcs_infra.json
# entry (as a "gcp_scan" field), preserving every other field already
# there -- unlike __mt_hub_infra_write_cache_entry, this must not replace
# the whole entry, since the Terraform overview it was computed from lives
# in the same cache record.
# Arguments:
#   $1 - Path to the infra JSON cache file
#   $2 - Repository path (the existing cache key)
#   $3 - GCP scan JSON (from __mt_hub_gcp_scan_repo)
#######################################
__mt_hub_infra_write_gcp_scan() {
  local cache_file="$1" repo_path="$2" scan_json="$3"
  local lock_file="${cache_file}.lock"

  (
    flock -x 200
    local tmp_cache
    tmp_cache=$(mktemp)
    jq --arg r "$repo_path" --argjson s "$scan_json" '.[$r].gcp_scan = $s' "$cache_file" > "$tmp_cache" && mv "$tmp_cache" "$cache_file"
  ) 200> "$lock_file"
}
