#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# ------------------------------------------
# Bats: mt-radar --iam helpers in .bash.d/20-vcs/60-iam-advisor.sh
# ------------------------------------------
# __mt_radar_iam_extract_report must accept the structured report whether
# the model returns it bare or (as AI_SYSTEM_PROMPT's envelope nudges it to)
# as a JSON string inside {"message": "..."}, and refuse plain prose so the
# caller falls back to showing text. __mt_radar_iam_fetch_current must keep
# only user-created service accounts (including ones from other projects)
# and drop Google-managed agents, users, and groups. gcloud is stubbed --
# no real API calls.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # The helpers resolve ai_parse_response.py via $HOME/.bash.d.
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  ln -s "$repo_root/.bash.d" "$HOME/.bash.d"

  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/58-infra-gcp-scan.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/20-vcs/60-iam-advisor.sh"

  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  PATH="$fake_bin:$PATH"
}

@test "extract_report accepts a bare structured report" {
  run __mt_radar_iam_extract_report '{"recommended":[{"name":"deployer","purpose":"ci","replaces":null,"roles":[{"role":"roles/run.admin","reason":"deploy"}]}],"current":[]}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.recommended[0].name' <<< "$output")" = "deployer" ]
  [ "$(jq -r '.current | length' <<< "$output")" = "0" ]
}

@test "extract_report unwraps a report nested as a string in the envelope's message" {
  local inner='{"recommended":[{"name":"runtime","purpose":"app","replaces":"old@p.iam.gserviceaccount.com","roles":[]}],"current":[]}'
  local envelope
  envelope=$(jq -n --arg m "$inner" '{category: "chat", message: $m}')
  run __mt_radar_iam_extract_report $'```json\n'"$envelope"$'\n```'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.recommended[0].replaces' <<< "$output")" = "old@p.iam.gserviceaccount.com" ]
}

@test "extract_report defaults a missing current list to empty" {
  run __mt_radar_iam_extract_report '{"recommended":[]}'
  [ "$status" -eq 0 ]
  [ "$(jq -c '.current' <<< "$output")" = "[]" ]
}

@test "extract_report rejects plain prose" {
  run __mt_radar_iam_extract_report "No IAM implementations required"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "extract_report rejects JSON without a recommended array" {
  run __mt_radar_iam_extract_report '{"category":"chat","message":"just words"}'
  [ "$status" -eq 1 ]
}

@test "fetch_current keeps user-created service accounts and groups roles per account" {
  cat > "$fake_bin/gcloud" << 'EOF'
#!/usr/bin/env bash
cat << 'JSON'
{"bindings":[
 {"role":"roles/run.admin","members":["serviceAccount:deployer@proj.iam.gserviceaccount.com","user:someone@example.com","group:team@example.com"]},
 {"role":"roles/storage.admin","members":["serviceAccount:deployer@proj.iam.gserviceaccount.com","serviceAccount:runner@other-proj.iam.gserviceaccount.com"]},
 {"role":"roles/run.serviceAgent","members":["serviceAccount:service-123@gcp-sa-run.iam.gserviceaccount.com"]},
 {"role":"roles/editor","members":["serviceAccount:123-compute@developer.gserviceaccount.com","serviceAccount:123@cloudservices.gserviceaccount.com"]}
]}
JSON
EOF
  chmod +x "$fake_bin/gcloud"

  run __mt_radar_iam_fetch_current "proj"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'map(.email) | sort | join(",")' <<< "$output")" = "deployer@proj.iam.gserviceaccount.com,runner@other-proj.iam.gserviceaccount.com" ]
  [ "$(jq -r '.[] | select(.email | startswith("deployer")) | .roles | sort | join(",")' <<< "$output")" = "roles/run.admin,roles/storage.admin" ]
}

@test "fetch_current returns an empty list for a policy with no bindings" {
  printf '#!/usr/bin/env bash\necho "{}"\n' > "$fake_bin/gcloud"
  chmod +x "$fake_bin/gcloud"

  run __mt_radar_iam_fetch_current "proj"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "fetch_current reports permission-denied and fails when gcloud is denied" {
  printf '#!/usr/bin/env bash\necho "ERROR: (gcloud.projects.get-iam-policy) PERMISSION_DENIED: nope" >&2\nexit 1\n' > "$fake_bin/gcloud"
  chmod +x "$fake_bin/gcloud"

  run __mt_radar_iam_fetch_current "proj"
  [ "$status" -eq 1 ]
  [ "$output" = "permission-denied" ]
}
