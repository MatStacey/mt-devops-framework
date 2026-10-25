del(.httpTarget.body, .pubsubTarget.data, .appEngineHttpTarget.body)
| if .httpTarget.headers then .httpTarget.headers |= with_entries(.value = "<redacted>") else . end
| if .httpTarget.uri then .httpTarget.uri |= split("?")[0] else . end
