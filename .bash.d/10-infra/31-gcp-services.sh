# shellcheck shell=bash
# ------------------------------------------
# GCP: Resources & Services
# ------------------------------------------
# ~/.bash.d/10-infra/31-gcp-services.sh
# See 30-gcp-config.sh for the gcl-/gcp-/gce-/gcs-/bq- naming convention.

#######################################
# GCP: Compute - List all VM instances
#######################################
alias gce-ls='gcloud compute instances list'

#######################################
# GCP: Compute - SSH into an instance
# Usage: gce-ssh <vm-name>
#######################################
alias gce-ssh='gcloud compute ssh'

#######################################
# GCP: Cloud Storage - List buckets or contents
# Usage: gcs-ls gs://bucket
#######################################
alias gcs-ls='gcloud storage ls'

#######################################
# GCP: BigQuery - List datasets in project
#######################################
alias bq-ls='bq ls'

#######################################
# GCP: Artifact Registry - List repositories
#######################################
alias gcl-gar-ls='gcloud artifacts repositories list'

#######################################
# GCP: IAM - List service accounts in active project
#######################################
alias gcl-iam-ls='gcloud iam service-accounts list'

#######################################
# GCP: PubSub - List subscriptions
#######################################
alias gcl-ps-subs='gcloud pubsub subscriptions list'

#######################################
# GCP: PubSub - List topics
#######################################
alias gcl-ps-topics='gcloud pubsub topics list'

#######################################
# GCP: Cloud Run Functions - List functions
#######################################
alias gcp-crf-ls='gcloud functions list'

GCP_IAM_MATRIX_AWK="$HOME/.bash.d/lib/awk/kv_matrix.awk"
GCP_IAM_MATRIX_MARK="✅"
GCP_IAM_MATRIX_EMPTY="-"
GCP_IAM_MEMBER_REGEX='^[A-Za-z0-9._@:+-]+$'

#######################################
# GCP: Add the IAM member type prefix: values with a type: prefix are kept,
# *.gserviceaccount.com becomes serviceAccount:, any other email user:
# Arguments:
#   $1 - Member
# Returns:
#   0 on success, 1 if the member is not a type:value or an email
# Outputs:
#   Normalised member
#######################################
__mt_gcp_normalize_member() {
  local member="$1"
  [[ "$member" =~ $GCP_IAM_MEMBER_REGEX ]] || return 1
  case "$member" in
    *:*) echo "$member" ;;
    *.gserviceaccount.com) echo "serviceAccount:${member}" ;;
    *@*) echo "user:${member}" ;;
    *) return 1 ;;
  esac
}

#######################################
# GCP: View IAM policy for one or more projects, or the roles one member
# holds in them (a role x project matrix when several projects are given)
# Usage: gcp-iam-show [-p <project>]... [-m <member>]
# Options:
#   -p, --project <id>     Project to inspect; repeatable (default: the active gcloud project)
#   -m, --member <member>  Only this member's roles; a type: prefix is kept, *.gserviceaccount.com
#                          becomes serviceAccount:, any other email becomes user:
#   -h, --help             Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 if any project was permission denied
# Outputs:
#   Without --member: the policy bindings table (headed per project when several).
#   With --member: "role<TAB>condition" rows for one project, otherwise a
#   role x project matrix.
# Example:
#   gcp-iam-show -m sa@proj.iam.gserviceaccount.com -p dev -p stage -p prod
# Globals:
#   gcl-get-project (Framework Function)
#######################################
gcp-iam-show() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local -a projects=()
  local member=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --project)
        projects+=("${2:-}")
        shift 2 || shift
        ;;
      -m | --member)
        member="${2:-}"
        shift 2 || shift
        ;;
      *)
        echo "Usage: gcp-iam-show [-p <project>]... [-m <member>]" >&2
        return 1
        ;;
    esac
  done
  [ "${#projects[@]}" -eq 0 ] && projects=("$(gcl-get-project)")

  local project rc=0 project_rc
  if [ -z "$member" ]; then
    for project in "${projects[@]}"; do
      [ "${#projects[@]}" -gt 1 ] && echo "== ${project} =="
      project_rc=0
      gcloud projects get-iam-policy "$project" --format="table(bindings.role, bindings.members)" --quiet || project_rc=$?
      [ "$rc" -eq 0 ] && rc="$project_rc"
    done
    return "$rc"
  fi

  member=$(__mt_gcp_normalize_member "$member") || {
    echo "Invalid --member: use an email or <type>:<value>." >&2
    return 1
  }
  local roles matrix_input="" row
  for project in "${projects[@]}"; do
    project_rc=0
    roles=$(__mt_gcl_run "reading the IAM policy of ${project}" gcloud projects get-iam-policy "$project" \
      --flatten="bindings[].members" --filter="bindings.members=${member}" \
      --format="value(bindings.role,bindings.condition.title)" --quiet) || project_rc=$?
    if [ "$project_rc" -ne 0 ]; then
      [ "$rc" -eq 0 ] && rc="$project_rc"
      continue
    fi
    while IFS= read -r row; do
      [ -n "$row" ] && matrix_input+="${project}"$'\t'"${row}"$'\n'
    done <<< "$roles"
  done

  if [ "${#projects[@]}" -eq 1 ]; then
    printf '%s' "$matrix_input" | cut -f2- | sort
  else
    local columns
    columns=$(printf '%s,' "${projects[@]}")
    printf '%s' "$matrix_input" | awk -v columns="${columns%,}" \
      -v mark="$GCP_IAM_MATRIX_MARK" -v empty="$GCP_IAM_MATRIX_EMPTY" -v header="ROLE" \
      -f "$GCP_IAM_MATRIX_AWK"
  fi
  return "$rc"
}

#######################################
# GCP: Read the latest payload of a secret
# Arguments:
#   $1 - Secret Name
# Outputs:
#   Prints secret payload string to STDOUT
#######################################
gcp-get-secret() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud secrets versions access latest --secret="$1"
}

#######################################
# GCP: Tail logs of a Cloud Run Function
# Arguments:
#   $1 - Function Name
#   $2 - Limit (default: 50)
# Outputs:
#   Prints log stream to STDOUT
#######################################
gcp-crf-logs() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local target_function="$1"
  local line_limit="${2:-50}"

  gcloud functions logs read "$target_function" --limit="$line_limit"
}

#######################################
# GCP: Run standard SQL query in BigQuery
# Arguments:
#   $1 - SQL query string (e.g., "SELECT...")
# Outputs:
#   Prints query results table to STDOUT
#######################################
bq-query() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  bq query --use_legacy_sql=false "$1"
}

#######################################
# GCP: Configure Docker auth for Artifact Registry
# Arguments:
#   $1 - Region (e.g., us-central1)
#######################################
gcp-gar-docker() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud auth configure-docker "$1-docker.pkg.dev"
}

#######################################
# GCP: Pull and auto-ack one message from a Pub/Sub subscription
# Arguments:
#   $1 - Subscription Name
# Outputs:
#   Prints the pulled message to STDOUT
#######################################
gcp-ps-pull() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud pubsub subscriptions pull "$1" --auto-ack --limit=1
}

#######################################
# GCP: Run any gcloud command and output as formatted JSON
# Arguments:
#   $@ - gcloud command and arguments
# Outputs:
#   Prints formatted JSON to STDOUT
#######################################
gcl-as-json() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud "$@" --format="json" | jq '.'
}

#######################################
# GCP: Autocompletion for gcp-get-secret
#######################################
_gcp_sec_read_completions() {
  mapfile -t COMPREPLY < <(compgen -W "$(gcloud secrets list --format="value(name)" 2> /dev/null)" -- "${COMP_WORDS[COMP_CWORD]}")
}
complete -F _gcp_sec_read_completions gcp-get-secret

#######################################
# GCP: Autocompletion for gce-ssh
#######################################
_gce_ssh_completions() {
  mapfile -t COMPREPLY < <(compgen -W "$(gcloud compute instances list --format="value(name)" 2> /dev/null)" -- "${COMP_WORDS[COMP_CWORD]}")
}
complete -F _gce_ssh_completions gce-ssh

#######################################
# GCP: Autocompletion for gcp-crf-logs
#######################################
_gcp_crf_logs_completions() {
  mapfile -t COMPREPLY < <(compgen -W "$(gcloud functions list --format="value(name)" 2> /dev/null)" -- "${COMP_WORDS[COMP_CWORD]}")
}
complete -F _gcp_crf_logs_completions gcp-crf-logs
