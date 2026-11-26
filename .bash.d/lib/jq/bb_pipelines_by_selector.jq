include "bb_selector";
# Input: an array of pipeline runs. Output: the newest run of each selector
# as "selector<TAB>#build<TAB>state<TAB>created_on", stalest first.
group_by(selector)
| map(max_by(.created_on))
| sort_by(.created_on)
| .[]
| "\(selector)\t#\(.build_number)\t\(.state.result.name // .state.stage.name // .state.name)\t\(.created_on)"
