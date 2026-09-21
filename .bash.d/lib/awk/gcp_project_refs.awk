# Reduces `grep -rHoE` matches ("<path>:<matched text>") for GCP project
# assignments -- `project_id: "x"`, `project_name = "x"`, `--project=x`,
# `gcloud config set project x`, `GCP_PROJECT=x` -- to "<project-id><TAB><path>".
# The project ID is the last token of the matched text once quotes and the
# assignment operator are stripped.

{
  path = $0
  sub(/:.*/, "", path)
  id = $0
  sub(/^[^:]*:/, "", id)
  sub(/["']$/, "", id)
  sub(/.*[=: "']/, "", id)
  if (id != "") print id "\t" path
}
