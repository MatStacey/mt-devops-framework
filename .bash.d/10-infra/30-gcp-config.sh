# shellcheck shell=bash disable=SC2119,SC2120
# ------------------------------------------
# GCP: Configuration & Authentication
# ------------------------------------------
# Naming convention for the Google Cloud command family (this file and
# 31-gcp-services.sh):
#   gcl-*  Reads or manages local gcloud CLI state — the active
#          configuration under ~/.config/gcloud/, or the CLI binary itself
#          (gcl-get, gcl-config, gcl-update). No account-level side effects.
#   gcp-*  Talks to a live Google Cloud account or service: auth, project
#          switching, IAM, Secret Manager, Cloud Run logs, Artifact
#          Registry, Pub/Sub (gcp-login, gcp-set-project, gcp-iam-show...).
#   gce-*  Thin `gcloud compute ...` aliases (gce-ls, gce-ssh) — mirrors
#          gcloud's own "gce" shorthand for Compute Engine.
#   gcs-*  Thin `gcloud storage ...` aliases (gcs-ls) — mirrors gcloud's
#          own "gcs" shorthand for Cloud Storage.
#   bq-*   BigQuery-specific operations, kept under its own short prefix
#          since it is a distinct GCP product with its own CLI (bq).
# This is a naming convention, not a hard technical boundary — a few
# functions (e.g. gcl-org-policies, gcl-export-vars) call the live API to
# resolve local config values, but are still `gcl-` because their purpose
# is reading/deriving local state rather than performing an account
# operation.

#######################################
# GCP: Legacy shortcut to set project
#######################################
alias gcpp="gcp-set-project"

__get_gcp_config_val() {
  local target_key="$1"
  local gcp_active="default"

  if [ -f "$HOME/.config/gcloud/active_config" ]; then
    read -r gcp_active < "$HOME/.config/gcloud/active_config"
  fi

  local gcp_config_file="$HOME/.config/gcloud/configurations/config_${gcp_active}"

  if [ -f "$gcp_config_file" ]; then
    while read -r key _ val; do
      if [ "$key" = "$target_key" ]; then
        echo "$val"
        return 0
      fi
    done < "$gcp_config_file"
  fi
  return 1
}

#######################################
# GCP: Update Google Cloud CLI tools
#######################################
gcl-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo "Checking for Google Cloud CLI updates..."
  if command -v apt-get > /dev/null && dpkg -l | grep -q "google-cloud-cli"; then
    sudo apt-get update && sudo apt-get install --only-upgrade google-cloud-cli
  else
    gcloud components update
  fi
}

#######################################
# GCP: Print an active gcloud configuration property
# Usage: gcl-get <project|project-number|region|user|zone>
#######################################
gcl-get() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  case "$1" in
    project) __get_gcp_config_val "project" ;;
    project-number)
      local project_id
      project_id=$(__get_gcp_config_val "project")
      [ -n "$project_id" ] && gcloud projects describe "$project_id" --format="value(projectNumber)"
      ;;
    region) __get_gcp_config_val "region" ;;
    zone) __get_gcp_config_val "zone" ;;
    user) __get_gcp_config_val "account" ;;
    *)
      echo "Usage: gcl-get <project|project-number|region|user|zone>" >&2
      return 1
      ;;
  esac
}

#######################################
# GCP: Print active user account (shortcut for `gcl-get user`)
#######################################
gcl-get-user() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get user
}

#######################################
# GCP: Print active project ID (shortcut for `gcl-get project`)
#######################################
gcl-get-project() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get project
}

#######################################
# GCP: Print active compute region (shortcut for `gcl-get region`)
#######################################
gcl-get-region() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get region
}

#######################################
# GCP: Print active compute zone (shortcut for `gcl-get zone`)
#######################################
gcl-get-zone() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get zone
}

#######################################
# GCP: Print active project Number, API call required (shortcut for `gcl-get project-number`)
#######################################
gcl-get-project-number() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcl-get project-number
}

#######################################
# GCP: List active configuration properties
# Arguments:
#   $@ - (Optional) Additional arguments passed directly to 'gcloud config list'
#######################################
gcl-config() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud config list "$@"
}

#######################################
# GCP: List org policies for a project
# Usage: gcl-org-policies [-p <project>]
# Options:
#   -p, --project <id>   Project to inspect (default: the active gcloud project)
#######################################
gcl-org-policies() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local project_id=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -p | --project)
        project_id="${2:-}"
        shift
        ;;
      *)
        echo "Usage: gcl-org-policies [-p <project>]" >&2
        return 1
        ;;
    esac
    shift
  done
  [ -z "$project_id" ] && project_id=$(gcl-get-project)

  [ -n "$project_id" ] && gcloud alpha resource-manager org-policies list --project="$project_id" --quiet
}

#######################################
# GCP: Login to user & application default
#######################################
gcp-login() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud auth login && gcloud auth application-default login
}

GCL_AUTH_EXIT_NO_ACCOUNT=1
GCL_AUTH_EXIT_REAUTH=2
GCL_AUTH_EXIT_NO_GCLOUD=3
GCL_AUTH_EXIT_CHECK_FAILED=4
GCL_SA_EMAIL_REGEX='^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.gserviceaccount\.com$'
GCL_SA_KEY_TYPE="service_account"

#######################################
# GCP: Check whether the active gcloud account has a usable token. Unlike
# 'gcloud auth list' this detects accounts that need re-authentication.
# Usage: gcl-auth-check [-q|--quiet]
# Options:
#   -q, --quiet   Print nothing, report through the exit code only
#   -h, --help    Show this help menu
# Returns:
#   0 token valid, 1 no active account, 2 re-authentication required,
#   3 gcloud not installed, 4 token check failed for another reason
# Outputs:
#   One status line (and the remedy on failure) unless --quiet
#######################################
gcl-auth-check() {
  local quiet=false
  case "${1:-}" in
    -h | --help)
      mt-help "${FUNCNAME[0]}"
      return 0
      ;;
    -q | --quiet) quiet=true ;;
  esac

  local account err_output rc=0
  if ! command -v gcloud > /dev/null 2>&1; then
    [ "$quiet" = true ] || echo -e "${CB_RED}🚨 gcloud is not installed.${C_RESET}"
    return "$GCL_AUTH_EXIT_NO_GCLOUD"
  fi

  account=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2> /dev/null)
  if [ -z "$account" ]; then
    [ "$quiet" = true ] || echo -e "${CB_RED}🚨 No active gcloud account. Run 'gcp-login'.${C_RESET}"
    return "$GCL_AUTH_EXIT_NO_ACCOUNT"
  fi

  err_output=$(CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud auth print-access-token 2>&1 > /dev/null) || rc=$?
  if [ "$rc" -eq 0 ]; then
    [ "$quiet" = true ] || echo -e "${CB_GREEN}✅ gcloud token for ${account} is valid.${C_RESET}"
    return 0
  fi

  if [[ "$err_output" == *[Rr]eauth* || "$err_output" == *invalid_grant* ]]; then
    [ "$quiet" = true ] || echo -e "${CB_YELLOW}⚠️  ${account} needs re-authentication. Run 'gcp-login'.${C_RESET}"
    return "$GCL_AUTH_EXIT_REAUTH"
  fi
  [ "$quiet" = true ] || echo -e "${CB_RED}🚨 Token check failed for ${account}: ${err_output}${C_RESET}"
  return "$GCL_AUTH_EXIT_CHECK_FAILED"
}

#######################################
# GCP: Login to application default only
#######################################
gcp-login-adc() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  gcloud auth application-default login
}

#######################################
# GCP: Switch active project
# Arguments:
#   $1 - (Optional) <project_id> to switch to.
#        Pass '-ls' to list available projects.
#        If left blank, opens an interactive fzf menu.
#######################################
gcp-set-project() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [[ "$1" == "-ls" ]]; then
    gcloud projects list --format="table(projectId,name,projectNumber)"
    return 0
  fi

  local project="$1"

  if [ -z "$project" ]; then
    project=$(gcloud projects list --format="value(projectId)" | fzf --prompt="Select GCP Project > ")
    if [ -z "$project" ]; then
      echo "⚠️ Project selection cancelled."
      return 0
    fi
  fi

  gcloud config set project "$project"
}

#######################################
# GCP: Export PROJECT_ID and PROJECT_NUMBER env vars to shell
# Arguments:
#   $1 - (Optional) <project_id> to export.
#        Pass '-ls' to list available projects.
#        If left blank, opens an interactive fzf menu.
#######################################
gcl-export-vars() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [[ "$1" == "-ls" ]]; then
    gcloud projects list --format="table(projectId,name,projectNumber)"
    return 0
  fi

  local target_project="$1"

  if [ -z "$target_project" ]; then
    target_project=$(gcloud projects list --format="value(projectId)" | fzf --prompt="Select GCP Project to Export > ")
    if [ -z "$target_project" ]; then
      echo "⚠️ Project selection cancelled."
      return 0
    fi
  fi

  export PROJECT_ID="$target_project"

  if [ -n "$PROJECT_ID" ]; then
    export PROJECT_NUMBER
    PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
    echo "✅ Exported PROJECT_ID=${PROJECT_ID} and PROJECT_NUMBER=${PROJECT_NUMBER}"
  else
    echo "🚨 Error: Could not determine active project ID."
  fi
}

_gcp_set_project_completions() {
  mapfile -t COMPREPLY < <(compgen -W "$(gcloud projects list --format="value(projectId)" 2> /dev/null)" -- "${COMP_WORDS[COMP_CWORD]}")
}
complete -F _gcp_set_project_completions gcp-set-project gcpp gcl-export-vars

#######################################
# GCP: Run a command as a service account without touching the active gcloud
# configuration. The command runs in a subshell (framework functions such as
# gcl-bq-query still work) with the identity set through environment variables
# only; a --key-file is activated inside a throwaway CLOUDSDK_CONFIG that is
# removed on every exit path. This does NOT enforce read-only: the service
# account's roles are the only control. --impersonate is preferred (no key);
# it covers gcloud, not client libraries or application-default credentials.
# Usage: gcl-as-sa (--impersonate <sa-email> | --key-file <path>) [-p <project>] -- <command> [args...]
# Options:
#   --impersonate <email>   Impersonate this service account (needs roles/iam.serviceAccountTokenCreator)
#   --key-file <path>       Use this service-account key file (never printed)
#   -p, --project <id>      Project for the command (CLOUDSDK_CORE_PROJECT)
#   -h, --help              Show this help menu
# Returns:
#   The command's exit code; 1 on bad usage, an invalid key or failed activation
# Outputs:
#   The command's output; "Running as <email>" on stderr
# Example:
#   gcl-as-sa --impersonate ro-sa@proj.iam.gserviceaccount.com -p proj -- gcl-bq-query "SELECT 1"
#######################################
gcl-as-sa() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local impersonate="" key_file="" project=""
  local -a command=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --impersonate)
        impersonate="${2:-}"
        shift
        ;;
      --key-file)
        key_file="${2:-}"
        shift
        ;;
      -p | --project)
        project="${2:-}"
        shift
        ;;
      --)
        shift
        command=("$@")
        break
        ;;
      *)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
    esac
    shift
  done

  local usage="Usage: gcl-as-sa (--impersonate <sa-email> | --key-file <path>) [-p <project>] -- <command> [args...]"
  if [ "${#command[@]}" -eq 0 ] || { [ -n "$impersonate" ] && [ -n "$key_file" ]; } || { [ -z "$impersonate" ] && [ -z "$key_file" ]; }; then
    echo "$usage" >&2
    return 1
  fi
  if [ -n "$project" ] && [[ ! "$project" =~ $GCL_PROJECT_ID_REGEX ]]; then
    echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
    return 1
  fi

  local identity="$impersonate"
  if [ -n "$impersonate" ] && [[ ! "$impersonate" =~ $GCL_SA_EMAIL_REGEX ]]; then
    echo -e "${CB_RED}❌ --impersonate needs a service account email.${C_RESET}" >&2
    return 1
  fi
  if [ -n "$key_file" ]; then
    if [ ! -f "$key_file" ] || [ "$(jq -r '.type // empty' "$key_file" 2> /dev/null)" != "$GCL_SA_KEY_TYPE" ]; then
      echo -e "${CB_RED}❌ ${key_file} is not a service-account key file.${C_RESET}" >&2
      return 1
    fi
    identity=$(jq -r '.client_email // "unknown"' "$key_file")
    local mode
    mode=$(stat -c %a "$key_file" 2> /dev/null || stat -f %Lp "$key_file" 2> /dev/null)
    if [[ "$mode" =~ ^[0-7]+$ ]] && [ $((8#$mode & 8#077)) -ne 0 ]; then
      echo -e "${CB_YELLOW}⚠️  ${key_file} is readable by other users (mode ${mode}); run chmod 600.${C_RESET}" >&2
    fi
  fi

  echo -e "${CB_YELLOW}🔐 Running as ${identity}${C_RESET}" >&2
  local config_dir="" rc=0
  [ -n "$key_file" ] && config_dir=$(mktemp -d)
  (
    [ -n "$config_dir" ] && trap 'rm -rf "$config_dir"' EXIT
    unset CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT GOOGLE_APPLICATION_CREDENTIALS
    [ -n "$project" ] && export CLOUDSDK_CORE_PROJECT="$project"
    if [ -n "$impersonate" ]; then
      export CLOUDSDK_AUTH_IMPERSONATE_SERVICE_ACCOUNT="$impersonate"
    else
      export CLOUDSDK_CONFIG="$config_dir" GOOGLE_APPLICATION_CREDENTIALS="$key_file"
      activation_error=$(gcloud auth activate-service-account --key-file="$key_file" --quiet 2>&1 > /dev/null) || {
        echo -e "${CB_RED}🚨 Could not activate the key file:${C_RESET} ${activation_error}" >&2
        exit 1
      }
    fi
    "${command[@]}"
  ) || rc=$?
  [ -n "$config_dir" ] && rm -rf "$config_dir"
  return "$rc"
}
