# Build a Firestore structuredQuery.
# Variables: collection (string), where (array of "<field><op><value>"), order (string or ""),
#            limit (number or null), all_descendants (bool), documents_path (projects/../documents)
def value_type($raw):
  if ($raw | test("^-?[0-9]+$")) then {integerValue: $raw}
  elif $raw == "true" then {booleanValue: true}
  elif $raw == "false" then {booleanValue: false}
  elif $raw == "null" then {nullValue: null}
  else {stringValue: $raw} end;

def operator:
  {"==": "EQUAL", "!=": "NOT_EQUAL", "<": "LESS_THAN", "<=": "LESS_THAN_OR_EQUAL", ">": "GREATER_THAN", ">=": "GREATER_THAN_OR_EQUAL"}[.];

def field_filter:
  capture("^(?<field>[^=!<>[:space:]]+)(?<op>==|!=|<=|>=|<|>)(?<value>.*)$")
  | {fieldFilter: {
      field: {fieldPath: .field},
      op: (.op | operator),
      value: (if .field == "__name__"
        then {referenceValue: "\($documents_path)/\($collection)/\(.value)"}
        else value_type(.value) end)}};

def order_by:
  split(":") as $parts
  | {field: {fieldPath: $parts[0]}, direction: (if ($parts[1] // "") == "desc" then "DESCENDING" else "ASCENDING" end)};

{from: [{collectionId: $collection} + (if $all_descendants then {allDescendants: true} else {} end)]}
+ (if ($where | length) == 0 then {}
   elif ($where | length) == 1 then {where: ($where[0] | field_filter)}
   else {where: {compositeFilter: {op: "AND", filters: ($where | map(field_filter))}}} end)
+ (if $order == "" then {} else {orderBy: [$order | order_by]} end)
+ (if $limit == null then {} else {limit: $limit} end)
