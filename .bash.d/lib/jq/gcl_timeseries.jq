def point_value:
  [.doubleValue, .int64Value, .distributionValue.mean, .boolValue, .stringValue]
  | map(select(. != null))
  | if length == 0 then "-" else .[0] end;

(((.metric.labels // {}) + (.resource.labels // {})) | to_entries | sort_by(.key) | map("\(.key)=\(.value)") | join(",")) as $labels
| .points[]?
| [$labels, .interval.endTime, (.value | point_value)]
| @tsv
