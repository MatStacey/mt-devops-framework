# shellcheck shell=bash
# ------------------------------------------
# GCP: Read-Only Observability Wrappers
# ------------------------------------------
# ~/.bash.d/10-infra/34-gcp-observability.sh

GCL_AUDIT_DEFAULT_SINCE="1d"
GCL_AUDIT_DEFAULT_LIMIT=500
GCL_AUDIT_JQ="$HOME/.bash.d/lib/jq/gcl_audit_changes.jq"
GCL_AUDIT_ACTIVITY_LOG="cloudaudit.googleapis.com%2Factivity"
GCL_AUDIT_SYSTEM_LOG="cloudaudit.googleapis.com%2Fsystem_event"
GCL_AUDIT_SERVICE_REGEX='^[A-Za-z0-9.-]+$'
GCL_AUDIT_PRINCIPAL_REGEX='^[A-Za-z0-9._@+-]+$'
GCL_AUDIT_PROJECT_REGEX='^[a-z0-9][a-z0-9:.-]*$'

#######################################
# GCP: List audit-log changes (who changed what) in projects over a time window.
# Reads the Admin Activity audit log (metadata only, no request bodies).
# Needs roles/logging.viewer. Results from all projects are merged and
# sorted by time; a project that is denied is reported while the others
# are still shown.
# Usage: gcl-audit-changes [-p <project>]... [--since <dur> | --start <rfc3339> [--end <rfc3339>]] [--service <api>] [--principal <email>] [--system] [--limit <n>]
# Options:
#   -p, --project <id>       Project to read; repeatable (default: the active gcloud project)
#   --since <dur>            Relative window, e.g. 90s, 30m, 6h, 2d (default: 1d)
#   --start <rfc3339>        Window start, e.g. 2026-10-05T00:00:00Z (overrides --since)
#   --end <rfc3339>          Window end (default: now)
#   --service <api>          Only this API, e.g. run.googleapis.com
#   --principal <email>      Only changes made by this principal
#   --system                 Also include system-event audit logs
#   --limit <n>              Maximum entries per project (default: 500)
#   -h, --help               Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 if any project was permission denied
# Outputs:
#   "timestamp<TAB>project<TAB>principal<TAB>service<TAB>method<TAB>resource<TAB>status" lines, oldest first
# Example:
#   gcl-audit-changes -p proj-a -p proj-b --start 2026-10-05T00:00:00Z --end 2026-10-05T12:00:00Z --service run.googleapis.com
#######################################
gcl-audit-changes() {
  local -a projects=()
  local since="$GCL_AUDIT_DEFAULT_SINCE" start="" end="" service="" principal="" system="" limit="$GCL_AUDIT_DEFAULT_LIMIT"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -p | --project)
        projects+=("${2:-}")
        shift
        ;;
      --since)
        since="${2:-}"
        shift
        ;;
      --start)
        start="${2:-}"
        shift
        ;;
      --end)
        end="${2:-}"
        shift
        ;;
      --service)
        service="${2:-}"
        shift
        ;;
      --principal)
        principal="${2:-}"
        shift
        ;;
      --system) system="1" ;;
      --limit)
        limit="${2:-}"
        shift
        ;;
      *)
        echo -e "${CB_RED}❌ Unknown option or argument: $1${C_RESET}" >&2
        return 1
        ;;
    esac
    shift
  done

  local project
  for project in "${projects[@]}"; do
    [[ "$project" =~ $GCL_AUDIT_PROJECT_REGEX ]] || {
      echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
      return 1
    }
  done
  [[ "$limit" =~ ^[1-9][0-9]*$ ]] || {
    echo -e "${CB_RED}❌ --limit must be a positive number.${C_RESET}" >&2
    return 1
  }
  if [ -n "$service" ] && [[ ! "$service" =~ $GCL_AUDIT_SERVICE_REGEX ]]; then
    echo -e "${CB_RED}❌ Invalid --service: ${service}${C_RESET}" >&2
    return 1
  fi
  if [ -n "$principal" ] && [[ ! "$principal" =~ $GCL_AUDIT_PRINCIPAL_REGEX ]]; then
    echo -e "${CB_RED}❌ Invalid --principal: ${principal}${C_RESET}" >&2
    return 1
  fi
  local time_filter
  time_filter=$(__mt_gcl_time_filter "$since" "$start" "$end") || {
    echo -e "${CB_RED}❌ Invalid --since (use e.g. 6h, 2d) or --start/--end (RFC3339 UTC).${C_RESET}" >&2
    return 1
  }

  __mt_gcl_preflight || return $?
  [ "${#projects[@]}" -eq 0 ] && projects=("$(gcl-get-project)")

  local result="" rc=0 project_rc rows row_count log_filter
  for project in "${projects[@]}"; do
    log_filter="logName=\"projects/${project}/logs/${GCL_AUDIT_ACTIVITY_LOG}\""
    [ -n "$system" ] && log_filter="(${log_filter} OR logName=\"projects/${project}/logs/${GCL_AUDIT_SYSTEM_LOG}\")"
    log_filter="${log_filter} AND ${time_filter}"
    [ -n "$service" ] && log_filter="${log_filter} AND protoPayload.serviceName=\"${service}\""
    [ -n "$principal" ] && log_filter="${log_filter} AND protoPayload.authenticationInfo.principalEmail=\"${principal}\""

    project_rc=0
    rows=$(
      __mt_gcl_run "reading audit logs of ${project}" gcloud logging read "$log_filter" \
        --project="$project" --order=asc --limit="$limit" --format=json --quiet |
        jq -r --arg project "$project" -f "$GCL_AUDIT_JQ"
      exit "${PIPESTATUS[0]}"
    ) || project_rc=$?
    if [ "$project_rc" -ne 0 ]; then
      [ "$rc" -eq 0 ] && rc="$project_rc"
      continue
    fi
    [ -z "$rows" ] && continue
    row_count=$(wc -l <<< "$rows")
    if [ "$row_count" -ge "$limit" ]; then
      echo -e "${CB_YELLOW}⚠️  ${project}: reached the ${limit}-entry limit; later changes may be missing (narrow the window or raise --limit).${C_RESET}" >&2
    fi
    result="${result}${rows}"$'\n'
  done

  [ -n "$result" ] && printf '%s' "$result" | sort -t$'\t' -k1,1 -s | __mt_strip_control_chars
  return "$rc"
}
