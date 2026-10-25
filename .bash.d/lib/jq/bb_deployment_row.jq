# One printed deployment row. Input: a selected deployment; $pipeline: its pipeline (or {}).
[
  .env,
  .state,
  (.started_on | if . == "" then "-" else . end),
  (.commit | if . == "" then "-" else . end),
  ($pipeline.target.ref_name // "-"),
  ($pipeline.build_number | if . == null then "-" else "#\(.)" end),
  ($pipeline.creator.display_name // "-")
] | @tsv
