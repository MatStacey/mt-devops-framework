# shellcheck shell=bash
# ------------------------------------------
# Repo Radar: Infrastructure Overview (Terraform)
# ------------------------------------------
# ~/.bash.d/20-vcs/57-infra.sh

#######################################
# Repo Radar: Classify a Terraform resource type into a broad, provider-
# agnostic infrastructure category, by substring on the resource type
# name (bash glob patterns via `case`, not regex -- Terraform resource
# type names are already provider_service_thing, e.g. google_sql_
# database_instance/aws_rds_cluster, so a substring match on common
# service-family words works across providers without needing a
# per-provider prefix table the size of every cloud's resource catalog).
# Order matters: more specific families (iam, messaging, data/analytics,
# database) are checked before the broad "compute" catch-all, since e.g.
# a *_function resource should land in "compute" but *_service_account
# should never fall through to it.
# Arguments:
#   $1 - Terraform resource type (e.g. "google_cloud_run_service")
# Outputs:
#   Prints one of: iam, messaging, data, database, storage, networking,
#   compute, other
#######################################
__mt_radar_infra_categorize_resource() {
  local rtype="$1"
  case "$rtype" in
    *iam* | *service_account* | *kms* | *secretmanager* | *secret_manager* | *certificate* | *ssl_cert*)
      echo "iam"
      ;;
    *pubsub* | *_topic | *_queue | *sqs* | *sns* | *eventarc*)
      echo "messaging"
      ;;
    *bigquery* | *dataflow* | *dataproc* | *composer* | *pipeline*)
      echo "data"
      ;;
    *sql* | *database* | *bigtable* | *spanner* | *firestore* | *redis* | *memorystore* | *dynamodb* | *rds*)
      echo "database"
      ;;
    *storage* | *bucket* | *disk* | *volume* | *filestore*)
      echo "storage"
      ;;
    *network* | *subnet* | *vpc* | *firewall* | *route* | *load_balancer* | *forwarding_rule* | *dns* | *_nat_* | *peering* | *address*)
      echo "networking"
      ;;
    *compute* | *instance* | *cluster* | *container* | *function* | *cloud_run* | *cloudrun* | *app_engine* | *node_pool* | *ecs* | *ec2* | *lambda*)
      echo "compute"
      ;;
    *)
      echo "other"
      ;;
  esac
}

#######################################
# Repo Radar: Analyze a repo's own Terraform (recursively, including local
# modules vendored in-repo -- an externally-sourced module's internals
# aren't visible here, only that it's used) and build a structured
# overview of the infrastructure it *deploys*: only `resource` blocks are
# counted, never `data` blocks (those reference existing infrastructure,
# not something this repo provisions). Deliberately regex/case-based
# rather than a real HCL parser -- correct for the common single-line
# `resource "type" "name" {` / `module "name" {` declaration style this
# framework's other heuristics already assume, at the cost of missing
# anything split across multiple lines or built with `for_each`/dynamic
# blocks whose type isn't a literal string.
# Arguments:
#   $1 - Repository path
# Outputs:
#   Prints a JSON object:
#   {status: "ok"|"no-terraform", analyzed_at: <epoch>|null,
#    tf_file_count, providers: [...], modules: [{name}],
#    resources: {<category>: [{type, name}]}, resource_count}
#######################################
__mt_radar_infra_analyze_repo() {
  local repo_path="$1"
  local -a tf_files=()
  while IFS= read -r -d '' f; do tf_files+=("$f"); done < <(
    find "$repo_path" -name "*.tf" -not -path "*/.terraform/*" -print0 2> /dev/null
  )

  if [ "${#tf_files[@]}" -eq 0 ]; then
    jq -n '{status: "no-terraform", analyzed_at: null, tf_file_count: 0, providers: [], modules: [], resources: {}, resource_count: 0}'
    return 0
  fi

  local providers_json
  providers_json=$(
    grep -hoE 'provider[[:space:]]+"[a-z0-9_-]+"' "${tf_files[@]}" 2> /dev/null |
      grep -oE '"[a-z0-9_-]+"' | tr -d '"' | sort -u | jq -R . | jq -s .
  )
  [ -z "$providers_json" ] && providers_json="[]"

  local modules_json="[]"
  local -a module_names=()
  while IFS= read -r name; do
    [ -n "$name" ] && module_names+=("$name")
  done < <(grep -hoE 'module[[:space:]]+"[a-zA-Z0-9_-]+"' "${tf_files[@]}" 2> /dev/null | grep -oE '"[a-zA-Z0-9_-]+"' | tr -d '"' | sort -u)
  if [ "${#module_names[@]}" -gt 0 ]; then
    modules_json=$(printf '%s\n' "${module_names[@]}" | jq -R '{name: .}' | jq -s .)
  fi

  local resource_tsv
  resource_tsv=$(mktemp)
  local rtype rname category
  while IFS=$'\t' read -r rtype rname; do
    [ -z "$rtype" ] && continue
    category=$(__mt_radar_infra_categorize_resource "$rtype")
    printf '%s\t%s\t%s\n' "$category" "$rtype" "$rname" >> "$resource_tsv"
  done < <(
    grep -hoE 'resource[[:space:]]+"[a-zA-Z0-9_]+"[[:space:]]+"[a-zA-Z0-9_-]+"' "${tf_files[@]}" 2> /dev/null |
      sed -E 's/resource[[:space:]]+"([a-zA-Z0-9_]+)"[[:space:]]+"([a-zA-Z0-9_-]+)"/\1\t\2/'
  )

  local resource_count
  resource_count=$(wc -l < "$resource_tsv")

  local resources_json="{}"
  if [ "$resource_count" -gt 0 ]; then
    resources_json=$(jq -R -s '
      split("\n") | map(select(length > 0) | split("\t")) |
      map({category: .[0], type: .[1], name: .[2]}) |
      group_by(.category) |
      map({key: .[0].category, value: map({type, name})}) |
      from_entries
    ' "$resource_tsv")
  fi
  rm -f "$resource_tsv"

  jq -n \
    --argjson tf_file_count "${#tf_files[@]}" \
    --argjson providers "$providers_json" \
    --argjson modules "$modules_json" \
    --argjson resources "$resources_json" \
    --argjson resource_count "$resource_count" \
    --argjson analyzed_at "$(date +%s)" \
    '{status: "ok", analyzed_at: $analyzed_at, tf_file_count: $tf_file_count, providers: $providers, modules: $modules, resources: $resources, resource_count: $resource_count}'
}

#######################################
# Repo Radar: Write one repo's infrastructure overview into its own JSON
# cache (.vcs_infra.json -- separate from .vcs_radar.json so the main
# dashboard cache stays small and fast to rewrite on every index run,
# even though this data is generated far less often), under the same
# exclusive-lock pattern as __mt_radar_write_cache_entry.
# Arguments:
#   $1 - Path to the infra JSON cache file
#   $2 - Repository path (becomes the cache key)
#   $3 - Infra overview JSON (from __mt_radar_infra_analyze_repo)
#######################################
__mt_radar_infra_write_cache_entry() {
  local cache_file="$1" repo_path="$2" infra_json="$3"
  local lock_file="${cache_file}.lock"

  (
    flock -x 200
    local tmp_cache
    tmp_cache=$(mktemp)
    jq --arg r "$repo_path" --argjson i "$infra_json" '.[$r] = $i' "$cache_file" > "$tmp_cache" && mv "$tmp_cache" "$cache_file"
  ) 200> "$lock_file"
}

#######################################
# Repo Radar: Standalone infrastructure analysis over every repo matching
# the type/name filters (or every repo, unfiltered) -- unlike
# __mt_radar_index, this never calls an AI provider and is cheap enough to
# just always re-run and overwrite, so there's no cache/force/update-
# missing bookkeeping to thread through here. Repos with no Terraform at
# all are silently skipped (not written to the cache) rather than
# recorded as an empty entry, so a full unfiltered run doesn't bloat
# .vcs_infra.json with one no-op entry per non-Terraform repo.
# Arguments:
#   $1 - VCS search root
#   $2 - Type filter (lowercased; empty = no filter)
#   $3 - Name filter (empty = no filter)
#   $4 - Path to the infra JSON cache file
#######################################
__mt_radar_infra_run() {
  local search_dir="$1" filter_type="${2,,}" filter_repo="$3" cache_file="$4"
  mkdir -p "$(dirname "$cache_file")"
  [ -f "$cache_file" ] || echo "{}" > "$cache_file"

  local msg_suffix=""
  [ -n "$filter_type" ] && msg_suffix=" of type '${filter_type}'"
  [ -n "$filter_repo" ] && msg_suffix="${msg_suffix} matching repo '${filter_repo}'"
  echo -e "${CB_BLUE}🔍 Scanning for Terraform to analyze${msg_suffix}...${C_RESET}"

  local analyzed=0 skipped=0
  local repo_path
  while IFS= read -r repo_path; do
    [ -z "$repo_path" ] && continue
    local repo_name repo_type rel_path
    repo_name=$(basename "$repo_path")
    rel_path="${repo_path#"$search_dir"/}"
    repo_type="Root"
    [[ "$rel_path" == */* ]] && repo_type="${rel_path%%/*}"

    [ -n "$filter_type" ] && [ "${repo_type,,}" != "$filter_type" ] && continue
    [ -n "$filter_repo" ] && [ "$repo_name" != "$filter_repo" ] && continue

    local infra_json status
    infra_json=$(__mt_radar_infra_analyze_repo "$repo_path")
    status=$(echo "$infra_json" | jq -r '.status')

    if [ "$status" != "ok" ]; then
      skipped=$((skipped + 1))
      continue
    fi

    __mt_radar_infra_write_cache_entry "$cache_file" "$repo_path" "$infra_json"
    echo -e "${CB_GREEN}✅ Infrastructure overview generated: ${repo_name}${C_RESET}"
    analyzed=$((analyzed + 1))
  done < <(__mt_radar_find_repos "$search_dir")

  if [ "$analyzed" -eq 0 ] && [ "$skipped" -eq 0 ]; then
    mt-log WARN "No repositories matched your filter criteria."
  else
    echo -e "\n${CB_CYAN}📊 Infrastructure analysis complete: ${analyzed} repo(s) analyzed, ${skipped} skipped (no Terraform found).${C_RESET}"
  fi
}

#######################################
# Repo Radar: Print one repo's cached infrastructure overview (by absolute
# path or bare repo name, same resolution as __mt_radar_preview), as a
# colorized summary or (with json_mode) the raw cached JSON object.
# Arguments:
#   $1 - Repo identifier: an absolute path (exact cache key) or a bare
#        repo name
#   $2 - Path to the infra JSON cache file
#   $3 - "true" to print the raw JSON instead of a colorized summary
#######################################
__mt_radar_infra_show() {
  local repo="$1" cache_file="$2" json_mode="$3"
  [ -f "$cache_file" ] || echo "{}" > "$cache_file"

  local infra
  infra=$(jq -r --arg r "$repo" '.[$r] // empty' "$cache_file" 2> /dev/null)

  if [ -z "$infra" ]; then
    local resolved
    resolved=$(jq -r --arg name "$repo" 'to_entries[] | select((.key | split("/") | last) == $name) | .key' "$cache_file" 2> /dev/null | head -n1)
    if [ -n "$resolved" ]; then
      infra=$(jq -r --arg r "$resolved" '.[$r] // empty' "$cache_file" 2> /dev/null)
    fi
  fi

  if [ -z "$infra" ] || [ "$infra" == "null" ]; then
    if [ "$json_mode" = true ]; then
      jq -n '{status: "not-analyzed"}'
    else
      echo -e "${CB_YELLOW}⚠️  No infrastructure overview found for \"${repo}\".${C_RESET}"
      echo -e "Run ${CB_GREEN}mt-radar --infra -r <repo>${C_RESET} to generate one (requires Terraform in the repo)."
    fi
    return 0
  fi

  if [ "$json_mode" = true ]; then
    echo "$infra"
    return 0
  fi

  echo -e "${CB_MAGENTA}▶ INFRASTRUCTURE OVERVIEW${C_RESET}"
  echo -e " ${CB_CYAN}Providers      :${C_RESET} $(echo "$infra" | jq -r '(.providers // []) | join(", ")')"
  echo -e " ${CB_CYAN}Terraform Files:${C_RESET} $(echo "$infra" | jq -r '.tf_file_count')"
  echo -e " ${CB_CYAN}Total Resources:${C_RESET} $(echo "$infra" | jq -r '.resource_count')"
  local modules
  modules=$(echo "$infra" | jq -r '(.modules // []) | map(.name) | join(", ")')
  [ -n "$modules" ] && echo -e " ${CB_CYAN}Modules Used   :${C_RESET} $modules"

  echo ""
  local category label items
  for category in compute networking storage database messaging iam data other; do
    items=$(echo "$infra" | jq -r --arg c "$category" '(.resources[$c] // []) | map("\(.type).\(.name)") | join(", ")')
    [ -z "$items" ] && continue
    if [ "$category" = "iam" ]; then
      label="IAM"
    else
      label="$(tr '[:lower:]' '[:upper:]' <<< "${category:0:1}")${category:1}"
    fi
    echo -e " ${CB_CYAN}${label}:${C_RESET} $items"
  done

  local gcp_scan
  gcp_scan=$(echo "$infra" | jq -r '.gcp_scan // empty')
  if [ -n "$gcp_scan" ] && [ "$gcp_scan" != "null" ]; then
    echo ""
    __mt_radar_gcp_scan_show "$gcp_scan"
  fi
}
