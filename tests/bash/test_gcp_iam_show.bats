#!/usr/bin/env bats
# ------------------------------------------
# Bats: gcp-iam-show in .bash.d/10-infra/31-gcp-services.sh and
# the generic pivot in .bash.d/lib/awk/kv_matrix.awk
# ------------------------------------------
# gcloud is replaced by a stub that logs its argv and serves per-project
# roles; STUB_DENY_PROJECT makes one project fail with a permission error.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  CALLS="$BATS_TEST_TMPDIR/calls"
  export CALLS
  cat > "$BATS_TEST_TMPDIR/bin/gcloud" << 'STUB'
#!/usr/bin/env bash
echo "gcloud $*" >> "$CALLS"
project="$3"
if [ -n "${STUB_DENY_PROJECT:-}" ] && [ "$project" = "$STUB_DENY_PROJECT" ]; then
  echo "ERROR: (gcloud) PERMISSION_DENIED: Permission 'resourcemanager.projects.getIamPolicy' denied" >&2
  exit 1
fi
case "$*" in
  *--flatten*)
    case "$project" in
      dev) printf 'roles/run.invoker\t\nroles/storage.objectViewer\t\n' ;;
      stage) printf 'roles/run.invoker\t\n' ;;
      prod) printf 'roles/run.invoker\t\nroles/pubsub.publisher\tbusiness-hours\n' ;;
    esac ;;
  *) echo "ROLE MEMBERS for $project" ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gcloud"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/33-gcp-read-only.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/10-infra/31-gcp-services.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_GREEN="" CB_BLUE="" CB_YELLOW="" C_RESET=""
  mt-help() { echo "help called"; }
  gcl-get-project() { echo "dev"; }
  gcl-get-user() { echo "me@example.test"; }
}

@test "no flags: policy table for the active project, unchanged argv" {
  run gcp-iam-show
  [ "$status" -eq 0 ]
  [ "$output" = "ROLE MEMBERS for dev" ]
  [ "$(cat "$CALLS")" = 'gcloud projects get-iam-policy dev --format=table(bindings.role, bindings.members) --quiet' ]
}

@test "-p x: policy table for that project without a heading" {
  run gcp-iam-show -p stage
  [ "$status" -eq 0 ]
  [ "$output" = "ROLE MEMBERS for stage" ]
}

@test "repeated -p without --member prints a heading per project" {
  run gcp-iam-show -p dev -p stage
  [ "$status" -eq 0 ]
  [[ "$output" == *"== dev =="*"ROLE MEMBERS for dev"*"== stage =="*"ROLE MEMBERS for stage"* ]]
}

@test "member normalisation: service account, user and explicit type" {
  [ "$(__mt_gcp_normalize_member sa@p.iam.gserviceaccount.com)" = "serviceAccount:sa@p.iam.gserviceaccount.com" ]
  [ "$(__mt_gcp_normalize_member me@example.test)" = "user:me@example.test" ]
  [ "$(__mt_gcp_normalize_member group:team@example.test)" = "group:team@example.test" ]
  run __mt_gcp_normalize_member 'bad member"'
  [ "$status" -eq 1 ]
  run __mt_gcp_normalize_member plainword
  [ "$status" -eq 1 ]
}

@test "--member passes the exact flatten and filter arguments" {
  run gcp-iam-show -p dev -m sa@p.iam.gserviceaccount.com
  [ "$status" -eq 0 ]
  grep -qF 'gcloud projects get-iam-policy dev --flatten=bindings[].members --filter=bindings.members=serviceAccount:sa@p.iam.gserviceaccount.com --format=value(bindings.role,bindings.condition.title) --quiet' "$CALLS"
}

@test "--member with one project prints sorted role and condition rows" {
  run gcp-iam-show -p prod -m me@example.test
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'roles/pubsub.publisher\tbusiness-hours\nroles/run.invoker\t')" ]
}

@test "--member with several projects prints a role x project matrix" {
  run gcp-iam-show -p dev -p stage -p prod -m sa@p.iam.gserviceaccount.com
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<< "$output")" = "$(printf 'ROLE\tdev\tstage\tprod')" ]
  [ "$(sed -n 2p <<< "$output")" = "$(printf 'roles/pubsub.publisher\t-\t-\tbusiness-hours')" ]
  [ "$(sed -n 3p <<< "$output")" = "$(printf 'roles/run.invoker\t✅\t✅\t✅')" ]
  [ "$(sed -n 4p <<< "$output")" = "$(printf 'roles/storage.objectViewer\t✅\t-\t-')" ]
}

@test "a denied project is named, the others are still printed, and the exit is 5" {
  STUB_DENY_PROJECT=stage run gcp-iam-show -p dev -p stage -p prod -m sa@p.iam.gserviceaccount.com
  [ "$status" -eq 5 ]
  [[ "$output" == *"Permission denied"* ]]
  [[ "$output" == *"resourcemanager.projects.getIamPolicy"* ]]
  [[ "$output" == *"roles/storage.objectViewer"* ]]
}

@test "bad usage exits 1" {
  run gcp-iam-show --bogus
  [ "$status" -eq 1 ]
  run gcp-iam-show -p dev -m 'not a member'
  [ "$status" -eq 1 ]
}

@test "-h shows help" {
  run gcp-iam-show -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"help called"* ]]
}

@test "kv_matrix.awk pivots column, key, value lines and honours column order" {
  run bash -c "printf 'a\tk2\t\na\tk1\tv\nb\tk1\t\n' | awk -v columns=b,a -v mark=X -v empty=. -v header=K -f '$repo_root/.bash.d/lib/awk/kv_matrix.awk'"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'K\tb\ta\nk1\tX\tv\nk2\t.\tX')" ]
}
