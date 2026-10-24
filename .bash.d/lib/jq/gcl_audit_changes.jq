.[] | [
  .timestamp,
  $project,
  (.protoPayload.authenticationInfo.principalEmail // "-"),
  (.protoPayload.serviceName // "-"),
  (.protoPayload.methodName // "-"),
  ((.protoPayload.resourceName // "-") | split("/") | .[-3:] | join("/")),
  (.protoPayload.status.code // 0)
] | @tsv
