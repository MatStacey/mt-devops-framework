def strip_uri: sub("^(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)[^/@]*@"; "\(.scheme)") | split("?")[0];
def redact_values: if . then with_entries(.value = "<redacted>") else . end;

del(.httpTarget.body, .pubsubTarget.data, .appEngineHttpTarget.body)
| (.httpTarget.headers, .appEngineHttpTarget.headers, .pubsubTarget.attributes) |= redact_values
| (.httpTarget.uri | select(. != null)) |= strip_uri
| (.appEngineHttpTarget.relativeUri | select(. != null)) |= strip_uri
