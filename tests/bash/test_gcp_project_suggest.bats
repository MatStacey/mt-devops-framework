#!/usr/bin/env bats
# ------------------------------------------
# Bats: __mt_radar_gcp_suggest_projects in .bash.d/20-vcs/58-infra-gcp-scan.sh
# ------------------------------------------
# Project IDs are mined from a repo's own files; only literal, valid IDs
# count, and the environment is inferred from whole dash-separated tokens.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  ln -s "$repo_root/.bash.d" "$HOME/.bash.d"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/58-infra-gcp-scan.sh"

  repo="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo/terraform/environments/dev" "$repo/node_modules/x" "$repo/.git"
}

@test "finds project IDs across terraform, yaml, pipelines and package.json" {
  printf 'project_name = "dev-cloud-connect"\n' > "$repo/terraform/environments/dev/main.tf"
  printf 'environments:\n  stage:\n    project_id: "stage-cloud-connect"\n' > "$repo/config.yaml"
  printf 'script:\n  - gcloud run deploy --project=production-cloud-connect --region=x\n' > "$repo/bitbucket-pipelines.yml"
  printf '{"scripts":{"p":"gcloud config set project qa-cloud-connect"}}\n' > "$repo/package.json"

  run __mt_radar_gcp_suggest_projects "$repo"
  [ "$(jq -r 'map(.project) | join(",")' <<< "$output")" = "dev-cloud-connect,stage-cloud-connect,qa-cloud-connect,production-cloud-connect" ]
  [ "$(jq -r 'map(.environment) | join(",")' <<< "$output")" = "dev,stage,test,prod" ]
}

@test "counts references and lists source files per project" {
  printf 'project = "dev-cloud-connect"\n' > "$repo/terraform/environments/dev/main.tf"
  printf 'project_id: dev-cloud-connect\n' > "$repo/config.yaml"

  run __mt_radar_gcp_suggest_projects "$repo"
  [ "$(jq -r '.[0].references' <<< "$output")" = "2" ]
  [ "$(jq -r '.[0].sources | length' <<< "$output")" = "2" ]
}

@test "ignores variable references, invalid IDs, and vendored directories" {
  printf 'project = var.project\nproject_id = "x"\nproject = local.p\n' > "$repo/terraform/environments/dev/main.tf"
  printf 'project = "ignored-in-node-modules"\n' > "$repo/node_modules/x/main.tf"
  printf 'project = "ignored-in-git"\n' > "$repo/.git/main.tf"

  run __mt_radar_gcp_suggest_projects "$repo"
  [ "$output" = "[]" ]
}

@test "environment matches whole tokens: connect-device-stage is stage, not dev" {
  printf 'project_id: connect-device-stage\nproject_id: connect-device-production\n' > "$repo/config.yaml"

  run __mt_radar_gcp_suggest_projects "$repo"
  [ "$(jq -r 'map(.environment) | join(",")' <<< "$output")" = "stage,prod" ]
}

@test "a project with no environment hint sorts last with an empty environment" {
  printf 'project_id: shared-tooling-project\nproject_id: dev-cloud-connect\n' > "$repo/config.yaml"

  run __mt_radar_gcp_suggest_projects "$repo"
  [ "$(jq -r '.[-1].project' <<< "$output")" = "shared-tooling-project" ]
  [ "$(jq -r '.[-1].environment' <<< "$output")" = "" ]
}

@test "a missing repo path yields an empty list" {
  run __mt_radar_gcp_suggest_projects "$BATS_TEST_TMPDIR/nope"
  [ "$output" = "[]" ]
}
