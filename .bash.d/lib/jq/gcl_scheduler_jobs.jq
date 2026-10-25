def strip_uri: sub("^(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)[^/@]*@"; "\(.scheme)") | split("?")[0];

.[]
| [
    $project,
    $location,
    (.name | split("/") | last),
    (.state // "-"),
    (.schedule // "-"),
    (.timeZone // "-"),
    (if .httpTarget then "\(.httpTarget.httpMethod // "POST") \(.httpTarget.uri | strip_uri)"
     elif .pubsubTarget then "pubsub:\(.pubsubTarget.topicName)"
     elif .appEngineHttpTarget then "appengine:\(.appEngineHttpTarget.relativeUri | strip_uri)"
     else "-" end),
    (.lastAttemptTime // "-"),
    (.status.code // 0)
  ]
| @tsv
