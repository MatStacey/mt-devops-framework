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
  source "$repo_bashd/20-vcs/58-infra-gcp-scan.sh"

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

@test "__mt_radar_gcp_check_resource matches on the Terraform label with no fallback needed" {
  cat > "$fake_bin/gcloud" << 'EOF'
#!/usr/bin/env bash
[[ "$*" == *"metadata.name=run"* ]] && echo '[{"metadata":{"name":"run","labels":{"cloud.googleapis.com/location":"europe-west1"}},"status":{"url":"https://run-x.a.run.app"}}]'
EOF
  chmod +x "$fake_bin/gcloud"

  run __mt_radar_gcp_check_resource "google_cloud_run_service" "run" "some-project" "connect-api"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
  [ "$(echo "$output" | jq -r '.matched_name')" = "null" ]
}

@test "__mt_radar_gcp_check_resource falls back to the repo name when the Terraform label doesn't match" {
  cat > "$fake_bin/gcloud" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"metadata.name=connect-api"* ]]; then
  echo '[{"metadata":{"name":"connect-api","labels":{"cloud.googleapis.com/location":"europe-west1"}},"status":{"url":"https://connect-api-x.a.run.app"}}]'
else
  echo '[]'
fi
EOF
  chmod +x "$fake_bin/gcloud"

  run __mt_radar_gcp_check_resource "google_cloud_run_service" "run" "production-cloud-connect" "connect-api"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.deployed')" = "true" ]
  [ "$(echo "$output" | jq -r '.matched_name')" = "connect-api" ]
  [ "$(echo "$output" | jq -r '.region')" = "europe-west1" ]
  [[ "$(echo "$output" | jq -r '.console_url')" == *"/connect-api/"* ]]
}

@test "__mt_radar_gcp_check_resource reports not-deployed when neither the label nor the fallback match" {
  cat > "$fake_bin/gcloud" << 'EOF'
#!/usr/bin/env bash
echo '[]'
EOF
  chmod +x "$fake_bin/gcloud"

  run __mt_radar_gcp_check_resource "google_cloud_run_service" "run" "some-project" "connect-api"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.deployed')" = "false" ]
  [ "$(echo "$output" | jq -r '.matched_name')" = "null" ]
}

@test "__mt_radar_gcp_check_resource skips the fallback lookup entirely when no fallback name is given" {
  cat > "$fake_bin/gcloud" << 'EOF'
#!/usr/bin/env bash
echo "$*" >> "$CALL_LOG"
echo '[]'
EOF
  chmod +x "$fake_bin/gcloud"
  export CALL_LOG="$BATS_TEST_TMPDIR/gcloud_calls.log"

  run __mt_radar_gcp_check_resource "google_cloud_run_service" "run" "some-project"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$CALL_LOG")" -eq 1 ]
}
