# gcl-sa-audit's keys check: one row per (user-managed key, finding code),
# or one row with finding "-" for a key with none. Only key IDs and dates are
# shown; key material is never requested. Same schema as every gcl-sa-audit
# check: {check, project, resource, principal, detail, finding}.
# Inputs:
#   $keys          [{project, sa, keys: [{name, validAfterTime, validBeforeTime, disabled}]}]
#   $max_age_days  keys created longer ago than this are OLD_KEY
#   $now           current time, epoch seconds

def codes: {no_expiry: "NO_EXPIRY", old: "OLD_KEY", unknown_age: "UNKNOWN_AGE", disabled: "DISABLED", none: "-"};
# epoch: seconds since 1970 for an RFC 3339 UTC time, or null if unparseable.
def epoch: try (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch null;
def day: .[0:10];

[
  $keys[] as $entry
  | $entry.keys[]
  | . as $key
  | ($key.validBeforeTime // "" | startswith("9999")) as $never
  | {
      check: "keys",
      project: $entry.project,
      resource: $entry.sa,
      principal: "-",
      detail: "key=\($key.name | split("/") | last) created=\($key.validAfterTime | day) expires=\(if $never then "never" else ($key.validBeforeTime // "?" | day) end)"
    } as $base
  | ([
      (select($never) | codes.no_expiry),
      (($key.validAfterTime // "" | epoch) as $created
        | if $created == null then codes.unknown_age
          elif ($now - $created) > ($max_age_days * 86400) then codes.old
          else empty end),
      (select($key.disabled == true) | codes.disabled)
    ] | if length == 0 then [codes.none] else . end)[]
  | $base + {finding: .}
]
| sort_by(.project, .resource, .detail, .finding)
