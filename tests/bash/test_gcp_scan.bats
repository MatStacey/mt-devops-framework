#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# ------------------------------------------
# Bats: __mt_radar_detect_environments (.bash.d/20-vcs/53-vcs-insight.sh)
# and __mt_radar_gcp_check_resource's fallback-name matching
# (.bash.d/20-vcs/58-infra-gcp-scan.sh)
# ------------------------------------------
# Covers two real bugs reported against a live repo (connect-api):
#
# 1. The "Environments" pills showed vague AI-guessed names instead of
#    "<TYPE>: GCP - <project-id>" -- __mt_radar_detect_environments adds a
#    deterministic heuristic for the common terraform/environments/<env>/
#    layout, extracting a literal project ID (never a var/local
#    reference -- same "don't guess" caution as __mt_radar_detect_gcp)
#    from each environment subfolder's own .tf files.
#
# 2. The GCP deployment scan reported connect-api's Cloud Run service as
#    "not found" even though it's definitely deployed -- the scan looked
#    up the live resource by its Terraform resource *label*
#    (`google_cloud_run_service.run`), but the resource's real name comes
#    from `name = var.service_name`, set to the repo's own name
#    ("connect-api") elsewhere. __mt_radar_gcp_check_resource now retries
#    with a fallback candidate name (the repo's own basename) whenever
#    the label doesn't match anything live.
#
# gcloud is stubbed on PATH for the resource-check tests -- no real
# network/API calls. Both files have no top-level side effects, so
# they're sourced directly, same as 56-audit.sh in test_deps_audit.bats.

setup() {
  repo_bashd="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/.bash.d"

  # shellcheck disable=SC1091
  source "$repo_bashd/20-vcs/53-vcs-insight.sh"
  # shellcheck disable=SC1091
  source "$repo_bashd/20-vcs/57-infra.sh"
  # shellcheck disable=SC1091
  source "$repo_bashd/20-vcs/58-infra-gcp-scan.sh"

  # The scan resolves its registry and the awk extractor via $HOME/.bash.d.
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  ln -s "$repo_bashd" "$HOME/.bash.d"

  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  PATH="$fake_bin:$PATH"

  repo_dir="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo_dir"
}

# ---------- __mt_radar_detect_environments ----------

@test "__mt_radar_detect_environments extracts a literal project ID per environment folder" {
  mkdir -p "$repo_dir/terraform/environments/dev/deploy-cloud-run"
  mkdir -p "$repo_dir/terraform/environments/production/deploy-cloud-run"
  cat > "$repo_dir/terraform/environments/dev/deploy-cloud-run/main.tf" << 'EOF'
locals {
  project_name = "dev-cloud-connect"
}
EOF
  cat > "$repo_dir/terraform/environments/production/deploy-cloud-run/main.tf" << 'EOF'
locals {
  project_name = "production-cloud-connect"
}
EOF

  run __mt_radar_detect_environments "$repo_dir"
  [ "$status" -eq 0 ]

  local dev_name dev_type prod_name
  dev_name=$(echo "$output" | jq -r '.[] | select(.type == "dev") | .name')
  dev_type=$(echo "$output" | jq -r '.[] | select(.type == "dev") | .type')
  prod_name=$(echo "$output" | jq -r '.[] | select(.type == "prod") | .name')

  [ "$dev_name" = "DEV: GCP - dev-cloud-connect" ]
  [ "$dev_type" = "dev" ]
  [ "$prod_name" = "PROD: GCP - production-cloud-connect" ]
}

@test "__mt_radar_detect_environments falls back to the folder name when no literal project ID is found" {
  mkdir -p "$repo_dir/terraform/environments/stage/deploy-cloud-run"
  cat > "$repo_dir/terraform/environments/stage/deploy-cloud-run/main.tf" << 'EOF'
locals {
  project_name = local.some_computed_value
}
EOF

  run __mt_radar_detect_environments "$repo_dir"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.[0].name')" = "STAGING: stage" ]
  [ "$(echo "$output" | jq -r '.[0].type')" = "staging" ]
}

@test "__mt_radar_detect_environments dedupes identical (type, project) pairs across sibling folders" {
  mkdir -p "$repo_dir/terraform/environments/stage/deploy-cloud-run"
  mkdir -p "$repo_dir/terraform/environments/stage-pd/deploy-cloud-run"
  for d in stage stage-pd; do
    cat > "$repo_dir/terraform/environments/$d/deploy-cloud-run/main.tf" << 'EOF'
locals {
  project_name = "stage-cloud-connect"
}
EOF
  done

  run __mt_radar_detect_environments "$repo_dir"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq 'length')" -eq 1 ]
}

@test "__mt_radar_detect_environments returns an empty array when there's no environments folder" {
  run __mt_radar_detect_environments "$repo_dir"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

# ---------- __mt_radar_gcp_check_resource: fallback-name matching ----------

# ---------- __mt_radar_gcp_check_resource / __mt_radar_gcp_list_resources ----------
# gcloud stubs print a fixed list for the command under test; matching is
# done client-side, so a stub only needs to return the project's whole list.

stub_gcloud() {
  cat > "$fake_bin/gcloud" << EOF
#!/usr/bin/env bash
echo "\$*" >> "$BATS_TEST_TMPDIR/gcloud_calls.log"
$1
EOF
  chmod +x "$fake_bin/gcloud"
}

RUN_LIST='echo '"'"'[{"metadata":{"name":"connect-api","labels":{"cloud.googleapis.com/location":"europe-west1"}},"status":{"url":"https://connect-api-x.a.run.app"}}]'"'"

@test "check_resource matches on the Terraform label with no fallback needed" {
  stub_gcloud "echo '[{\"metadata\":{\"name\":\"run\",\"labels\":{\"cloud.googleapis.com/location\":\"europe-west1\"}},\"status\":{\"url\":\"https://run-x.a.run.app\"}}]'"

  run __mt_radar_gcp_check_resource "google_cloud_run_service" "run" "some-project" "connect-api"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
  [ "$(echo "$output" | jq -r '.matched_name')" = "null" ]
  [ "$(echo "$output" | jq -r '.group')" = "compute" ]
}

@test "check_resource falls back to the repo name when the Terraform label doesn't match" {
  stub_gcloud "$RUN_LIST"

  run __mt_radar_gcp_check_resource "google_cloud_run_service" "run" "production-cloud-connect" "connect-api"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
  [ "$(echo "$output" | jq -r '.matched_name')" = "connect-api" ]
  [ "$(echo "$output" | jq -r '.region')" = "europe-west1" ]
  [ "$(echo "$output" | jq -r '.live_url')" = "https://connect-api-x.a.run.app" ]
  [[ "$(echo "$output" | jq -r '.console_url')" == *"/europe-west1/connect-api/"* ]]
}

@test "check_resource reports not-deployed when nothing in the live list matches" {
  stub_gcloud "echo '[]'"

  run __mt_radar_gcp_check_resource "google_cloud_run_service" "run" "some-project" "connect-api"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.deployed')" = "false" ]
  [ "$(echo "$output" | jq -r '.reason')" = "null" ]
}

@test "check_resource prefers a literal attribute name over the Terraform label" {
  stub_gcloud "echo '[{\"name\":\"projects/p/topics/cp-update\"},{\"name\":\"projects/p/topics/cp_update_label\"}]'"

  run __mt_radar_gcp_check_resource "google_pubsub_topic" "cp_update_label" "p" "" '{"name":"cp-update"}'
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
  [ "$(echo "$output" | jq -r '.matched_name')" = "cp-update" ]
  [ "$(echo "$output" | jq -r '.group')" = "messaging" ]
}

@test "check_resource matches a label with underscores against its dashed live name" {
  stub_gcloud "echo '[{\"name\":\"projects/p/topics/cp-update\"}]'"

  run __mt_radar_gcp_check_resource "google_pubsub_topic" "cp_update" "p"
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
  [ "$(echo "$output" | jq -r '.matched_name')" = "cp-update" ]
}

@test "check_resource uses the type's own identifying attribute (service account account_id)" {
  stub_gcloud "echo '[{\"email\":\"jwt-generator@p.iam.gserviceaccount.com\"},{\"email\":\"other@p.iam.gserviceaccount.com\"}]'"

  run __mt_radar_gcp_check_resource "google_service_account" "function_runtime" "p" "" '{"account_id":"jwt-generator"}'
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
  [ "$(echo "$output" | jq -r '.group')" = "iam" ]
}

@test "check_resource matches a BigQuery dataset via bq by dataset_id" {
  cat > "$fake_bin/bq" << 'EOF'
#!/usr/bin/env bash
echo '[{"datasetReference":{"datasetId":"telemetry","projectId":"p"},"location":"EU"}]'
EOF
  chmod +x "$fake_bin/bq"

  run __mt_radar_gcp_check_resource "google_bigquery_dataset" "telemetry_ds" "p" "" '{"dataset_id":"telemetry"}'
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
  [ "$(echo "$output" | jq -r '.region')" = "EU" ]
  [ "$(echo "$output" | jq -r '.group')" = "data" ]
}

@test "check_resource treats empty bq output as an empty list, not an error" {
  printf '#!/usr/bin/env bash\n' > "$fake_bin/bq"
  chmod +x "$fake_bin/bq"

  run __mt_radar_gcp_check_resource "google_bigquery_dataset" "x" "p"
  [ "$(echo "$output" | jq -r '.deployed')" = "false" ]
  [ "$(echo "$output" | jq -r '.reason')" = "null" ]
}

@test "check_resource reports unsupported for a type missing from the registry" {
  run __mt_radar_gcp_check_resource "google_project_iam_member" "x" "p"
  [ "$(echo "$output" | jq -r '.supported')" = "false" ]
  [ "$(echo "$output" | jq -r '.reason')" = "unsupported-resource-type" ]
  [ "$(echo "$output" | jq -r '.group')" = "null" ]
}

@test "check_resource reports permission-denied when the list call is denied" {
  stub_gcloud 'echo "ERROR: PERMISSION_DENIED: nope" >&2; exit 1'

  run __mt_radar_gcp_check_resource "google_cloud_run_service" "run" "p"
  [ "$(echo "$output" | jq -r '.deployed')" = "false" ]
  [ "$(echo "$output" | jq -r '.reason')" = "permission-denied" ]
}

@test "list_resources makes one call per spec and reuses the cache for every resource of that type" {
  stub_gcloud "echo '[{\"name\":\"projects/p/topics/a\"},{\"name\":\"projects/p/topics/b\"}]'"
  cache_dir="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$cache_dir"

  __mt_radar_gcp_check_resource "google_pubsub_topic" "a" "p" "" "{}" "$cache_dir" > /dev/null
  __mt_radar_gcp_check_resource "google_pubsub_topic" "b" "p" "" "{}" "$cache_dir" > /dev/null
  run __mt_radar_gcp_check_resource "google_pubsub_topic" "c" "p" "" "{}" "$cache_dir"
  [ "$(echo "$output" | jq -r '.deployed')" = "false" ]
  [ "$(wc -l < "$BATS_TEST_TMPDIR/gcloud_calls.log")" -eq 1 ]
}

@test "list_resources caches a failure too, so a denied type isn't retried per resource" {
  stub_gcloud 'echo "PERMISSION_DENIED" >&2; exit 1'
  cache_dir="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$cache_dir"

  __mt_radar_gcp_check_resource "google_pubsub_topic" "a" "p" "" "{}" "$cache_dir" > /dev/null
  __mt_radar_gcp_check_resource "google_pubsub_topic" "b" "p" "" "{}" "$cache_dir" > /dev/null
  [ "$(wc -l < "$BATS_TEST_TMPDIR/gcloud_calls.log")" -eq 1 ]
}

@test "list_resources queries every configured region for a regional spec and merges the results" {
  GCP_SCAN_REGIONS="europe-west1 europe-west2"
  stub_gcloud 'case "$*" in
  *region=europe-west1*) echo "[{\"name\":\"projects/p/locations/europe-west1/instances/cache-a\"}]" ;;
  *region=europe-west2*) echo "[{\"name\":\"projects/p/locations/europe-west2/instances/cache-b\"}]" ;;
esac'

  run __mt_radar_gcp_check_resource "google_redis_instance" "cache_b" "p"
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
  [ "$(echo "$output" | jq -r '.region')" = "europe-west2" ]
  [ "$(wc -l < "$BATS_TEST_TMPDIR/gcloud_calls.log")" -eq 2 ]
}

@test "a regional spec still succeeds when only one region's call fails" {
  GCP_SCAN_REGIONS="europe-west1 europe-west2"
  stub_gcloud 'case "$*" in
  *region=europe-west1*) echo "PERMISSION_DENIED" >&2; exit 1 ;;
  *region=europe-west2*) echo "[{\"name\":\"projects/p/locations/europe-west2/instances/cache-b\"}]" ;;
esac'

  run __mt_radar_gcp_check_resource "google_redis_instance" "cache_b" "p"
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
}

# ---------- registry integrity ----------

@test "every registry type points at an existing spec with a command and a name extractor" {
  run jq -r '. as $r | .types | to_entries[] | select(($r.specs[.value.spec] // null) == null) | .key' "$repo_bashd/lib/registry/gcp_scan_types.json"
  [ -z "$output" ]
  run jq -r '.specs | to_entries[] | select((.value.cmd | length) == 0 or (.value.name_jq // "") == "") | .key' "$repo_bashd/lib/registry/gcp_scan_types.json"
  [ -z "$output" ]
}

@test "every registry command carries the project placeholder, and regional ones the region placeholder" {
  run jq -r '.specs | to_entries[] | select((.value.cmd | join(" ") | contains("{project}")) | not) | .key' "$repo_bashd/lib/registry/gcp_scan_types.json"
  [ -z "$output" ]
  run jq -r '.specs | to_entries[] | select(.value.regional == true and ((.value.cmd | join(" ") | contains("{region}")) | not)) | .key' "$repo_bashd/lib/registry/gcp_scan_types.json"
  [ -z "$output" ]
}

# ---------- scan_repo end to end ----------

@test "scan_repo aggregates statuses across types using shared list calls" {
  stub_gcloud 'case "$*" in
  *"pubsub topics"*) echo "[{\"name\":\"projects/p/topics/cp-update\"}]" ;;
  *"secrets list"*) echo "[]" ;;
esac'
  infra='{"resources":{"messaging":[{"type":"google_pubsub_topic","name":"cp_update","attrs":{}}],"iam":[{"type":"google_secret_manager_secret","name":"api_key","attrs":{"secret_id":"api-key"}},{"type":"google_project_iam_member","name":"x","attrs":{}}]}}'

  run __mt_radar_gcp_scan_repo "$infra" "p" "some-repo"
  [ "$(echo "$output" | jq -r '.checked_count')" = "2" ]
  [ "$(echo "$output" | jq -r '.deployed_count')" = "1" ]
  [ "$(echo "$output" | jq -r '.unsupported_count')" = "1" ]
  [ "$(echo "$output" | jq -r '.sync_status')" = "amber" ]
}

# ---------- tf_resources.awk ----------

@test "tf_resources.awk captures top-level literal attributes and skips variables and nested blocks" {
  cat > "$repo_dir/main.tf" << 'EOF'
resource "google_pubsub_topic" "cp_update" {
  name = "cp-update"
}
resource "google_cloud_run_service" "run" {
  name = var.service_name
  template {
    metadata {
      name = "nested-should-not-count"
    }
  }
}
resource "google_service_account" "sa" {
  account_id = "my-sa" # trailing comment
  display_name = "ignored"
}
resource "google_storage_bucket" "b" {
  name = "${var.env}-bucket"
}
EOF
  run awk -f "$repo_bashd/lib/awk/tf_resources.awk" "$repo_dir/main.tf"
  [ "${lines[0]}" = $'google_pubsub_topic\tcp_update\tname\tcp-update' ]
  [ "${lines[1]}" = $'google_cloud_run_service\trun' ]
  [ "${lines[2]}" = $'google_service_account\tsa\taccount_id\tmy-sa' ]
  [ "${lines[3]}" = $'google_storage_bucket\tb' ]
}

@test "__mt_radar_infra_analyze_repo carries each resource's literal attrs" {
  cat > "$repo_dir/main.tf" << 'EOF'
resource "google_pubsub_topic" "cp_update" {
  name = "cp-update"
}
EOF
  run __mt_radar_infra_analyze_repo "$repo_dir"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.resources.messaging[0].attrs.name')" = "cp-update" ]
}
