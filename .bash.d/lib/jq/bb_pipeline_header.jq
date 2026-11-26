include "bb_selector";
# One-line summary of a pipeline run: "#build trigger ref commit selector".
# A pull-request run has no ref_name, so its source branch is shown instead.
"#\(.build_number) \(.trigger.name // "-") \(.target.ref_name // .target.source // "-") \((.target.commit.hash // "-") | .[0:12]) \(selector)"
