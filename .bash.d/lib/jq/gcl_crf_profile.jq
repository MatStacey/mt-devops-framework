# One row (or object with --json) describing a Cloud Run function (gen2) in a project.
# Variables: project (string), as_json (bool)
def source_label:
  if .buildConfig.source.storageSource then
    "gs://\(.buildConfig.source.storageSource.bucket)/\(.buildConfig.source.storageSource.object)#\(.buildConfig.source.storageSource.generation // "-")"
  elif .buildConfig.source.repoSource then
    "\(.buildConfig.source.repoSource.repoName // "-")@\(.buildConfig.source.repoSource.branchName // .buildConfig.source.repoSource.tagName // .buildConfig.source.repoSource.commitSha // "-")"
  else "-" end;

def trigger_label:
  if .eventTrigger then
    ([.eventTrigger.eventType, .eventTrigger.pubsubTopic] | map(select(. != null)) | join(" "))
  else "https" end;

{
  project: $project,
  state: (.state // "-"),
  runtime: (.buildConfig.runtime // "-"),
  entryPoint: (.buildConfig.entryPoint // "-"),
  revision: (.serviceConfig.revision // "-"),
  updateTime: (.updateTime // "-"),
  source: source_label,
  trigger: trigger_label,
  serviceAccount: (.serviceConfig.serviceAccountEmail // "-"),
  deploymentTool: (.labels["deployment-tool"] // "-"),
  commit: (.labels["commit-sha"] // .labels["git-commit"] // "-")
}
| if $as_json then . else [.project, .state, .runtime, .entryPoint, .revision, .updateTime, .source, .trigger, .serviceAccount, .deploymentTool, .commit] | @tsv end
