# Render the grouped Pub/Sub map as a tree.
.[]
| .topic,
  ((.subscriptions | length) as $count
   | .subscriptions | to_entries[]
   | (if .key == $count - 1 then "  └─ " else "  ├─ " end) as $branch
   | .value
   | $branch + .name + "  (" + .project + ")  " + .delivery
     + (if .target != "" then " → " + .target else "" end)
     + (if .filter != "" then "   filter: " + .filter else "" end)
     + (if .dlq != "" then "   dlq: " + .dlq else "" end)
     + (if .state != "ACTIVE" then "   state: " + .state else "" end))
