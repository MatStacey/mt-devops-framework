# Flatten a Cloud Run service (v1 JSON) to "project<TAB>key<TAB>value" lines for comparison.
# Environment and secret VALUES are never emitted: a literal env var is "set",
# a secret reference is "secret:<name>:<version>".
def present: select(. != null and . != "");

(.metadata.annotations // {}) as $service_annotations
| (.spec.template.metadata.annotations // {}) as $annotations
| (.spec.template.spec // {}) as $spec
| ($spec.containers // []) as $containers
| ($containers[0] // {}) as $main
| [
    ["image", $main.image],
    ["revision", .status.latestReadyRevisionName],
    ["client-name", $service_annotations["run.googleapis.com/client-name"]],
    ["serviceAccount", $spec.serviceAccountName],
    ["ingress", $service_annotations["run.googleapis.com/ingress"]],
    ["timeoutSeconds", $spec.timeoutSeconds],
    ["containerConcurrency", $spec.containerConcurrency],
    ["cpu", $main.resources.limits.cpu],
    ["memory", $main.resources.limits.memory],
    ["minScale", $annotations["autoscaling.knative.dev/minScale"]],
    ["maxScale", $annotations["autoscaling.knative.dev/maxScale"]],
    ["vpcConnector", $annotations["run.googleapis.com/vpc-access-connector"]],
    ["vpcEgress", $annotations["run.googleapis.com/vpc-access-egress"]],
    ["cloudsql", $annotations["run.googleapis.com/cloudsql-instances"]],
    ["startupProbe", ($main.startupProbe | if . == null then null else del(.httpGet.httpHeaders) | tojson end)],
    ["livenessProbe", ($main.livenessProbe | if . == null then null else del(.httpGet.httpHeaders) | tojson end)]
  ]
  + [$containers[].env[]? | ["env." + .name, (if .valueFrom.secretKeyRef then "secret:\(.valueFrom.secretKeyRef.name):\(.valueFrom.secretKeyRef.key)" else "set" end)]]
  + [$spec.volumes[]? | select(.secret) | ["volume." + .name, .secret.secretName]]
| .[]
| select(.[1] | . != null and . != "")
| [$project, .[0], (.[1] | tostring)]
| @tsv
