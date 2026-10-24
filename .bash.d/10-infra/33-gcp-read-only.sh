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
  local since="$1" start="$2" end="$3" now seconds
  now=$(date +%s)
  if [ -z "$start" ]; then
    seconds=$(__mt_gcl_duration_seconds "$since") || return 1
    start=$(__mt_gcl_rfc3339 $((now - seconds)))
  fi
  [ -z "$end" ] && end=$(__mt_gcl_rfc3339 "$now")
  [[ "$start" =~ $GCL_RFC3339_REGEX && "$end" =~ $GCL_RFC3339_REGEX ]] || return 1
  printf 'timestamp>="%s" AND timestamp<="%s"\n' "$start" "$end"
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
# GCP: Run a read-only BigQuery query. Only a single SELECT/WITH statement
# is accepted (the statement must start with the keyword and contain no
# semicolon), and permission failures name the missing permission. For a
# hard guarantee, run under an account limited to bigquery.dataViewer + jobUser.
# Usage: gcl-bq-query [-p <project>] [--json] "<sql>"
# Arguments:
#   <sql>                A single SELECT or WITH statement (standard SQL); the only
#                        semicolon allowed is one trailing semicolon
# Options:
#   -p, --project <id>   Project to run (and bill) the job in (default: the active gcloud project)
#   --json               Print the result as JSON instead of a table
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on failure or a rejected statement, 5 on permission denied
# Outputs:
#   Query result on stdout
#######################################
gcl-bq-query() {
  local project="" format="pretty" sql=""
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
      *) sql="$1" ;;
    esac
    shift
  done
  if [ -z "$sql" ]; then
    echo "Usage: gcl-bq-query [-p <project>] [--json] \"<sql>\"" >&2
    return 1
  fi

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

  local result err_file rc=0
  err_file=$(mktemp)
  result=$(bq query --project_id="$project" --use_legacy_sql=false --format="$format" "$statement" 2> "$err_file") || rc=$?
  if [ "$rc" -ne 0 ]; then
    __mt_gcl_report_failure "BigQuery job in ${project}" "$(cat "$err_file")"
    rc=$?
    rm -f "$err_file"
    return "$rc"
  fi
  rm -f "$err_file"
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
