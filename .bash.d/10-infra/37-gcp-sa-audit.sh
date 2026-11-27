# shellcheck shell=bash
# ------------------------------------------
# GCP: Service Account Trust Audit (read-only)
# ------------------------------------------
# ~/.bash.d/10-infra/37-gcp-sa-audit.sh

GCL_SA_AUDIT_USAGE="Usage: gcl-sa-audit [-p <project>]... [--check <wif|invoker|keys>]... [--expected-pool <pool-id>] [--expected-invoker <sa-email>]... [--json]"
GCL_SA_AUDIT_CHECKS=(wif invoker keys)
GCL_SA_AUDIT_JQ_DIR="$HOME/.bash.d/lib/jq"
GCL_SA_AUDIT_TSV_JQ='.[] | [.check, .project, .resource, .principal, .detail, .finding] | @tsv'
GCL_SA_AUDIT_NO_FINDING="-"
GCL_WIF_USER_ROLE="roles/iam.workloadIdentityUser"
GCL_SECRET_ROLE_PREFIX="roles/secretmanager."
GCL_WIF_PLACEHOLDER_REGEX='[<>{}$]|TODO|REPLACE|CHANGEME|example'
GCL_WIF_POOL_ID_REGEX='^[a-z0-9-]{4,32}$'
GCL_WIF_POOL_NOT_FOUND_REGEX='NOT_FOUND|not found|does not exist'
GCL_WIF_DEFAULT_BROAD_CLAIMS="assertion.repository_owner assertion.repository_owner_id assertion.workspaceUuid assertion.namespace_path assertion.namespace_id"
GCL_RUN_INVOKER_ROLE="roles/run.invoker"
GCL_RUN_SERVICES_FORMAT='json(metadata.name,metadata.labels."cloud.googleapis.com/location")'
GCL_SA_MEMBER_PREFIX="serviceAccount:"
GCL_SA_EMAIL_REGEX='^[^@[:space:]]+@[^@[:space:]]+\.gserviceaccount\.com$'
GCL_SA_KEYS_FORMAT="json(name,validAfterTime,validBeforeTime,disabled)"
GCL_SA_KEY_DEFAULT_MAX_AGE_DAYS=90

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
# GCP: wif check, collect step: read one project's IAM policy and each
# service account's workloadIdentityUser members, appending one JSON line
# per record to policies.ndjson and bindings.ndjson in the work directory
# Arguments:
#   $1 - Project ID, $2 - work directory, $3 - service account emails, one per line
# Returns:
#   0 on success, otherwise the first failure's code (each failure reported)
#######################################
__mt_gcl_sa_audit_wif_collect() {
  local project="$1" work="$2" accounts="$3" rc=0 step_rc policy account
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
  done <<< "$accounts"
  return "$rc"
}

#######################################
# GCP: keys check, collect step: list each service account's user-managed
# keys (name and dates only; key material is never requested) into
# keys.ndjson in the work directory
# Arguments:
#   $1 - Project ID, $2 - work directory, $3 - service account emails, one per line
# Returns:
#   0 on success, otherwise the first failure's code (each failure reported)
#######################################
__mt_gcl_sa_audit_keys_collect() {
  local project="$1" work="$2" accounts="$3" rc=0 step_rc keys account
  while IFS= read -r account; do
    [ -z "$account" ] && continue
    step_rc=0
    keys=$(__mt_gcl_run "listing the keys of ${account}" \
      gcloud iam service-accounts keys list --iam-account="$account" --project="$project" \
      --managed-by=user --format="$GCL_SA_KEYS_FORMAT" --quiet) || step_rc=$?
    if [ "$step_rc" -ne 0 ]; then
      [ "$rc" -eq 0 ] && rc="$step_rc"
      continue
    fi
    jq -c --arg project "$project" --arg sa "$account" \
      '{project: $project, sa: $sa, keys: [.[]? | {name, validAfterTime, validBeforeTime, disabled}]}' \
      <<< "${keys:-[]}" >> "$work/keys.ndjson"
  done <<< "$accounts"
  return "$rc"
}

#######################################
# GCP: invoker check, collect step: record one project's number (for
# number-bearing service-account emails) in numbers.txt, then each Cloud Run
# service's roles/run.invoker members in services.ndjson. An unreadable
# project number is recorded as unknown in numbers.unknown.
# Arguments:
#   $1 - Project ID, $2 - work directory
# Returns:
#   0 on success, otherwise the first failure's code (each failure reported)
#######################################
__mt_gcl_sa_audit_invoker_collect() {
  local project="$1" work="$2" rc=0 step_rc number services policy service region
  number=$(__mt_gcl_run "reading the project number of ${project}" \
    gcloud projects describe "$project" --format="value(projectNumber)" --quiet) || rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$number" ]; then
    echo "$number" >> "$work/numbers.txt"
  else
    echo "$project" >> "$work/numbers.unknown"
  fi

  step_rc=0
  services=$(__mt_gcl_run "listing Cloud Run services of ${project}" \
    gcloud run services list --project="$project" --format="$GCL_RUN_SERVICES_FORMAT" --quiet) || step_rc=$?
  if [ "$step_rc" -ne 0 ]; then
    [ "$rc" -eq 0 ] && rc="$step_rc"
    return "$rc"
  fi
  while IFS=$'\t' read -r service region; do
    [ -z "$service" ] && continue
    step_rc=0
    policy=$(__mt_gcl_run "reading the invoker policy of ${region}/${service} in ${project}" \
      gcloud run services get-iam-policy "$service" --region="$region" --project="$project" --format=json --quiet) || step_rc=$?
    if [ "$step_rc" -ne 0 ]; then
      [ "$rc" -eq 0 ] && rc="$step_rc"
      continue
    fi
    jq -c --arg project "$project" --arg region "$region" --arg service "$service" --arg role "$GCL_RUN_INVOKER_ROLE" \
      '{project: $project, region: $region, service: $service, members: [.bindings[]? | select(.role == $role) | .members[]]}' \
      <<< "$policy" >> "$work/services.ndjson"
  done < <(jq -r '.[]? | [.metadata.name, .metadata.labels["cloud.googleapis.com/location"]] | @tsv' <<< "${services:-[]}")
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
# GCP: wif check, findings step: describe each referenced pool once, then
# write the wif findings array to findings_wif.json in the work directory
# Arguments:
#   $1 - work directory, $2 - expected pool ID ("" for any)
# Returns:
#   0 on success, otherwise the first pool failure's code; 1 if jq fails
#######################################
__mt_gcl_sa_audit_wif_findings() {
  local work="$1" expected_pool="$2" rc=0 step_rc number location pool
  while IFS=$'\t' read -r number location pool; do
    [ -z "$pool" ] && continue
    step_rc=0
    __mt_gcl_sa_audit_pool "$number" "$location" "$pool" "$work" || step_rc=$?
    [ "$step_rc" -ne 0 ] && [ "$rc" -eq 0 ] && rc="$step_rc"
  done < <(jq -rs -L "$GCL_SA_AUDIT_JQ_DIR" -f "$GCL_SA_AUDIT_JQ_DIR/gcl_sa_wif_pools.jq" "$work/bindings.ndjson")

  local -a claims
  read -ra claims <<< "${GCP_WIF_BROAD_CLAIMS:-$GCL_WIF_DEFAULT_BROAD_CLAIMS}"
  jq -n -L "$GCL_SA_AUDIT_JQ_DIR" \
    --slurpfile bindings "$work/bindings.ndjson" --slurpfile policies "$work/policies.ndjson" \
    --slurpfile pools "$work/pools.ndjson" --arg expected "$expected_pool" \
    --argjson claims "$(jq -cn '$ARGS.positional' --args "${claims[@]}")" \
    --arg placeholder "$GCL_WIF_PLACEHOLDER_REGEX" --arg secret_role_prefix "$GCL_SECRET_ROLE_PREFIX" \
    -f "$GCL_SA_AUDIT_JQ_DIR/gcl_sa_wif_findings.jq" > "$work/findings_wif.json" || return 1
  return "$rc"
}

#######################################
# GCP: The steps of gcl-sa-audit after argument parsing; the caller owns
# and removes the work directory
# Arguments:
#   $1 - checks to run, space-separated; $2 - expected pool ID ("" for any);
#   $3 - expected invokers as serviceAccount:<email>, space-separated;
#   $4 - key age limit in days; $5 - non-empty for JSON output;
#   $6 - work directory; $7... - project IDs
# Returns:
#   See gcl-sa-audit
# Outputs:
#   See gcl-sa-audit
#######################################
__mt_gcl_sa_audit_run() {
  local checks=" $1 " expected_pool="$2" expected_invokers="$3" max_age_days="$4" as_json="$5" work="$6"
  shift 6
  local project rc=0 step_rc accounts account_count=0 listed_rc check
  touch "$work"/{policies,bindings,pools,keys,services}.ndjson "$work/numbers.txt" "$work"/findings_{wif,invoker,keys}.json
  for project in "$@"; do
    if [[ "$checks" == *" wif "* || "$checks" == *" keys "* ]]; then
      step_rc=0
      accounts=$(__mt_gcl_sa_list "$project") || step_rc=$?
      [ "$step_rc" -ne 0 ] && [ "$rc" -eq 0 ] && rc="$step_rc"
      account_count=$((account_count + $(grep -c . <<< "$accounts")))
      listed_rc="$step_rc"
      for check in wif keys; do
        [[ "$checks" == *" ${check} "* ]] && [ "$listed_rc" -eq 0 ] || continue
        step_rc=0
        "__mt_gcl_sa_audit_${check}_collect" "$project" "$work" "$accounts" || step_rc=$?
        [ "$step_rc" -ne 0 ] && [ "$rc" -eq 0 ] && rc="$step_rc"
      done
    fi
    if [[ "$checks" == *" invoker "* ]]; then
      step_rc=0
      __mt_gcl_sa_audit_invoker_collect "$project" "$work" || step_rc=$?
      [ "$step_rc" -ne 0 ] && [ "$rc" -eq 0 ] && rc="$step_rc"
    fi
  done

  if [[ "$checks" == *" wif "* ]]; then
    step_rc=0
    __mt_gcl_sa_audit_wif_findings "$work" "$expected_pool" || step_rc=$?
    [ "$step_rc" -eq 1 ] && return 1
    [ "$step_rc" -ne 0 ] && [ "$rc" -eq 0 ] && rc="$step_rc"
  fi
  if [[ "$checks" == *" invoker "* ]]; then
    local -a invokers
    read -ra invokers <<< "$expected_invokers"
    jq -n --slurpfile services "$work/services.ndjson" \
      --argjson projects "$(jq -cn '$ARGS.positional' --args "$@")" \
      --argjson numbers "$(jq -Rsc 'split("\n") | map(select(. != ""))' "$work/numbers.txt")" \
      --argjson numbers_complete "$([ -s "$work/numbers.unknown" ] && echo false || echo true)" \
      --argjson expected "$(jq -cn '$ARGS.positional' --args "${invokers[@]}")" \
      -f "$GCL_SA_AUDIT_JQ_DIR/gcl_sa_invoker_findings.jq" > "$work/findings_invoker.json" || return 1
  fi
  if [[ "$checks" == *" keys "* ]]; then
    jq -n --slurpfile keys "$work/keys.ndjson" --argjson max_age_days "$max_age_days" --argjson now "$(date +%s)" \
      -f "$GCL_SA_AUDIT_JQ_DIR/gcl_sa_key_findings.jq" > "$work/findings_keys.json" || return 1
  fi

  local findings
  findings=$(jq -cs 'add // []' "$work"/findings_{wif,invoker,keys}.json) || return 1
  if [ -n "$as_json" ]; then
    jq '.' <<< "$findings" | __mt_strip_control_chars
  else
    jq -r "$GCL_SA_AUDIT_TSV_JQ" <<< "$findings" | __mt_strip_control_chars
  fi
  __mt_gcl_sa_audit_summary "$findings" "$rc" "$checks" "$account_count" "$(grep -c . "$work/services.ndjson")" "$#"
  return "$rc"
}

#######################################
# GCP: Print gcl-sa-audit's summary line to stderr. Rows with finding "-"
# (inventory rows) are not counted. The all-clear is printed only when
# everything was read.
# Arguments:
#   $1 - findings JSON array, $2 - the run's exit code so far, $3 - checks run
#   (space-padded), $4 - service accounts listed, $5 - Cloud Run services
#   read, $6 - projects audited
#######################################
__mt_gcl_sa_audit_summary() {
  local findings="$1" rc="$2" checks="$3" account_count="$4" service_count="$5" project_count="$6"
  local total scope=()
  total=$(jq --arg none "$GCL_SA_AUDIT_NO_FINDING" '[.[] | select(.finding != $none)] | length' <<< "$findings")
  if [ "$total" -eq 0 ] && [ "$rc" -ne 0 ]; then
    echo -e "${CB_YELLOW}⚠️  No findings in what could be read; some projects or policies were unreadable (see above)${C_RESET}" >&2
    return 0
  fi
  if [ "$total" -eq 0 ]; then
    echo -e "${CB_GREEN}✅ No findings.${C_RESET}" >&2
    return 0
  fi
  [[ "$checks" == *" wif "* || "$checks" == *" keys "* ]] && scope+=("${account_count} service accounts")
  [[ "$checks" == *" invoker "* ]] && scope+=("${service_count} Cloud Run services")
  local joined="${scope[0]}"
  [ "${#scope[@]}" -gt 1 ] && joined+=" and ${scope[1]}"
  echo -e "${CB_YELLOW}⚠️  ${total} findings across ${joined} in ${project_count} projects${C_RESET}" >&2
}

#######################################
# GCP: Audit who can act as each service account and Cloud Run service.
# Read-only: key material is never requested (no `keys get`, `keys create`
# or privateKeyData). Checks (all three by default):
#   wif      Every service account's roles/iam.workloadIdentityUser members,
#            with each Workload Identity Pool they name described once.
#            Codes: WILDCARD_POOL, BROAD_ATTRIBUTE (an attribute mapped from
#            a claim in gcp.wif_broad_claims), PLACEHOLDER_SUBJECT,
#            NO_CONDITION, POOL_MISSING (missing or deleted), POOL_MISMATCH
#            (not --expected-pool). "+SECRETS" is appended when the service
#            account holds a project-level roles/secretmanager.* role.
#   invoker  Every roles/run.invoker member of every Cloud Run service (an
#            inventory; "-" when nothing is wrong). Codes: PUBLIC_INVOKER
#            (allUsers/allAuthenticatedUsers), CROSS_PROJECT (a service
#            account from a project not given with -p, by ID or by project
#            number), MISSING_INVOKER (an --expected-invoker that is absent).
#   keys     Every user-managed key of every service account, by ID and
#            dates. Codes: NO_EXPIRY, OLD_KEY (older than
#            gcp.sa_key_max_age_days), DISABLED; "-" when none apply.
# Usage: gcl-sa-audit [-p <project>]... [--check <wif|invoker|keys>]... [--expected-pool <pool-id>] [--expected-invoker <sa-email>]... [--json]
# Options:
#   -p, --project <id>             Project to audit; repeatable (default: the active gcloud project)
#   --check <list>                 Checks to run: wif, invoker, keys; repeatable or comma-separated (default: all)
#   --expected-pool <pool-id>      wif: report members that use any other pool (POOL_MISMATCH)
#   --expected-invoker <sa-email>  invoker: report services this account cannot invoke; repeatable,
#                                  with or without a serviceAccount: prefix
#   --json                         Print the findings as a JSON array instead of rows
#   -h, --help                     Show this help menu
# Returns:
#   0 when everything was read (with or without findings), 1 on bad usage
#   or failure, 5 if any project or resource was permission denied (the
#   rest is still audited, and no findings is then not an all-clear)
# Outputs:
#   "check<TAB>project<TAB>resource<TAB>principal<TAB>detail<TAB>finding" rows
#   on stdout. wif: resource is the service account and detail is
#   "pool=<id> attr=<attr><-<claim> condition=<set|none>". invoker: resource
#   is "<region>/<service>" and detail "roles/run.invoker". keys: resource
#   is the service account, principal "-" and detail
#   "key=<id> created=<date> expires=<date|never>". A summary goes to stderr.
# Globals:
#   GCP_WIF_BROAD_CLAIMS (gcp.wif_broad_claims in config.yaml, space-separated)
#   GCP_SA_KEY_MAX_AGE_DAYS (gcp.sa_key_max_age_days in config.yaml, default 90)
#######################################
gcl-sa-audit() {
  local expected_pool="" as_json="" checks="" expected_invokers="" check invoker
  local -a projects=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -p | --project | --expected-pool | --check | --expected-invoker)
        if [ -z "${2:-}" ]; then
          echo "$GCL_SA_AUDIT_USAGE" >&2
          return 1
        fi
        case "$1" in
          --expected-pool) expected_pool="$2" ;;
          --check) checks+=" ${2//,/ }" ;;
          --expected-invoker)
            invoker="${2#"$GCL_SA_MEMBER_PREFIX"}"
            if [[ ! "$invoker" =~ $GCL_SA_EMAIL_REGEX ]]; then
              echo -e "${CB_RED}❌ Invalid service account email: $2${C_RESET}" >&2
              return 1
            fi
            expected_invokers+=" ${GCL_SA_MEMBER_PREFIX}${invoker}"
            ;;
          *) projects+=("$2") ;;
        esac
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
  [ -z "${checks// /}" ] && checks="${GCL_SA_AUDIT_CHECKS[*]}"
  for check in $checks; do
    if [[ ! " ${GCL_SA_AUDIT_CHECKS[*]} " == *" ${check} "* ]]; then
      echo -e "${CB_RED}❌ Unknown check: ${check} (choose from: ${GCL_SA_AUDIT_CHECKS[*]})${C_RESET}" >&2
      return 1
    fi
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
  local max_age_days="${GCP_SA_KEY_MAX_AGE_DAYS:-$GCL_SA_KEY_DEFAULT_MAX_AGE_DAYS}"
  if [[ ! "$max_age_days" =~ ^[1-9][0-9]*$ ]]; then
    echo -e "${CB_RED}❌ gcp.sa_key_max_age_days must be a positive whole number, not '${max_age_days}'.${C_RESET}" >&2
    return 1
  fi
  __mt_gcl_preflight || return $?
  [ "${#projects[@]}" -eq 0 ] && projects=("$(gcl-get-project)")

  local work rc=0
  work=$(mktemp -d) || return 1
  __mt_gcl_sa_audit_run "$checks" "$expected_pool" "$expected_invokers" "$max_age_days" "$as_json" "$work" "${projects[@]}" || rc=$?
  rm -rf "$work"
  return "$rc"
}
