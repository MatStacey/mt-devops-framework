# Convert Firestore typed values to plain JSON; one object per document with _id.
def unwrap:
  if has("nullValue") then null
  elif has("mapValue") then ((.mapValue.fields // {}) | map_values(unwrap))
  elif has("arrayValue") then ((.arrayValue.values // []) | map(unwrap))
  elif has("integerValue") then (.integerValue | tonumber)
  elif has("doubleValue") then .doubleValue
  elif has("booleanValue") then .booleanValue
  elif has("geoPointValue") then .geoPointValue
  else (.stringValue // .timestampValue // .referenceValue // .bytesValue) end;

(if type == "array" then .[] | (.document? // empty) else . end)
| {_id: (.name | split("/") | last)} + ((.fields // {}) | map_values(unwrap))
