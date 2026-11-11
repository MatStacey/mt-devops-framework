# Count log entries by resource type and service for one project. Payloads are never read.
# Variables: project (string)
def service_name:
  .resource.labels as $labels
  | ($labels.service_name // $labels.function_name // $labels.job_name // $labels.subscription_id // $labels.topic_id // $labels.bucket_name)
  // (.logName | split("/") | last);

group_by([(.resource.type // "-"), service_name])
| .[]
| [
    $project,
    (.[0].resource.type // "-"),
    (.[0] | service_name),
    length,
    (map(.timestamp // "") | min),
    (map(.timestamp // "") | max)
  ]
| @tsv
