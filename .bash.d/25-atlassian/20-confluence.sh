# shellcheck shell=bash
# ------------------------------------------
# Version Control: Confluence Cloud Read Helpers
# ------------------------------------------
# ~/.bash.d/25-atlassian/20-confluence.sh

CONFLUENCE_GATEWAY_HOST="https://api.atlassian.com/ex/confluence"
CONFLUENCE_PAGE_LIMIT=50
CONFLUENCE_SEARCH_LIMIT=25
CONFLUENCE_MAX_PAGES=20
CONFLUENCE_JQ_DIR="$HOME/.bash.d/lib/jq"
CONFLUENCE_TEXT_SCRIPT="$HOME/.bash.d/lib/python/confluence_text.py"
__MT_CONFLUENCE_GATEWAY_URL=""

#######################################
# Confluence: Resolve the scoped-token gateway base URL for CONFLUENCE_SITE
# into __MT_CONFLUENCE_GATEWAY_URL, looking up the site's cloud ID once per
# shell. Scoped tokens return 401 against the site URL, so every request goes
# through this gateway. Must be called directly (not via command substitution)
# so the cached value survives in the calling shell.
# Returns:
#   0 on success, 1 if CONFLUENCE_SITE is unset or the cloud ID lookup fails
# Globals:
#   CONFLUENCE_SITE, __MT_CONFLUENCE_GATEWAY_URL (written)
#######################################
__mt_conf_gateway() {
  [ -n "$__MT_CONFLUENCE_GATEWAY_URL" ] && return 0
  if [ -z "${CONFLUENCE_SITE:-}" ]; then
    echo -e "${CB_RED}🚨 CONFLUENCE_SITE is not set (e.g. yourorg.atlassian.net). Add it to ~/secrets/secrets.sh.${C_RESET}" >&2
    return 1
  fi

  local tenant cloud_id
  tenant=$(mt-http --raw "https://${CONFLUENCE_SITE}/_edge/tenant_info") || return 1
  cloud_id=$(jq -r '.cloudId // empty' <<< "$tenant")
  if [ -z "$cloud_id" ]; then
    echo -e "${CB_RED}🚨 Could not resolve the cloud ID for ${CONFLUENCE_SITE}.${C_RESET}" >&2
    return 1
  fi
  __MT_CONFLUENCE_GATEWAY_URL="${CONFLUENCE_GATEWAY_HOST}/${cloud_id}"
}

#######################################
# Confluence: Check credentials and resolve the gateway in the caller's shell
# so later requests (made inside command substitutions) reuse the cached URL.
# Returns:
#   0 when ready, 1 when credentials or CONFLUENCE_SITE are missing or the lookup fails
#######################################
__mt_conf_prepare() {
  if [ -z "${CONFLUENCE_EMAIL:-}" ] || [ -z "${CONFLUENCE_API_TOKEN:-}" ]; then
    echo -e "${CB_RED}🚨 CONFLUENCE_EMAIL / CONFLUENCE_API_TOKEN are not set in ~/secrets/secrets.sh.${C_RESET}" >&2
    return 1
  fi
  __mt_conf_gateway
}

#######################################
# Confluence: Call the Confluence Cloud API through mt-http with the stored
# credentials, and record the secret as used on success.
# Arguments:
#   $1 - Path beginning with /wiki/, or a full https:// URL
#   $@ - Further mt-http options (e.g. --raw, -q key=value)
# Returns:
#   mt-http's exit code; 1 when credentials or CONFLUENCE_SITE are missing
# Globals:
#   CONFLUENCE_EMAIL, CONFLUENCE_API_TOKEN, SECRETS_MANAGER
#######################################
__mt_conf_api() {
  local target="$1"
  shift
  if [ -z "${CONFLUENCE_EMAIL:-}" ] || [ -z "${CONFLUENCE_API_TOKEN:-}" ]; then
    echo -e "${CB_RED}🚨 CONFLUENCE_EMAIL / CONFLUENCE_API_TOKEN are not set in ~/secrets/secrets.sh.${C_RESET}" >&2
    return 1
  fi
  if [[ "$target" != https://* ]]; then
    __mt_conf_gateway || return 1
    target="${__MT_CONFLUENCE_GATEWAY_URL}${target}"
  fi

  local rc=0
  mt-http -u "${CONFLUENCE_EMAIL}:${CONFLUENCE_API_TOKEN}" "$@" "$target" || rc=$?
  [ "$rc" -eq 0 ] && python3 "$SECRETS_MANAGER" touch "CONFLUENCE_API_TOKEN" 2> /dev/null
  return "$rc"
}

#######################################
# Confluence: Extract a numeric page or folder ID from an ID or a Confluence URL
# Arguments:
#   $1 - ID or URL containing /pages/<id> or /folder/<id>
# Returns:
#   0 and the ID on stdout, 1 if none can be found
#######################################
__mt_conf_extract_id() {
  local input="$1"
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    echo "$input"
  elif [[ "$input" =~ /(pages|folder)/([0-9]+) ]]; then
    echo "${BASH_REMATCH[2]}"
  else
    echo -e "${CB_RED}🚨 '${input}' is not a Confluence ID or page/folder URL.${C_RESET}" >&2
    return 1
  fi
}

#######################################
# Confluence: Read a page as plain text (or raw storage-format HTML)
# Usage: conf-get [--storage] <page-id|page-url>
# Arguments:
#   <page-id|page-url>   Numeric page ID or a URL containing /pages/<id>
# Options:
#   --storage            Print the raw storage-format body instead of text
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on bad usage or missing configuration, mt-http's code on API failure
# Outputs:
#   Page title followed by the body on stdout, with terminal control
#   characters removed
#######################################
conf-get() {
  local raw_storage=false target=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      --storage) raw_storage=true ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) target="$1" ;;
    esac
    shift
  done
  if [ -z "$target" ]; then
    echo "Usage: conf-get [--storage] <page-id|page-url>" >&2
    return 1
  fi

  local page_id page title body
  page_id=$(__mt_conf_extract_id "$target") || return 1
  __mt_conf_prepare || return 1
  page=$(__mt_conf_api "/wiki/api/v2/pages/${page_id}" --raw -q "body-format=storage") || return $?
  title=$(jq -r '.title' <<< "$page")
  body=$(jq -r '.body.storage.value // ""' <<< "$page")

  echo "# ${title}" | __mt_strip_control_chars
  echo
  if [ "$raw_storage" = true ]; then
    __mt_strip_control_chars <<< "$body"
  else
    python3 "$CONFLUENCE_TEXT_SCRIPT" <<< "$body" | __mt_strip_control_chars
  fi
}

#######################################
# Confluence: List a folder's direct children (pages, folders, ...)
# Usage: conf-folder <folder-id|folder-url>
# Arguments:
#   <folder-id|folder-url>   Numeric folder ID or a URL containing /folder/<id>
# Options:
#   -h, --help               Show this help menu
# Returns:
#   0 on success, 1 on bad usage or missing configuration, mt-http's code on API failure
# Outputs:
#   One "type<TAB>id<TAB>title" line per child on stdout
#######################################
conf-folder() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [ -z "$1" ]; then
    echo "Usage: conf-folder <folder-id|folder-url>" >&2
    return 1
  fi

  local folder_id next page children="[]" pages=0
  folder_id=$(__mt_conf_extract_id "$1") || return 1
  __mt_conf_prepare || return 1
  next="/wiki/api/v2/folders/${folder_id}/direct-children?limit=${CONFLUENCE_PAGE_LIMIT}"

  while [ -n "$next" ] && [ "$pages" -lt "$CONFLUENCE_MAX_PAGES" ]; do
    page=$(__mt_conf_api "$next" --raw) || return $?
    children=$(jq -c --argjson more "$(jq -c '.results // []' <<< "$page")" '. + $more' <<< "$children")
    next=$(jq -r '._links.next // empty' <<< "$page")
    pages=$((pages + 1))
  done
  if [ -n "$next" ]; then
    echo -e "${CB_YELLOW}⚠️  Results truncated after ${CONFLUENCE_MAX_PAGES} pages.${C_RESET}" >&2
  fi
  jq -r -f "$CONFLUENCE_JQ_DIR/conf_children.jq" <<< "$children" | __mt_strip_control_chars
}

#######################################
# Confluence: Search with a text term or a raw CQL query
# Usage: conf-search [-s <space-key>] [--cql] <text|cql>
# Arguments:
#   <text|cql>           Text to search for, or a CQL query with --cql
# Options:
#   -s, --space <key>    Restrict a text search to one space
#   --cql                Treat the argument as a CQL query
#   -h, --help           Show this help menu
# Returns:
#   0 on success, 1 on bad usage or missing configuration, mt-http's code on API failure
# Outputs:
#   One "type<TAB>id<TAB>title<TAB>space" line per hit on stdout
#######################################
conf-search() {
  local space="" use_cql=false query=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -s | --space)
        space="${2:-}"
        shift
        ;;
      --cql) use_cql=true ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) query="$1" ;;
    esac
    shift
  done
  if [ -z "$query" ]; then
    echo "Usage: conf-search [-s <space-key>] [--cql] <text|cql>" >&2
    return 1
  fi

  local cql="$query" escaped
  if [ "$use_cql" = false ]; then
    escaped="${query//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    cql="text ~ \"${escaped}\""
    [ -n "$space" ] && cql="space = \"${space}\" AND ${cql}"
  fi

  local result
  __mt_conf_prepare || return 1
  result=$(__mt_conf_api "/wiki/rest/api/search" --raw -q "cql=${cql}" -q "limit=${CONFLUENCE_SEARCH_LIMIT}") || return $?
  jq -r -f "$CONFLUENCE_JQ_DIR/conf_search.jq" <<< "$result" | __mt_strip_control_chars
}
