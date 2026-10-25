# shellcheck shell=bash
# ------------------------------------------
# GCP: Read-Only Firestore Access
# ------------------------------------------
# ~/.bash.d/10-infra/35-gcp-firestore.sh

GCL_FIRESTORE_API="https://firestore.googleapis.com/v1/projects"
GCL_FIRESTORE_DEFAULT_DATABASE="(default)"
GCL_FIRESTORE_DEFAULT_LIMIT=100
GCL_FIRESTORE_QUERY_JQ="$HOME/.bash.d/lib/jq/firestore_structured_query.jq"
GCL_FIRESTORE_UNWRAP_JQ="$HOME/.bash.d/lib/jq/firestore_unwrap.jq"
GCL_FIRESTORE_DB_REGEX='^(\(default\)|[a-z][a-z0-9-]*)$'
GCL_FIRESTORE_PATH_REGEX='^[A-Za-z0-9_.@+=,~%-]+(/[A-Za-z0-9_.@+=,~%-]+)*$'
GCL_FIRESTORE_COLLECTION_REGEX='^[A-Za-z0-9_-]+$'
GCL_FIRESTORE_FIELD_REGEX='^[A-Za-z0-9_.-]+$'
GCL_FIRESTORE_WHERE_REGEX='^[^=!<>[:space:]]+(==|!=|<=|>=|<|>).*$'
GCL_FIRESTORE_ORDER_REGEX='^[A-Za-z0-9_.-]+(:desc|:asc)?$'

#######################################
# GCP: Check a Firestore document path: valid characters and no . or .. segment
# Arguments:
#   $1 - Path
# Returns:
#   0 if valid, 1 otherwise
#######################################
__mt_gcl_firestore_path_ok() {
  [[ "$1" =~ $GCL_FIRESTORE_PATH_REGEX ]] || return 1
  [[ "/$1/" != *"/./"* && "/$1/" != *"/../"* ]]
}

#######################################
# GCP: Build the JSON structuredQuery for gcl-firestore query/count
# Arguments:
#   $1 - Documents path (projects/<p>/databases/<db>/documents), $2 - collection
#   $3 - order-by ("" for none), $4 - limit ("" for none), $5 - 1 for all descendants
#   $6... - where expressions
# Outputs:
#   structuredQuery JSON
#######################################
__mt_gcl_firestore_query() {
  local documents_path="$1" collection="$2" order="$3" limit="$4" all_descendants="$5" where_json
  shift 5
  where_json=$(printf '%s\n' "$@" | jq -R . | jq -s 'map(select(. != ""))')
  jq -n -c --arg documents_path "$documents_path" --arg collection "$collection" --arg order "$order" \
    --argjson limit "${limit:-null}" --argjson all_descendants "$([ "$all_descendants" = "1" ] && echo true || echo false)" \
    --argjson where "$where_json" -f "$GCL_FIRESTORE_QUERY_JQ"
}

#######################################
# GCP: Read Firestore documents over REST (gcloud has no document reads).
# Read-only by construction: only GET, runQuery and runAggregationQuery are
# called. Needs roles/datastore.viewer.
# Usage: gcl-firestore get <doc-path> [--fields a,b.c] [-p <project>] [-d <database>]
#        gcl-firestore query|count (--collection <id> [--where '<field><op><value>']... [--order-by <field>[:desc]] [--limit <n>] [--all-descendants] | --json '<structuredQuery>'|@file) [--parent <doc-path>] [-p <project>] [-d <database>]
# Arguments:
#   <doc-path>                Document path, e.g. users/abc or users/abc/orders/1
# Options:
#   -p, --project <id>        Project (default: the active gcloud project)
#   -d, --database <name>     Database (default: (default))
#   --fields <a,b.c>          get: only these fields
#   --collection <id>         query/count: collection to query
#   --where '<f><op><v>'      query/count: filter; repeatable (ANDed). Operators == != < <= > >=. Values: integers,
#                             true/false/null, otherwise strings. Field __name__ matches the document ID.
#   --order-by <f>[:desc]     query: sort field
#   --limit <n>               query: maximum documents (default: 100); count: cap the count
#   --all-descendants         query/count: include subcollections with the same ID
#   --json <q>|@file          query/count: a raw structuredQuery instead of the builder options
#   --parent <doc-path>       query/count: run under this document (subcollections)
#   -h, --help                Show this help menu
# Returns:
#   0 on success, 1 on failure or bad usage, 5 on permission denied
# Outputs:
#   get/query: one JSON object per document with _id; count: a bare integer
# Example:
#   gcl-firestore count --collection devices --where '__name__>=a' --where '__name__<b' -p proj
#   gcl-firestore get users/abc --fields name,address.city -p proj
#######################################
gcl-firestore() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  local action="${1:-}" doc_path="" project="" database="$GCL_FIRESTORE_DEFAULT_DATABASE" fields="" collection="" order="" limit="" all_descendants="" raw_json="" parent=""
  local -a where=()
  shift
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
      -d | --database)
        database="${2:-}"
        shift
        ;;
      --fields)
        fields="${2:-}"
        shift
        ;;
      --collection)
        collection="${2:-}"
        shift
        ;;
      --where)
        where+=("${2:-}")
        shift
        ;;
      --order-by)
        order="${2:-}"
        shift
        ;;
      --limit)
        limit="${2:-}"
        shift
        ;;
      --all-descendants) all_descendants="1" ;;
      --json)
        raw_json="${2:-}"
        shift
        ;;
      --parent)
        parent="${2:-}"
        shift
        ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) doc_path="$1" ;;
    esac
    shift
  done

  local usage="Usage: gcl-firestore get <doc-path> | query|count --collection <id> [--where ...] | --json <q> [-p <project>] [-d <database>]"
  local item
  case "$action" in
    get)
      __mt_gcl_firestore_path_ok "$doc_path" || {
        echo "$usage" >&2
        return 1
      }
      ;;
    query | count)
      if [ -z "$collection" ] && [ -z "$raw_json" ]; then
        echo "$usage" >&2
        return 1
      fi
      if [ -n "$collection" ] && [ -n "$raw_json" ]; then
        echo -e "${CB_RED}❌ Use either --collection or --json, not both.${C_RESET}" >&2
        return 1
      fi
      [ -n "$collection" ] && [[ ! "$collection" =~ $GCL_FIRESTORE_COLLECTION_REGEX ]] && {
        echo -e "${CB_RED}❌ Invalid collection: ${collection}${C_RESET}" >&2
        return 1
      }
      for item in "${where[@]}"; do
        [[ "$item" =~ $GCL_FIRESTORE_WHERE_REGEX ]] || {
          echo -e "${CB_RED}❌ Invalid --where (use <field><op><value>): ${item}${C_RESET}" >&2
          return 1
        }
      done
      [ -n "$order" ] && [[ ! "$order" =~ $GCL_FIRESTORE_ORDER_REGEX ]] && {
        echo -e "${CB_RED}❌ Invalid --order-by (use <field>[:desc]): ${order}${C_RESET}" >&2
        return 1
      }
      [ -n "$limit" ] && [[ ! "$limit" =~ ^[1-9][0-9]*$ ]] && {
        echo -e "${CB_RED}❌ --limit must be a positive number.${C_RESET}" >&2
        return 1
      }
      [ -n "$parent" ] && ! __mt_gcl_firestore_path_ok "$parent" && {
        echo -e "${CB_RED}❌ Invalid --parent: ${parent}${C_RESET}" >&2
        return 1
      }
      ;;
    *)
      echo "$usage" >&2
      return 1
      ;;
  esac
  [ -n "$project" ] && [[ ! "$project" =~ $GCL_PROJECT_ID_REGEX ]] && {
    echo -e "${CB_RED}❌ Invalid project: ${project}${C_RESET}" >&2
    return 1
  }
  [[ "$database" =~ $GCL_FIRESTORE_DB_REGEX ]] || {
    echo -e "${CB_RED}❌ Invalid database: ${database}${C_RESET}" >&2
    return 1
  }
  if [ -n "$fields" ]; then
    local -a field_list
    IFS=, read -ra field_list <<< "$fields"
    for item in "${field_list[@]}"; do
      [[ "$item" =~ $GCL_FIRESTORE_FIELD_REGEX ]] || {
        echo -e "${CB_RED}❌ Invalid --fields entry: ${item}${C_RESET}" >&2
        return 1
      }
    done
  fi
  if [ "${raw_json:0:1}" = "@" ]; then
    [ -r "${raw_json:1}" ] || {
      echo -e "${CB_RED}❌ Cannot read ${raw_json:1}.${C_RESET}" >&2
      return 1
    }
    raw_json=$(< "${raw_json:1}")
  fi
  if [ -n "$raw_json" ] && ! jq -e . > /dev/null 2>&1 <<< "$raw_json"; then
    echo -e "${CB_RED}❌ --json is not valid JSON.${C_RESET}" >&2
    return 1
  fi

  __mt_gcl_preflight || return $?
  [ -z "$project" ] && project=$(gcl-get-project)
  local documents_path="projects/${project}/databases/${database}/documents"
  local base="${GCL_FIRESTORE_API}/${project}/databases/${database}/documents"

  local response
  if [ "$action" = "get" ]; then
    local -a mask=()
    for item in "${field_list[@]}"; do
      mask+=(-q "mask.fieldPaths=${item}")
    done
    response=$(__mt_gcl_rest "reading ${doc_path} in ${project}" GET "${base}/${doc_path}" "" "${mask[@]}") || return $?
    jq -c -f "$GCL_FIRESTORE_UNWRAP_JQ" <<< "$response" | __mt_strip_control_chars
    return 0
  fi

  local structured_query="$raw_json"
  if [ -z "$structured_query" ]; then
    [ "$action" = "query" ] && [ -z "$limit" ] && limit="$GCL_FIRESTORE_DEFAULT_LIMIT"
    structured_query=$(__mt_gcl_firestore_query "$documents_path" "$collection" "$order" "$limit" "$all_descendants" "${where[@]}") || {
      echo -e "${CB_RED}❌ Could not build the query.${C_RESET}" >&2
      return 1
    }
  fi
  local url="${base}${parent:+/${parent}}" body
  if [ "$action" = "query" ]; then
    body=$(jq -c --argjson query "$structured_query" -n '{structuredQuery: $query}')
    response=$(__mt_gcl_rest "querying Firestore in ${project}" POST "${url}:runQuery" "$body") || return $?
    jq -c -f "$GCL_FIRESTORE_UNWRAP_JQ" <<< "$response" | __mt_strip_control_chars
    return 0
  fi
  body=$(jq -c --argjson query "$structured_query" -n '{structuredAggregationQuery: {structuredQuery: $query, aggregations: [{alias: "count", count: {}}]}}')
  response=$(__mt_gcl_rest "counting Firestore documents in ${project}" POST "${url}:runAggregationQuery" "$body") || return $?
  jq -r '[.[]? | .result.aggregateFields.count.integerValue | select(. != null)] | (.[0] // "0")' <<< "$response"
}
