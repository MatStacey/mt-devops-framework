# Group Pub/Sub subscriptions under their topics.
# Variables: subs (subscriptions array), topics (topics array), needle (topic substring or "")
# Output: [{topic, subscriptions: [{name, project, delivery, target, filter, dlq, state}]}], sorted by topic.
# Push endpoints lose userinfo and the query string (they can carry tokens).
def strip_uri: sub("^(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)[^/@]*@"; "\(.scheme)") | split("?")[0];

def delivery:
  if .pushConfig.pushEndpoint then {delivery: "push", target: (.pushConfig.pushEndpoint | strip_uri)}
  elif .bigqueryConfig.table then {delivery: "bigquery", target: .bigqueryConfig.table}
  elif .cloudStorageConfig.bucket then {delivery: "gcs", target: .cloudStorageConfig.bucket}
  else {delivery: "pull", target: ""} end;

def subscription_row:
  {
    name: (.name | split("/") | last),
    project: (.name | split("/") | .[0:2] | join("/")),
    filter: (.filter // ""),
    dlq: (.deadLetterPolicy.deadLetterTopic // ""),
    state: (.state // "ACTIVE")
  } + delivery;

(($subs | map(.topic)) + ($topics | map(.name)) | unique) as $topic_names
| [ $topic_names[]
    | select($needle == "" or contains($needle))
    | . as $topic
    | {topic: $topic, subscriptions: [$subs[] | select(.topic == $topic) | subscription_row] | sort_by(.name)} ]
