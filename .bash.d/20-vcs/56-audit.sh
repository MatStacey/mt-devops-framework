# shellcheck shell=bash
# ------------------------------------------
# Git: Dependency Vulnerability Audit
# ------------------------------------------
# ~/.bash.d/20-vcs/56-audit.sh

#######################################
# Repo: Run a dependency vulnerability audit for the current directory's
# project, dispatching to the right tool based on its manifest files --
# npm audit for a package.json, pip-audit for a Python project, OWASP
# dependency-check for a Maven pom.xml. Anything else reports as
# unsupported rather than guessing wrong, since there's no single audit
# tool that covers every build ecosystem the way
# __mt_hub_detect_build_tool's file-presence checks do for detection
# alone. On-demand only (not part of mt-hub --index) since a real audit
# hits a registry/database and can take real time -- from a few seconds
# (npm/pip) up to several minutes on a cold cache (Maven's OWASP
# dependency-check, which builds a local CVE database on first run) --
# too slow to run automatically for every repo on every index pass.
# Usage: mt-audit-deps [-j|--json]
# Options:
#   -j, --json   Print the result as a single JSON object instead of a
#                colorized summary
# Globals:
#   NVD_API_KEY (optional) -- speeds up the Maven branch's first-run CVE
#     database build (see mt-add-nvd-key); works without one, just slower.
#   DEPENDENCY_CHECK_PLUGIN_VERSION -- pinned org.owasp:dependency-check-
#     maven version for the Maven branch (config.yaml's
#     java.dependency_check_plugin_version).
#######################################
mt-audit-deps() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local json_mode=false
  [[ "$1" == "-j" || "$1" == "--json" ]] && json_mode=true

  local tool="" status="unsupported" message="" vulns="null"

  if [ -f "package.json" ]; then
    tool="npm audit"
    if ! command -v npm > /dev/null 2>&1; then
      status="tool-missing"
      message="npm is not installed."
    else
      local raw
      raw=$(npm audit --json 2> /dev/null)
      if echo "$raw" | jq -e '.metadata.vulnerabilities' > /dev/null 2>&1; then
        status="ok"
        vulns=$(echo "$raw" | jq -c '.metadata.vulnerabilities')
      else
        status="error"
        message="npm audit did not return the expected JSON shape."
      fi
    fi
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    tool="pip-audit"
    if ! command -v pip-audit > /dev/null 2>&1; then
      status="tool-missing"
      message="pip-audit is not installed (pip install pip-audit)."
    else
      local raw
      raw=$(pip-audit -f json 2> /dev/null)
      if echo "$raw" | jq -e 'type == "array"' > /dev/null 2>&1; then
        status="ok"
        # pip-audit doesn't categorize findings by severity the way npm
        # audit does -- total is the only honest number to report here.
        local total
        total=$(echo "$raw" | jq '[.[].vulns[]?] | length')
        vulns=$(jq -n --argjson total "$total" '{critical: null, high: null, moderate: null, low: null, info: null, total: $total}')
      else
        status="error"
        message="pip-audit did not return the expected JSON shape."
      fi
    fi
  elif [ -f "pom.xml" ]; then
    tool="OWASP dependency-check"
    if ! command -v mvn > /dev/null 2>&1; then
      status="tool-missing"
      message="Maven is not installed."
    else
      # First run on a repo builds OWASP's local NVD (CVE) database from
      # scratch -- can take several minutes, much longer without an NVD
      # API key (see mt-add-nvd-key) since NVD rate-limits anonymous
      # requests hard. Later runs reuse that cache and are quick.
      [ "$json_mode" = true ] || echo -e "${C_DIM}⏳ Running OWASP dependency-check (first run builds a local CVE database -- can take several minutes)...${C_RESET}"

      local nvd_key_flag=()
      [ -n "${NVD_API_KEY:-}" ] && nvd_key_flag=(-DnvdApiKey="$NVD_API_KEY")

      local report_file="target/dependency-check-report.json"
      rm -f "$report_file"
      local raw mvn_exit
      raw=$(mvn -B -q "org.owasp:dependency-check-maven:${DEPENDENCY_CHECK_PLUGIN_VERSION:-9.2.0}:check" \
        -Dformat=JSON "${nvd_key_flag[@]}" 2>&1)
      mvn_exit=$?

      if [ "$mvn_exit" -ne 0 ]; then
        status="error"
        if echo "$raw" | grep -qE "NVD API Key|NoDataException"; then
          # Confirmed against a real run: without an API key, NVD's own
          # rate limiting doesn't just slow the first-time CVE database
          # build down (as its own docs suggest) -- it can fail it
          # outright with this exact error. Give a direct, actionable
          # message instead of a raw Maven stack trace tail.
          message="OWASP dependency-check couldn't build its local CVE database -- NVD's rate limit blocks this without an API key. Run 'mt-add-nvd-key' (free, see https://nvd.nist.gov/developers/request-an-api-key) and try again."
        else
          message="mvn dependency-check failed: $(echo "$raw" | tail -n 10 | tr '\n' ' ')"
        fi
      elif [ ! -f "$report_file" ]; then
        status="error"
        message="dependency-check ran but produced no report at ${report_file}."
      else
        status="ok"
        vulns=$(jq -c '
          ([.dependencies[]?.vulnerabilities[]?.severity // empty] | map(ascii_upcase)) as $sevs |
          {
            critical: ($sevs | map(select(. == "CRITICAL")) | length),
            high: ($sevs | map(select(. == "HIGH")) | length),
            moderate: ($sevs | map(select(. == "MEDIUM")) | length),
            low: ($sevs | map(select(. == "LOW")) | length),
            info: null,
            total: ($sevs | length)
          }' "$report_file")
        rm -f "$report_file"
      fi
    fi
  else
    message="No supported manifest found in this directory (npm/pip/Maven projects only, for now)."
  fi

  if [ "$json_mode" = true ]; then
    jq -n --arg status "$status" --arg tool "$tool" --arg message "$message" --argjson vulns "$vulns" \
      '{status: $status, tool: (if $tool == "" then null else $tool end), message: (if $message == "" then null else $message end), vulnerabilities: $vulns}'
    return 0
  fi

  case "$status" in
    ok)
      echo -e "${CB_BLUE}🔍 ${tool} results:${C_RESET}"
      echo "$vulns" | jq -r 'to_entries[] | "  \(.key): \(.value // "n/a")"'
      ;;
    tool-missing | unsupported)
      echo -e "${CB_YELLOW}⚠️  ${message}${C_RESET}"
      ;;
    error)
      echo -e "${CB_RED}🚨 ${message}${C_RESET}"
      ;;
  esac
}

#######################################
# Repo: Turn the combined console output of `mvn versions:display-
# dependency-updates versions:display-property-updates versions:display-
# parent-updates` into a JSON array -- see lib/awk/maven_version_updates.awk
# for the actual line-matching logic and why it's substring- rather than
# exact-sentence-based.
# Arguments:
#   $1 - Raw combined stdout+stderr from the three mvn goals
# Outputs:
#   Prints a JSON array: [{scope, artifact, current, latest}, ...] where
#   scope is "dependency", "property", "parent", or "plugin" (a
#   pluginManagement-declared build plugin, e.g. spring-boot-maven-plugin --
#   display-dependency-updates reports these alongside regular
#   dependencies)
#######################################
__mt_parse_maven_version_updates() {
  local raw="$1"
  local awk_script="$HOME/.bash.d/lib/awk/maven_version_updates.awk"
  echo "$raw" | awk -f "$awk_script" | jq -R -s '
    split("\n") | map(select(length > 0) | split("\t")) |
    map({scope: .[0], artifact: .[1], current: .[2], latest: .[3]})
  '
}

#######################################
# Repo: Check whether the current directory's project has newer versions
# available for its dependencies -- distinct from mt-audit-deps, which
# checks for known *vulnerabilities*, not version currency. Dispatches by
# manifest file, same pattern as mt-audit-deps: npm outdated for a
# package.json, pip list --outdated for a Python project, and the Maven
# Versions Plugin's three separate display-*-updates goals for a pom.xml
# -- regular <dependencies>, <properties>-defined versions, and the
# <parent> POM itself (easy to miss by hand, since a parent-version bump
# -- e.g. Spring Boot's own starter-parent -- isn't a <dependency> at
# all). On-demand only, same reasoning as mt-audit-deps: a real registry
# lookup takes real time, too slow for every repo on every index pass.
# Usage: mt-deps-outdated [-j|--json]
# Options:
#   -j, --json   Print the result as a single JSON object instead of a
#                colorized summary
# Globals:
#   VERSIONS_PLUGIN_VERSION -- pinned org.codehaus.mojo:versions-maven-
#     plugin version for the Maven branch (config.yaml's
#     java.versions_plugin_version).
#######################################
mt-deps-outdated() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local json_mode=false
  [[ "$1" == "-j" || "$1" == "--json" ]] && json_mode=true

  local tool="" status="unsupported" message="" updates="[]"

  if [ -f "package.json" ]; then
    tool="npm outdated"
    if ! command -v npm > /dev/null 2>&1; then
      status="tool-missing"
      message="npm is not installed."
    else
      # npm outdated exits non-zero when it finds outdated packages -- by
      # design, same as npm audit -- so the JSON shape is what's checked,
      # never the exit code.
      local raw
      raw=$(npm outdated --json 2> /dev/null)
      [ -z "$raw" ] && raw="{}"
      if echo "$raw" | jq -e 'type == "object"' > /dev/null 2>&1; then
        status="ok"
        updates=$(echo "$raw" | jq -c '
          to_entries | map({scope: "dependency", artifact: .key, current: (.value.current // "none"), latest: .value.latest})
        ')
      else
        status="error"
        message="npm outdated did not return the expected JSON shape."
      fi
    fi
  elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    tool="pip list --outdated"
    local pip_bin="pip"
    command -v pip > /dev/null 2>&1 || pip_bin="pip3"
    if ! command -v "$pip_bin" > /dev/null 2>&1; then
      status="tool-missing"
      message="pip is not installed."
    else
      local raw
      raw=$("$pip_bin" list --outdated --format=json 2> /dev/null)
      if echo "$raw" | jq -e 'type == "array"' > /dev/null 2>&1; then
        status="ok"
        updates=$(echo "$raw" | jq -c '
          map({scope: "dependency", artifact: .name, current: .version, latest: .latest_version})
        ')
      else
        status="error"
        message="pip list --outdated did not return the expected JSON shape."
      fi
    fi
  elif [ -f "pom.xml" ]; then
    tool="Maven Versions Plugin"
    if ! command -v mvn > /dev/null 2>&1; then
      status="tool-missing"
      message="Maven is not installed."
    else
      local vp_version="${VERSIONS_PLUGIN_VERSION:-2.16.2}"
      # Deliberately no -q here (unlike mt-audit-deps's Maven branch) --
      # the plugin's report is [INFO]-level console output, not a file, so
      # quiet mode would suppress the exact lines being parsed.
      #
      # -DprocessDependencyManagement=false restricts display-dependency-
      # updates to what this project's own pom.xml actually declares,
      # rather than every artifact touched by an inherited BOM (e.g.
      # Spring Boot's own starter-parent, or a google-cloud libraries-bom
      # import) -- without it, a project with either pulls in 1000+
      # transitive entries the developer has no direct control over
      # anyway, burying the handful of updates that are actually theirs
      # to act on (confirmed against a real Spring Boot + GCP BOM project:
      # 1108 lines of noise down to 16 real ones).
      local raw mvn_exit
      raw=$(mvn -B -DprocessDependencyManagement=false \
        "org.codehaus.mojo:versions-maven-plugin:${vp_version}:display-dependency-updates" \
        "org.codehaus.mojo:versions-maven-plugin:${vp_version}:display-property-updates" \
        "org.codehaus.mojo:versions-maven-plugin:${vp_version}:display-parent-updates" 2>&1)
      mvn_exit=$?

      if [ "$mvn_exit" -ne 0 ]; then
        status="error"
        message="mvn versions-plugin failed: $(echo "$raw" | tail -n 10 | tr '\n' ' ')"
      else
        status="ok"
        updates=$(__mt_parse_maven_version_updates "$raw")
      fi
    fi
  else
    message="No supported manifest found in this directory (npm/pip/Maven projects only, for now)."
  fi

  if [ "$json_mode" = true ]; then
    jq -n --arg status "$status" --arg tool "$tool" --arg message "$message" --argjson updates "$updates" \
      '{status: $status, tool: (if $tool == "" then null else $tool end), message: (if $message == "" then null else $message end), updates: $updates}'
    return 0
  fi

  case "$status" in
    ok)
      local count
      count=$(echo "$updates" | jq 'length')
      if [ "$count" -eq 0 ]; then
        echo -e "${CB_GREEN}✅ Everything is up to date (${tool}).${C_RESET}"
      else
        echo -e "${CB_BLUE}📦 ${tool} found ${count} update(s):${C_RESET}"
        echo "$updates" | jq -r '.[] | "  [\(.scope)] \(.artifact): \(.current) -> \(.latest)"'
      fi
      ;;
    tool-missing | unsupported)
      echo -e "${CB_YELLOW}⚠️  ${message}${C_RESET}"
      ;;
    error)
      echo -e "${CB_RED}🚨 ${message}${C_RESET}"
      ;;
  esac
}
