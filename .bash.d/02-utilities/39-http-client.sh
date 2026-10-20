# shellcheck shell=bash
# ------------------------------------------
# Utilities: Authenticated HTTP Client
# ------------------------------------------
# ~/.bash.d/02-utilities/39-http-client.sh

MT_HTTP_EXIT_USAGE=2
MT_HTTP_EXIT_TRANSPORT=3
MT_HTTP_EXIT_STATUS=4
MT_HTTP_ATLASSIAN_GATEWAY="https://api.atlassian.com/ex/confluence/<cloudId>"

#######################################
# HTTP: Replace every credential value and URL userinfo in stdin with ***
# Arguments:
#   $@ - Secret strings to mask
# Outputs:
#   Masked text on stdout, with terminal control characters removed
#######################################
__mt_http_redact() {
  local text secret
  text=$(cat)
  for secret in "$@"; do
    [ -n "$secret" ] && text="${text//"$secret"/***}"
  done
  sed -E 's#(://)[^/@[:space:]]+@#\1***@#' <<< "$text" | __mt_strip_control_chars
}

#######################################
# HTTP: Strip terminal control characters (C0 including ESC and CR, DEL, and
# the C1 range U+0080-U+009F) from stdin, keeping tabs and newlines, so
# untrusted remote text cannot drive the terminal.
# Outputs:
#   Sanitised text on stdout
#######################################
__mt_strip_control_chars() {
  perl -pe 's/[\x00-\x08\x0B-\x1F\x7F]|\xC2[\x80-\x9F]//g'
}

#######################################
# HTTP: Make an authenticated HTTP request with curl. Credentials are passed
# to curl on stdin (never argv) and masked from every message printed.
# Usage: mt-http [OPTIONS] <url>
# Arguments:
#   <url>                 Request URL
# Options:
#   -X, --method <verb>   HTTP method (default: GET, or POST when a body is given)
#   -H, --header <h>      Extra header "Name: value" (repeatable)
#   -d, --data <body>     Request body; prefix with @ to read from a file
#   -q, --query <k=v>     URL-encoded query parameter (repeatable, GET only)
#   -u, --user <u:p>      HTTP basic auth
#   -b, --bearer <token>  Bearer token auth
#   --raw                 Do not pretty-print JSON responses
#   -v, --verbose         Print method, redacted URL and status to stderr
#   -h, --help            Show this help
# Returns:
#   0 on 2xx/3xx, 2 on bad usage, 3 on transport failure (DNS, TLS, timeout),
#   4 on an HTTP 4xx/5xx response (status and body printed to stderr)
# Outputs:
#   Response body on stdout
#######################################
mt-http() {
  local method="" body="" user="" bearer="" raw=false verbose=false url=""
  local -a headers=() queries=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -X | --method)
        method="${2:-}"
        shift
        ;;
      -H | --header)
        headers+=("${2:-}")
        shift
        ;;
      -d | --data)
        body="${2:-}"
        shift
        ;;
      -q | --query)
        queries+=("${2:-}")
        shift
        ;;
      -u | --user)
        user="${2:-}"
        shift
        ;;
      -b | --bearer)
        bearer="${2:-}"
        shift
        ;;
      --raw) raw=true ;;
      -v | --verbose) verbose=true ;;
      -*)
        echo -e "${CB_RED}❌ Unknown option: $1${C_RESET}" >&2
        return "$MT_HTTP_EXIT_USAGE"
        ;;
      *) url="$1" ;;
    esac
    shift
  done

  if [ -z "$url" ]; then
    echo "Usage: mt-http [OPTIONS] <url>" >&2
    return "$MT_HTTP_EXIT_USAGE"
  fi
  if [ -n "$user" ] && [ -n "$bearer" ]; then
    echo -e "${CB_RED}❌ Use either --user or --bearer, not both.${C_RESET}" >&2
    return "$MT_HTTP_EXIT_USAGE"
  fi
  if [ -n "$body" ] && [ "${#queries[@]}" -gt 0 ]; then
    echo -e "${CB_RED}❌ --query cannot be combined with --data.${C_RESET}" >&2
    return "$MT_HTTP_EXIT_USAGE"
  fi
  [ -z "$method" ] && { [ -n "$body" ] && method="POST" || method="GET"; }

  local -a curl_args=(--silent --show-error --location --request "$method" --config -)
  local header query
  for header in "${headers[@]}"; do
    curl_args+=(--header "$header")
  done
  if [ "${#queries[@]}" -gt 0 ]; then
    curl_args+=(--get)
    for query in "${queries[@]}"; do
      curl_args+=(--data-urlencode "$query")
    done
  fi
  [ -n "$body" ] && curl_args+=(--data-binary "$body")

  local auth_config=""
  [ -n "$user" ] && auth_config="user = \"${user//\"/\\\"}\""
  [ -n "$bearer" ] && auth_config="header = \"Authorization: Bearer ${bearer//\"/\\\"}\""

  local work_dir body_file err_file status curl_rc=0
  work_dir=$(mktemp -d)
  body_file="$work_dir/body"
  err_file="$work_dir/err"
  local -a secrets=("$user" "$bearer" "${user#*:}")

  [ "$verbose" = true ] && echo -e "${CB_BLUE}🌐 ${method} $(__mt_http_redact "${secrets[@]}" <<< "$url")${C_RESET}" >&2

  status=$(printf '%s\n' "$auth_config" | curl "${curl_args[@]}" --output "$body_file" --write-out '%{http_code}' -- "$url" 2> "$err_file") || curl_rc=$?

  if [ "$curl_rc" -ne 0 ]; then
    echo -e "${CB_RED}🚨 Request failed before a response was received (curl exit ${curl_rc}):${C_RESET}" >&2
    __mt_http_redact "${secrets[@]}" < "$err_file" >&2
    rm -rf "$work_dir"
    return "$MT_HTTP_EXIT_TRANSPORT"
  fi
  [ "$verbose" = true ] && echo -e "${CB_BLUE}↩️  HTTP ${status}${C_RESET}" >&2

  local rc=0
  if [ "$status" -ge 400 ]; then
    echo -e "${CB_RED}🚨 HTTP ${status}${C_RESET}" >&2
    __mt_http_hint "$status" "$url" "$user" >&2
    rc="$MT_HTTP_EXIT_STATUS"
  fi

  local out_stream=1
  [ "$rc" -ne 0 ] && out_stream=2
  if [ "$raw" = false ] && command -v jq > /dev/null 2>&1 && jq -e . "$body_file" > /dev/null 2>&1; then
    jq . "$body_file" | __mt_http_redact "${secrets[@]}" >&"$out_stream"
  else
    __mt_http_redact "${secrets[@]}" < "$body_file" >&"$out_stream"
  fi
  rm -rf "$work_dir"
  return "$rc"
}

#######################################
# HTTP: Print a remedy for a well-known failure
# Arguments:
#   $1 - HTTP status, $2 - URL, $3 - basic-auth user (empty if unused)
# Outputs:
#   Hint text on stdout, nothing when there is no known remedy
#######################################
__mt_http_hint() {
  local status="$1" url="$2" user="$3"
  if [ "$status" = "401" ] && [ -n "$user" ] && [[ "$url" == *.atlassian.net/* ]]; then
    echo -e "${CB_YELLOW}💡 Scoped Atlassian tokens return 401 against the site URL; use the gateway: ${MT_HTTP_ATLASSIAN_GATEWAY}${C_RESET}"
  fi
}
