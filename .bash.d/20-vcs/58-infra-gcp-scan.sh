# shellcheck shell=bash
# ------------------------------------------
# Repo Radar: Live GCP Deployment Scanning
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
# Repo Radar: Check whether one Terraform-declared google_* resource actually
# exists in a live GCP project, dispatching the `gcloud ... list` call by
# resource type. Every call is scoped with an explicit --project (never the
# ambient `gcloud config` project) and --quiet (never an interactive
# confirmation prompt). A resource type this framework doesn't yet know how
# to check is reported as unsupported rather than guessed at.
# Arguments:
#   $1 - Terraform resource type (e.g. "google_cloud_run_v2_service")
#   $2 - Terraform resource name (the Terraform resource label, used as the
#        first-choice expected live resource name -- real deployments name
#        the resource after this label far more often than not)
#   $3 - GCP project ID to check against
#   $4 - Fallback candidate name (optional) -- tried only if $2 doesn't
#        match anything live, e.g. the repo's own basename. Real-world
#        Terraform overwhelmingly deploys resources named after the repo
#        itself (`name = var.service_name`, set from a repo-named CI
#        variable/tfvars, not the Terraform resource label), which this
#        catches without evaluating the Terraform itself -- something
#        __mt_radar_detect_gcp's own docstring already rules out doing
#        for the same reason (a variable, not a literal, is what's
#        actually there far more often than not).
# Outputs:
#   Prints a JSON object: {type, name, supported: bool, deployed: bool,
#   region: string|null, console_url: string|null, live_url: string|null,
#   matched_name: string|null (the live name that actually matched, only
#   when it differs from $2 -- i.e. it matched via the $4 fallback),
#   reason: string|null}
#######################################
__mt_radar_gcp_check_resource() {
  local rtype="$1" rname="$2" project="$3" fallback_name="${4:-}"
  local deployed=false region="null" console_url="null" live_url="null" reason="null" supported=true
  local matched_name="null"
  local raw

  # Try the Terraform label first, then the fallback candidate (if given
  # and different) only when the label didn't match anything live.
  local -a candidates=("$rname")
  [ -n "$fallback_name" ] && [ "$fallback_name" != "$rname" ] && candidates+=("$fallback_name")

  # Every branch below captures stdout separately from stderr (never
  # merged) and checks the real exit code for success/failure -- gcloud
  # often emits benign warnings on stderr (e.g. deprecation notices)
  # alongside perfectly valid JSON on stdout, so merging the two streams
  # would misparse a successful, empty result as an API error. stderr is
  # written to $gcp_stderr_file (overwritten each candidate attempt, not
  # discarded) so a genuine failure's reason can be classified below
  # rather than lumped into a single opaque "api-error".
  local gcp_stderr_file
  gcp_stderr_file=$(mktemp)
  local rc candidate found=false
  case "$rtype" in
    google_cloud_run_service | google_cloud_run_v2_service | google_cloud_run_v2_job)
      for candidate in "${candidates[@]}"; do
        raw=$(gcloud run services list --project="$project" --filter="metadata.name=$candidate" --format=json --quiet 2> "$gcp_stderr_file")
        rc=$?
        [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ] && {
          found=true
          break
        }
      done
      if [ "$found" = true ]; then
        deployed=true
        [ "$candidate" != "$rname" ] && matched_name="\"$candidate\""
        region=$(echo "$raw" | jq -r '.[0].metadata.labels."cloud.googleapis.com/location" // .[0].region // empty')
        live_url=$(echo "$raw" | jq -r '.[0].status.url // empty')
        console_url="https://console.cloud.google.com/run/detail/${region}/${candidate}/metrics?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason=$(__mt_radar_gcp_classify_error "$(cat "$gcp_stderr_file")")
      fi
      ;;
    google_container_cluster | google_container_node_pool)
      for candidate in "${candidates[@]}"; do
        raw=$(gcloud container clusters list --project="$project" --filter="name=$candidate" --format=json --quiet 2> "$gcp_stderr_file")
        rc=$?
        [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ] && {
          found=true
          break
        }
      done
      if [ "$found" = true ]; then
        deployed=true
        [ "$candidate" != "$rname" ] && matched_name="\"$candidate\""
        region=$(echo "$raw" | jq -r '.[0].location // empty')
        console_url="https://console.cloud.google.com/kubernetes/clusters/details/${region}/${candidate}/details?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason=$(__mt_radar_gcp_classify_error "$(cat "$gcp_stderr_file")")
      fi
      ;;
    google_compute_instance | google_compute_instance_template | google_compute_instance_group*)
      for candidate in "${candidates[@]}"; do
        raw=$(gcloud compute instances list --project="$project" --filter="name=$candidate" --format=json --quiet 2> "$gcp_stderr_file")
        rc=$?
        [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ] && {
          found=true
          break
        }
      done
      if [ "$found" = true ]; then
        deployed=true
        [ "$candidate" != "$rname" ] && matched_name="\"$candidate\""
        region=$(echo "$raw" | jq -r '.[0].zone // empty' | sed -E 's#.*/##')
        console_url="https://console.cloud.google.com/compute/instancesDetail/zones/${region}/instances/${candidate}?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason=$(__mt_radar_gcp_classify_error "$(cat "$gcp_stderr_file")")
      fi
      ;;
    google_sql_database_instance)
      for candidate in "${candidates[@]}"; do
        raw=$(gcloud sql instances list --project="$project" --filter="name=$candidate" --format=json --quiet 2> "$gcp_stderr_file")
        rc=$?
        [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ] && {
          found=true
          break
        }
      done
      if [ "$found" = true ]; then
        deployed=true
        [ "$candidate" != "$rname" ] && matched_name="\"$candidate\""
        region=$(echo "$raw" | jq -r '.[0].region // empty')
        console_url="https://console.cloud.google.com/sql/instances/${candidate}/overview?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason=$(__mt_radar_gcp_classify_error "$(cat "$gcp_stderr_file")")
      fi
      ;;
    google_storage_bucket)
      for candidate in "${candidates[@]}"; do
        raw=$(gcloud storage buckets describe "gs://${candidate}" --project="$project" --format=json --quiet 2> /dev/null)
        rc=$?
        [ "$rc" -eq 0 ] && [ -n "$(echo "$raw" | jq -r '.name // empty' 2> /dev/null)" ] && {
          found=true
          break
        }
      done
      if [ "$found" = true ]; then
        deployed=true
        [ "$candidate" != "$rname" ] && matched_name="\"$candidate\""
        console_url="https://console.cloud.google.com/storage/browser/${candidate}?project=${project}"
        live_url="https://storage.googleapis.com/${candidate}"
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
      for candidate in "${candidates[@]}"; do
        raw=$(gcloud dataflow jobs list --project="$project" --region="$dataflow_region" --filter="name:$candidate" --format=json --quiet 2> "$gcp_stderr_file")
        rc=$?
        [ "$rc" -eq 0 ] && [ "$(echo "$raw" | jq 'length')" -gt 0 ] && {
          found=true
          break
        }
      done
      if [ "$found" = true ]; then
        deployed=true
        [ "$candidate" != "$rname" ] && matched_name="\"$candidate\""
        region="$dataflow_region"
        local job_id
        job_id=$(echo "$raw" | jq -r '.[0].id // empty')
        console_url="https://console.cloud.google.com/dataflow/jobs/${dataflow_region}/${job_id}?project=${project}"
      elif [ "$rc" -ne 0 ]; then
        reason=$(__mt_radar_gcp_classify_error "$(cat "$gcp_stderr_file")")
      fi
      ;;
    *)
      supported=false
      reason="unsupported-resource-type"
      ;;
  esac

  rm -f "$gcp_stderr_file"

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
    --argjson matched_name "$matched_name" \
    --argjson reason "$reason" \
    '{type: $t, name: $n, supported: $supported, deployed: $deployed, region: $region, console_url: $console_url, live_url: $live_url, matched_name: $matched_name, reason: $reason}'
}

#######################################
# Repo Radar: Scan every google_* resource in an already-analyzed Terraform
# infrastructure overview (see __mt_radar_infra_analyze_repo) against a live
# GCP project, and compute a red/amber/green sync status from the results:
# green = every checked resource is deployed, red = none are, amber =
# some but not all, unknown = nothing was checkable (no google_* resources,
# or none of their types are supported yet). This is a deployment-
# completeness signal, not a config/state drift check -- see this file's
# header comment.
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
    result=$(__mt_radar_gcp_check_resource "$rtype" "$rname" "$project" "$repo_name")
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
