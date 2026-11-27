# gcl-sa-audit's wif check: one finding object per (member, finding code),
# in the schema shared by every gcl-sa-audit check:
# {check, project, resource, principal, detail, finding}.
# Inputs (all via --slurpfile / --arg / --argjson):
#   $bindings     [{project, sa, members: [workloadIdentityUser members]}]
#   $policies     [{<project>: <project IAM policy>}, ...]
#   $pools        [{number, location, pool, state, providers: [...]}];
#                 state "NOT_FOUND" when describe found no pool, and a pool
#                 that could not be read is absent (its findings are unknown)
#   $expected     expected pool ID, or "" for any
#   $claims       claim expressions treated as broad, e.g. ["assertion.repository_owner"]
#   $placeholder  case-insensitive regex for placeholder member values
#   $secret_role_prefix  role prefix that marks a service account high-impact
include "gcl_wif_member";

def codes: {
  wildcard: "WILDCARD_POOL",
  broad: "BROAD_ATTRIBUTE",
  placeholder: "PLACEHOLDER_SUBJECT",
  no_condition: "NO_CONDITION",
  missing: "POOL_MISSING",
  mismatch: "POOL_MISMATCH",
  secrets_suffix: "+SECRETS"
};

($policies | add // {}) as $by_project
| ($pools | map({key: "\(.number)/\(.location)/\(.pool)", value: .}) | from_entries) as $pool_index
| [
    $bindings[] as $b
    | ([$by_project[$b.project].bindings[]?
        | select(.role | startswith($secret_role_prefix))
        | .members[]] | index("serviceAccount:\($b.sa)") != null) as $holds_secrets
    | $b.members[] as $member
    | ($member | wif_member) as $m
    | $pool_index["\($m.number)/\($m.location)/\($m.pool)"] as $pool
    | (if $pool == null then null else ($pool.state == "NOT_FOUND" or $pool.state == "DELETED") end) as $missing
    | (if $m.kind == "attribute" and $pool != null
       then first($pool.providers[]?.attributeMapping["attribute.\($m.attr)"] // empty) // null
       else null end) as $claim
    | (if $pool == null then "?"
       elif $missing or ($pool.providers | length) == 0 then "-"
       elif any($pool.providers[]; (.attributeCondition // "") == "") then "none"
       else "set" end) as $condition
    | [
        (select($m.kind == "wildcard") | codes.wildcard),
        (select($claim != null and ($claims | index($claim)) != null) | codes.broad),
        (select($m.kind != "wildcard" and ($m.value | test($placeholder; "i"))) | codes.placeholder),
        (select($condition == "none") | codes.no_condition),
        (select($missing == true) | codes.missing),
        (select($expected != "" and $m.pool != $expected) | codes.mismatch)
      ][]
    | {
        check: "wif",
        project: $b.project,
        resource: $b.sa,
        principal: $member,
        detail: "pool=\($m.pool) attr=\(if $m.attr then "\($m.attr)<-\($claim // "?")" else "-" end) condition=\($condition)",
        finding: (. + (if $holds_secrets then codes.secrets_suffix else "" end))
      }
  ]
| sort_by(.project, .resource, .principal, .finding)
