# shellcheck shell=bash
# ------------------------------------------
# GCP: Read-Only Inspection Wrappers
# ------------------------------------------
# ~/.bash.d/10-infra/33-gcp-read-only.sh

GCL_EXIT_DENIED=5
GCL_GCS_DEFAULT_MAX_PREFIXES=50
GCL_LOG_DEFAULT_LIMIT=1000
GCL_LOG_DEFAULT_FRESHNESS="1d"
GCL_LOG_TEMPLATE_MAX_LENGTH=160
GCL_LOG_TEMPLATE_SED="$HOME/.bash.d/lib/sed/log_template.sed"
GCL_BQ_DEFAULT_MAX_BYTES_BILLED=10737418240
GCL_REST_MAX_PAGES=20
GCL_RFC3339_FORMAT="%Y-%m-%dT%H:%M:%SZ"
GCL_RFC3339_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$'

#######################################
# GCP: Verify the gcloud token is usable before a read-only call
# Returns:
#   0 if usable, otherwise gcl-auth-check's exit code (remedy already printed)
#######################################
__mt_gcl_preflight() {
  local rc=0
  gcl-auth-check --quiet || rc=$?
  [ "$rc" -eq 0 ] && return 0
  gcl-auth-check >&2
  return "$rc"
}

#######################################
# GCP: Report a failed gcloud/bq call, naming missing permissions when the
# error is a permission denial
# Arguments:
#   $1 - What was being attempted, $2 - captured stderr
# Returns:
#   GCL_EXIT_DENIED for a permission denial, 1 otherwise
#######################################
__mt_gcl_report_failure() {
  local context="$1" err permissions
  err=$(__mt_strip_control_chars <<< "$2")
  if grep -qiE 'permission|access denied|forbidden|\b403\b' <<< "$err"; then
    permissions=$(grep -oE '[a-z]+(\.[a-zA-Z]+)+\.(create|get|list|use|update|delete|getIamPolicy)[A-Za-z]*' <<< "$err" | sort -u | paste -sd, -)
    printf '%b🚫 Permission denied for %s%s as %s.%b\n' "$CB_RED" "$context" "${permissions:+ (missing: ${permissions})}" "$(gcl-get-user 2> /dev/null)" "$C_RESET" >&2
    return "$GCL_EXIT_DENIED"
  fi
  printf '%b🚨 %s failed:%b %s\n' "$CB_RED" "$context" "$C_RESET" "$err" >&2
  return 1
}

#######################################
# GCP: Run a command, passing its stdout through and reporting a failure
# via __mt_gcl_report_failure
# Arguments:
#   $1 - What is being attempted, $2... - the command and its arguments
# Returns:
#   0 on success, otherwise __mt_gcl_report_failure's result
#######################################
__mt_gcl_run() {
  local context="$1" err_file rc=0
  shift
  err_file=$(mktemp)
  "$@" 2> "$err_file" || rc=$?
  if [ "$rc" -ne 0 ]; then
    __mt_gcl_report_failure "$context" "$(cat "$err_file")"
    rc=$?
  fi
  rm -f "$err_file"
  return "$rc"
}

#######################################
# GCP: Convert a duration such as 90s, 30m, 6h or 2d to seconds
# Arguments:
#   $1 - Duration
# Returns:
#   0 on success, 1 if the duration is not <number><s|m|h|d>
# Outputs:
#   Seconds
#######################################
__mt_gcl_duration_seconds() {
  local duration="$1" amount unit
  [[ "$duration" =~ ^([0-9]+)([smhd])$ ]] || return 1
  amount="${BASH_REMATCH[1]}"
  unit="${BASH_REMATCH[2]}"
  case "$unit" in
    s) echo "$amount" ;;
    m) echo $((amount * 60)) ;;
    h) echo $((amount * 3600)) ;;
    d) echo $((amount * 86400)) ;;
  esac
}

#######################################
# GCP: Format epoch seconds as a UTC RFC3339 timestamp
# Arguments:
#   $1 - Epoch seconds
# Outputs:
#   Timestamp such as 2026-10-05T12:00:00Z
#######################################
__mt_gcl_rfc3339() {
  date -u -d "@$1" +"$GCL_RFC3339_FORMAT" 2> /dev/null || date -u -r "$1" +"$GCL_RFC3339_FORMAT"
}

#######################################
# GCP: Convert an RFC3339 timestamp to epoch seconds
# Arguments:
#   $1 - Timestamp
# Outputs:
#   Epoch seconds
#######################################
__mt_gcl_epoch() {
  date -u -d "$1" +%s 2> /dev/null || date -u -j -f "$GCL_RFC3339_FORMAT" "$1" +%s
}

#######################################
# GCP: Resolve a relative or absolute time window to start and end timestamps
# Arguments:
#   $1 - Relative window (e.g. 1d), used when $2 is empty
#   $2 - Window start (RFC3339), $3 - window end (RFC3339, default: now)
# Returns:
#   0 on success, 1 on an invalid duration or timestamp
# Outputs:
#   "start end" (RFC3339, space-separated)
#######################################
__mt_gcl_window() {
  local since="$1" start="$2" end="$3" now seconds
  now=$(date +%s)
  if [ -z "$start" ]; then
    seconds=$(__mt_gcl_duration_seconds "$since") || return 1
    start=$(__mt_gcl_rfc3339 $((now - seconds)))
  fi
  [ -z "$end" ] && end=$(__mt_gcl_rfc3339 "$now")
  [[ "$start" =~ $GCL_RFC3339_REGEX && "$end" =~ $GCL_RFC3339_REGEX ]] || return 1
  echo "${start} ${end}"
}

#######################################
# GCP: Build a Cloud Logging timestamp filter from a relative or absolute window
# Arguments:
#   $1 - Relative window (e.g. 1d), used when $2 is empty
#   $2 - Window start (RFC3339), $3 - window end (RFC3339, default: now)
# Returns:
#   0 on success, 1 on an invalid duration or timestamp
# Outputs:
#   timestamp>="..." AND timestamp<="..."
#######################################
__mt_gcl_time_filter() {
  local start end
  read -r start end < <(__mt_gcl_window "$1" "$2" "$3") || return 1
  [ -z "$end" ] && return 1
  printf 'timestamp>="%s" AND timestamp<="%s"\n' "$start" "$end"
}

#######################################
# GCP: Call a Google REST API with the active gcloud account's access token.
# The token is handed to mt-http as a bearer credential (never printed) and a
# request body travels through a private temp file. A 4xx/5xx response is
# reported via __mt_gcl_report_failure. Run __mt_gcl_preflight first.
# Arguments:
#   $1 - What is being attempted, $2 - HTTP method, $3 - URL
#   $4 - JSON body (empty for none), $5... - extra mt-http arguments (e.g. -q k=v)
# Returns:
#   0 on success, otherwise __mt_gcl_report_failure's result
# Outputs:
#   Response body
#######################################
__mt_gcl_rest() {
  local context="$1" method="$2" url="$3" body="$4" token err_file body_dir="" rc=0
  shift 4
  token=$(gcloud auth print-access-token 2> /dev/null) || {
    echo -e "${CB_RED}🚨 Could not get a gcloud access token; run gcl-auth-check.${C_RESET}" >&2
    return 1
  }
  local -a args=(-X "$method" -b "$token" --raw)
  if [ -n "$body" ]; then
    body_dir=$(mktemp -d)
    printf '%s' "$body" > "${body_dir}/body.json"
    args+=(-H "Content-Type: application/json" -d "@${body_dir}/body.json")
  fi
  err_file=$(mktemp)
  mt-http "${args[@]}" "$@" "$url" 2> "$err_file" || rc=$?
  if [ "$rc" -ne 0 ]; then
    __mt_gcl_report_failure "$context" "$(cat "$err_file")"
    rc=$?
  fi
  rm -f "$err_file"
  [ -n "$body_dir" ] && rm -rf "$body_dir"
  return "$rc"
}

#######################################
# GCP: GET a paginated Google REST list, following nextPageToken
# Arguments:
#   $1 - What is being attempted, $2 - name of the array field holding the items
#   $3 - URL, $4... - extra mt-http arguments (e.g. -q k=v)
# Returns:
#   0 on success, otherwise the failing call's result
# Outputs:
#   One compact JSON item per line
#######################################
__mt_gcl_rest_collect() {
  local context="$1" items_key="$2" url="$3" response page_token="" pages=0
  shift 3
  local -a page_args
  while true; do
    page_args=()
    [ -n "$page_token" ] && page_args=(-q "pageToken=${page_token}")
    response=$(__mt_gcl_rest "$context" GET "$url" "" "$@" "${page_args[@]}") || return $?
    jq -c --arg key "$items_key" '.[$key][]?' <<< "$response"
    page_token=$(jq -r '.nextPageToken // empty' <<< "$response")
    pages=$((pages + 1))
    [ -z "$page_token" ] && return 0
    if [ "$pages" -ge "$GCL_REST_MAX_PAGES" ]; then
      echo -e "${CB_YELLOW}⚠️  ${context}: stopped after ${GCL_REST_MAX_PAGES} pages; results are incomplete.${C_RESET}" >&2
      return 0
    fi
  done
}

#######################################
# GCP: Summarise a GCS location -- one line per immediate prefix with its
# object count and total size. Read-only.
# Usage: gcl-gcs-summary <gs://bucket[/prefix]> [-m <max-prefixes>]
# Arguments:
#   <gs://bucket[/prefix]>   Location to summarise
# Options:
#   -m, --max <n>            Maximum prefixes to inspect (default: 50)
#   -h, --help               Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 on permission denied
# Outputs:
#   "prefix<TAB>objects<TAB>size" per prefix, plus a line for top-level objects
#######################################
gcl-gcs-summary() {
  local location="" max_prefixes="$GCL_GCS_DEFAULT_MAX_PREFIXES"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -m | --max)
        max_prefixes="${2:-}"
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) location="$1" ;;
    esac
    shift
  done
  if [[ "$location" != gs://* ]] || [[ ! "$max_prefixes" =~ ^[0-9]+$ ]]; then
    echo "Usage: gcl-gcs-summary <gs://bucket[/prefix]> [-m <max-prefixes>]" >&2
    return 1
  fi
  __mt_gcl_preflight || return $?

  location="${location%/}/"
  local listing err_file
  err_file=$(mktemp)
  if ! listing=$(gcloud storage ls "$location" 2> "$err_file"); then
    __mt_gcl_report_failure "listing ${location}" "$(cat "$err_file")"
    local rc=$?
    rm -f "$err_file"
    return "$rc"
  fi
  rm -f "$err_file"

  local entry objects size shown=0 top_level=0 report=""
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    if [[ "$entry" != */ ]]; then
      top_level=$((top_level + 1))
      continue
    fi
    if [ "$shown" -ge "$max_prefixes" ]; then
      echo -e "${CB_YELLOW}… more prefixes not shown (raise --max).${C_RESET}" >&2
      break
    fi
    objects=$(gcloud storage ls "${entry}**" 2> /dev/null | grep -vc '/$')
    size=$(gcloud storage du --summarize "$entry" 2> /dev/null | awk '{print $1}')
    report+=$(printf '%s\t%s\t%s' "${entry#"$location"}" "$objects" "$(numfmt --to=iec "${size:-0}" 2> /dev/null || echo "${size:-0}")")$'\n'
    shown=$((shown + 1))
  done <<< "$listing"
  [ "$top_level" -gt 0 ] && report+=$(printf '%s\t%s\t%s' "(top-level objects)" "$top_level" "-")$'\n'
  printf '%s' "$report" | __mt_strip_control_chars
  return 0
}

#######################################
# GCP: Count Cloud Run log lines by message template. Numbers, IDs, UUIDs,
# emails, URLs, long tokens and quoted strings are masked, but the remaining
# text of each distinct template (first 160 characters) is printed, so treat
# the output as log content, not as payload-free.
# Usage: gcl-run-log-summary <service> [-p <project>] [--limit <n>] [--freshness <dur>] [--severity <level>]
# Arguments:
#   <service>              Cloud Run service name
# Options:
#   -p, --project <id>     Project (default: the active gcloud project)
#   --limit <n>            Maximum log entries to read (default: 1000)
#   --freshness <dur>      How far back to read, e.g. 1h, 1d (default: 1d)
#   --severity <level>     Minimum severity, e.g. WARNING, ERROR (default: all)
#   -h, --help             Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 on permission denied
# Outputs:
#   "count<TAB>template" lines, most frequent first
#######################################
gcl-run-log-summary() {
  local service="" project="" limit="$GCL_LOG_DEFAULT_LIMIT" freshness="$GCL_LOG_DEFAULT_FRESHNESS" severity=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -p | --project)
        project="${2:-}"
        shift
        ;;
      --limit)
        limit="${2:-}"
        shift
        ;;
      --freshness)
        freshness="${2:-}"
        shift
        ;;
      --severity)
        severity="${2:-}"
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) service="$1" ;;
    esac
    shift
  done
  if [ -z "$service" ] || [[ ! "$limit" =~ ^[0-9]+$ ]] || [[ ! "$service" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Usage: gcl-run-log-summary <service> [-p <project>] [--limit <n>] [--freshness <dur>] [--severity <level>]" >&2
    return 1
  fi
  if [ -n "$severity" ] && [[ ! "$severity" =~ ^[A-Z]+$ ]]; then
    echo -e "${CB_RED}❌ --severity must be an upper-case level such as ERROR.${C_RESET}" >&2
    return 1
  fi
  __mt_gcl_preflight || return $?
  [ -z "$project" ] && project=$(gcl-get-project)

  local log_filter="resource.type=cloud_run_revision AND resource.labels.service_name=\"${service}\""
  [ -n "$severity" ] && log_filter="${log_filter} AND severity>=${severity}"

  local lines err_file rc=0
  err_file=$(mktemp)
  lines=$(gcloud logging read "$log_filter" --project="$project" --limit="$limit" --freshness="$freshness" \
    --format='value(textPayload,jsonPayload.message)' --quiet 2> "$err_file") || rc=$?
  if [ "$rc" -ne 0 ]; then
    __mt_gcl_report_failure "reading logs for ${service}" "$(cat "$err_file")"
    rc=$?
    rm -f "$err_file"
    return "$rc"
  fi
  rm -f "$err_file"

  tr '\t' ' ' <<< "$lines" |
    sed -E -f "$GCL_LOG_TEMPLATE_SED" |
    cut -c1-"$GCL_LOG_TEMPLATE_MAX_LENGTH" |
    grep -v '^[[:space:]]*$' |
    sort | uniq -c | sort -rn |
    awk '{count = $1; $1 = ""; sub(/^ /, ""); printf "%s\t%s\n", count, $0}' |
    __mt_strip_control_chars
}

#######################################
# GCP: Convert a byte size such as 5000, 500M or 20G (IEC suffixes) to bytes
# Arguments:
#   $1 - Size
# Returns:
#   0 on success, 1 if the size is not a number with an optional K/M/G/T suffix
# Outputs:
#   Bytes
#######################################
__mt_gcl_parse_bytes() {
  local size="$1"
  if [[ "$size" =~ ^[0-9]+$ ]]; then
    echo "$size"
    return 0
  fi
  [[ "$size" =~ ^[0-9]+[KMGT]$ ]] || return 1
  numfmt --from=iec "$size" 2> /dev/null
}

#######################################
# GCP: Run a read-only BigQuery query. Only a single SELECT/WITH statement
# is accepted (the statement must start with the keyword and contain no
# semicolon), and permission failures name the missing permission. For a
# hard guarantee, run under an account limited to bigquery.dataViewer + jobUser.
# Every run is preceded by a dry run; a query estimated to scan more than the
# cap (gcp.bq_max_bytes_billed in config.yaml, default 10 GiB) is refused, and
# the real run carries the cap as --maximum_bytes_billed.
# Usage: gcl-bq-query [-p <project>] [--json] [--max-bytes <size>] [--dry-run] "<sql>"
# Arguments:
#   <sql>                A single SELECT or WITH statement (standard SQL); the only
#                        semicolon allowed is one trailing semicolon
# Options:
#   -p, --project <id>   Project to run (and bill) the job in (default: the active gcloud project)
#   --json               Print the result as JSON instead of a table
#   --max-bytes <size>   Scan cap for this call, bytes or with a K/M/G/T suffix (default: gcp.bq_max_bytes_billed)
#   --dry-run            Print the estimated scan and exit without running the query
#   -h, --help           Show this help menu
# Globals:
#   GCP_BQ_MAX_BYTES_BILLED
# Returns:
#   0 on success, 1 on failure, a rejected statement or an over-cap estimate, 5 on permission denied
# Outputs:
#   Query result on stdout; the scan estimate and cap on stderr
#######################################
gcl-bq-query() {
  local project="" format="pretty" sql="" max_bytes_arg="" dry_run=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -p | --project)
        project="${2:-}"
        shift
        ;;
      --json) format="json" ;;
      --max-bytes)
        max_bytes_arg="${2:-}"
        shift
        ;;
      --dry-run) dry_run="1" ;;
      *) sql="$1" ;;
    esac
    shift
  done
  if [ -z "$sql" ]; then
    echo "Usage: gcl-bq-query [-p <project>] [--json] [--max-bytes <size>] [--dry-run] \"<sql>\"" >&2
    return 1
  fi
  local cap
  cap=$(__mt_gcl_parse_bytes "${max_bytes_arg:-${GCP_BQ_MAX_BYTES_BILLED:-$GCL_BQ_DEFAULT_MAX_BYTES_BILLED}}") || {
    echo -e "${CB_RED}❌ Invalid scan cap '${max_bytes_arg:-${GCP_BQ_MAX_BYTES_BILLED}}': use bytes or a K/M/G/T suffix (e.g. 500M).${C_RESET}" >&2
    return 1
  }

  local statement
  statement="${sql%"${sql##*[![:space:]]}"}"
  statement="${statement%;}"
  statement="${statement%"${statement##*[![:space:]]}"}"
  if [[ ! "$statement" =~ ^[[:space:]]*([Ss][Ee][Ll][Ee][Cc][Tt]|[Ww][Ii][Tt][Hh])([[:space:]]|\() ]]; then
    echo -e "${CB_RED}🚫 Only SELECT or WITH statements are allowed.${C_RESET}" >&2
    return 1
  fi
  if [[ "$statement" == *\;* ]]; then
    echo -e "${CB_RED}🚫 Rejected: multiple statements (semicolon) are not allowed.${C_RESET}" >&2
    return 1
  fi
  __mt_gcl_preflight || return $?
  [ -z "$project" ] && project=$(gcl-get-project)

  local estimate_json estimate rc=0
  estimate_json=$(__mt_gcl_run "BigQuery dry run in ${project}" bq query --dry_run --format=json \
    --use_legacy_sql=false --project_id="$project" "$statement") || return $?
  estimate=$(jq -r '.statistics.totalBytesProcessed // .statistics.query.totalBytesProcessed // empty' <<< "$estimate_json" 2> /dev/null)
  if [[ ! "$estimate" =~ ^[0-9]+$ ]]; then
    echo -e "${CB_RED}🚨 Could not read the scan estimate from the BigQuery dry run; not running the query.${C_RESET}" >&2
    return 1
  fi
  echo -e "${CB_YELLOW}💰 Estimated scan: $(numfmt --to=iec "$estimate") (cap $(numfmt --to=iec "$cap"))${C_RESET}" >&2
  [ -n "$dry_run" ] && return 0
  if [ "$estimate" -gt "$cap" ]; then
    echo -e "${CB_RED}🚫 Estimated scan exceeds the cap; raise it with --max-bytes (or gcp.bq_max_bytes_billed) to run this query.${C_RESET}" >&2
    return 1
  fi

  local result
  result=$(__mt_gcl_run "BigQuery job in ${project}" bq query --project_id="$project" --use_legacy_sql=false \
    --format="$format" --maximum_bytes_billed="$cap" "$statement") || return $?
  __mt_strip_control_chars <<< "$result"
}

#######################################
# GCP: Describe a Workload Identity Pool and list its providers. Read-only.
# Usage: gcl-wif-describe <pool> [-l <location>] [-p <project>]
# Arguments:
#   <pool>               Workload Identity Pool ID
# Options:
#   -l, --location <l>   Pool location (default: global)
#   -p, --project <id>   Project (default: the active gcloud project)
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 on permission denied
# Outputs:
#   Pool description followed by its providers
#######################################
gcl-wif-describe() {
  local pool="" location="global" project=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -l | --location)
        location="${2:-}"
        shift
        ;;
      -p | --project)
        project="${2:-}"
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) pool="$1" ;;
    esac
    shift
  done
  if [ -z "$pool" ]; then
    echo "Usage: gcl-wif-describe <pool> [-l <location>] [-p <project>]" >&2
    return 1
  fi
  __mt_gcl_preflight || return $?
  [ -z "$project" ] && project=$(gcl-get-project)

  local err_file output rc=0
  err_file=$(mktemp)
  output=$(gcloud iam workload-identity-pools describe "$pool" --location="$location" --project="$project" --quiet 2> "$err_file") || rc=$?
  if [ "$rc" -eq 0 ]; then
    output+=$'\n\nProviders\n'
    output+=$(gcloud iam workload-identity-pools providers list --workload-identity-pool="$pool" --location="$location" --project="$project" --quiet 2> "$err_file") || rc=$?
  fi
  [ "$rc" -eq 0 ] && __mt_strip_control_chars <<< "$output"
  if [ "$rc" -ne 0 ]; then
    __mt_gcl_report_failure "describing pool ${pool}" "$(cat "$err_file")"
    rc=$?
  fi
  rm -f "$err_file"
  return "$rc"
}
