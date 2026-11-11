($traffic[0]) as $counts
| ([$forwarding_rules[0][] | {key: .name, value: .}] | from_entries) as $rules
| def served($map; $failed; $name):
    if $map[$name] != null then ($map[$name] | tostring) elif $failed then "?" else "0" end;
  split("\t") as $fields
| $fields[0] as $kind
| $fields[1] as $name
| (if $kind == "forwarding-rule" then
     ($rules[$name] // {}) as $rule
     | if (($rule.target // "") | test("/targetHttps?Proxies/"))
       then served($counts.lb; $counts.lb_failed; $name)
       else "n/a" end
   elif $kind == "cloud-run" then served($counts.run; $counts.run_failed; $name)
   else "n/a" end) as $served
| ($fields + [$served]) | join("\t")
