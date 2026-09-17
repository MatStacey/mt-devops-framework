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
        shift 2
        ;;
      --folder)
        folder="$2"
        shift 2
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
#   gcl-api-check appengine.googleapis.com connect-api-dev connect-api-prod
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
        shift 2
        ;;
      -r | --region)
        region="$2"
        shift 2
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
        shift 2
        ;;
      -p | --project)
        project="$2"
        shift 2
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
        shift 2
        ;;
      -p | --project)
        project="$2"
        shift 2
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
# GCP: Describe a single Dataflow job
# Usage: gcl-dataflow-describe <job-id> [-p <project>] [--full]
# Options:
#   -p, --project <id>   Project to inspect (default: the active gcloud project)
#   --full               Include full job details (steps, environment)
#######################################
gcl-dataflow-describe() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local job_id="$1"
  if [[ -z "$job_id" ]]; then
    echo "Usage: gcl-dataflow-describe <job-id> [-p <project>] [--full]" >&2
    return 1
  fi
  shift

  local project="" full=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --project)
        project="$2"
        shift 2
        ;;
      --full)
        full=true
        shift
        ;;
      *)
        echo "Usage: gcl-dataflow-describe <job-id> [-p <project>] [--full]" >&2
        return 1
        ;;
    esac
  done
  [ -z "$project" ] && project=$(gcl-get-project)

  local -a full_flag=()
  $full && full_flag=(--full)

  gcloud dataflow jobs describe "$job_id" --project="$project" "${full_flag[@]}" --quiet
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
        shift 2
        ;;
      --limit)
        limit="$2"
        shift 2
        ;;
      --fmt)
        fmt="$2"
        shift 2
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
        shift 2
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
