#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-sku-price in .bash.d/10-infra/34-gcp-observability.sh
# ------------------------------------------
# __mt_gcl_rest is a stub that serves fixture JSON by URL and logs each call;
# STUB_REST_RC makes every call fail with that code.

bats_require_minimum_version 1.5.0

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  FIXTURES="$repo_root/tests/bash/fixtures/gcl_sku_price"
  CACHE_DIR="$BATS_TEST_TMPDIR/cache"
  CALLS="$BATS_TEST_TMPDIR/calls"
  export FIXTURES CACHE_DIR CALLS
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/34-gcp-observability.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  unset GCL_BILLING_CURRENCY
  # shellcheck disable=SC2317
  mt-help() { echo "help called"; }
  gcl-auth-check() { return 0; }
  # shellcheck disable=SC2317
  __mt_gcl_rest() {
    echo "REST $2 $3 ${*:5}" >> "$CALLS"
    if [ -n "${STUB_REST_RC:-}" ]; then
      echo "denied" >&2
      return "$STUB_REST_RC"
    fi
    case "$3" in
      */v1/services) cat "$FIXTURES/services.json" ;;
      */skus) cat "$FIXTURES/skus.json" ;;
    esac
  }
}

@test "an exact display-name match wins over substring matches" {
  run --separate-stderr gcl-sku-price "cloud run"
  [ "$status" -eq 0 ]
  grep -q 'services/RUN-1/skus' "$CALLS"
  ! grep -q 'RUN-2' "$CALLS"
}

@test "an ambiguous substring lists the matches and exits 1 without a SKU call" {
  run --separate-stderr gcl-sku-price "cloud s"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *$'CS-1\tCloud Storage'* ]]
  [[ "$stderr" == *$'CSQ-1\tCloud SQL'* ]]
  ! grep -q '/skus' "$CALLS"
}

@test "a single substring match is used" {
  run --separate-stderr gcl-sku-price "compute"
  [ "$status" -eq 0 ]
  grep -q 'services/CE-1/skus' "$CALLS"
}

@test "no matching service exits 1" {
  run --separate-stderr gcl-sku-price "nonexistent"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"No billing service matches 'nonexistent'"* ]]
}

@test "the SKU call carries the page size and currency" {
  run --separate-stderr gcl-sku-price "Cloud Run" --currency GBP
  grep -q 'pageSize=5000 -q currencyCode=GBP' "$CALLS"
}

@test "a two-tier SKU gives two rows and prices are built without floating point" {
  run --separate-stderr gcl-sku-price "Cloud Run"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'CPU Allocation Time\ts\t0\t0.0000125'* ]]
  [[ "$output" == *$'CPU Allocation Time\ts\t180000\t0'* ]]
  [[ "$output" == *$'Memory Allocation Time\tGiBy.s\t0\t1.5'* ]]
  [[ "$output" == *$'Requests\tcount\t0\t10'* ]]
  [[ "$output" != *e-* ]]
  [ "$(wc -l <<< "$output")" -eq 4 ]
}

@test "rows are sorted by description then tier start" {
  run --separate-stderr gcl-sku-price "Cloud Run"
  [ "$(cut -f1 <<< "$output" | head -1)" = "CPU Allocation Time" ]
  [ "$(cut -f3 <<< "$output" | head -2 | tail -1)" = "180000" ]
  [ "$(cut -f1 <<< "$output" | tail -1)" = "Requests" ]
}

@test "--region keeps only SKUs available there" {
  run --separate-stderr gcl-sku-price "Cloud Run" --region us-central1
  [[ "$output" == *"Memory Allocation Time"* ]]
  [[ "$output" == *"Requests"* ]]
  [[ "$output" != *"CPU Allocation Time"* ]]
}

@test "--match filters descriptions case-insensitively" {
  run --separate-stderr gcl-sku-price "Cloud Run" --match 'cpu|requests'
  [[ "$output" == *"CPU Allocation Time"* ]]
  [[ "$output" == *"Requests"* ]]
  [[ "$output" != *"Memory"* ]]
}

@test "no SKU after filtering prints an info line and exits 0" {
  run --separate-stderr gcl-sku-price "Cloud Run" --match 'zzz-none'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" == *"No SKUs match."* ]]
}

@test "the second run reuses the cached service list" {
  gcl-sku-price "Cloud Run" > /dev/null
  gcl-sku-price "Compute" > /dev/null
  [ "$(grep -c 'v1/services ' "$CALLS")" -eq 1 ]
  [ -f "$CACHE_DIR/gcp_billing_services.tsv" ]
}

@test "a cache older than the TTL is refetched" {
  gcl-sku-price "Cloud Run" > /dev/null
  touch -d '8 days ago' "$CACHE_DIR/gcp_billing_services.tsv"
  gcl-sku-price "Cloud Run" > /dev/null
  [ "$(grep -c 'v1/services ' "$CALLS")" -eq 2 ]
}

@test "a failed services call leaves no cache file and passes the code through" {
  STUB_REST_RC=1 run --separate-stderr gcl-sku-price "Cloud Run"
  [ "$status" -eq 1 ]
  [ ! -f "$CACHE_DIR/gcp_billing_services.tsv" ]
  [ -z "$(find "$CACHE_DIR" -type f 2> /dev/null)" ]
}

@test "a denied call exits 5" {
  STUB_REST_RC=5 run --separate-stderr gcl-sku-price "Cloud Run"
  [ "$status" -eq 5 ]
}

@test "bad currency, region and match regex exit 1 without any call" {
  run gcl-sku-price "Cloud Run" --currency gbp
  [ "$status" -eq 1 ]
  run gcl-sku-price "Cloud Run" --region 'Bad Region'
  [ "$status" -eq 1 ]
  run --separate-stderr gcl-sku-price "Cloud Run" --match '('
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"Invalid --match regex"* ]]
  run gcl-sku-price
  [ "$status" -eq 1 ]
  [ ! -f "$CALLS" ]
}

@test "GCL_BILLING_CURRENCY from config is the default currency" {
  GCL_BILLING_CURRENCY=EUR run --separate-stderr gcl-sku-price "Cloud Run"
  grep -q 'currencyCode=EUR' "$CALLS"
}

@test "-h shows help" {
  run gcl-sku-price -h
  [ "$output" = "help called" ]
}
