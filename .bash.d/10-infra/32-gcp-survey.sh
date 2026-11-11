# shellcheck shell=bash
# ------------------------------------------
# GCP: Read-Only Cross-Project Reconnaissance
# ------------------------------------------
# ~/.bash.d/10-infra/32-gcp-survey.sh
#
# gcl-* wrappers for read-only lookups a single project/environment often
# isn't the right scope for -- listing projects, checking API enablement
# across several of them, and describing/surveying Cloud Run, Redis,
# Dataflow, VPC networking, and IAM-key resources with an explicit
# -p/--project override rather than only ever the active gcloud config
# project. See 30-gcp-config.sh's own naming-convention comment for the
# gcl-*/gcp-*/gce-*/gcs-* split this file follows.

GCL_RUN_PROFILE_JQ="$HOME/.bash.d/lib/jq/gcl_run_profile.jq"
GCL_RUN_MATRIX_AWK="$HOME/.bash.d/lib/awk/kv_matrix.awk"
GCL_RUN_COMMIT_JQ="$HOME/.bash.d/lib/jq/gcl_run_commit.jq"
GCL_RUN_UNKNOWN_COMMIT="unknown (no SHA tag)"
GCL_RUN_BRANCH_REGEX='^[A-Za-z0-9._/@+-]+$'
GCL_RUN_DIFF_FLAG="⚠️"
GCL_RUN_ABSENT_TEXT="(absent)"
GCL_RUN_NOT_FOUND_REGEX='cannot find service|not found|NOT_FOUND'
GCL_PUBSUB_MAP_JQ="$HOME/.bash.d/lib/jq/gcl_pubsub_map.jq"
GCL_PUBSUB_TREE_JQ="$HOME/.bash.d/lib/jq/gcl_pubsub_tree.jq"
GCL_DATAFLOW_TIMELINE_DEFAULT_SINCE="7d"
GCL_DATAFLOW_MESSAGE_MAX_LENGTH=160
GCL_DATAFLOW_MESSAGE_LOG="dataflow.googleapis.com%2Fjob-message"
GCL_DATAFLOW_JOB_REGEX='^[A-Za-z0-9_.-]+$'
GCL_DATAFLOW_LABEL_JOB_NAME="dataflow_job_name"
GCL_DATAFLOW_LABEL_JOB_ID="dataflow_job_id"
GCL_DATAFLOW_TIMELINE_JQ="$HOME/.bash.d/lib/jq/gcl_dataflow_timeline.jq"
GCL_SCHEDULER_DEFAULT_LOCATIONS="europe-west1 europe-west2"
GCL_SCHEDULER_JOBS_JQ="$HOME/.bash.d/lib/jq/gcl_scheduler_jobs.jq"
GCL_SCHEDULER_DESCRIBE_JQ="$HOME/.bash.d/lib/jq/gcl_scheduler_describe.jq"
GCL_SCHEDULER_JOB_REGEX='^[A-Za-z0-9_-]+$'
GCL_SCHEDULER_LOCATION_REGEX='^[a-z0-9-]+$'

#######################################
# GCP: List projects, optionally filtered by name and/or parent folder
# Usage: gcl-projects-list [-f <name-filter>] [--folder <folder-id>]
# Options:
#   -f, --filter <text>    Only projects whose name contains this text
#   --folder <id>          Only projects directly under this folder ID
# Outputs:
#   Prints a table of project ID/name/number/parent to STDOUT
#######################################
gcl-projects-list() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local name_filter="" folder=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f | --filter)
        name_filter="$2"
        shift 2 || shift
        ;;
      --folder)
        folder="$2"
        shift 2 || shift
        ;;
      *)
        echo "Usage: gcl-projects-list [-f <name-filter>] [--folder <folder-id>]" >&2
        return 1
        ;;
    esac
  done

  local -a filter_parts=()
  [ -n "$name_filter" ] && filter_parts+=("name:*${name_filter}*")
  [ -n "$folder" ] && filter_parts+=("parent.type:folder" "parent.id:${folder}")

  local filter_expr=""
  if [ "${#filter_parts[@]}" -gt 0 ]; then
    filter_expr=$(printf ' AND %s' "${filter_parts[@]}")
    filter_expr="${filter_expr# AND }"
  fi

  if [ -n "$filter_expr" ]; then
    gcloud projects list --filter="$filter_expr" --format="table(projectId,name,projectNumber,parent.type,parent.id)" --quiet
  else
    gcloud projects list --format="table(projectId,name,projectNumber,parent.type,parent.id)" --quiet
  fi
}

#######################################
# GCP: Check whether an API is enabled across one or more projects
# Usage: gcl-api-check <api> <project> [project...]
#
# Examples:
#   gcl-api-check appengine.googleapis.com example-api-dev example-api-prod
#######################################
gcl-api-check() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local api="$1"
  if [[ -z "$api" ]]; then
    echo "Usage: gcl-api-check <api> <project> [project...]" >&2
    return 1
  fi
  shift

  if [[ "$#" -eq 0 ]]; then
    echo "Usage: gcl-api-check <api> <project> [project...]" >&2
    return 1
  fi

  printf "${CB_BLUE}%-40s %-12s${C_RESET}\n" "PROJECT" "ENABLED"
  echo "------------------------------------------------------"

  local project enabled_name
  for project in "$@"; do
    enabled_name=$(gcloud services list --enabled --project="$project" --filter="config.name:${api}" --format="value(config.name)" --quiet 2> /dev/null)
    if [ -n "$enabled_name" ]; then
      printf "%-40s ${CB_GREEN}%-12s${C_RESET}\n" "$project" "yes"
    else
      printf "%-40s ${CB_YELLOW}%-12s${C_RESET}\n" "$project" "no"
    fi
  done
}

#######################################
# GCP: Read-only survey of a project's networking surface -- VPC
# peerings, VPC Access connectors (region-scoped, skipped if no region
# given), Private Service Connect service attachments, Memorystore
# Redis instances, and custom routes. One consolidated report instead
# of five separate raw gcloud calls when planning connectivity between
# services.
# Usage: gcl-network-survey [-p <project>] [-r <region>]
# Options:
#   -p, --project <id>   Project to survey (default: the active gcloud project)
#   -r, --region <name>  Region for the VPC Access connector check (skipped if omitted)
#######################################
gcl-network-survey() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local project="" region=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --project)
        project="$2"
        shift 2 || shift
        ;;
      -r | --region)
        region="$2"
        shift 2 || shift
        ;;
      *)
        echo "Usage: gcl-network-survey [-p <project>] [-r <region>]" >&2
        return 1
        ;;
    esac
  done
  [ -z "$project" ] && project=$(gcl-get-project)

  echo -e "${CB_BLUE}🌐 VPC Peerings${C_RESET}"
  gcloud compute networks peerings list --project="$project" --format="table(name,network,peerNetwork,state)" --quiet

  echo -e "\n${CB_BLUE}🔌 VPC Access Connectors${C_RESET}"
  if [ -n "$region" ]; then
    gcloud compute networks vpc-access connectors list --project="$project" --region="$region" --format="table(name,network,ipCidrRange,state)" --quiet
  else
    echo -e "${CB_YELLOW}⚠️  No region given (-r), skipping -- VPC Access connectors are region-scoped.${C_RESET}"
  fi

  echo -e "\n${CB_BLUE}🔗 Private Service Connect Attachments${C_RESET}"
  gcloud compute service-attachments list --project="$project" --format="table(name,region,connectionPreference)" --quiet

  echo -e "\n${CB_BLUE}💾 Memorystore Redis Instances${C_RESET}"
  gcloud redis instances list --project="$project" --region=- --format="table(name,region,tier,host,port)" --quiet

  echo -e "\n${CB_BLUE}🛣️  Custom Routes${C_RESET}"
  gcloud compute routes list --project="$project" --format="table(name,network,destRange,priority)" --quiet
}

#######################################
# GCP: Describe a single Cloud Run service
# Usage: gcl-run-describe <service> -r <region> [-p <project>]
# Options:
#   -r, --region <name>  Region the service is deployed in (required)
#   -p, --project <id>   Project to inspect (default: the active gcloud project)
#######################################
gcl-run-describe() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local service="$1"
  if [[ -z "$service" ]]; then
    echo "Usage: gcl-run-describe <service> -r <region> [-p <project>]" >&2
    return 1
  fi
  shift

  local project="" region=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r | --region)
        region="$2"
        shift 2 || shift
        ;;
      -p | --project)
        project="$2"
        shift 2 || shift
        ;;
      *)
        echo "Usage: gcl-run-describe <service> -r <region> [-p <project>]" >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$region" ]]; then
    echo "Usage: gcl-run-describe <service> -r <region> [-p <project>]" >&2
    return 1
  fi
  [ -z "$project" ] && project=$(gcl-get-project)

  gcloud run services describe "$service" --region="$region" --project="$project" --quiet
}

#######################################
# GCP: Work out the commit a Cloud Run service was deployed from -- a
# commit-sha label, a hex image tag, or (for a digest-pinned image) a hex tag
# Artifact Registry lists for that digest
# Arguments:
#   $1 - Service JSON, $2 - project
# Outputs:
#   The commit SHA, or nothing when it cannot be determined
#######################################
__mt_gcl_run_deployed_commit() {
  local description="$1" project="$2" found image tags
  found=$(jq -r -f "$GCL_RUN_COMMIT_JQ" <<< "$description" | head -1)
  case "$found" in
    sha:*) echo "${found#sha:}" ;;
    digest:*)
      image="${found#digest:}"
      tags=$(gcloud artifacts docker images list "${image%@*}" --project="$project" --include-tags \
        --filter="version=${image#*@}" --format='value(tags)' --quiet 2> /dev/null | sed 's/[,;]/\n/g')
      grep -m1 -E '^[0-9a-f]{7,40}$' <<< "$tags"
      ;;
  esac
}

#######################################
# GCP: How far a commit is behind a branch of a local repository (no fetch)
# Arguments:
#   $1 - Repository path, $2 - branch, $3 - commit SHA (may be empty)
# Outputs:
#   0, a number of commits, "not on branch", "unknown (not in local repo)" or the unknown-SHA text
#######################################
__mt_gcl_run_behind() {
  local repo="$1" branch="$2" sha="$3"
  if [ -z "$sha" ]; then
    echo "$GCL_RUN_UNKNOWN_COMMIT"
    return 0
  fi
  if ! git -C "$repo" cat-file -e "${sha}^{commit}" 2> /dev/null; then
    echo "unknown (not in local repo)"
    return 0
  fi
  if ! git -C "$repo" merge-base --is-ancestor "$sha" "origin/${branch}" 2> /dev/null; then
    echo "not on branch"
    return 0
  fi
  git -C "$repo" rev-list --count "${sha}..origin/${branch}"
}

#######################################
# GCP: Compare one Cloud Run service across projects (environments): image,
# revision, service account, scaling, networking, probes, environment variable
# names and secret references. Environment variable VALUES are never shown
# (a literal value reads "set"; a secret reads "secret:<name>:<version>"), so
# the output is safe to paste. Rows that differ are marked; a project without
# the service shows (absent).
# With --repo it also finds each deployed commit and reports how far it is
# behind the repository's branch (local refs only; nothing is fetched).
# Usage: gcl-run-compare <service> -r <region> -p <project> -p <project> [...] [--all] [--repo <path> [--branch <name>]]
# Arguments:
#   <service>              Cloud Run service name
# Options:
#   -r, --region <region>  Region of the service
#   -p, --project <id>     Project to compare; repeat for each (at least two)
#   --all                  Print every row, not only the ones that differ
#   --repo <path>          Add commit and "behind origin/<branch>" rows from this local repository
#                          (run mt-bulk-update --repo <path> first so its refs are current)
#   --branch <name>        Branch to compare against (default: the repository's default branch)
#   -h, --help             Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 if any project was permission denied
# Outputs:
#   A key x project table, differing rows marked with a warning sign; the behind row reads
#   0, a number of commits, "not on branch" or "unknown (...)"
#######################################
gcl-run-compare() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local service="" region="" show_all="" repo="" branch=""
  local -a projects=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      --repo)
        repo="${2:-}"
        shift
        ;;
      --branch)
        branch="${2:-}"
        shift
        ;;
      -r | --region)
        region="${2:-}"
        shift
        ;;
      -p | --project)
        projects+=("${2:-}")
        shift
        ;;
      --all) show_all="1" ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) service="$1" ;;
    esac
    shift
  done
  if [ -z "$service" ] || [ -z "$region" ] || [ "${#projects[@]}" -lt 2 ]; then
    echo "Usage: gcl-run-compare <service> -r <region> -p <project> -p <project> [...] [--all] [--repo <path> [--branch <name>]]" >&2
    return 1
  fi
  if [ -n "$repo" ]; then
    git -C "$repo" rev-parse --git-dir > /dev/null 2>&1 || {
      echo -e "${CB_RED}❌ ${repo} is not a git repository.${C_RESET}" >&2
      return 1
    }
    [ -z "$branch" ] && branch=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2> /dev/null)
    branch="${branch#origin/}"
    [[ "$branch" =~ $GCL_RUN_BRANCH_REGEX ]] || {
      echo -e "${CB_RED}❌ Could not determine the branch; pass --branch.${C_RESET}" >&2
      return 1
    }
  elif [ -n "$branch" ]; then
    echo -e "${CB_RED}❌ --branch needs --repo.${C_RESET}" >&2
    return 1
  fi
  [[ "$service" =~ ^[A-Za-z0-9_-]+$ && "$region" =~ ^[a-z0-9-]+$ ]] || {
    echo -e "${CB_RED}❌ Invalid service or region.${C_RESET}" >&2
    return 1
  }
  local project
  for project in "${projects[@]}"; do
    [[ "$project" =~ $GCL_PROJECT_ID_REGEX ]] || {
      echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
      return 1
    }
  done
  __mt_gcl_preflight || return $?

  local profiles="" rc=0 description err_file project_rc columns
  local -a shown=()
  for project in "${projects[@]}"; do
    err_file=$(mktemp)
    project_rc=0
    description=$(gcloud run services describe "$service" --region="$region" --project="$project" --format=json --quiet 2> "$err_file") || project_rc=$?
    if [ "$project_rc" -eq 0 ]; then
      shown+=("$project")
      profiles+=$(jq -r --arg project "$project" -f "$GCL_RUN_PROFILE_JQ" <<< "$description")$'\n'
      if [ -n "$repo" ]; then
        local deployed_sha
        deployed_sha=$(__mt_gcl_run_deployed_commit "$description" "$project")
        [ -n "$deployed_sha" ] && profiles+="${project}"$'\t'"commit"$'\t'"${deployed_sha:0:12}"$'\n'
        profiles+="${project}"$'\t'"behind origin/${branch}"$'\t'"$(__mt_gcl_run_behind "$repo" "$branch" "$deployed_sha")"$'\n'
      fi
    elif grep -qiE "$GCL_RUN_NOT_FOUND_REGEX" "$err_file"; then
      shown+=("$project")
      profiles+="${project}"$'\t'"service"$'\t'"${GCL_RUN_ABSENT_TEXT}"$'\n'
    else
      __mt_gcl_report_failure "describing ${service} in ${project}" "$(cat "$err_file")"
      project_rc=$?
      [ "$rc" -eq 0 ] && rc="$project_rc"
    fi
    rm -f "$err_file"
  done

  columns=$(printf '%s,' "${shown[@]}")
  printf '%s' "$profiles" | awk -v columns="${columns%,}" -v header="KEY" -v empty="-" -v mark="set" \
    -v flag="$GCL_RUN_DIFF_FLAG" -v diff_only="$([ -z "$show_all" ] && echo 1 || echo 0)" \
    -f "$GCL_RUN_MATRIX_AWK" | __mt_strip_control_chars
  return "$rc"
}

#######################################
# GCP: Map Pub/Sub topics to their subscriptions across projects: delivery
# type (push, bigquery, gcs, pull) and target, filter, dead-letter topic and
# any non-ACTIVE state. Subscriptions are matched to topics by full path, so
# listing two projects shows subscriptions that cross them. Push URLs are
# shown without userinfo and query string.
# Usage: gcl-pubsub-map [-p <project>]... [-t <topic-substring>] [--json]
# Options:
#   -p, --project <id>       Project to read; repeatable (default: the active gcloud project)
#   -t, --topic <text>       Only topics whose full path contains this text
#   --json                   Print the grouped structure as JSON instead of a tree
#   -h, --help               Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 if any project was permission denied
# Outputs:
#   A topic -> subscription tree
#######################################
gcl-pubsub-map() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local needle="" as_json=""
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
      -t | --topic)
        needle="${2:-}"
        shift
        ;;
      --json) as_json="1" ;;
      *)
        echo "Usage: gcl-pubsub-map [-p <project>]... [-t <topic-substring>] [--json]" >&2
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
  __mt_gcl_preflight || return $?
  [ "${#projects[@]}" -eq 0 ] && projects=("$(gcl-get-project)")

  local all_subs="[]" all_topics="[]" rc=0 step_rc found
  for project in "${projects[@]}"; do
    step_rc=0
    found=$(__mt_gcl_run "listing subscriptions of ${project}" gcloud pubsub subscriptions list --project="$project" --format=json --quiet) || step_rc=$?
    if [ "$step_rc" -eq 0 ]; then
      all_subs=$(jq -c --argjson more "${found:-[]}" '. + $more' <<< "$all_subs")
    else
      [ "$rc" -eq 0 ] && rc="$step_rc"
    fi
    step_rc=0
    found=$(__mt_gcl_run "listing topics of ${project}" gcloud pubsub topics list --project="$project" --format=json --quiet) || step_rc=$?
    if [ "$step_rc" -eq 0 ]; then
      all_topics=$(jq -c --argjson more "${found:-[]}" '. + $more' <<< "$all_topics")
    else
      [ "$rc" -eq 0 ] && rc="$step_rc"
    fi
  done

  local map
  map=$(jq -n -c --argjson subs "$all_subs" --argjson topics "$all_topics" --arg needle "$needle" -f "$GCL_PUBSUB_MAP_JQ") || return 1
  if [ -n "$as_json" ]; then
    jq '.' <<< "$map" | __mt_strip_control_chars
  else
    jq -r -f "$GCL_PUBSUB_TREE_JQ" <<< "$map" | __mt_strip_control_chars
  fi
  return "$rc"
}

#######################################
# GCP: Describe a single Memorystore Redis instance
# Usage: gcl-redis-describe <instance> -r <region> [-p <project>]
# Options:
#   -r, --region <name>  Region the instance is in (required)
#   -p, --project <id>   Project to inspect (default: the active gcloud project)
#######################################
gcl-redis-describe() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local instance="$1"
  if [[ -z "$instance" ]]; then
    echo "Usage: gcl-redis-describe <instance> -r <region> [-p <project>]" >&2
    return 1
  fi
  shift

  local project="" region=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r | --region)
        region="$2"
        shift 2 || shift
        ;;
      -p | --project)
        project="$2"
        shift 2 || shift
        ;;
      *)
        echo "Usage: gcl-redis-describe <instance> -r <region> [-p <project>]" >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$region" ]]; then
    echo "Usage: gcl-redis-describe <instance> -r <region> [-p <project>]" >&2
    return 1
  fi
  [ -z "$project" ] && project=$(gcl-get-project)

  gcloud redis instances describe "$instance" --region="$region" --project="$project" --quiet
}

#######################################
# GCP: Describe a single Dataflow job, or -- without needing dataflow.jobs.get --
# read its job-message timeline from Cloud Logging and list its worker VMs
# from Compute. With --timeline or --workers the argument may be a job ID or
# a job name, and `dataflow jobs describe` is not called.
# Usage: gcl-dataflow-describe <job-id|name> [-p <project>] [--full] [--timeline [--since <dur>]] [--workers]
# Options:
#   -p, --project <id>   Project to inspect (default: the active gcloud project)
#   --full               Include full job details (steps, environment)
#   --timeline           Job messages, oldest first, with a marker when the job ID changes (relaunch or update)
#   --since <dur>        With --timeline, how far back to read, e.g. 6h, 7d (default: 7d)
#   --workers            Worker VMs of the job (name, zone, machine type, status, created)
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 on permission denied
# Outputs:
#   The job description, or timeline rows "timestamp<TAB>severity<TAB>job_id<TAB>message", or a worker table
#######################################
gcl-dataflow-describe() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local job_id="$1"
  if [[ -z "$job_id" ]]; then
    echo "Usage: gcl-dataflow-describe <job-id|name> [-p <project>] [--full] [--timeline [--since <dur>]] [--workers]" >&2
    return 1
  fi
  shift

  local project="" full=false timeline=false workers=false since="$GCL_DATAFLOW_TIMELINE_DEFAULT_SINCE"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --project)
        project="$2"
        shift 2 || shift
        ;;
      --full)
        full=true
        shift
        ;;
      --timeline)
        timeline=true
        shift
        ;;
      --workers)
        workers=true
        shift
        ;;
      --since)
        since="${2:-}"
        shift 2 || shift
        ;;
      *)
        echo "Usage: gcl-dataflow-describe <job-id|name> [-p <project>] [--full] [--timeline [--since <dur>]] [--workers]" >&2
        return 1
        ;;
    esac
  done
  [ -z "$project" ] && project=$(gcl-get-project)

  if $timeline || $workers; then
    __mt_gcl_dataflow_inspect "$job_id" "$project" "$timeline" "$workers" "$since"
    return $?
  fi

  local -a full_flag=()
  $full && full_flag=(--full)

  gcloud dataflow jobs describe "$job_id" --project="$project" "${full_flag[@]}" --quiet
}

#######################################
# GCP: Dataflow job timeline and worker VMs, read from Cloud Logging and Compute
# Arguments:
#   $1 - Job ID or name, $2 - project, $3 - true to print the timeline,
#   $4 - true to list workers, $5 - timeline window (e.g. 7d)
# Returns:
#   0 on success, 1 on bad input, otherwise the failing call's result
#######################################
__mt_gcl_dataflow_inspect() {
  local job="$1" project="$2" timeline="$3" workers="$4" since="$5"
  [[ "$job" =~ $GCL_DATAFLOW_JOB_REGEX ]] || {
    echo -e "${CB_RED}❌ Invalid job ID or name: ${job}${C_RESET}" >&2
    return 1
  }
  [[ "$project" =~ $GCL_PROJECT_ID_REGEX ]] || {
    echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
    return 1
  }
  local time_filter
  time_filter=$(__mt_gcl_time_filter "$since" "" "") || {
    echo -e "${CB_RED}❌ Invalid --since (use e.g. 6h, 7d).${C_RESET}" >&2
    return 1
  }
  __mt_gcl_preflight || return $?

  local rc=0 entries
  if [ "$timeline" = true ]; then
    local log_filter="resource.type=\"dataflow_step\" AND (resource.labels.job_name=\"${job}\" OR resource.labels.job_id=\"${job}\")"
    log_filter="${log_filter} AND logName=\"projects/${project}/logs/${GCL_DATAFLOW_MESSAGE_LOG}\" AND ${time_filter}"
    entries=$(__mt_gcl_run "reading Dataflow job messages of ${job}" gcloud logging read "$log_filter" \
      --project="$project" --order=asc --format=json --quiet) || return $?
    [ -n "$entries" ] && jq -r --argjson max_length "$GCL_DATAFLOW_MESSAGE_MAX_LENGTH" -f "$GCL_DATAFLOW_TIMELINE_JQ" <<< "$entries" | __mt_strip_control_chars
  fi
  if [ "$workers" = true ]; then
    __mt_gcl_run "listing worker VMs of ${job}" gcloud compute instances list --project="$project" \
      --filter="labels.${GCL_DATAFLOW_LABEL_JOB_NAME}=${job} OR labels.${GCL_DATAFLOW_LABEL_JOB_ID}=${job}" \
      --format='table(name,zone.basename(),machineType.basename(),status,creationTimestamp)' --quiet | __mt_strip_control_chars
    rc="${PIPESTATUS[0]}"
  fi
  return "$rc"
}

#######################################
# GCP: Read logs with a custom filter and optional custom output format
# -- gcl-as-json only ever emits JSON, with no way to project a
# --format=value(...) expression the way raw 'gcloud logging read' can.
# Usage: gcl-logging-read <filter> [-p <project>] [--limit <n>] [--fmt <format-expr>]
# Options:
#   -p, --project <id>     Project to read from (default: the active gcloud project)
#   --limit <n>            Maximum number of log entries (default: 50)
#   --fmt <format-expr>    A gcloud --format expression, e.g. 'value(textPayload)'
#
# Examples:
#   gcl-logging-read 'resource.type=cloud_run_revision AND severity>=ERROR' --limit 20
#   gcl-logging-read 'resource.type=cloud_run_revision' --fmt 'value(textPayload)'
#######################################
gcl-logging-read() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local log_filter="$1"
  if [[ -z "$log_filter" ]]; then
    echo "Usage: gcl-logging-read <filter> [-p <project>] [--limit <n>] [--fmt <format-expr>]" >&2
    return 1
  fi
  shift

  local project="" limit=50 fmt=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --project)
        project="$2"
        shift 2 || shift
        ;;
      --limit)
        limit="$2"
        shift 2 || shift
        ;;
      --fmt)
        fmt="$2"
        shift 2 || shift
        ;;
      *)
        echo "Usage: gcl-logging-read <filter> [-p <project>] [--limit <n>] [--fmt <format-expr>]" >&2
        return 1
        ;;
    esac
  done
  [ -z "$project" ] && project=$(gcl-get-project)

  if [ -n "$fmt" ]; then
    gcloud logging read "$log_filter" --project="$project" --limit="$limit" --format="$fmt" --quiet
  else
    gcloud logging read "$log_filter" --project="$project" --limit="$limit" --quiet
  fi
}

#######################################
# GCP: List a service account's IAM keys and its own IAM policy bindings
# in one call -- the two checks a "who can use/impersonate this service
# account, and what keys already exist" audit needs together.
# Usage: gcl-iam-keys <service-account-email> [-p <project>]
# Options:
#   -p, --project <id>   Project to inspect (default: the active gcloud project)
#######################################
gcl-iam-keys() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local sa_email="$1"
  if [[ -z "$sa_email" ]]; then
    echo "Usage: gcl-iam-keys <service-account-email> [-p <project>]" >&2
    return 1
  fi
  shift

  local project=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --project)
        project="$2"
        shift 2 || shift
        ;;
      *)
        echo "Usage: gcl-iam-keys <service-account-email> [-p <project>]" >&2
        return 1
        ;;
    esac
  done
  [ -z "$project" ] && project=$(gcl-get-project)

  echo -e "${CB_BLUE}🔑 Keys${C_RESET}"
  gcloud iam service-accounts keys list --iam-account="$sa_email" --format="table(name.basename(),validAfterTime,validBeforeTime,keyType)" --quiet

  echo -e "\n${CB_BLUE}📜 IAM Policy${C_RESET}"
  gcloud iam service-accounts get-iam-policy "$sa_email" --project="$project" --format="table(bindings.role,bindings.members)" --quiet
}

#######################################
# GCP: Cloud Scheduler locations to search -- the given ones, every location
# of the project, or the configured scan regions
# Arguments:
#   $1 - Project, $2 - 1 to use every location of the project
#   $3... - Explicit locations (override both)
# Returns:
#   0 on success, otherwise the failing call's result
# Outputs:
#   One location per line
#######################################
__mt_gcl_scheduler_locations() {
  local project="$1" all_locations="$2" location
  shift 2 || return 1
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$@"
    return 0
  fi
  if [ "$all_locations" = "1" ]; then
    __mt_gcl_run "listing Cloud Scheduler locations of ${project}" gcloud scheduler locations list \
      --project="$project" --format='value(locationId)' --quiet
    return $?
  fi
  for location in ${GCP_SCAN_REGIONS:-$GCL_SCHEDULER_DEFAULT_LOCATIONS}; do
    echo "$location"
  done
}

#######################################
# GCP: Find the locations of a Cloud Scheduler job
# Arguments:
#   $1 - Project, $2 - job, $3... - locations to search
# Returns:
#   0 if searched without error, otherwise the first failing call's result
# Outputs:
#   Locations that hold the job, one per line
#######################################
__mt_gcl_scheduler_locate() {
  local project="$1" job="$2" location jobs rc=0 location_rc
  shift 2 || return 1
  for location in "$@"; do
    location_rc=0
    jobs=$(__mt_gcl_run "listing Cloud Scheduler jobs in ${project}/${location}" gcloud scheduler jobs list \
      --location="$location" --project="$project" --format='value(name)' --quiet) || location_rc=$?
    if [ "$location_rc" -ne 0 ]; then
      [ "$rc" -eq 0 ] && rc="$location_rc"
      continue
    fi
    grep -qx ".*/jobs/${job}" <<< "$jobs" && echo "$location"
  done
  return "$rc"
}

#######################################
# GCP: List, describe, pause or resume Cloud Scheduler jobs across projects and
# locations. Scheduler is regional, so the locations searched are -l, every
# location of the project (--all-locations), or the configured scan regions
# (gcp.scan_regions). describe hides request bodies and header values; pause and
# resume change a job's state and ask for confirmation (or --yes).
# Usage: gcl-scheduler list [-p <project>]... [-l <location>]... [--all-locations]
#        gcl-scheduler describe <job> [-p <project>] [-l <location>]...
#        gcl-scheduler pause|resume <job> [-p <project>] [-l <location>]... [--yes]
# Arguments:
#   <job>                    Job ID (the last segment of its name)
# Options:
#   -p, --project <id>       Project; repeatable for list (default: the active gcloud project)
#   -l, --location <region>  Location to search; repeatable (default: gcp.scan_regions)
#   --all-locations          Search every Cloud Scheduler location of the project
#   --yes                    pause/resume: skip the confirmation (required without a terminal)
#   -h, --help               Show this help menu
# Globals:
#   GCP_SCAN_REGIONS
# Returns:
#   0 on success, 1 on failure, bad usage or an ambiguous/unknown job, 5 on permission denied
# Outputs:
#   list: "project<TAB>location<TAB>job<TAB>state<TAB>schedule<TAB>timeZone<TAB>target<TAB>lastAttemptTime<TAB>status" rows
#   describe: the job as JSON
#######################################
gcl-scheduler() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local action="${1:-}" job=""
  shift
  local -a projects=() locations=()
  local all_locations="" assume_yes=""
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
      -l | --location)
        locations+=("${2:-}")
        shift
        ;;
      --all-locations) all_locations="1" ;;
      --yes) assume_yes="1" ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) job="$1" ;;
    esac
    shift
  done

  local usage="Usage: gcl-scheduler list|describe|pause|resume [<job>] [-p <project>] [-l <location>] [--all-locations] [--yes]"
  case "$action" in
    list) ;;
    describe | pause | resume)
      [ -z "$job" ] && {
        echo "$usage" >&2
        return 1
      }
      [[ "$job" =~ $GCL_SCHEDULER_JOB_REGEX ]] || {
        echo -e "${CB_RED}❌ Invalid job ID: ${job}${C_RESET}" >&2
        return 1
      }
      [ "${#projects[@]}" -gt 1 ] && {
        echo -e "${CB_RED}❌ ${action} takes a single project.${C_RESET}" >&2
        return 1
      }
      ;;
    *)
      echo "$usage" >&2
      return 1
      ;;
  esac
  local item
  for item in "${projects[@]}"; do
    [[ "$item" =~ $GCL_PROJECT_ID_REGEX ]] || {
      echo -e "${CB_RED}❌ Invalid project: ${item}${C_RESET}" >&2
      return 1
    }
  done
  for item in "${locations[@]}"; do
    [[ "$item" =~ $GCL_SCHEDULER_LOCATION_REGEX ]] || {
      echo -e "${CB_RED}❌ Invalid location: ${item}${C_RESET}" >&2
      return 1
    }
  done
  if [[ "$action" == "pause" || "$action" == "resume" ]] && [ -z "$assume_yes" ] && [ ! -t 0 ]; then
    echo -e "${CB_RED}🚫 ${action} changes a job; pass --yes when there is no terminal to confirm on.${C_RESET}" >&2
    return 1
  fi

  __mt_gcl_preflight || return $?
  [ "${#projects[@]}" -eq 0 ] && projects=("$(gcl-get-project)")

  local project rc=0 step_rc found_locations
  local -a search_locations
  if [ "$action" = "list" ]; then
    for project in "${projects[@]}"; do
      mapfile -t search_locations < <(__mt_gcl_scheduler_locations "$project" "$all_locations" "${locations[@]}")
      for item in "${search_locations[@]}"; do
        step_rc=0
        __mt_gcl_run "listing Cloud Scheduler jobs in ${project}/${item}" gcloud scheduler jobs list \
          --location="$item" --project="$project" --format=json --quiet |
          jq -r --arg project "$project" --arg location "$item" -f "$GCL_SCHEDULER_JOBS_JQ" |
          __mt_strip_control_chars
        step_rc="${PIPESTATUS[0]}"
        [ "$rc" -eq 0 ] && rc="$step_rc"
      done
    done
    return "$rc"
  fi

  project="${projects[0]}"
  mapfile -t search_locations < <(__mt_gcl_scheduler_locations "$project" "$all_locations" "${locations[@]}")
  step_rc=0
  found_locations=$(__mt_gcl_scheduler_locate "$project" "$job" "${search_locations[@]}") || step_rc=$?
  local -a found=()
  [ -n "$found_locations" ] && mapfile -t found <<< "$found_locations"
  if [ "${#found[@]}" -ne 1 ]; then
    [ "$step_rc" -ne 0 ] && return "$step_rc"
    if [ "${#found[@]}" -eq 0 ]; then
      echo -e "${CB_RED}❌ Job ${job} not found in ${project} (searched: ${search_locations[*]}).${C_RESET}" >&2
    else
      echo -e "${CB_RED}❌ Job ${job} exists in several locations (${found[*]}); pass -l.${C_RESET}" >&2
    fi
    return 1
  fi
  local location="${found[0]}"

  if [ "$action" = "describe" ]; then
    __mt_gcl_run "describing ${job}" gcloud scheduler jobs describe "$job" --location="$location" \
      --project="$project" --format=json --quiet | jq -f "$GCL_SCHEDULER_DESCRIBE_JQ" | __mt_strip_control_chars
    return "${PIPESTATUS[0]}"
  fi

  if [ -z "$assume_yes" ]; then
    local reply
    read -r -p "${action^} job ${job} in ${project}/${location}? [y/N] " reply
    [[ "$reply" =~ ^[Yy] ]] || {
      echo "Cancelled."
      return 1
    }
  fi
  __mt_gcl_run "${action} of ${job}" gcloud scheduler jobs "$action" "$job" --location="$location" \
    --project="$project" --quiet > /dev/null || return $?
  echo -e "${CB_GREEN}✅ ${action^}d ${job} (${project}/${location}).${C_RESET}"
}
