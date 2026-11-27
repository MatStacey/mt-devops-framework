# gcl-sa-audit's invoker check: one row per roles/run.invoker member of each
# Cloud Run service (an inventory: finding "-" when nothing is wrong), plus a
# MISSING_INVOKER row for each expected invoker a service lacks. Same schema
# as every gcl-sa-audit check: {check, project, resource, principal, detail, finding}.
# Inputs:
#   $services  [{project, region, service, members: [run.invoker members]}]
#   $projects  the audited project IDs
#   $numbers   their project numbers, as far as they could be resolved
#   $numbers_complete  false when any audited project's number is unknown, so
#              a number-bearing member cannot be judged
#   $expected  expected invokers, each as "serviceAccount:<email>"

def codes: {public: "PUBLIC_INVOKER", cross: "CROSS_PROJECT", missing: "MISSING_INVOKER", none: "-"};

# {id: <project id>} or {number: <project number>} named by a service-account
# member, or null when the member names neither.
def member_owner:
  if test("^serviceAccount:[0-9]+-compute@developer\\.gserviceaccount\\.com$") then {number: capture(":(?<n>[0-9]+)-").n}
  elif test("^serviceAccount:service-[0-9]+@gcp-sa-[^.@]+\\.iam\\.gserviceaccount\\.com$") then {number: capture(":service-(?<n>[0-9]+)@").n}
  elif test("^serviceAccount:[0-9]+@cloudbuild\\.gserviceaccount\\.com$") then {number: capture(":(?<n>[0-9]+)@").n}
  elif test("^serviceAccount:[^@]+@[^.@]+\\.iam\\.gserviceaccount\\.com$") then {id: capture("@(?<p>[^.@]+)\\.iam\\.").p}
  elif test("^serviceAccount:[^@]+@appspot\\.gserviceaccount\\.com$") then {id: capture(":(?<p>[^@]+)@appspot").p}
  else null end;

def finding_for($member):
  if $member == "allUsers" or $member == "allAuthenticatedUsers" then codes.public
  else ($member | member_owner) as $owner
  | if $owner == null then codes.none
    elif $owner.id then (if ($projects | index($owner.id)) == null then codes.cross else codes.none end)
    elif $numbers_complete and ($numbers | index($owner.number)) == null then codes.cross
    else codes.none end
  end;

[
  $services[] as $s
  | {check: "invoker", project: $s.project, resource: "\($s.region)/\($s.service)", detail: "roles/run.invoker"} as $base
  | (($s.members[] | . as $m | $base + {principal: $m, finding: finding_for($m)}),
     ($expected[] | select(. as $e | ($s.members | index($e)) == null) | $base + {principal: ., finding: codes.missing}))
]
| sort_by(.project, .resource, .principal, .finding)
