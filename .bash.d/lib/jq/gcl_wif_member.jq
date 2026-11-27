# jq module: load with `jq -L "$GCL_SA_AUDIT_JQ_DIR"` and
# `include "gcl_wif_member";` at the top of the filter.
#
# wif_member: parse a Workload Identity Federation IAM member
# (principal://... or principalSet://iam.googleapis.com/projects/<number>/
# locations/<location>/workloadIdentityPools/<pool>/<rest>) into
# {number, location, pool, kind, attr, value}, where kind is "wildcard"
# (rest is "*"), "attribute" (attribute.<attr>/<value>), "subject" or
# "group". Emits nothing for any other member, e.g. serviceAccount:...
def wif_member:
  (capture("^principal(Set)?://iam\\.googleapis\\.com/projects/(?<number>[0-9]+)/locations/(?<location>[^/]+)/workloadIdentityPools/(?<pool>[^/]+)/(?<rest>.+)$") // empty)
  | . as $m
  | if $m.rest == "*" then {kind: "wildcard", attr: null, value: null}
    elif ($m.rest | startswith("attribute.")) then
      ($m.rest | ltrimstr("attribute.") | capture("^(?<attr>[^/]+)/(?<value>.*)$") // {attr: ., value: ""}) + {kind: "attribute"}
    else ($m.rest | capture("^(?<kind>[^/]+)/(?<value>.*)$") // {kind: ., value: ""}) + {attr: null}
    end
  | {number: $m.number, location: $m.location, pool: $m.pool} + .;
