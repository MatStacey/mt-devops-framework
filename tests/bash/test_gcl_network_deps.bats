#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcl-network-deps in .bash.d/10-infra/36-gcp-network.sh
# ------------------------------------------
# gcloud is a stub that logs its argv and serves fixtures from
# tests/bash/fixtures/gcl_network_deps; STUB_DENY=<section word> makes that list fail
# with a permission error.

bats_require_minimum_version 1.5.0

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  CALLS="$BATS_TEST_TMPDIR/calls"
  FIXTURES="$repo_root/tests/bash/fixtures/gcl_network_deps"
  export CALLS FIXTURES
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
echo "gcloud $*" >> "$CALLS"
region=""
for arg in "$@"; do
  case "$arg" in
    --region=* | --location=*) region="${arg#*=}" ;;
  esac
done
serve() { if [ -f "$FIXTURES/$1.json" ]; then cat "$FIXTURES/$1.json"; else echo '[]'; fi; }
if [ -n "${STUB_DENY:-}" ] && [[ " $* " == *" $STUB_DENY "* ]]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'run.services.list' denied on resource" >&2
  exit 1
fi
case "$1 $2 $3" in
  "auth list "*) echo "me@example.test" ;;
  "compute networks describe")
    if [ -f "$FIXTURES/network-$4.json" ]; then cat "$FIXTURES/network-$4.json"; else echo "ERROR: (gcloud) The resource '$4' was not found" >&2; exit 1; fi ;;
  "compute networks subnets") serve subnets ;;
  "compute networks vpc-access")
    if [ "$4" = "locations" ] && [ -n "${STUB_LOCATIONS_FAIL:-}" ]; then
      echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'vpcaccess.locations.list' denied" >&2
      exit 1
    elif [ "$4" = "locations" ]; then printf 'europe-west1\nus-central1\n'; else serve "connectors-$region"; fi ;;
  "compute instances list") serve instances ;;
  "compute instance-groups list") serve instance_groups ;;
  "compute network-endpoint-groups list") serve negs ;;
  "compute backend-services list") serve backend_services ;;
  "compute url-maps list") serve url_maps ;;
  "compute target-http-proxies list") serve http_proxies ;;
  "compute target-https-proxies list") serve https_proxies ;;
  "compute target-tcp-proxies list") serve tcp_proxies ;;
  "compute target-ssl-proxies list") serve ssl_proxies ;;
  "compute forwarding-rules list") serve forwarding_rules ;;
  "compute routers list") serve routers ;;
  "compute firewall-rules list") serve firewalls ;;
  "compute addresses list") serve addresses ;;
  "run services list") serve run ;;
  "functions list "*) serve functions ;;
  "redis instances list") serve redis ;;
  "sql instances list") serve sql ;;
  "scheduler jobs list") serve "scheduler-$region" ;;
  "run jobs list") serve run_jobs ;;
  "scheduler locations list")
    if [ -n "${STUB_LOCATIONS_FAIL:-}" ]; then
      echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'cloudscheduler.locations.list' denied" >&2
      exit 1
    fi
    printf 'europe-west1\nus-central1\n' ;;
  *) echo '[]' ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/32-gcp-survey.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/36-gcp-network.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET="" C_DIM=""
  GCP_SCAN_REGIONS="europe-west2"
  # shellcheck disable=SC2317
  mt-help() { echo "help called"; }
  gcl-get-project() { echo "proj-a"; }
  gcl-get-user() { echo "me@example.test"; }
  gcl-auth-check() { return 0; }
  METRIC_CALLS="$BATS_TEST_TMPDIR/metric_calls"
  export METRIC_CALLS
  # shellcheck disable=SC2317
  gcl-metric-read() {
    echo "gcl-metric-read $*" >> "$METRIC_CALLS"
    case "$1" in
      run.googleapis.com/request_count)
        [ -n "${STUB_RUN_METRIC_DENIED:-}" ] && return 5
        echo '[{"resource":{"labels":{"service_name":"svc-a"}},"points":[{"value":{"int64Value":"12"}}]},{"resource":{"labels":{"service_name":"elsewhere"}},"points":[{"value":{"int64Value":"99"}}]}]'
        ;;
      loadbalancing.googleapis.com/https/request_count)
        echo '[{"resource":{"labels":{"forwarding_rule_name":"fr1"}},"points":[{"value":{"doubleValue":7.0}}]}]'
        ;;
      *) return 0 ;;
    esac
  }
}

kinds_of() { cut -f1,2 <<< "$output"; }

@test "legacy-net lists its own resources and none of legacy-net-2's" {
  run --separate-stderr gcl-network-deps legacy-net
  [ "$status" -eq 0 ]
  for expected in $'peering\tpeer-1' $'instance\ti1' $'instance-group\tig1' $'router\tr1' $'firewall\tfw1' $'subnet\ts1' $'redis\tred1' $'cloud-sql\tsql1'; do
    [[ "$output" == *"$expected"* ]]
  done
  for unexpected in $'\ti2\t' $'\tig2\t' $'\tr2\t' $'\tfw2\t' $'\ts2\t' $'\tred2\t' $'\ta3\t'; do
    [[ "$output" != *"$unexpected"* ]]
  done
}

@test "the full load-balancer chain is reported" {
  run --separate-stderr gcl-network-deps legacy-net
  local chain
  chain=$(kinds_of)
  for expected in $'instance-group\tig1' $'backend-service\tbs1' $'url-map\tum1' $'target-proxy\tpx1' $'forwarding-rule\tfr1'; do
    [[ "$chain" == *"$expected"* ]]
  done
  [[ "$chain" != *"bs2"* && "$chain" != *"fr2"* ]]
}

@test "router detail lists NAT gateways and an address on a subnet of the network is reported" {
  run --separate-stderr gcl-network-deps legacy-net
  [[ "$output" == *$'router\tr1\teurope-west1\tnat=nat-1'* ]]
  [[ "$output" == *$'address\ta1\teurope-west1\tRESERVED users=1'* ]]
}

@test "an auto-mode network leaves out its auto subnet but lists a custom subnet and the reserved IP on the auto subnet" {
  run --separate-stderr gcl-network-deps auto-net
  [ "$status" -eq 0 ]
  [[ "$output" == *$'subnet\tcustom-sub\t'* ]]
  [[ "$output" != *$'subnet\tauto-net\t'* ]]
  [[ "$output" == *$'address\ta2\t'* ]]
}

@test "serverless consumers of the network are matched; unrelated ones are not" {
  run --separate-stderr gcl-network-deps legacy-net
  [[ "$output" == *$'vpc-connector\tconn-1\teurope-west1'* ]]
  [[ "$output" == *$'cloud-run\tsvc-a\teurope-west1\tconnector=conn-1'* ]]
  [[ "$output" == *$'cloud-run\tsvc-b\teurope-west1\tdirect-vpc'* ]]
  [[ "$output" == *$'function\tfn-1\teurope-west1\tGEN_2 connector=conn-1'* ]]
  [[ "$output" == *$'scheduler\tjob-1\teurope-west1\tsvc-a-abc-ew.a.run.app'* ]]
  [[ "$output" != *"svc-c"* && "$output" != *"svc-d"* && "$output" != *"fn-2"* ]]
  [[ "$output" != *"job-2"* && "$output" != *"job-3"* && "$output" != *"conn-2"* ]]
}

@test "a connector attached through a subnet of the network is matched in that subnet's region" {
  run --separate-stderr gcl-network-deps auto-net
  [[ "$output" == *$'vpc-connector\tconn-3\teurope-west2'* ]]
}

@test "without -r connectors and Scheduler are listed once per region in the union" {
  run --separate-stderr gcl-network-deps legacy-net
  [ "$(grep -c 'vpc-access connectors list --region=europe-west1' "$CALLS")" -eq 1 ]
  [ "$(grep -c 'vpc-access connectors list --region=europe-west2' "$CALLS")" -eq 1 ]
  [ "$(grep -c 'scheduler jobs list --location=europe-west1' "$CALLS")" -eq 1 ]
  [ "$(grep -c 'scheduler jobs list --location=europe-west2' "$CALLS")" -eq 1 ]
  ! grep -q 'us-central1' "$CALLS"
  [[ "$stderr" == *"Regions checked: europe-west1 europe-west2"* ]]
}

@test "-r restricts the regional lists to the given regions" {
  run --separate-stderr gcl-network-deps legacy-net -r europe-west1
  [ "$(grep -c 'vpc-access connectors list' "$CALLS")" -eq 1 ]
  ! grep -q 'connectors list --region=europe-west2' "$CALLS"
  ! grep -q 'scheduler jobs list --location=europe-west2' "$CALLS"
}

@test "--all-regions uses the project's own location lists" {
  run --separate-stderr gcl-network-deps legacy-net --all-regions
  grep -q 'connectors list --region=us-central1' "$CALLS"
  grep -q 'scheduler jobs list --location=us-central1' "$CALLS"
}

@test "the summary warns when resources reference the network and is green when none do" {
  run --separate-stderr gcl-network-deps legacy-net
  [[ "$stderr" == *"resources reference legacy-net; it is not safe to delete"* ]]
  [[ "$stderr" == *"Not covered: Shared VPC service projects"* ]]
  run --separate-stderr gcl-network-deps empty-net -r us-central1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [[ "$stderr" == *"Nothing in proj-a references empty-net"* ]]
}

@test "a denied section is reported, the rest are still printed, and the exit code is 5" {
  STUB_DENY=run run --separate-stderr gcl-network-deps legacy-net
  [ "$status" -eq 5 ]
  [[ "$stderr" == *"Permission denied"* ]]
  [[ "$stderr" == *"run.services.list"* ]]
  [[ "$output" == *$'instance\ti1'* ]]
  [[ "$output" == *$'function\tfn-1'* ]]
  [[ "$output" != *"cloud-run"* ]]
}

@test "an unknown network exits 1" {
  run --separate-stderr gcl-network-deps nosuch-net
  [ "$status" -eq 1 ]
}

@test "bad usage makes no gcloud call" {
  run gcl-network-deps
  [ "$status" -eq 1 ]
  run gcl-network-deps 'Bad_Net'
  [ "$status" -eq 1 ]
  run gcl-network-deps legacy-net -p 'BAD PROJECT'
  [ "$status" -eq 1 ]
  run gcl-network-deps legacy-net -r 'bad region'
  [ "$status" -eq 1 ]
  run gcl-network-deps legacy-net -r europe-west1 --all-regions
  [ "$status" -eq 1 ]
  run gcl-network-deps legacy-net --bogus
  [ "$status" -eq 1 ]
  [ ! -f "$CALLS" ]
}

@test "-h shows help" {
  run gcl-network-deps -h
  [ "$output" = "help called" ]
}

@test "a failed region discovery under --all-regions is not reported as a complete scan" {
  STUB_LOCATIONS_FAIL=1 run --separate-stderr gcl-network-deps legacy-net --all-regions
  [ "$status" -eq 5 ]
  [[ "$stderr" == *"No regions to check for VPC connectors"* ]]
  [[ "$stderr" == *"No regions to check for Scheduler jobs"* ]]
}

@test "a Scheduler job is matched by URL prefix, so a job on another function sharing the host is not" {
  run --separate-stderr gcl-network-deps legacy-net
  [[ "$output" == *$'function\ton\teurope-west1\tGEN_1 connector=conn-1'* ]]
  [[ "$output" == *$'scheduler\thits-on\t'* ]]
  [[ "$output" != *"hits-off"* ]]
  [[ "$output" != *$'\tfunction\toff'* && "$output" != *$'function\toff\t'* ]]
  [[ "$output" != *"job-prefix"* ]]
}

@test "a Direct VPC service that names only a subnetwork is matched in the subnet's region" {
  run --separate-stderr gcl-network-deps legacy-net
  [[ "$output" == *$'cloud-run\tsvc-sub\teurope-west1\tdirect-vpc'* ]]
}

@test "Cloud Run jobs are scanned, with the jobs that run them" {
  run --separate-stderr gcl-network-deps legacy-net
  [[ "$output" == *$'cloud-run-job\tjob-conn\teurope-west1\tconnector=conn-1'* ]]
  [[ "$output" == *$'cloud-run-job\tjob-direct\teurope-west1\tdirect-vpc'* ]]
  [[ "$output" == *$'scheduler\tjob-runs-job\teurope-west1\teurope-west1-run.googleapis.com'* ]]
  [[ "$output" != *"job-other"* && "$output" != *"job-runs-other"* ]]
}

@test "the jobs' regions join the region union" {
  GCP_SCAN_REGIONS="us-central1" run --separate-stderr gcl-network-deps legacy-net
  grep -q 'connectors list --region=europe-west1' "$CALLS"
}

@test "a section whose gcloud output is not JSON is reported once" {
  printf '#!/usr/bin/env bash\necho "gcloud $*" >> "$CALLS"\ncase "$1 $2 $3" in\n  "compute networks describe") cat "$FIXTURES/network-legacy-net.json" ;;\n  "compute firewall-rules list") echo "not json" ;;\n  *) echo "[]" ;;\nesac\n' > "$BATS_TEST_TMPDIR/bin/gcloud"
  run --separate-stderr gcl-network-deps legacy-net -r europe-west1
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"gcloud returned non-JSON output"* ]]
}

@test "--traffic-days adds request counts: matched rules and services, zero for no series, n/a elsewhere" {
  run --separate-stderr gcl-network-deps legacy-net --traffic-days 30
  [ "$status" -eq 0 ]
  [[ "$output" == *$'forwarding-rule\tfr1\tglobal\tEXTERNAL_MANAGED\t7'* ]]
  [[ "$output" == *$'cloud-run\tsvc-a\teurope-west1\tconnector=conn-1\t12'* ]]
  [[ "$output" == *$'cloud-run\tsvc-b\teurope-west1\tdirect-vpc\t0'* ]]
  [[ "$output" == *$'instance\ti1\teurope-west1-b\t-\tn/a'* ]]
  [[ "$output" == *$'cloud-run-job\tjob-conn\teurope-west1\tconnector=conn-1\tn/a'* ]]
  [[ "$stderr" == *"of them served requests in the last 30d"* ]]
  grep -q -- '--since 30d --align window --aligner ALIGN_SUM --reducer REDUCE_SUM --group-by resource.label.service_name --json' "$METRIC_CALLS"
  [ "$(wc -l < "$METRIC_CALLS")" -eq 4 ]
}

@test "an L4 passthrough forwarding rule is n/a" {
  run --separate-stderr gcl-network-deps legacy-net --traffic-days 7
  [[ "$output" == *$'forwarding-rule\tfr3\t'*$'\tINTERNAL\tn/a'* ]]
}

@test "a denied metric call gives ? in that metric's rows and exit 5" {
  STUB_RUN_METRIC_DENIED=1 run --separate-stderr gcl-network-deps legacy-net --traffic-days 30
  [ "$status" -eq 5 ]
  [[ "$output" == *$'cloud-run\tsvc-a\teurope-west1\tconnector=conn-1\t?'* ]]
  [[ "$output" == *$'forwarding-rule\tfr1\tglobal\tEXTERNAL_MANAGED\t7'* ]]
}

@test "without --traffic-days no metrics are read and rows keep four columns" {
  run --separate-stderr gcl-network-deps legacy-net
  [ ! -f "$METRIC_CALLS" ]
  [ -z "$(awk -F'\t' 'NF != 4' <<< "$output")" ]
}

@test "invalid --traffic-days values exit 1 without any call" {
  local value
  for value in 0 abc 43 -1 ""; do
    run gcl-network-deps legacy-net --traffic-days "$value"
    [ "$status" -eq 1 ]
  done
  [ ! -f "$CALLS" ]
  [ ! -f "$METRIC_CALLS" ]
}
