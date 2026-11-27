# shellcheck shell=bash
# ------------------------------------------
# GCP: Service Account Trust Audit (read-only)
# ------------------------------------------
# ~/.bash.d/10-infra/37-gcp-sa-audit.sh

GCL_SA_AUDIT_USAGE="Usage: gcl-sa-audit [-p <project>]... [--expected-pool <pool-id>] [--json]"
GCL_SA_AUDIT_JQ_DIR="$HOME/.bash.d/lib/jq"
GCL_SA_AUDIT_TSV_JQ='.[] | [.check, .project, .resource, .principal, .detail, .finding] | @tsv'
GCL_WIF_USER_ROLE="roles/iam.workloadIdentityUser"
GCL_SECRET_ROLE_PREFIX="roles/secretmanager."
GCL_WIF_PLACEHOLDER_REGEX='[<>{}$]|TODO|REPLACE|CHANGEME|example'
GCL_WIF_POOL_ID_REGEX='^[a-z0-9-]{4,32}$'
GCL_WIF_POOL_NOT_FOUND_REGEX='NOT_FOUND|not found|does not exist'
GCL_WIF_DEFAULT_BROAD_CLAIMS="assertion.repository_owner assertion.repository_owner_id assertion.workspaceUuid assertion.namespace_path assertion.namespace_id"

#######################################
# GCP: List a project's service account emails, one per line
# Arguments:
#   $1 - Project ID
# Returns:
#   0 on success, otherwise __mt_gcl_run's result (failure already reported)
# Outputs:
#   Service account emails on stdout
#######################################
__mt_gcl_sa_list() {
  local project="$1" accounts rc=0
  accounts=$(__mt_gcl_run "listing service accounts of ${project}" \
    gcloud iam service-accounts list --project="$project" --format="json(email)" --quiet) || rc=$?
  [ "$rc" -ne 0 ] && return "$rc"
  jq -r '.[].email' <<< "${accounts:-[]}"
}

#######################################
# GCP: Collect one project's IAM policy and each service account's
# workloadIdentityUser members, appending one JSON line per record to
# policies.ndjson and bindings.ndjson in the work directory
# Arguments:
#   $1 - Project ID, $2 - work directory
# Returns:
#   0 on success, otherwise the first failure's code (each failure reported)
# Outputs:
#   The number of service accounts read, on stdout
#######################################
__mt_gcl_sa_audit_collect() {
  local project="$1" work="$2" rc=0 step_rc accounts policy account count=0
  accounts=$(__mt_gcl_sa_list "$project") || return $?
  policy=$(__mt_gcl_run "reading the IAM policy of ${project}" \
    gcloud projects get-iam-policy "$project" --format=json --quiet) || rc=$?
  [ "$rc" -eq 0 ] && jq -c --arg project "$project" '{($project): .}' <<< "$policy" >> "$work/policies.ndjson"

  while IFS= read -r account; do
    [ -z "$account" ] && continue
    step_rc=0
    policy=$(__mt_gcl_run "reading the IAM policy of ${account}" \
      gcloud iam service-accounts get-iam-policy "$account" --project="$project" --format=json --quiet) || step_rc=$?
    if [ "$step_rc" -ne 0 ]; then
      [ "$rc" -eq 0 ] && rc="$step_rc"
      continue
    fi
    jq -c --arg project "$project" --arg sa "$account" --arg role "$GCL_WIF_USER_ROLE" \
      '{project: $project, sa: $sa, members: [.bindings[]? | select(.role == $role) | .members[]]}' \
      <<< "$policy" >> "$work/bindings.ndjson"
    count=$((count + 1))
  done <<< "$accounts"
  echo "$count"
  return "$rc"
}

#######################################
# GCP: Describe one Workload Identity Pool and list its providers, appending
# a JSON line to pools.ndjson. A pool that does not exist is recorded with
# state NOT_FOUND; one that cannot be read is reported and left out.
# Arguments:
#   $1 - Project number, $2 - location, $3 - pool ID, $4 - work directory
# Returns:
#   0 on success or NOT_FOUND, otherwise __mt_gcl_report_failure's result
#######################################
__mt_gcl_sa_audit_pool() {
  local number="$1" location="$2" pool="$3" work="$4" err_file description providers rc=0
  err_file=$(mktemp)
  description=$(gcloud iam workload-identity-pools describe "$pool" --location="$location" \
    --project="$number" --format=json --quiet 2> "$err_file") || rc=$?
  if [ "$rc" -eq 0 ]; then
    providers=$(gcloud iam workload-identity-pools providers list --workload-identity-pool="$pool" \
      --location="$location" --project="$number" --format=json --quiet 2> "$err_file") || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    jq -c --arg number "$number" --arg location "$location" --arg pool "$pool" --argjson providers "${providers:-[]}" \
      '{number: $number, location: $location, pool: $pool, state: (.state // "ACTIVE"), providers: $providers}' \
      <<< "$description" >> "$work/pools.ndjson"
  elif grep -qE "$GCL_WIF_POOL_NOT_FOUND_REGEX" "$err_file"; then
    jq -nc --arg number "$number" --arg location "$location" --arg pool "$pool" \
      '{number: $number, location: $location, pool: $pool, state: "NOT_FOUND", providers: []}' >> "$work/pools.ndjson"
    rc=0
  else
    __mt_gcl_report_failure "describing pool ${pool} in project ${number}" "$(cat "$err_file")"
    rc=$?
  fi
  rm -f "$err_file"
  return "$rc"
}

#######################################
# GCP: The steps of gcl-sa-audit after argument parsing; the caller owns
# and removes the work directory
# Arguments:
#   $1 - expected pool ID ("" for any), $2 - non-empty for JSON output,
#   $3 - work directory, $4... - project IDs
# Returns:
#   See gcl-sa-audit
# Outputs:
#   See gcl-sa-audit
#######################################
__mt_gcl_sa_audit_run() {
  local expected_pool="$1" as_json="$2" work="$3"
  shift 3
  local project rc=0 step_rc collected accounts=0
  touch "$work/policies.ndjson" "$work/bindings.ndjson" "$work/pools.ndjson"
  for project in "$@"; do
    step_rc=0
    collected=$(__mt_gcl_sa_audit_collect "$project" "$work") || step_rc=$?
    accounts=$((accounts + ${collected:-0}))
    [ "$step_rc" -ne 0 ] && [ "$rc" -eq 0 ] && rc="$step_rc"
  done

  local number location pool
  while IFS=$'\t' read -r number location pool; do
    [ -z "$pool" ] && continue
    step_rc=0
    __mt_gcl_sa_audit_pool "$number" "$location" "$pool" "$work" || step_rc=$?
    [ "$step_rc" -ne 0 ] && [ "$rc" -eq 0 ] && rc="$step_rc"
  done < <(jq -rs -L "$GCL_SA_AUDIT_JQ_DIR" -f "$GCL_SA_AUDIT_JQ_DIR/gcl_sa_wif_pools.jq" "$work/bindings.ndjson")

  local -a claims
  read -ra claims <<< "${GCP_WIF_BROAD_CLAIMS:-$GCL_WIF_DEFAULT_BROAD_CLAIMS}"
  local findings
  findings=$(jq -n -L "$GCL_SA_AUDIT_JQ_DIR" \
    --slurpfile bindings "$work/bindings.ndjson" --slurpfile policies "$work/policies.ndjson" \
    --slurpfile pools "$work/pools.ndjson" --arg expected "$expected_pool" \
    --argjson claims "$(jq -cn '$ARGS.positional' --args "${claims[@]}")" \
    --arg placeholder "$GCL_WIF_PLACEHOLDER_REGEX" --arg secret_role_prefix "$GCL_SECRET_ROLE_PREFIX" \
    -f "$GCL_SA_AUDIT_JQ_DIR/gcl_sa_wif_findings.jq") || return 1

  if [ -n "$as_json" ]; then
    jq '.' <<< "$findings" | __mt_strip_control_chars
  else
    jq -r "$GCL_SA_AUDIT_TSV_JQ" <<< "$findings" | __mt_strip_control_chars
  fi
  local total
  total=$(jq 'length' <<< "$findings")
  if [ "$total" -eq 0 ] && [ "$rc" -ne 0 ]; then
    echo -e "${CB_YELLOW}⚠️  No findings in what could be read; some projects or policies were unreadable (see above)${C_RESET}" >&2
  elif [ "$total" -eq 0 ]; then
    echo -e "${CB_GREEN}✅ No findings.${C_RESET}" >&2
  else
    echo -e "${CB_YELLOW}⚠️  ${total} findings across ${accounts} service accounts in $# projects${C_RESET}" >&2
  fi
  return "$rc"
}

#######################################
# GCP: Audit who can act as each service account. The wif check reads every
# service account's roles/iam.workloadIdentityUser members, describes each
# Workload Identity Pool they name once, and reports wildcard pool members,
# attribute members mapped from broad claims (gcp.wif_broad_claims),
# placeholder values, providers without an attribute condition, missing or
# deleted pools, and pools other than --expected-pool. A finding on a
# service account that holds a project-level roles/secretmanager.* role
# gets "+SECRETS" appended. Read-only.
# Usage: gcl-sa-audit [-p <project>]... [--expected-pool <pool-id>] [--json]
# Options:
#   -p, --project <id>         Project to audit; repeatable (default: the active gcloud project)
#   --expected-pool <pool-id>  Report members that use any other pool (POOL_MISMATCH)
#   --json                     Print the findings as a JSON array instead of rows
#   -h, --help                 Show this help menu
# Returns:
#   0 when every project was read (with or without findings), 1 on bad usage
#   or failure, 5 if any project or resource was permission denied (the
#   other projects are still audited)
# Outputs:
#   "check<TAB>project<TAB>resource<TAB>principal<TAB>detail<TAB>finding" rows
#   on stdout, where detail is "pool=<id> attr=<attr><-<claim> condition=<set|none>";
#   finding codes: WILDCARD_POOL, BROAD_ATTRIBUTE, PLACEHOLDER_SUBJECT,
#   NO_CONDITION, POOL_MISSING, POOL_MISMATCH. A summary goes to stderr.
# Globals:
#   GCP_WIF_BROAD_CLAIMS (gcp.wif_broad_claims in config.yaml, space-separated)
#######################################
gcl-sa-audit() {
  local expected_pool="" as_json=""
  local -a projects=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -p | --project | --expected-pool)
        if [ -z "${2:-}" ]; then
          echo "$GCL_SA_AUDIT_USAGE" >&2
          return 1
        fi
        [ "$1" = "--expected-pool" ] && expected_pool="$2" || projects+=("$2")
        shift
        ;;
      --json) as_json="1" ;;
      *)
        echo "$GCL_SA_AUDIT_USAGE" >&2
        return 1
        ;;
    esac
    shift
  done
  local project
  for project in "${projects[@]}"; do
    [[ "$project" =~ $GCL_PROJECT_ID_REGEX ]] || {
      echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
      return 1
    }
  done
  if [ -n "$expected_pool" ] && [[ ! "$expected_pool" =~ $GCL_WIF_POOL_ID_REGEX ]]; then
    echo -e "${CB_RED}❌ Invalid pool ID: ${expected_pool}${C_RESET}" >&2
    return 1
  fi
  __mt_gcl_preflight || return $?
  [ "${#projects[@]}" -eq 0 ] && projects=("$(gcl-get-project)")

  local work rc=0
  work=$(mktemp -d) || return 1
  __mt_gcl_sa_audit_run "$expected_pool" "$as_json" "$work" "${projects[@]}" || rc=$?
  rm -rf "$work"
  return "$rc"
}
