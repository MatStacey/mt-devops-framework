# shellcheck shell=bash
# ------------------------------------------
# Version Control: Bitbucket Pipelines, Environments and Variables
# ------------------------------------------
# ~/.bash.d/20-vcs/63-bitbucket-ci.sh

BITBUCKET_PIPELINES_DEFAULT_COUNT=10
BITBUCKET_LOG_DEFAULT_TAIL=100
BITBUCKET_PR_TITLE_MAX=250
BITBUCKET_ENV_TYPES=("Test" "Staging" "Production")
BITBUCKET_REDACT_SED="$HOME/.bash.d/lib/sed/redact_log.sed"

#######################################
# Bitbucket: Percent-encode the braces of a UUID for use in an API path
# Arguments:
#   $1 - UUID, with or without braces
# Outputs:
#   Encoded UUID on stdout
#######################################
__mt_bb_encode_uuid() {
  local uuid="$1"
  uuid="${uuid//\{/%7B}"
  echo "${uuid//\}/%7D}"
}

#######################################
# Bitbucket: Resolve a pipeline build number or UUID to an encoded UUID
# Arguments:
#   $1 - workspace/repo, $2 - build number or UUID
# Returns:
#   0 and the encoded UUID on stdout, 1 if no such pipeline exists
#######################################
__mt_bb_resolve_pipeline() {
  local repo="$1" ref="$2" found
  if [[ ! "$ref" =~ ^[0-9]+$ ]]; then
    __mt_bb_encode_uuid "$ref"
    return 0
  fi
  found=$(__mt_bb_api "repositories/${repo}/pipelines/${ref}" --raw) || return $?
  found=$(jq -r '.uuid // empty' <<< "$found")
  if [ -z "$found" ]; then
    echo -e "${CB_RED}🚨 No pipeline with build number ${ref}.${C_RESET}" >&2
    return 1
  fi
  __mt_bb_encode_uuid "$found"
}

#######################################
# Bitbucket: Print a JSON request body to a private temp file, so secret
# values never appear on a command line. The caller removes the directory.
# Arguments:
#   $1 - JSON text
# Outputs:
#   Path of the body file on stdout
#######################################
__mt_bb_body_file() {
  local dir
  dir=$(mktemp -d) || return 1
  printf '%s' "$1" > "$dir/body.json"
  echo "$dir/body.json"
}

#######################################
# Bitbucket: List recent pipeline runs, show a run's steps, or print a
# step's log tail with credentials redacted
# Usage: bb-pipelines [-r <workspace/repo>] [-n <count>] [<build#|uuid> [--log <step#|uuid>] [--tail <lines>]]
# Arguments:
#   <build#|uuid>        Pipeline build number or UUID (omit to list recent runs)
# Options:
#   -r, --repo <w/r>     Repository (default: the current directory's Bitbucket remote)
#   -n, --count <n>      Number of runs to list (default: 10)
#   --log <step>         Print the log of a step, by 1-based number or UUID
#   --tail <lines>       Lines of log to keep (default: 100)
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on bad usage or missing credentials, mt-http's code on API failure
# Outputs:
#   Runs or steps as tab-separated lines; logs as redacted text
#######################################
bb-pipelines() {
  local repo="" count="$BITBUCKET_PIPELINES_DEFAULT_COUNT" ref="" log_step="" tail_lines="$BITBUCKET_LOG_DEFAULT_TAIL"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -r | --repo)
        repo="${2:-}"
        shift
        ;;
      -n | --count)
        count="${2:-}"
        shift
        ;;
      --log)
        log_step="${2:-}"
        shift
        ;;
      --tail)
        tail_lines="${2:-}"
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) ref="$1" ;;
    esac
    shift
  done
  if [[ ! "$count" =~ ^[0-9]+$ ]] || [[ ! "$tail_lines" =~ ^[0-9]+$ ]]; then
    echo -e "${CB_RED}❌ --count and --tail must be whole numbers.${C_RESET}" >&2
    return 1
  fi
  if [ -n "$log_step" ] && [ -z "$ref" ]; then
    echo "Usage: bb-pipelines [-r <w/r>] <build#|uuid> --log <step#|uuid>" >&2
    return 1
  fi
  repo=$(__mt_bb_resolve_repo "$repo") || return 1

  local data
  if [ -z "$ref" ]; then
    data=$(__mt_bb_api "repositories/${repo}/pipelines/" --raw -q "pagelen=${count}" -q "sort=-created_on") || return $?
    jq -r -f "$BITBUCKET_JQ_DIR/bb_pipelines_list.jq" <<< "$data" | __mt_strip_control_chars
    return 0
  fi

  local pipeline_uuid steps
  pipeline_uuid=$(__mt_bb_resolve_pipeline "$repo" "$ref") || return $?
  steps=$(__mt_bb_collect "repositories/${repo}/pipelines/${pipeline_uuid}/steps/") || return $?

  if [ "$steps" = "[]" ]; then
    data=$(__mt_bb_api "repositories/${repo}/pipelines/${pipeline_uuid}" --raw) || return $?
    jq -r -f "$BITBUCKET_JQ_DIR/bb_pipeline_no_steps.jq" <<< "$data" | __mt_strip_control_chars
    return 0
  fi
  if [ -z "$log_step" ]; then
    jq -r -f "$BITBUCKET_JQ_DIR/bb_pipeline_steps.jq" <<< "$steps" | __mt_strip_control_chars
    return 0
  fi

  local step_uuid="$log_step"
  if [[ "$log_step" =~ ^[0-9]+$ ]]; then
    step_uuid=$(jq -r --argjson n "$log_step" '.[$n - 1].uuid // empty' <<< "$steps")
    if [ -z "$step_uuid" ]; then
      echo -e "${CB_RED}🚨 Pipeline has no step number ${log_step}.${C_RESET}" >&2
      return 1
    fi
  fi
  step_uuid=$(__mt_bb_encode_uuid "$step_uuid")
  data=$(__mt_bb_api "repositories/${repo}/pipelines/${pipeline_uuid}/steps/${step_uuid}/log" --raw) || return $?
  tail -n "$tail_lines" <<< "$data" | sed -E -f "$BITBUCKET_REDACT_SED" | __mt_strip_control_chars
}

#######################################
# Bitbucket: Print the encoded UUID of a deployment environment by name
# Arguments:
#   $1 - workspace/repo, $2 - environment name (case-insensitive)
# Returns:
#   0 and the encoded UUID on stdout, 1 if no environment has that name
#######################################
__mt_bb_environment_uuid() {
  local repo="$1" name="$2" envs uuid
  envs=$(__mt_bb_collect "repositories/${repo}/environments/") || return $?
  uuid=$(jq -r --arg n "$name" '[.[] | select(.name | ascii_downcase == ($n | ascii_downcase))][0].uuid // empty' <<< "$envs")
  if [ -z "$uuid" ]; then
    echo -e "${CB_RED}🚨 No environment named '${name}'.${C_RESET}" >&2
    return 1
  fi
  __mt_bb_encode_uuid "$uuid"
}

#######################################
# Bitbucket: List or create deployment environments
# Usage: bb-env [-r <workspace/repo>] list | create <name> [--type Test|Staging|Production]
# Arguments:
#   list                 List environments
#   create <name>        Create an environment
# Options:
#   -r, --repo <w/r>     Repository (default: the current directory's Bitbucket remote)
#   --type <type>        Environment type for create: Test, Staging or Production (default: Test)
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on bad usage or missing credentials, mt-http's code on API failure
# Outputs:
#   "name<TAB>type<TAB>uuid" per environment for list
#######################################
bb-env() {
  local repo="" action="" env_name="" env_type="${BITBUCKET_ENV_TYPES[0]}"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -r | --repo)
        repo="${2:-}"
        shift
        ;;
      --type)
        env_type="${2:-}"
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      list | create)
        if [ -z "$action" ]; then action="$1"; else env_name="$1"; fi
        ;;
      *) env_name="$1" ;;
    esac
    shift
  done

  local valid_type=false candidate
  for candidate in "${BITBUCKET_ENV_TYPES[@]}"; do
    [ "$candidate" = "$env_type" ] && valid_type=true
  done
  if [ "$valid_type" = false ]; then
    echo -e "${CB_RED}❌ --type must be one of: ${BITBUCKET_ENV_TYPES[*]}${C_RESET}" >&2
    return 1
  fi
  if [ "$action" != "list" ] && { [ "$action" != "create" ] || [ -z "$env_name" ]; }; then
    echo "Usage: bb-env [-r <w/r>] list | create <name> [--type Test|Staging|Production]" >&2
    return 1
  fi
  repo=$(__mt_bb_resolve_repo "$repo") || return 1

  local data
  if [ "$action" = "list" ]; then
    data=$(__mt_bb_collect "repositories/${repo}/environments/") || return $?
    jq -r '.[] | "\(.name)\t\(.environment_type.name // "-")\t\(.uuid)"' <<< "$data" | __mt_strip_control_chars
    return 0
  fi

  local body body_file rc=0
  body=$(jq -nc --arg name "$env_name" --arg type "$env_type" '{type: "deployment_environment", name: $name, environment_type: {type: "deployment_environment_type", name: $type}}')
  body_file=$(__mt_bb_body_file "$body") || return 1
  __mt_bb_api "repositories/${repo}/environments/" -H "Content-Type: application/json" -d "@${body_file}" --raw > /dev/null || rc=$?
  rm -rf "$(dirname "$body_file")"
  [ "$rc" -eq 0 ] && echo -e "${CB_GREEN}✅ Created ${env_type} environment '${env_name}'.${C_RESET}"
  return "$rc"
}

#######################################
# Bitbucket: List or add pipeline variables, repository-wide or per environment.
# Secured values are never shown, and new values are read from stdin or a
# silent prompt -- never taken from the command line.
# Usage: bb-var [-r <workspace/repo>] [-e <environment>] list | add [--secured] <KEY>
# Arguments:
#   list                 List variables
#   add <KEY>            Add a variable; the value is read from stdin, or prompted
# Options:
#   -r, --repo <w/r>     Repository (default: the current directory's Bitbucket remote)
#   -e, --env <name>     Use the variables of this deployment environment
#   --secured            Mark the new variable as secured
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on bad usage or missing credentials, mt-http's code on API failure
# Outputs:
#   "key<TAB>value<TAB>uuid" per variable for list; secured values print as (secured)
#######################################
bb-var() {
  local repo="" env_name="" action="" key="" secured=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -r | --repo)
        repo="${2:-}"
        shift
        ;;
      -e | --env)
        env_name="${2:-}"
        shift
        ;;
      --secured) secured=true ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      list | add)
        if [ -z "$action" ]; then action="$1"; else key="$1"; fi
        ;;
      *) key="$1" ;;
    esac
    shift
  done
  if [ "$action" != "list" ] && { [ "$action" != "add" ] || [ -z "$key" ]; }; then
    echo "Usage: bb-var [-r <w/r>] [-e <env>] list | add [--secured] <KEY>" >&2
    return 1
  fi
  repo=$(__mt_bb_resolve_repo "$repo") || return 1

  local variables_path="repositories/${repo}/pipelines_config/variables"
  if [ -n "$env_name" ]; then
    local env_uuid
    env_uuid=$(__mt_bb_environment_uuid "$repo" "$env_name") || return $?
    variables_path="repositories/${repo}/deployments_config/environments/${env_uuid}/variables"
  fi

  local data
  if [ "$action" = "list" ]; then
    data=$(__mt_bb_collect "${variables_path}") || return $?
    jq -r '.[] | "\(.key)\t\(if .secured then "(secured)" else (.value // "") end)\t\(.uuid)"' <<< "$data" | __mt_strip_control_chars
    return 0
  fi

  local value
  if [ -t 0 ]; then
    read -r -s -p "Value for ${key}: " value < /dev/tty
    echo
  else
    IFS= read -r value
  fi

  local body body_file rc=0
  body=$(jq -nc --arg key "$key" --arg value "$value" --argjson secured "$secured" '{key: $key, value: $value, secured: $secured}')
  body_file=$(__mt_bb_body_file "$body") || return 1
  __mt_bb_api "${variables_path}" -H "Content-Type: application/json" -d "@${body_file}" --raw > /dev/null || rc=$?
  rm -rf "$(dirname "$body_file")"
  [ "$rc" -eq 0 ] && echo -e "${CB_GREEN}✅ Added variable ${key}${C_RESET}"
  return "$rc"
}

#######################################
# Bitbucket: Create a pull request through the API, or report the existing
# open one for the same branches.
# Arguments:
#   $1 - workspace/repo, $2 - source branch, $3 - destination branch,
#   $4 - title (empty = last commit subject), $5 - description
# Returns:
#   0 and the PR URL on stdout when created or already open, 1 on any failure
#   (callers fall back to opening the browser)
#######################################
__mt_bb_create_pull_request() {
  local repo="$1" source="$2" dest="$3" title="$4" description="$5"
  [ -z "$title" ] && title=$(git log -1 --format=%s)
  title="${title:0:BITBUCKET_PR_TITLE_MAX}"

  local existing url
  existing=$(__mt_bb_api "repositories/${repo}/pullrequests" --raw \
    -q "q=source.branch.name=\"${source}\" AND destination.branch.name=\"${dest}\" AND state=\"OPEN\"") || return 1
  url=$(jq -r '.values[0].links.html.href // empty' <<< "$existing")
  if [ -n "$url" ]; then
    echo "$url"
    return 0
  fi

  local body body_file created rc=0
  body=$(jq -nc --arg title "$title" --arg desc "$description" --arg src "$source" --arg dst "$dest" \
    '{title: $title, description: $desc, source: {branch: {name: $src}}, destination: {branch: {name: $dst}}}')
  body_file=$(__mt_bb_body_file "$body") || return 1
  created=$(__mt_bb_api "repositories/${repo}/pullrequests" -H "Content-Type: application/json" -d "@${body_file}" --raw) || rc=$?
  rm -rf "$(dirname "$body_file")"
  [ "$rc" -ne 0 ] && return 1
  jq -r -f "$BITBUCKET_JQ_DIR/bb_pr_created.jq" <<< "$created"
}
