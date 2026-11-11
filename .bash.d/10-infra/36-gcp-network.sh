# shellcheck shell=bash
# ------------------------------------------
# GCP: VPC Network Dependency Inventory
# ------------------------------------------
# ~/.bash.d/10-infra/36-gcp-network.sh

GCL_NETWORK_NAME_REGEX='^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$'
GCL_NETWORK_REGION_REGEX='^[a-z0-9-]+$'
GCL_NETWORK_DEPS_JQ="$HOME/.bash.d/lib/jq/gcl_network_deps.jq"
GCL_NETWORK_REGIONS_JQ="$HOME/.bash.d/lib/jq/gcl_network_regions.jq"
GCL_NETWORK_EMPTY_LIST="[]"
GCL_NETWORK_TRAFFIC_MAX_DAYS=42
GCL_NETWORK_TRAFFIC_JQ="$HOME/.bash.d/lib/jq/gcl_network_traffic.jq"
GCL_NETWORK_TRAFFIC_COUNTS_JQ="$HOME/.bash.d/lib/jq/gcl_network_traffic_counts.jq"
# "kind:metric type:resource label" -- request-count metrics, summed per forwarding rule / Cloud Run service
GCL_NETWORK_TRAFFIC_METRICS=(
  "lb:loadbalancing.googleapis.com/https/request_count:forwarding_rule_name"
  "lb:loadbalancing.googleapis.com/https/external/regional/request_count:forwarding_rule_name"
  "lb:loadbalancing.googleapis.com/https/internal/request_count:forwarding_rule_name"
  "run:run.googleapis.com/request_count:service_name"
)
# "section:gcloud words" -- listed in the project and filtered by exact network match in jq
GCL_NETWORK_SECTIONS=(
  "instances:compute instances list"
  "instance_groups:compute instance-groups list"
  "negs:compute network-endpoint-groups list"
  "backend_services:compute backend-services list"
  "url_maps:compute url-maps list"
  "http_proxies:compute target-http-proxies list"
  "https_proxies:compute target-https-proxies list"
  "tcp_proxies:compute target-tcp-proxies list"
  "ssl_proxies:compute target-ssl-proxies list"
  "forwarding_rules:compute forwarding-rules list"
  "routers:compute routers list"
  "firewalls:compute firewall-rules list"
  "subnets:compute networks subnets list"
  "addresses:compute addresses list"
  "run:run services list"
  "run_jobs:run jobs list"
  "functions:functions list"
  "redis:redis instances list --region=-"
  "sql:sql instances list"
)

#######################################
# GCP: Run one gcloud list into a JSON file, writing an empty list when the
# call fails or returns something that is not JSON.
# Arguments:
#   $1 - Output file, $2 - What is being attempted, $3... - the gcloud arguments
# Returns:
#   0 on success, GCL_EXIT_DENIED on a permission denial, 1 otherwise
#######################################
__mt_gcl_network_collect() {
  local out_file="$1" context="$2" data rc=0
  shift 2 || return 1
  data=$(__mt_gcl_run "$context" gcloud "$@") || rc=$?
  if [ "$rc" -eq 0 ] && { [ -z "$data" ] || jq -e . > /dev/null 2>&1 <<< "$data"; }; then
    printf '%s\n' "${data:-$GCL_NETWORK_EMPTY_LIST}" > "$out_file"
    return 0
  fi
  echo "$GCL_NETWORK_EMPTY_LIST" > "$out_file"
  if [ "$rc" -eq 0 ]; then
    echo -e "${CB_RED}❌ ${context}: gcloud returned non-JSON output.${C_RESET}" >&2
    rc=1
  fi
  return "$rc"
}

#######################################
# GCP: Fold a section's return code into the scan's overall code (a denial
# outranks any other failure).
# Arguments:
#   $1 - Current overall code, $2 - Section's return code
# Outputs:
#   The new overall code
#######################################
__mt_gcl_network_merge_rc() {
  local overall="$1" section_rc="$2"
  if [ "$section_rc" -eq 0 ] || [ "$overall" -eq "$GCL_EXIT_DENIED" ]; then
    echo "$overall"
  elif [ "$section_rc" -eq "$GCL_EXIT_DENIED" ]; then
    echo "$GCL_EXIT_DENIED"
  else
    echo 1
  fi
}

#######################################
# GCP: List a regional resource once per region and merge the results.
# Arguments:
#   $1 - Output file, $2 - Scratch directory, $3 - Project, $4 - section label,
#   $5 - gcloud words with a trailing --region/--location flag name, $6... - regions
# Returns:
#   0 on success, otherwise the worst per-region code
#######################################
__mt_gcl_network_collect_regional() {
  local out_file="$1" scratch="$2" project="$3" label="$4" flag="$5" region index=0 rc=0 region_rc
  shift 5
  local -a words files=()
  read -ra words <<< "$label"
  for region in "$@"; do
    index=$((index + 1))
    region_rc=0
    __mt_gcl_network_collect "$scratch/regional.$index.json" "listing ${words[*]} in ${project}/${region}" \
      "${words[@]}" "${flag}=${region}" --project="$project" --format=json --quiet || region_rc=$?
    files+=("$scratch/regional.$index.json")
    rc=$(__mt_gcl_network_merge_rc "$rc" "$region_rc")
  done
  if [ "${#files[@]}" -eq 0 ]; then
    echo "$GCL_NETWORK_EMPTY_LIST" > "$out_file"
  else
    jq -s 'add // []' "${files[@]}" > "$out_file"
  fi
  return "$rc"
}

#######################################
# GCP: Read request counts for the last N days from Cloud Monitoring and
# write them to <scratch>/traffic.json as
# {lb, run, lb_failed, run_failed}.
# Arguments:
#   $1 - Scratch directory, $2 - Project, $3 - Days
# Returns:
#   0 if every metric was read, otherwise the worst code (GCL_EXIT_DENIED outranks 1)
#######################################
__mt_gcl_network_traffic_counts() {
  local scratch="$1" project="$2" days="$3" overall=0 spec kind metric label series metric_rc
  local lb_json="{}" run_json="{}" lb_failed=false run_failed=false
  for spec in "${GCL_NETWORK_TRAFFIC_METRICS[@]}"; do
    kind="${spec%%:*}"
    metric="${spec#*:}"
    label="${metric##*:}"
    metric="${metric%:*}"
    metric_rc=0
    series=$(gcl-metric-read "$metric" -p "$project" --since "${days}d" --align window --aligner ALIGN_SUM \
      --reducer REDUCE_SUM --group-by "resource.label.${label}" --json) || metric_rc=$?
    if [ "$metric_rc" -ne 0 ]; then
      [ "$kind" = "lb" ] && lb_failed=true || run_failed=true
      overall=$(__mt_gcl_network_merge_rc "$overall" "$metric_rc")
      continue
    fi
    [ -z "$series" ] && continue
    if [ "$kind" = "lb" ]; then
      lb_json=$(jq -c --arg label "$label" --argjson base "$lb_json" -f "$GCL_NETWORK_TRAFFIC_COUNTS_JQ" <<< "$series")
    else
      run_json=$(jq -c --arg label "$label" --argjson base "$run_json" -f "$GCL_NETWORK_TRAFFIC_COUNTS_JQ" <<< "$series")
    fi
  done
  jq -nc --argjson lb "$lb_json" --argjson run "$run_json" --argjson lb_failed "$lb_failed" --argjson run_failed "$run_failed" \
    '{lb: $lb, run: $run, lb_failed: $lb_failed, run_failed: $run_failed}' > "$scratch/traffic.json"
  return "$overall"
}

#######################################
# GCP: Collect every section for a network and print the dependency rows.
# Arguments:
#   $1 - Scratch directory, $2 - Network, $3 - Project, $4 - "1" for every region,
#   $5... - Explicit regions
# Returns:
#   0 for a complete scan, GCL_EXIT_DENIED if any section was denied, 1 otherwise
# Outputs:
#   Rows on stdout; progress and the summary on stderr
#######################################
__mt_gcl_network_scan() {
  local scratch="$1" network="$2" project="$3" all_regions="$4" traffic_days="$5" overall=0 section_rc spec name
  shift 5
  local -a explicit_regions=("$@") words
  local network_path="projects/${project}/global/networks/${network}"

  local description
  description=$(__mt_gcl_run "describing network ${network} in ${project}" gcloud compute networks describe "$network" \
    --project="$project" --format=json --quiet) || return $?
  local auto_mode peerings
  auto_mode=$(jq -r '.autoCreateSubnetworks // false' <<< "$description")
  peerings=$(jq -c '.peerings // []' <<< "$description")

  for spec in "${GCL_NETWORK_SECTIONS[@]}"; do
    name="${spec%%:*}"
    read -ra words <<< "${spec#*:}"
    section_rc=0
    __mt_gcl_network_collect "$scratch/${name}.json" "listing ${words[*]} in ${project}" \
      "${words[@]}" --project="$project" --format=json --quiet || section_rc=$?
    overall=$(__mt_gcl_network_merge_rc "$overall" "$section_rc")
  done

  local -a connector_regions scheduler_regions
  if [ "${#explicit_regions[@]}" -gt 0 ]; then
    connector_regions=("${explicit_regions[@]}")
    scheduler_regions=("${explicit_regions[@]}")
  elif [ "$all_regions" = "1" ]; then
    local connector_list scheduler_list discovery_rc=0
    connector_list=$(__mt_gcl_run "listing VPC connector locations of ${project}" gcloud compute networks vpc-access locations list \
      --project="$project" --format='value(locationId)' --quiet) || discovery_rc=$?
    overall=$(__mt_gcl_network_merge_rc "$overall" "$discovery_rc")
    discovery_rc=0
    scheduler_list=$(__mt_gcl_scheduler_locations "$project" 1) || discovery_rc=$?
    overall=$(__mt_gcl_network_merge_rc "$overall" "$discovery_rc")
    mapfile -t connector_regions < <(printf '%s' "$connector_list" | sed '/^$/d')
    mapfile -t scheduler_regions < <(printf '%s' "$scheduler_list" | sed '/^$/d')
    if [ "${#connector_regions[@]}" -eq 0 ]; then
      echo -e "${CB_RED}❌ No regions to check for VPC connectors.${C_RESET}" >&2
      overall=$(__mt_gcl_network_merge_rc "$overall" 1)
    fi
    if [ "${#scheduler_regions[@]}" -eq 0 ]; then
      echo -e "${CB_RED}❌ No regions to check for Scheduler jobs.${C_RESET}" >&2
      overall=$(__mt_gcl_network_merge_rc "$overall" 1)
    fi
  else
    local -a scan_regions
    read -ra scan_regions <<< "${GCP_SCAN_REGIONS:-$GCL_SCHEDULER_DEFAULT_LOCATIONS}"
    mapfile -t connector_regions < <({
      printf '%s\n' "${scan_regions[@]}"
      jq -r --arg net "$network_path" --slurpfile subnets "$scratch/subnets.json" --slurpfile run "$scratch/run.json" \
        --slurpfile run_jobs "$scratch/run_jobs.json" --slurpfile functions "$scratch/functions.json" -n -f "$GCL_NETWORK_REGIONS_JQ"
    } | sort -u)
    scheduler_regions=("${connector_regions[@]}")
  fi
  echo -e "${C_DIM}🔎 Regions checked: ${connector_regions[*]}${C_RESET}" >&2
  [ "${connector_regions[*]}" != "${scheduler_regions[*]}" ] &&
    echo -e "${C_DIM}🔎 Scheduler regions checked: ${scheduler_regions[*]}${C_RESET}" >&2

  section_rc=0
  __mt_gcl_network_collect_regional "$scratch/connectors.json" "$scratch" "$project" \
    "compute networks vpc-access connectors list" --region "${connector_regions[@]}" || section_rc=$?
  overall=$(__mt_gcl_network_merge_rc "$overall" "$section_rc")
  section_rc=0
  __mt_gcl_network_collect_regional "$scratch/scheduler.json" "$scratch" "$project" \
    "scheduler jobs list" --location "${scheduler_regions[@]}" || section_rc=$?
  overall=$(__mt_gcl_network_merge_rc "$overall" "$section_rc")

  local -a slurp_args=()
  for name in connectors scheduler "${GCL_NETWORK_SECTIONS[@]%%:*}"; do
    slurp_args+=(--slurpfile "$name" "$scratch/${name}.json")
  done
  local rows count
  rows=$(jq -n -r --arg net "$network_path" --arg name "$network" --arg project "$project" \
    --argjson auto "$auto_mode" --argjson peerings "$peerings" "${slurp_args[@]}" -f "$GCL_NETWORK_DEPS_JQ" |
    __mt_strip_control_chars)
  count=0
  [ -n "$rows" ] && count=$(wc -l <<< "$rows")
  local served=""
  if [ -n "$traffic_days" ] && [ -n "$rows" ]; then
    section_rc=0
    __mt_gcl_network_traffic_counts "$scratch" "$project" "$traffic_days" || section_rc=$?
    overall=$(__mt_gcl_network_merge_rc "$overall" "$section_rc")
    rows=$(jq -R -r --slurpfile traffic "$scratch/traffic.json" --slurpfile forwarding_rules "$scratch/forwarding_rules.json" \
      -f "$GCL_NETWORK_TRAFFIC_JQ" <<< "$rows")
    served=$(awk -F'\t' '$5 ~ /^[0-9]+$/ && $5 > 0' <<< "$rows" | wc -l)
  fi
  [ -n "$rows" ] && echo "$rows"

  if [ "$count" -gt 0 ]; then
    echo -e "${CB_YELLOW}⚠️  ${count} resources reference ${network}; it is not safe to delete.${C_RESET}" >&2
    [ -n "$served" ] && echo -e "${CB_YELLOW}${served} of them served requests in the last ${traffic_days}d.${C_RESET}" >&2
  else
    echo -e "${CB_GREEN}✅ Nothing in ${project} references ${network}.${C_RESET}" >&2
  fi
  echo -e "${C_DIM}Not covered: Shared VPC service projects, regions not checked.${C_RESET}" >&2
  return "$overall"
}

#######################################
# GCP: List everything in a project that still references a VPC network --
# instances, instance groups and NEGs, the whole load-balancer chain,
# routers/NAT, firewall rules, subnets, reserved addresses, VPC peerings,
# Memorystore Redis, Cloud SQL private IP, VPC connectors, and the Cloud Run
# services and jobs, functions and Cloud Scheduler jobs that depend on them. Every
# match is by exact network path, never a name substring. A section that is
# denied or fails is reported and the rest are still listed. Read-only. Needs
# compute.viewer, run.viewer, cloudfunctions.viewer, vpcaccess.viewer,
# cloudscheduler.viewer, redis.viewer and cloudsql.viewer.
# With --traffic-days it also reads request counts from Cloud Monitoring (needs
# monitoring.viewer) and adds a fifth column: the summed requests over the window for
# forwarding rules and Cloud Run services, "0" when a matched resource served none,
# "?" when the metric could not be read, and "n/a" for every other kind. Forwarding
# rules that are not HTTP(S) Application Load Balancers (L4 passthrough, TCP/SSL
# proxy) are "n/a", because the request-count metrics do not cover them.
# Usage: gcl-network-deps <network> [-p <project>] [-r <region>]... [--all-regions] [--traffic-days <n>]
# Options:
#   -p, --project <id>    Project that owns the network (default: the active gcloud project)
#   -r, --region <name>   Region to check for VPC connectors and Scheduler jobs, repeatable;
#                         default: scan regions + the network's subnet regions + the regions of
#                         every Cloud Run service and function
#   --all-regions         Check every region (cannot be combined with -r)
#   --traffic-days <n>    Add a requests_<n>d column (1-42 days; default: no metrics are read)
#   -h, --help            Show this help
# Returns:
#   0 for a complete scan, 1 on a failed section, bad usage or an unknown network,
#   5 if any section was permission-denied
# Outputs:
#   "kind<TAB>name<TAB>location<TAB>detail" per dependent resource on stdout (plus
#   "<TAB>requests" with --traffic-days); regions checked and a summary on stderr
# Example: gcl-network-deps legacy-net -p my-project --traffic-days 30
#######################################
gcl-network-deps() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local usage="Usage: gcl-network-deps <network> [-p <project>] [-r <region>]... [--all-regions] [--traffic-days <n>]"
  local network="" project="" all_regions="" traffic_days="" traffic_set=""
  local -a regions=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --project)
        project="${2:-}"
        shift
        ;;
      -r | --region)
        regions+=("${2:-}")
        shift
        ;;
      --all-regions) all_regions="1" ;;
      --traffic-days)
        traffic_days="${2:-}"
        traffic_set="1"
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) network="$1" ;;
    esac
    shift
  done
  if [ -z "$network" ] || { [ -n "$all_regions" ] && [ "${#regions[@]}" -gt 0 ]; }; then
    echo "$usage" >&2
    return 1
  fi
  if [[ ! "$network" =~ $GCL_NETWORK_NAME_REGEX ]]; then
    echo -e "${CB_RED}❌ Invalid network name: ${network}${C_RESET}" >&2
    return 1
  fi
  if [ -n "$traffic_set" ] && { [[ ! "$traffic_days" =~ ^[1-9][0-9]*$ ]] || [ "$traffic_days" -gt "$GCL_NETWORK_TRAFFIC_MAX_DAYS" ]; }; then
    echo -e "${CB_RED}❌ --traffic-days must be a whole number from 1 to ${GCL_NETWORK_TRAFFIC_MAX_DAYS}.${C_RESET}" >&2
    return 1
  fi
  local region
  for region in "${regions[@]}"; do
    [[ "$region" =~ $GCL_NETWORK_REGION_REGEX ]] || {
      echo -e "${CB_RED}❌ Invalid region: ${region}${C_RESET}" >&2
      return 1
    }
  done
  [ -z "$project" ] && project=$(gcl-get-project)
  if [[ ! "$project" =~ $GCL_PROJECT_ID_REGEX ]]; then
    echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
    return 1
  fi
  __mt_gcl_preflight || return $?

  local scratch rc=0
  scratch=$(mktemp -d) || return 1
  __mt_gcl_network_scan "$scratch" "$network" "$project" "$all_regions" "$traffic_days" "${regions[@]}" || rc=$?
  rm -rf "$scratch"
  return "$rc"
}
