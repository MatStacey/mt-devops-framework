# Find the commit a Cloud Run service was deployed from.
# Output: "sha:<hex>" from a commit-sha label or a hex image tag,
#         "digest:<image>@sha256:..." when the image is pinned by digest, or nothing.
def hex_commit: select(. != null and test("^[0-9a-f]{7,40}$"));

(.spec.template.metadata.labels["commit-sha"] // .metadata.labels["commit-sha"] // empty | hex_commit | "sha:\(.)"),
(.spec.template.spec.containers[0].image // "") as $image
| if ($image | test("@sha256:")) then "digest:\($image)"
  elif ($image | test(":[^:/@]+$")) then ($image | capture(":(?<tag>[^:/@]+)$").tag | hex_commit | "sha:\(.)")
  else empty end
