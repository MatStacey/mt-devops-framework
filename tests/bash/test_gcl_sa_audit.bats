#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-sa-audit in .bash.d/10-infra/37-gcp-sa-audit.sh
# ------------------------------------------
# gcloud is replaced by a stub on PATH that logs its argv and serves the
# fixtures in fixtures/gcl_sa_audit/ (copied, with __RECENT__ set to
# yesterday) by command and resource; proj-denied fails with a permission
# error and an unknown pool with NOT_FOUND. STUB_DENY_DESCRIBE denies project
# describes and STUB_DENY_RUN_POLICY=<project> denies that project's Cloud Run
# IAM policies.

# shellcheck disable=SC2154  # $stderr is set by `run --separate-stderr`
bats_require_minimum_version 1.5.0

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  export FIXTURES="$BATS_TEST_TMPDIR/fixtures" GCLOUD_LOG="$BATS_TEST_TMPDIR/gcloud.log"
  cp -r "$BATS_TEST_DIRNAME/fixtures/gcl_sa_audit" "$FIXTURES"
  sed -i "s|__RECENT__|$(date -u -d '-1 day' +%Y-%m-%dT%H:%M:%SZ)|g" "$FIXTURES"/keys_*.json
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GCLOUD_LOG"
project="" pool="" account=""
for arg in "$@"; do
  case "$arg" in
    --project=*) project="${arg#--project=}" ;;
    --workload-identity-pool=*) pool="${arg#--workload-identity-pool=}" ;;
    --iam-account=*) account="${arg#--iam-account=}" ;;
  esac
done
if [ "$project" = "proj-denied" ] || [ "$4" = "proj-denied" ]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'iam.serviceAccounts.list' denied" >&2
  exit 1
fi
deny() {
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission '$1' denied" >&2
  exit 1
}
serve() {
  [ -f "$FIXTURES/$1" ] && cat "$FIXTURES/$1" && exit 0
  echo "ERROR: (gcloud) NOT_FOUND: Requested entity was not found." >&2
  exit 1
}
case "$1 $2 $3" in
  "iam service-accounts list") serve "sa_list_${project}.json" ;;
  "projects get-iam-policy "*) serve "project_policy_$3.json" ;;
  "iam service-accounts get-iam-policy") serve "sa_policy_${4%%@*}.json" ;;
  "iam workload-identity-pools describe") serve "pool_$4.json" ;;
  "iam workload-identity-pools providers") serve "providers_${pool}.json" ;;
  "projects describe "*)
    [ -n "${STUB_DENY_DESCRIBE:-}" ] && deny resourcemanager.projects.get
    serve "number_$3.txt"
    ;;
  "run services list") serve "run_services_${project}.json" ;;
  "run services get-iam-policy")
    [ "$project" = "${STUB_DENY_RUN_POLICY:-}" ] && deny run.services.getIamPolicy
    serve "run_policy_${project}_$4.json"
    ;;
  "iam service-accounts keys") serve "keys_${account%%@*}.json" ;;
esac
exit 1
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/37-gcp-sa-audit.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  unset GCP_WIF_BROAD_CLAIMS
  mt-help() { echo "help called"; }
  gcl-get-project() { echo "proj-b"; }
  gcl-get-user() { echo "me@example.test"; }
  gcl-auth-check() { return 0; }
}

# Prints "<service account local part> <finding>" for each row on stdout.
findings_of() {
  awk -F'\t' '{ split($3, sa, "@"); print sa[1], $6 }' <<< "$1" | sort
}

@test "each finding code is raised by the fixture built for it" {
  run --separate-stderr gcl-sa-audit -p proj-a --check wif
  [ "$status" -eq 0 ]
  [ "$(findings_of "$output")" = "builder NO_CONDITION
builder POOL_MISSING
builder POOL_MISSING
deployer BROAD_ATTRIBUTE+SECRETS
deployer PLACEHOLDER_SUBJECT+SECRETS
deployer WILDCARD_POOL+SECRETS" ]
}

@test "rows use the shared six-column schema with the wif detail" {
  run --separate-stderr gcl-sa-audit -p proj-a --check wif
  [[ "$output" == *$'wif\tproj-a\tdeployer@proj-a.iam.gserviceaccount.com\tprincipalSet://iam.googleapis.com/projects/111/locations/global/workloadIdentityPools/ci-pool/attribute.repository_owner/acme\tpool=ci-pool attr=repository_owner<-assertion.repository_owner condition=set\tBROAD_ATTRIBUTE+SECRETS'* ]]
  [[ "$output" == *$'\tpool=loose-pool attr=- condition=none\tNO_CONDITION'* ]]
  [[ "$output" == *$'\tpool=ci-pools attr=- condition=-\tPOOL_MISSING'* ]]
  [ "$(awk -F'\t' '{ print NF }' <<< "$output" | sort -u)" = "6" ]
}

@test "+SECRETS is appended only for a service account with a project-level secretmanager role" {
  run --separate-stderr gcl-sa-audit -p proj-a --check wif
  [ "$(grep -c '^wif.proj-a.deployer@.*+SECRETS$' <<< "$output")" -eq 3 ]
  [ "$(grep -c '^wif.proj-a.builder@.*+SECRETS$' <<< "$output")" -eq 0 ]
}

@test "members of other roles and non-WIF members are ignored" {
  run --separate-stderr gcl-sa-audit -p proj-a --check wif
  [ "$(grep -c "WILDCARD_POOL" <<< "$output")" -eq 1 ]
  [[ "$output" != *"svc.id.goog"* ]]
  [[ "$output" != *"clean@"* ]]
}

@test "a clean project prints no rows, says so and exits 0" {
  run --separate-stderr gcl-sa-audit
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" == *"✅ No findings."* ]]
}

@test "the summary counts findings, service accounts and projects" {
  run --separate-stderr gcl-sa-audit -p proj-a -p proj-b --check wif
  [[ "$stderr" == *"6 findings across 4 service accounts in 2 projects"* ]]
}

@test "--expected-pool flags a plural pool name as both mismatched and missing" {
  run --separate-stderr gcl-sa-audit -p proj-a --expected-pool ci-pool --check wif
  [ "$status" -eq 0 ]
  [[ "$output" == *$'/ci-pools/subject/repo:acme/app\tpool=ci-pools attr=- condition=-\tPOOL_MISMATCH'* ]]
  [[ "$output" == *$'/ci-pools/subject/repo:acme/app\tpool=ci-pools attr=- condition=-\tPOOL_MISSING'* ]]
  [ "$(grep -c "POOL_MISMATCH" <<< "$output")" -eq 3 ]
}

@test "a denied project is reported, the other still prints, and the exit code is 5" {
  run --separate-stderr gcl-sa-audit -p proj-denied -p proj-a
  [ "$status" -eq 5 ]
  [[ "$stderr" == *"Permission denied for listing service accounts of proj-denied"* ]]
  [[ "$output" == *"deployer@proj-a"* ]]
}

@test "--json prints the same findings as an array" {
  run --separate-stderr gcl-sa-audit -p proj-a --json --check wif
  [ "$status" -eq 0 ]
  jq -e 'type == "array" and length == 6' <<< "$output"
  jq -e 'all(.[]; keys == ["check", "detail", "finding", "principal", "project", "resource"])' <<< "$output"
}

@test "--json with no findings prints an empty array" {
  run --separate-stderr gcl-sa-audit --json
  [ "$(jq -c . <<< "$output")" = "[]" ]
}

@test "each pool is described once, not once per member" {
  run --separate-stderr gcl-sa-audit -p proj-a -p proj-b --check wif
  [ "$(grep -c "workload-identity-pools describe ci-pool " "$GCLOUD_LOG")" -eq 1 ]
  [ "$(grep -c "providers list --workload-identity-pool=ci-pool " "$GCLOUD_LOG")" -eq 1 ]
}

@test "gcp.wif_broad_claims replaces the default claims" {
  GCP_WIF_BROAD_CLAIMS="assertion.sub" run --separate-stderr gcl-sa-audit -p proj-a --check wif
  [ "$(grep -c "BROAD_ATTRIBUTE" <<< "$output")" -eq 0 ]
}

@test "bad usage is rejected before any gcloud call" {
  local args
  for args in "--bogus" "-p" "--expected-pool" "-p BAD_PROJECT" "--expected-pool Bad_Pool" "--expected-pool abc"; do
    # shellcheck disable=SC2086
    run gcl-sa-audit $args
    [ "$status" -eq 1 ] || {
      echo "args: $args -> $status"
      return 1
    }
  done
  [ ! -f "$GCLOUD_LOG" ]
}

@test "terminal control characters in fixture values are stripped" {
  mkdir -p "$BATS_TEST_TMPDIR/fx"
  cp "$FIXTURES"/*.json "$BATS_TEST_TMPDIR/fx/"
  sed -i 's|subject/REPLACE_ME|subject/REPLACE_ME\\u001b[31m|' "$BATS_TEST_TMPDIR/fx/sa_policy_deployer.json"
  FIXTURES="$BATS_TEST_TMPDIR/fx" run --separate-stderr gcl-sa-audit -p proj-a --check wif
  [[ "$output" == *"PLACEHOLDER_SUBJECT"* ]]
  [[ "$output" != *$'\033'* ]]
}

@test "no findings with an unreadable project warns instead of giving the all-clear" {
  run --separate-stderr gcl-sa-audit -p proj-denied -p proj-b
  [ "$status" -eq 5 ]
  [ -z "$output" ]
  [[ "$stderr" != *"✅"* ]]
  [[ "$stderr" == *"⚠️  No findings in what could be read; some projects or policies were unreadable (see above)"* ]]
}

@test "invoker: public, cross-project and missing expected invokers are coded, with no key calls" {
  run --separate-stderr gcl-sa-audit -p proj-a --check invoker --expected-invoker deployer@proj-a.iam.gserviceaccount.com
  [ "$status" -eq 0 ]
  [[ "$output" == *$'invoker\tproj-a\teurope-west1/web\tallUsers\troles/run.invoker\tPUBLIC_INVOKER'* ]]
  [[ "$output" == *$'invoker\tproj-a\teurope-west2/api\tserviceAccount:caller@proj-b.iam.gserviceaccount.com\troles/run.invoker\tCROSS_PROJECT'* ]]
  [[ "$output" == *$'invoker\tproj-a\teurope-west2/api\tserviceAccount:999-compute@developer.gserviceaccount.com\troles/run.invoker\tCROSS_PROJECT'* ]]
  [[ "$output" == *$'invoker\tproj-a\teurope-west1/web\tserviceAccount:deployer@proj-a.iam.gserviceaccount.com\troles/run.invoker\tMISSING_INVOKER'* ]]
  [[ "$output" == *$'invoker\tproj-a\teurope-west2/api\tserviceAccount:deployer@proj-a.iam.gserviceaccount.com\troles/run.invoker\t-'* ]]
  [ "$(grep -c "MISSING_INVOKER" <<< "$output")" -eq 1 ]
  [ "$(grep -c "keys\|service-accounts" "$GCLOUD_LOG")" -eq 0 ]
}

@test "invoker: other roles' members are not invoker rows" {
  run --separate-stderr gcl-sa-audit -p proj-a --check invoker
  [ "$(grep -c "europe-west2/api.allUsers" <<< "$output")" -eq 0 ]
}

@test "invoker: a member from another audited project, by ID or number, is not cross-project" {
  run --separate-stderr gcl-sa-audit -p proj-a -p proj-b --check invoker
  [[ "$output" == *$'serviceAccount:caller@proj-b.iam.gserviceaccount.com\troles/run.invoker\t-'* ]]
  [[ "$output" == *$'serviceAccount:222-compute@developer.gserviceaccount.com\troles/run.invoker\t-'* ]]
  [[ "$output" == *$'serviceAccount:999-compute@developer.gserviceaccount.com\troles/run.invoker\tCROSS_PROJECT'* ]]
}

@test "invoker: an unreadable project number leaves number-bearing members unjudged and exits 5" {
  STUB_DENY_DESCRIBE=1 run --separate-stderr gcl-sa-audit -p proj-a --check invoker
  [ "$status" -eq 5 ]
  [[ "$output" == *$'serviceAccount:999-compute@developer.gserviceaccount.com\troles/run.invoker\t-'* ]]
  [[ "$output" == *$'serviceAccount:caller@proj-b.iam.gserviceaccount.com\troles/run.invoker\tCROSS_PROJECT'* ]]
}

@test "invoker: --expected-invoker accepts the serviceAccount: form and rejects a non-service-account" {
  run --separate-stderr gcl-sa-audit -p proj-a --check invoker --expected-invoker serviceAccount:deployer@proj-a.iam.gserviceaccount.com
  [ "$(grep -c "MISSING_INVOKER" <<< "$output")" -eq 1 ]
  rm -f "$GCLOUD_LOG"
  run gcl-sa-audit --check invoker --expected-invoker someone@example.test
  [ "$status" -eq 1 ]
  [ ! -f "$GCLOUD_LOG" ]
}

@test "keys: no-expiry, old, disabled and fresh keys are coded, with IDs and dates only" {
  run --separate-stderr gcl-sa-audit -p proj-a --check keys
  [ "$status" -eq 0 ]
  [[ "$output" == *$'keys\tproj-a\tdeployer@proj-a.iam.gserviceaccount.com\t-\tkey=aaa111 created=2019-03-01 expires=never\tNO_EXPIRY'* ]]
  [[ "$output" == *$'keys\tproj-a\tdeployer@proj-a.iam.gserviceaccount.com\t-\tkey=aaa111 created=2019-03-01 expires=never\tOLD_KEY'* ]]
  [[ "$output" == *$'\tkey=bbb222 created='*$' expires=2099-01-01\t-'* ]]
  [[ "$output" == *$'\tkey=ccc333 created='*$' expires=2099-01-01\tDISABLED'* ]]
  [ "$(grep -c "bbb222" <<< "$output")" -eq 1 ]
  [ "$(grep -c "run " "$GCLOUD_LOG")" -eq 0 ]
}

@test "keys: key material never appears and keys are never fetched or created" {
  run --separate-stderr gcl-sa-audit -p proj-a --check keys --json
  [[ "$output$stderr" != *"LEAKED-KEY-MATERIAL"* ]]
  [[ "$output" != *"privateKeyData"* ]]
  [ "$(grep -cE "keys (get|create)|privateKeyData" "$GCLOUD_LOG")" -eq 0 ]
  grep -q -- "keys list --iam-account=deployer@proj-a.iam.gserviceaccount.com --project=proj-a --managed-by=user" "$GCLOUD_LOG"
}

@test "keys: gcp.sa_key_max_age_days sets the age limit and is validated" {
  GCP_SA_KEY_MAX_AGE_DAYS=100000 run --separate-stderr gcl-sa-audit -p proj-a --check keys
  [ "$(grep -c "OLD_KEY" <<< "$output")" -eq 0 ]
  rm -f "$GCLOUD_LOG"
  GCP_SA_KEY_MAX_AGE_DAYS=soon run gcl-sa-audit -p proj-a --check keys
  [ "$status" -eq 1 ]
  [ ! -f "$GCLOUD_LOG" ]
}

@test "with no --check all three checks run" {
  run --separate-stderr gcl-sa-audit -p proj-a
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\nwif\t'* || "$output" == $'wif\t'* ]]
  [[ "$output" == *$'\ninvoker\t'* ]]
  [[ "$output" == *$'\nkeys\t'* ]]
  [[ "$stderr" == *"findings across 3 service accounts and 2 Cloud Run services in 1 projects"* ]]
}

@test "--check takes a comma-separated list and runs only those checks" {
  run --separate-stderr gcl-sa-audit -p proj-a --check wif,keys
  [ "$(grep -c $'^invoker\t' <<< "$output")" -eq 0 ]
  [ "$(grep -c "run services" "$GCLOUD_LOG")" -eq 0 ]
  [ "$(grep -c $'^keys\t' <<< "$output")" -gt 0 ]
}

@test "--check bogus exits 1 with no gcloud call" {
  run gcl-sa-audit --check bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown check: bogus"* ]]
  run gcl-sa-audit --check wif,bogus
  [ "$status" -eq 1 ]
  [ ! -f "$GCLOUD_LOG" ]
}

@test "a denied Cloud Run policy still leaves the project's key rows, and exits 5" {
  STUB_DENY_RUN_POLICY=proj-a run --separate-stderr gcl-sa-audit -p proj-a
  [ "$status" -eq 5 ]
  [[ "$output" == *$'keys\tproj-a\tdeployer@'* ]]
  [ "$(grep -c $'^invoker\t' <<< "$output")" -eq 0 ]
  [[ "$stderr" == *"Permission denied for reading the invoker policy"* ]]
}

@test "inventory rows alone are not findings" {
  printf '[{"name":"k/fresh1","validAfterTime":"%s","validBeforeTime":"2099-01-01T00:00:00Z","disabled":false}]' \
    "$(date -u -d '-1 day' +%Y-%m-%dT%H:%M:%SZ)" > "$FIXTURES/keys_runner.json"
  run --separate-stderr gcl-sa-audit -p proj-b --check keys
  [ "$status" -eq 0 ]
  [[ "$output" == *$'key=fresh1 created='*$'\t-'* ]]
  [[ "$stderr" == *"✅ No findings."* ]]
}

@test "keys: a key whose creation date cannot be read is UNKNOWN_AGE, not clean" {
  printf '[{"name":"k/odd1","validAfterTime":"not-a-date","validBeforeTime":"2099-01-01T00:00:00Z","disabled":false}]' > "$FIXTURES/keys_runner.json"
  run --separate-stderr gcl-sa-audit -p proj-b --check keys
  [ "$status" -eq 0 ]
  [[ "$output" == *$'key=odd1 created=not-a-date expires=2099-01-01\tUNKNOWN_AGE'* ]]
  [[ "$stderr" != *"✅"* ]]
  [[ "$stderr" == *"1 findings across 1 service accounts in 1 projects"* ]]
}
