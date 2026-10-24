#!/usr/bin/env bats
# ------------------------------------------
# Bats: read-only GCP wrappers in .bash.d/10-infra/33-gcp-read-only.sh
# ------------------------------------------
# gcloud and bq are replaced by stubs that log their argv and serve
# fixtures; STUB_DENY makes the data calls fail with a permission error.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  mkdir -p "$HOME/.config/gcloud/configurations"
  printf 'project = proj-1\naccount = me@example.test\n' > "$HOME/.config/gcloud/configurations/config_default"
  CALLS="$BATS_TEST_TMPDIR/calls"
  export CALLS
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
echo "gcloud $*" >> "$CALLS"
case "$1 $2" in
  "auth list") echo "me@example.test"; exit 0 ;;
  "auth print-access-token") [ -n "${STUB_REAUTH:-}" ] && { echo "Reauthentication failed" >&2; exit 1; }; echo tok; exit 0 ;;
  "config get-value") echo "proj-1"; exit 0 ;;
esac
if [ -n "${STUB_DENY:-}" ]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'storage.objects.list' denied on resource" >&2
  exit 1
fi
case "$1 $2" in
  "storage ls")
    case "$3" in
      gs://b/pack/\*\*) printf 'gs://b/pack/a.json\ngs://b/pack/b.json\ngs://b/pack/sub/\n' ;;
      gs://b/mods/\*\*) printf 'gs://b/mods/x.json\n' ;;
      gs://b/) printf 'gs://b/pack/\ngs://b/mods/\ngs://b/readme.txt\ngs://b/evil\033]0;pwn\007\302\233x/\n' ;;
    esac ;;
  "storage du") case "$4" in */pack/) echo "2048  gs://b/pack/" ;; *) echo "1024  gs://b/mods/" ;; esac ;;
  "logging read")
    printf 'Pack 12 failed for user a@b.com\nPack 99 failed for user c@d.org\nPack 7 failed for user e@f.io\nStarted request id 3f2a1b9c-1111-2222-3333-444455556666\n\n' ;;
  "iam workload-identity-pools") printf 'name: pool-x\033[31m\n' ;;
esac
STUB
  cat > "$BATS_TEST_TMPDIR/bin/bq" << 'STUB'
#!/usr/bin/env bash
echo "bq $*" >> "$CALLS"
if [ -n "${STUB_DENY:-}" ]; then
  echo "BigQuery error: Access Denied: Project proj-1: User does not have bigquery.jobs.create permission in project proj-1." >&2
  exit 1
fi
case "$*" in
  *--dry_run*) echo "{\"statistics\":{\"totalBytesProcessed\":\"${STUB_BYTES:-1024}\"}}"; exit 0 ;;
esac
echo "col1"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud" "$BATS_TEST_TMPDIR/bin/bq"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/30-gcp-config.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  # shellcheck disable=SC2317
  mt-help() { :; }
}

@test "gcs summary lists prefixes with object counts and sizes" {
  run gcl-gcs-summary gs://b
  [ "$status" -eq 0 ]
  [[ "$output" == *$'pack/\t2\t2.0K'* ]]
  [[ "$output" == *$'mods/\t1\t1.0K'* ]]
  [[ "$output" == *$'(top-level objects)\t1'* ]]
}

@test "gcs summary honours --max" {
  run gcl-gcs-summary gs://b -m 1
  [[ "$output" == *pack/* ]]
  [[ "$output" != *mods/* ]]
}

@test "gcs summary rejects a non-gs location" {
  run gcl-gcs-summary /tmp/x
  [ "$status" -eq 1 ]
}

@test "a permission denial names the missing permission and returns 5" {
  STUB_DENY=1 run gcl-gcs-summary gs://b
  [ "$status" -eq 5 ]
  [[ "$output" == *"Permission denied"* ]]
  [[ "$output" == *storage.objects.list* ]]
}

@test "an expired token stops before any data call" {
  STUB_REAUTH=1 run gcl-gcs-summary gs://b
  [ "$status" -eq 2 ]
  run grep -c "storage ls" "$CALLS"
  [ "$output" = "0" ]
}

@test "run log summary counts templates and never prints raw payloads" {
  run gcl-run-log-summary my-svc
  [ "$status" -eq 0 ]
  [[ "$output" == *$'3\tPack N failed for user EMAIL'* ]]
  [[ "$output" == *$'1\tStarted request id UUID'* ]]
  [[ "$output" != *a@b.com* ]]
}

@test "run log summary scopes to the service and severity" {
  run gcl-run-log-summary my-svc --severity ERROR --limit 5
  grep -q 'service_name="my-svc" AND severity>=ERROR' "$CALLS"
  grep -q -- '--limit=5' "$CALLS"
}

@test "run log summary rejects an injected service name" {
  run gcl-run-log-summary 'x" OR 1=1'
  [ "$status" -eq 1 ]
}

@test "bq query runs a SELECT" {
  run gcl-bq-query "SELECT 1"
  [ "$status" -eq 0 ]
  [[ "$output" == *col1* ]]
  grep -q -- '--project_id=proj-1' "$CALLS"
}

@test "bq query accepts WITH and a trailing semicolon" {
  run gcl-bq-query "WITH t AS (SELECT 1) SELECT * FROM t;"
  [ "$status" -eq 0 ]
}

@test "bq query rejects data-changing and multi-statement SQL without calling bq" {
  for sql in "DELETE FROM t WHERE 1=1" "SELECT 1; DROP TABLE t" "SELECT 1 UNION ALL SELECT 2; SELECT 3" "CREATE TABLE x AS SELECT 1" "INSERT INTO t SELECT 1" "SELECT '--', 1; DROP TABLE t" $'SELECT 1;\nSELECT 2' $'UNDROP SCHEMA p.d\nselect 1' $'-- hi\nDROP TABLE t'; do
    run gcl-bq-query "$sql"
    [ "$status" -eq 1 ]
  done
  run grep -q "^bq " "$CALLS"
  [ "$status" -ne 0 ]
}

@test "bq query accepts multi-line SELECT/WITH and ordinary identifiers" {
  for sql in $'SELECT\n  load, created FROM t' $'WITH\n a AS (SELECT 1)\nSELECT * FROM a' "SELECT 1 -- note" "select x from t where y LIKE '%#%'"; do
    run gcl-bq-query "$sql"
    [ "$status" -eq 0 ]
  done
}

@test "bq permission failure names bigquery.jobs.create and returns 5" {
  STUB_DENY=1 run gcl-bq-query "SELECT 1"
  [ "$status" -eq 5 ]
  [[ "$output" == *bigquery.jobs.create* ]]
}

@test "wif describe shows the pool and its providers" {
  run gcl-wif-describe pool-x
  [ "$status" -eq 0 ]
  grep -q "providers list --workload-identity-pool=pool-x" "$CALLS"
}

@test "wif describe reports a permission denial" {
  STUB_DENY=1 run gcl-wif-describe pool-x
  [ "$status" -eq 5 ]
}

@test "terminal control characters never reach the output" {
  run gcl-gcs-summary gs://b
  [[ "$output" != *$'\033'* ]]
  [[ "$output" != *$'\a'* ]]
  [[ "$output" != *$'\xc2\x9b'* ]]
  run gcl-wif-describe pool-x
  [[ "$output" != *$'\033'* ]]
}

@test "control characters in error text are stripped" {
  run __mt_gcl_report_failure "ctx" $'boom \033[31m bad'
  [[ "$output" != *$'\033'* ]]
}

@test "the executed statement is exactly the validated one" {
  run gcl-bq-query "SELECT 1 ;  "
  [ "$status" -eq 0 ]
  grep -qx "bq query --project_id=proj-1 --use_legacy_sql=false --format=pretty --maximum_bytes_billed=10737418240 SELECT 1" "$CALLS"
}

@test "literal backslash escapes in error text are not expanded into control characters" {
  run __mt_gcl_report_failure "ctx" 'name \033[2J and \e]0;x\a'
  [[ "$output" != *$'\033'* ]]
  [[ "$output" == *'\033[2J'* ]]
}

@test "log templates mask URLs and long tokens" {
  run bash -c 'printf "%s\n" "GET https://x.example/a?k=abc fetched token QWxhZGRpbjpvcGVuIHNlc2FtZQ12345 ok" | sed -E -f "$1"' _ "$repo_root/.bash.d/lib/sed/log_template.sed"
  [[ "$output" == *URL* ]]
  [[ "$output" == *TOKEN* ]]
  [[ "$output" != *QWxhZ* ]]
}

@test "bq query dry-runs first and passes the cap as --maximum_bytes_billed" {
  run gcl-bq-query "SELECT 1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Estimated scan: 1.0K (cap 10G)"* ]]
  [ "$(grep -c '^bq ' "$CALLS")" -eq 2 ]
  [[ "$(grep '^bq ' "$CALLS" | sed -n 1p)" == *"--dry_run"* ]]
  [[ "$(grep '^bq ' "$CALLS" | sed -n 2p)" == *"--maximum_bytes_billed=10737418240"* ]]
}

@test "bq query over the cap is refused and the real query never runs" {
  STUB_BYTES=20000000000 run gcl-bq-query "SELECT 1"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--max-bytes"* ]]
  [ "$(grep -c '^bq ' "$CALLS")" -eq 1 ]
  [[ "$(grep '^bq ' "$CALLS")" == *"--dry_run"* ]]
}

@test "bq query --dry-run prints the estimate and never runs the query" {
  run gcl-bq-query --dry-run "SELECT 1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Estimated scan"* ]]
  [[ "$output" != *col1* ]]
  [ "$(grep -c '^bq ' "$CALLS")" -eq 1 ]
}

@test "bq query --max-bytes overrides the configured cap and accepts IEC suffixes" {
  GCP_BQ_MAX_BYTES_BILLED=1000 STUB_BYTES=5000 run gcl-bq-query "SELECT 1"
  [ "$status" -eq 1 ]
  GCP_BQ_MAX_BYTES_BILLED=1000 STUB_BYTES=5000 run gcl-bq-query --max-bytes 1M "SELECT 1"
  [ "$status" -eq 0 ]
  grep -q -- '--maximum_bytes_billed=1048576' "$CALLS"
}

@test "bq query honours the configured cap" {
  GCP_BQ_MAX_BYTES_BILLED=2048 STUB_BYTES=4096 run gcl-bq-query "SELECT 1"
  [ "$status" -eq 1 ]
}

@test "bq query rejects an invalid --max-bytes before calling bq" {
  run gcl-bq-query --max-bytes lots "SELECT 1"
  [ "$status" -eq 1 ]
  ! grep -q '^bq ' "$CALLS" 2> /dev/null
}

@test "bq query with a denied dry run names the missing permission and returns 5" {
  STUB_DENY=1 run gcl-bq-query --dry-run "SELECT 1"
  [ "$status" -eq 5 ]
  [[ "$output" == *bigquery.jobs.create* ]]
}

@test "bq byte-size parser handles plain numbers and suffixes" {
  [ "$(__mt_gcl_parse_bytes 500)" = "500" ]
  [ "$(__mt_gcl_parse_bytes 2K)" = "2048" ]
  [ "$(__mt_gcl_parse_bytes 1G)" = "1073741824" ]
  run __mt_gcl_parse_bytes 5X
  [ "$status" -eq 1 ]
}
