# jq module: load with `jq -L "$BITBUCKET_JQ_DIR"` and
# `include "bb_report_annotations";`.
#
# annotation_rows($max): an array of Code Insights annotations as indented
# "  severity<TAB>path:line<TAB>summary" rows, most severe first (CRITICAL,
# HIGH, MEDIUM, LOW, then anything else), at most $max of them, followed by
# "  … +<n> more" when some were left out.
def severity_rank: {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}[.severity // ""] // 4;

def annotation_rows($max):
  sort_by(severity_rank) as $sorted
  | ($sorted[0:$max][] | "  \(.severity // "-")\t\(.path // "-"):\(.line // "-")\t\((.summary // "-") | gsub("[\t\r\n]+"; " "))"),
    (if ($sorted | length) > $max then "  … +\(($sorted | length) - $max) more" else empty end);
