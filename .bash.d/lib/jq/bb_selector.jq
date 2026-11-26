# jq module (the first in this repo): load with `jq -L "$BITBUCKET_JQ_DIR"`
# and `include "bb_selector";` at the top of the filter.
#
# selector: a pipeline run's target selector as "<type>:<pattern>",
# "default", or "-" when the run has none, plus " (imported: <name>)" when
# the run used a pipeline imported from another repository.
def selector:
  .target.selector as $s
  | (if $s == null then "-"
     elif $s.type == "default" then "default"
     else "\($s.type):\($s.pattern // "-")"
     end)
  + (if $s.imported_from.pipelineName then " (imported: \($s.imported_from.pipelineName))" else "" end);
