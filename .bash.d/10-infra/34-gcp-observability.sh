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

GCL_SEARCH_DEFAULT_SINCE="1d"
GCL_SEARCH_DEFAULT_LIMIT=1000
GCL_SEARCH_TERM_MAX_LENGTH=200
GCL_SEARCH_HITS_JQ="$HOME/.bash.d/lib/jq/gcl_log_hits.jq"
GCL_INVENTORY_SECTIONS=(alerts dashboards uptime metrics logmetrics)
GCL_INVENTORY_FILTER_MAX_LENGTH=120
GCL_INVENTORY_CUSTOM_METRICS_FILTER='metric.type = starts_with("custom.googleapis.com/") OR metric.type = starts_with("workload.googleapis.com/") OR metric.type = starts_with("external.googleapis.com/")'
GCL_INVENTORY_JQ="$HOME/.bash.d/lib/jq/gcl_monitoring_inventory.jq"
GCL_METRIC_DEFAULT_SINCE="1h"
GCL_METRIC_DEFAULT_ALIGN="60s"
GCL_METRIC_API="https://monitoring.googleapis.com/v3/projects"
GCL_METRIC_SERIES_JQ="$HOME/.bash.d/lib/jq/gcl_timeseries.jq"
GCL_METRIC_DESCRIPTORS_JQ="$HOME/.bash.d/lib/jq/gcl_metric_descriptors.jq"
GCL_METRIC_TYPE_REGEX='^[A-Za-z0-9_./-]+$'
GCL_METRIC_ALIGNER_REGEX='^ALIGN_[A-Z0-9_]+$'
GCL_METRIC_REDUCER_REGEX='^REDUCE_[A-Z0-9_]+$'
GCL_METRIC_GROUP_REGEX='^[A-Za-z0-9_.:-]+$'

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
    [[ "$project" =~ $GCL_PROJECT_ID_REGEX ]] || {
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

#######################################
# GCP: List Cloud Monitoring metric descriptors matching a filter
# Arguments:
#   $1 - Project, $2 - descriptor filter (e.g. metric.type = starts_with("custom.googleapis.com/"))
# Returns:
#   0 on success, otherwise the failing call's result
# Outputs:
#   "type<TAB>kind<TAB>value type<TAB>unit<TAB>description" rows
#######################################
__mt_gcl_metric_descriptors() {
  local project="$1" descriptor_filter="$2"
  __mt_gcl_rest_collect "listing metric descriptors of ${project}" metricDescriptors \
    "${GCL_METRIC_API}/${project}/metricDescriptors" -q "filter=${descriptor_filter}" |
    jq -r -f "$GCL_METRIC_DESCRIPTORS_JQ" | __mt_strip_control_chars
  return "${PIPESTATUS[0]}"
}

#######################################
# GCP: Read Cloud Monitoring time series for a metric over a time window (gcloud
# has no command for this), or list the metric types under a prefix. Read-only;
# needs roles/monitoring.viewer.
# Usage: gcl-metric-read <metric.type> [-p <project>] [--filter '<extra>'] [--since <dur> | --start <rfc3339> [--end <rfc3339>]] [--align <dur>|window] [--aligner ALIGN_*] [--reducer REDUCE_*] [--group-by <field,...>] [--json]
#        gcl-metric-read --list <metric-type-prefix> [-p <project>]
# Arguments:
#   <metric.type>              Metric type, e.g. logging.googleapis.com/byte_count
# Options:
#   -p, --project <id>         Project (default: the active gcloud project)
#   --filter <expr>            Extra filter ANDed onto the metric type, e.g. 'resource.labels.job_name="x"'
#   --since <dur>              Relative window, e.g. 30m, 6h, 30d (default: 1h)
#   --start <rfc3339>          Window start (overrides --since)
#   --end <rfc3339>            Window end (default: now)
#   --align <dur>|window       Alignment period, or "window" for one value per series over the whole window
#                              (default 60s when --aligner or --reducer is given)
#   --aligner <ALIGN_*>        Per-series aligner, e.g. ALIGN_SUM, ALIGN_MAX, ALIGN_RATE
#   --reducer <REDUCE_*>       Cross-series reducer, e.g. REDUCE_SUM
#   --group-by <f1,f2>         Fields to group the reduced series by, e.g. resource.type
#   --json                     Print the series as JSON instead of tab-separated rows
#   --list <prefix>            List metric types starting with this prefix (to find exact names)
#   -h, --help                 Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 on permission denied
# Outputs:
#   "labels<TAB>end_time<TAB>value" rows, or with --list
#   "type<TAB>kind<TAB>value type<TAB>unit<TAB>description" rows
# Example:
#   gcl-metric-read logging.googleapis.com/byte_count -p proj --since 30d --align window --aligner ALIGN_SUM --reducer REDUCE_SUM --group-by resource.type
#   gcl-metric-read --list dataflow.googleapis.com/job/ -p proj
#   gcl-metric-read pubsub.googleapis.com/subscription/num_undelivered_messages -p proj --filter 'resource.labels.subscription_id="sub"' --since 6h --align 60s --aligner ALIGN_MAX
#######################################
gcl-metric-read() {
  local project="" metric="" list_prefix="" extra_filter="" since="$GCL_METRIC_DEFAULT_SINCE" start="" end="" align="" aligner="" reducer="" group_by="" as_json=""
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
      --filter)
        extra_filter="${2:-}"
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
      --align)
        align="${2:-}"
        shift
        ;;
      --aligner)
        aligner="${2:-}"
        shift
        ;;
      --reducer)
        reducer="${2:-}"
        shift
        ;;
      --group-by)
        group_by="${2:-}"
        shift
        ;;
      --json) as_json="1" ;;
      --list)
        list_prefix="${2:-}"
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) metric="$1" ;;
    esac
    shift
  done

  local usage="Usage: gcl-metric-read <metric.type> [options] | gcl-metric-read --list <prefix> [-p <project>]"
  if [ -z "$metric" ] && [ -z "$list_prefix" ]; then
    echo "$usage" >&2
    return 1
  fi
  [ -n "$project" ] && [[ ! "$project" =~ $GCL_PROJECT_ID_REGEX ]] && {
    echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
    return 1
  }
  local checked_value
  for checked_value in "$metric" "$list_prefix"; do
    [ -n "$checked_value" ] && [[ ! "$checked_value" =~ $GCL_METRIC_TYPE_REGEX ]] && {
      echo -e "${CB_RED}❌ Invalid metric type: ${checked_value}${C_RESET}" >&2
      return 1
    }
  done
  [ -n "$aligner" ] && [[ ! "$aligner" =~ $GCL_METRIC_ALIGNER_REGEX ]] && {
    echo -e "${CB_RED}❌ --aligner must look like ALIGN_SUM.${C_RESET}" >&2
    return 1
  }
  [ -n "$reducer" ] && [[ ! "$reducer" =~ $GCL_METRIC_REDUCER_REGEX ]] && {
    echo -e "${CB_RED}❌ --reducer must look like REDUCE_SUM.${C_RESET}" >&2
    return 1
  }

  __mt_gcl_preflight || return $?
  [ -z "$project" ] && project=$(gcl-get-project)
  local url="${GCL_METRIC_API}/${project}"

  if [ -n "$list_prefix" ]; then
    __mt_gcl_metric_descriptors "$project" "metric.type = starts_with(\"${list_prefix}\")"
    return $?
  fi

  local window window_start window_end
  window=$(__mt_gcl_window "$since" "$start" "$end") || {
    echo -e "${CB_RED}❌ Invalid --since (use e.g. 6h, 30d) or --start/--end (RFC3339 UTC).${C_RESET}" >&2
    return 1
  }
  read -r window_start window_end <<< "$window"

  local -a query=(-q "filter=metric.type=\"${metric}\"${extra_filter:+ AND ${extra_filter}}"
    -q "interval.startTime=${window_start}" -q "interval.endTime=${window_end}")
  if [ -n "$aligner" ] || [ -n "$reducer" ] || [ -n "$align" ]; then
    local period_seconds
    if [ "$align" = "window" ]; then
      period_seconds=$(($(__mt_gcl_epoch "$window_end") - $(__mt_gcl_epoch "$window_start")))
    else
      period_seconds=$(__mt_gcl_duration_seconds "${align:-$GCL_METRIC_DEFAULT_ALIGN}") || {
        echo -e "${CB_RED}❌ --align must be a duration such as 60s or 5m, or the word window.${C_RESET}" >&2
        return 1
      }
    fi
    query+=(-q "aggregation.alignmentPeriod=${period_seconds}s")
    [ -n "$aligner" ] && query+=(-q "aggregation.perSeriesAligner=${aligner}")
    [ -n "$reducer" ] && query+=(-q "aggregation.crossSeriesReducer=${reducer}")
  fi
  if [ -n "$group_by" ]; then
    local field
    local -a group_fields
    IFS=, read -ra group_fields <<< "$group_by"
    for field in "${group_fields[@]}"; do
      [[ "$field" =~ $GCL_METRIC_GROUP_REGEX ]] || {
        echo -e "${CB_RED}❌ Invalid --group-by field: ${field}${C_RESET}" >&2
        return 1
      }
      query+=(-q "aggregation.groupByFields=${field}")
    done
  fi

  local series rc=0
  series=$(__mt_gcl_rest_collect "reading ${metric} in ${project}" timeSeries "${url}/timeSeries" "${query[@]}") || rc=$?
  [ "$rc" -ne 0 ] && return "$rc"
  [ -z "$series" ] && return 0
  if [ -n "$as_json" ]; then
    jq -s '.' <<< "$series" | __mt_strip_control_chars
  else
    jq -r -f "$GCL_METRIC_SERIES_JQ" <<< "$series" | __mt_strip_control_chars
  fi
}

#######################################
# GCP: Count where a text term appears in Cloud Logging across projects --
# grouped by resource type and service, never printing log payloads (results
# can contain customer data). Full-text search is slow and billed per scan, so
# the window and entry limit default tight; a project that reaches the limit
# is flagged because its counts are then a lower bound.
# Usage: gcl-logging-search <term> [-p <project>]... [--since <dur>] [--filter '<extra>'] [--limit <n>]
# Arguments:
#   <term>                 Text to search for (matched as a quoted global text search)
# Options:
#   -p, --project <id>     Project to search; repeatable (default: the active gcloud project)
#   --since <dur>          How far back, e.g. 6h, 2d (default: 1d)
#   --filter <expr>        Extra Cloud Logging filter ANDed onto the search
#   --limit <n>            Maximum entries to read per project (default: 1000)
#   -h, --help             Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 if any project was permission denied
# Outputs:
#   "project<TAB>resource type<TAB>service<TAB>hits<TAB>first seen<TAB>last seen" rows, most hits first
#######################################
gcl-logging-search() {
  local term="" since="$GCL_SEARCH_DEFAULT_SINCE" extra_filter="" limit="$GCL_SEARCH_DEFAULT_LIMIT"
  local -a projects=()
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
      --filter)
        extra_filter="${2:-}"
        shift
        ;;
      --limit)
        limit="${2:-}"
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) term="$1" ;;
    esac
    shift
  done

  if [ -z "$term" ]; then
    echo "Usage: gcl-logging-search <term> [-p <project>]... [--since <dur>] [--filter '<extra>'] [--limit <n>]" >&2
    return 1
  fi
  if [ "${#term}" -gt "$GCL_SEARCH_TERM_MAX_LENGTH" ] || [[ "$term" == *[[:cntrl:]]* ]]; then
    echo -e "${CB_RED}❌ The search term must be printable text of at most ${GCL_SEARCH_TERM_MAX_LENGTH} characters.${C_RESET}" >&2
    return 1
  fi
  [[ "$limit" =~ ^[1-9][0-9]*$ ]] || {
    echo -e "${CB_RED}❌ --limit must be a positive number.${C_RESET}" >&2
    return 1
  }
  local project
  for project in "${projects[@]}"; do
    [[ "$project" =~ $GCL_PROJECT_ID_REGEX ]] || {
      echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
      return 1
    }
  done
  local window_start window_end time_filter
  read -r window_start window_end < <(__mt_gcl_window "$since" "" "") || true
  if [ -z "$window_end" ]; then
    echo -e "${CB_RED}❌ Invalid --since (use e.g. 6h, 2d).${C_RESET}" >&2
    return 1
  fi
  time_filter="timestamp>=\"${window_start}\" AND timestamp<=\"${window_end}\""

  local escaped_term="${term//\\/\\\\}"
  escaped_term="${escaped_term//\"/\\\"}"
  local log_filter="\"${escaped_term}\" AND ${time_filter}"
  [ -n "$extra_filter" ] && log_filter="${log_filter} AND (${extra_filter})"

  __mt_gcl_preflight || return $?
  [ "${#projects[@]}" -eq 0 ] && projects=("$(gcl-get-project)")

  local result="" rc=0 step_rc entries entry_count rows
  for project in "${projects[@]}"; do
    step_rc=0
    entries=$(__mt_gcl_run "searching logs of ${project}" gcloud logging read "$log_filter" \
      --project="$project" --limit="$limit" --format=json --quiet) || step_rc=$?
    if [ "$step_rc" -ne 0 ]; then
      [ "$rc" -eq 0 ] && rc="$step_rc"
      continue
    fi
    [ -z "$entries" ] && continue
    entry_count=$(jq 'length' <<< "$entries")
    rows=$(jq -r --arg project "$project" -f "$GCL_SEARCH_HITS_JQ" <<< "$entries")
    [ -n "$rows" ] && result+="${rows}"$'\n'
    if [ "$entry_count" -ge "$limit" ]; then
      echo -e "${CB_YELLOW}⚠️  ${project}: reached the ${limit}-entry limit; counts are a lower bound (narrow --since or --filter).${C_RESET}" >&2
    fi
  done

  [ -n "$result" ] && printf '%s' "$result" | sort -t$'\t' -k4,4nr -s | __mt_strip_control_chars
  return "$rc"
}

#######################################
# GCP: Inventory of a project's monitoring setup: alert policies, dashboards,
# uptime checks, custom metric descriptors and log-based metrics. Read-only.
# Each section is independent: a denied or failing one is reported and the
# others still run.
# Usage: gcl-monitoring-inventory [-p <project>]... [--section alerts|dashboards|uptime|metrics|logmetrics]
# Options:
#   -p, --project <id>    Project to inspect; repeatable (default: the active gcloud project)
#   --section <name>      Only this section (alerts, dashboards, uptime, metrics, logmetrics)
#   -h, --help            Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 if any section was permission denied
# Outputs:
#   A heading per project and section, then tab-separated rows
#######################################
gcl-monitoring-inventory() {
  local only_section=""
  local -a projects=()
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
      --section)
        only_section="${2:-}"
        shift
        ;;
      *)
        echo -e "${CB_RED}❌ Unknown option or argument: $1${C_RESET}" >&2
        return 1
        ;;
    esac
    shift
  done
  local project section
  for project in "${projects[@]}"; do
    [[ "$project" =~ $GCL_PROJECT_ID_REGEX ]] || {
      echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
      return 1
    }
  done
  if [ -n "$only_section" ] && [[ " ${GCL_INVENTORY_SECTIONS[*]} " != *" ${only_section} "* ]]; then
    echo -e "${CB_RED}❌ --section must be one of: ${GCL_INVENTORY_SECTIONS[*]}.${C_RESET}" >&2
    return 1
  fi
  __mt_gcl_preflight || return $?
  [ "${#projects[@]}" -eq 0 ] && projects=("$(gcl-get-project)")

  local rc=0 section_rc json
  for project in "${projects[@]}"; do
    for section in "${GCL_INVENTORY_SECTIONS[@]}"; do
      [ -n "$only_section" ] && [ "$only_section" != "$section" ] && continue
      echo -e "${CB_BLUE}== ${project} / ${section} ==${C_RESET}"
      section_rc=0
      case "$section" in
        alerts | uptime | logmetrics)
          local -a read_command
          case "$section" in
            alerts) read_command=(gcloud monitoring policies list) ;;
            uptime) read_command=(gcloud monitoring uptime list-configs) ;;
            logmetrics) read_command=(gcloud logging metrics list) ;;
          esac
          json=$(__mt_gcl_run "reading ${section} of ${project}" "${read_command[@]}" --project="$project" --format=json --quiet) || section_rc=$?
          [ "$section_rc" -eq 0 ] && [ -n "$json" ] && jq -r --arg section "$section" --argjson filter_max "$GCL_INVENTORY_FILTER_MAX_LENGTH" \
            -f "$GCL_INVENTORY_JQ" <<< "$json" | __mt_strip_control_chars
          ;;
        dashboards)
          __mt_gcl_run "reading dashboards of ${project}" gcloud monitoring dashboards list --project="$project" \
            --format='value(displayName,name.basename())' --quiet | __mt_strip_control_chars
          section_rc="${PIPESTATUS[0]}"
          ;;
        metrics)
          __mt_gcl_metric_descriptors "$project" "$GCL_INVENTORY_CUSTOM_METRICS_FILTER"
          section_rc=$?
          ;;
      esac
      [ "$rc" -eq 0 ] && rc="$section_rc"
      [ "$section_rc" -eq "$GCL_EXIT_DENIED" ] && rc="$GCL_EXIT_DENIED"
    done
  done
  return "$rc"
}
