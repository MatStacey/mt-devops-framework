# shellcheck shell=bash
# ------------------------------------------
# Version Control: Confluence Cloud Read and Write Helpers
# ------------------------------------------
# ~/.bash.d/25-atlassian/20-confluence.sh

CONFLUENCE_GATEWAY_HOST="https://api.atlassian.com/ex/confluence"
CONFLUENCE_PAGE_LIMIT=50
CONFLUENCE_SEARCH_LIMIT=25
CONFLUENCE_MAX_PAGES=20
CONFLUENCE_EXIT_STALE=6
CONFLUENCE_EXIT_RENDER_ERRORS=7
CONFLUENCE_DEFAULT_VERSION_MESSAGE="Updated with conf-put"
CONFLUENCE_RENDER_ERROR_PATTERNS=("wysiwyg-unknown-macro")
CONFLUENCE_PUT_USAGE="Usage: conf-put <page-id|page-url> (@<file> | -) [-m <message>] [--title <text>] [--expect-version <n>] [--yes]"
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
#   A "# <title> (version <n>)" header followed by the body on stdout, with
#   terminal control characters removed
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

  local page_id page title version body
  page_id=$(__mt_conf_extract_id "$target") || return 1
  __mt_conf_prepare || return 1
  page=$(__mt_conf_api "/wiki/api/v2/pages/${page_id}" --raw -q "body-format=storage") || return $?
  title=$(jq -r '.title' <<< "$page")
  version=$(jq -r '.version.number // "?"' <<< "$page")
  body=$(jq -r '.body.storage.value // ""' <<< "$page")

  echo "# ${title} (version ${version})" | __mt_strip_control_chars
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

#######################################
# Confluence: Resolve conf-put's body source to a readable, non-empty file.
# Arguments:
#   $1 - "@<file>", or "-" to read stdin (copied into $2)
#   $2 - Private scratch directory
# Returns:
#   0 and the file path on stdout, 1 on a literal, unreadable or empty source
#   or when "-" is given with stdin on a terminal
#######################################
__mt_conf_put_body_file() {
  local source="$1" scratch="$2" file
  if [ "$source" = "-" ]; then
    if [ -t 0 ]; then
      echo -e "${CB_RED}🚨 Pipe the page body in, or use @<file>.${C_RESET}" >&2
      return 1
    fi
    file="$scratch/body.xhtml"
    cat > "$file"
  elif [[ "$source" == @* ]]; then
    file="${source#@}"
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
      echo -e "${CB_RED}🚨 Cannot read body file: ${file}${C_RESET}" >&2
      return 1
    fi
  else
    echo -e "${CB_RED}🚨 conf-put takes the body as @<file> or - (stdin), not literal text.${C_RESET}" >&2
    return 1
  fi
  if [ ! -s "$file" ]; then
    echo -e "${CB_RED}🚨 The page body is empty; refusing to wipe the page.${C_RESET}" >&2
    return 1
  fi
  echo "$file"
}

#######################################
# Confluence: Show what conf-put will change and ask to continue, unless
# --yes was given. Without a terminal and without --yes, nothing is written.
# Arguments:
#   $1 - One-line summary of the change
#   $2 - Non-empty to skip the question (--yes)
# Returns:
#   0 to continue, 1 otherwise
#######################################
__mt_conf_put_confirm() {
  local summary="$1" assume_yes="$2" reply=""
  echo -e "✏️  ${summary}" | __mt_strip_control_chars >&2
  [ -n "$assume_yes" ] && return 0
  if ! __mt_has_tty; then
    echo -e "${CB_RED}🚨 No terminal to confirm on; pass --yes to update without asking.${C_RESET}" >&2
    return 1
  fi
  read -r -p "Update the page? [y/N] " -n 1 reply < /dev/tty || reply=""
  echo >&2
  [[ "$reply" == [yY] ]]
}

#######################################
# Confluence: PUT a prepared page body, mapping a version conflict to the
# stale exit code and adding a scope hint to a 401/403.
# Arguments:
#   $1 - Page ID
#   $2 - Scratch directory holding request.json; the response is written
#        to put.json there
# Returns:
#   0 on success, CONFLUENCE_EXIT_STALE on HTTP 409, mt-http's code otherwise
#######################################
__mt_conf_put_request() {
  local page_id="$1" scratch="$2" rc=0
  __mt_conf_api "/wiki/api/v2/pages/${page_id}" -X PUT -H "Content-Type: application/json" \
    -d "@${scratch}/request.json" --raw > "${scratch}/put.json" 2> "${scratch}/put.err" || rc=$?
  [ "$rc" -eq 0 ] && return 0

  cat "${scratch}/put.err" >&2
  if grep -q "HTTP 409" "${scratch}/put.err"; then
    echo -e "${CB_RED}🚨 Someone else saved the page first; re-read it with conf-get and try again.${C_RESET}" >&2
    return "$CONFLUENCE_EXIT_STALE"
  fi
  if grep -qE "HTTP 40[13]" "${scratch}/put.err"; then
    echo -e "${CB_YELLOW}💡 The API token may lack the write:page:confluence scope.${C_RESET}" >&2
  fi
  return "$rc"
}

#######################################
# Confluence: The steps of conf-put after argument parsing; the caller owns
# and removes the scratch directory.
# Arguments:
#   $1 - Page ID, $2 - body source (@<file> or -), $3 - version message,
#   $4 - new title (empty = keep), $5 - expected version (empty = any),
#   $6 - non-empty to skip confirmation, $7 - private scratch directory
# Returns:
#   See conf-put
# Outputs:
#   See conf-put
#######################################
__mt_conf_put_run() {
  local page_id="$1" source="$2" message="$3" new_title="$4" expect_version="$5" assume_yes="$6" scratch="$7"
  local body_file page status title version
  body_file=$(__mt_conf_put_body_file "$source" "$scratch") || return 1
  __mt_conf_prepare || return 1
  page=$(__mt_conf_api "/wiki/api/v2/pages/${page_id}" --raw -q "body-format=storage") || return $?

  status=$(jq -r '.status // "unknown"' <<< "$page")
  if [ "$status" != "current" ]; then
    echo -e "${CB_RED}🚨 Page ${page_id} is ${status}, not current; refusing to update it.${C_RESET}" >&2
    return 1
  fi
  title=$(jq -r '.title' <<< "$page")
  version=$(jq -r '.version.number' <<< "$page")
  if [ -n "$expect_version" ] && [ "$expect_version" != "$version" ]; then
    echo -e "${CB_RED}🚨 Page is at version ${version} (saved $(jq -r '.version.createdAt // "?"' <<< "$page") by $(jq -r '.version.authorId // "?"' <<< "$page")), not ${expect_version}.${C_RESET}" >&2
    return "$CONFLUENCE_EXIT_STALE"
  fi

  local old_bytes new_bytes next_version=$((version + 1))
  old_bytes=$(jq -r '(.body.storage.value // "") | utf8bytelength' <<< "$page")
  new_bytes=$(wc -c < "$body_file")
  [ -z "$new_title" ] && new_title="$title"
  __mt_conf_put_confirm "Update \"${title}\" v${version} → v${next_version} (${old_bytes} → ${new_bytes// /} bytes)" "$assume_yes" || return 1

  jq -n --arg id "$page_id" --arg title "$new_title" --rawfile body "$body_file" --argjson version "$next_version" \
    --arg message "$message" -f "$CONFLUENCE_JQ_DIR/conf_put_body.jq" > "${scratch}/request.json" || return 1
  __mt_conf_put_request "$page_id" "$scratch" || return $?

  local url view pattern
  url=$(jq -r '(._links.base // "") + (._links.webui // "")' "${scratch}/put.json")
  printf '%s\t%s\n' "$url" "$(jq -r '.version.number' "${scratch}/put.json")" | __mt_strip_control_chars
  view=$(__mt_conf_api "/wiki/api/v2/pages/${page_id}" --raw -q "body-format=view") || return $?
  for pattern in "${CONFLUENCE_RENDER_ERROR_PATTERNS[@]}"; do
    if grep -qF -- "$pattern" <<< "$view"; then
      echo -e "${CB_YELLOW}⚠️  Updated to v${next_version}, but the page renders with macro errors.${C_RESET}" >&2
      return "$CONFLUENCE_EXIT_RENDER_ERRORS"
    fi
  done
}

#######################################
# Confluence: Replace a page's body (storage-format XHTML) with a new version,
# after showing the change and confirming. The body is read from a file or
# stdin and never appears on a command line.
# Usage: conf-put <page-id|page-url> (@<file> | -) [-m <message>] [--title <text>] [--expect-version <n>] [--yes]
# Arguments:
#   <page-id|page-url>      Numeric page ID or a URL containing /pages/<id>
#   @<file> | -             New body from a file, or from stdin (not a terminal);
#                           literal text is rejected and an empty body is refused
# Options:
#   -m, --message <text>    Version comment (default: "Updated with conf-put")
#   --title <text>          New page title (default: keep the current one)
#   --expect-version <n>    Refuse unless the page is still at version n (see conf-get)
#   --yes                   Skip the confirmation (required without a terminal)
#   -h, --help              Show this help menu
# Returns:
#   0 on success; 1 on bad usage, missing configuration, a page that is not
#   current, or no confirmation; 6 when the page has moved past
#   --expect-version or someone saved it first (HTTP 409); 7 when the update
#   succeeded but the page renders with macro errors; mt-http's code on any
#   other API failure (a 401/403 adds a write:page:confluence scope hint)
# Outputs:
#   "<page-url><TAB><new-version>" on stdout; the change summary, prompt and
#   errors on stderr
# Example: conf-get 12345 | head -1; conf-put 12345 @page.xhtml --expect-version 4 -m "Sync from repo"
#######################################
conf-put() {
  local target="" source="" message="$CONFLUENCE_DEFAULT_VERSION_MESSAGE" new_title="" expect_version="" assume_yes=""
  local positionals=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -m | --message | --title | --expect-version)
        if [ -z "${2:-}" ]; then
          echo "$CONFLUENCE_PUT_USAGE" >&2
          return 1
        fi
        case "$1" in
          -m | --message) message="$2" ;;
          --title) new_title="$2" ;;
          --expect-version) expect_version="$2" ;;
        esac
        shift
        ;;
      --yes) assume_yes="1" ;;
      -?*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return 1
        ;;
      *) positionals+=("$1") ;;
    esac
    shift
  done
  if [ "${#positionals[@]}" -ne 2 ]; then
    echo "$CONFLUENCE_PUT_USAGE" >&2
    return 1
  fi
  target="${positionals[0]}"
  source="${positionals[1]}"
  if [ -z "$target" ] || [ -z "$source" ]; then
    echo "$CONFLUENCE_PUT_USAGE" >&2
    return 1
  fi
  if [ -n "$expect_version" ] && [[ ! "$expect_version" =~ ^[1-9][0-9]*$ ]]; then
    echo -e "${CB_RED}❌ --expect-version must be a positive whole number.${C_RESET}" >&2
    return 1
  fi

  local page_id scratch rc=0
  page_id=$(__mt_conf_extract_id "$target") || return 1
  scratch=$(mktemp -d) || return 1
  __mt_conf_put_run "$page_id" "$source" "$message" "$new_title" "$expect_version" "$assume_yes" "$scratch" || rc=$?
  rm -rf "$scratch"
  return "$rc"
}
