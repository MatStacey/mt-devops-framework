# Dataflow job-message timeline: one row per message, plus a separator line
# whenever the job ID changes (a relaunch or in-place update under the same name).
# Variables: max_length (number) -- message length cap
def first_line: (. // "") | split("\n")[0];

. as $entries
| range(0; length) as $i
| $entries[$i] as $entry
| (if $i == 0 then null else $entries[$i - 1] end) as $previous
| (if $previous != null and ($previous.resource.labels.job_id // "-") != ($entry.resource.labels.job_id // "-")
   then "--- job_id changed: \($previous.resource.labels.job_id // "-") -> \($entry.resource.labels.job_id // "-") ---"
   else empty end),
  ([
     ($entry.timestamp // "-"),
     ($entry.severity // "-"),
     ($entry.resource.labels.job_id // "-"),
     (($entry.textPayload // $entry.jsonPayload.message) | first_line | .[0:$max_length])
   ] | @tsv)
