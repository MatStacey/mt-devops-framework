.[]
| [
    $project,
    $location,
    (.name | split("/") | last),
    (.state // "-"),
    (.schedule // "-"),
    (.timeZone // "-"),
    (if .httpTarget then "\(.httpTarget.httpMethod // "POST") \(.httpTarget.uri | split("?")[0])"
     elif .pubsubTarget then "pubsub:\(.pubsubTarget.topicName)"
     elif .appEngineHttpTarget then "appengine:\(.appEngineHttpTarget.relativeUri)"
     else "-" end),
    (.lastAttemptTime // "-"),
    (.status.code // 0)
  ]
| @tsv
