# Rows for one gcl-monitoring-inventory section. Input: the gcloud JSON list.
# Variables: section (alerts|uptime|logmetrics), filter_max (number)
def squash: gsub("\\s+"; " ");

.[]
| if $section == "alerts" then
    [.displayName, (if .enabled == null then true else .enabled end | tostring), ((.conditions // []) | length), ((.notificationChannels // []) | length)]
  elif $section == "uptime" then
    [.displayName, (.monitoredResource.labels.host // .monitoredResource.type // "-"), (.httpCheck.path // (.tcpCheck.port | if . == null then null else tostring end) // "-"), (.period // "-")]
  elif $section == "logmetrics" then
    [.name, ((.filter // "") | squash | .[0:$filter_max])]
  else empty end
| @tsv
