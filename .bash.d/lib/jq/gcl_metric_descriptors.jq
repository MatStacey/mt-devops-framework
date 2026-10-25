[.type, .metricKind, .valueType, (.unit // "-"), ((.description // "") | gsub("\n"; " "))] | @tsv
