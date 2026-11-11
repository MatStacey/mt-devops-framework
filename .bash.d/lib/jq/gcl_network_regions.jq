def norm: if type == "string" then sub("^https://(www|compute)\\.googleapis\\.com/compute/(v1|beta|alpha)/"; "") else "" end;
def last_segment: if type == "string" then split("/") | last else empty end;
(
  [$subnets[0][] | select((.network | norm) == $net) | .region | last_segment],
  [$run[0][], $run_jobs[0][] | .metadata.labels["cloud.googleapis.com/location"] // empty],
  [$functions[0][] | .name | split("/") | .[3] // empty]
) | .[]
