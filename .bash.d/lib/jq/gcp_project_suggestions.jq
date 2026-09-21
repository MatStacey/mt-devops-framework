# Aggregates "<project-id><TAB><relative path>" lines (raw input, slurped)
# into project suggestions, most useful first: environment order
# (dev, stage, prod, then unclassified), then most-referenced.
#
# Output: [{project, environment, references, sources: [up to $max_sources paths]}]
# The environment is inferred from the project ID itself (dev/stage/prod/test).

# Matches whole dash/underscore-separated tokens, so "connect-device-stage"
# is stage, not dev (the "dev" inside "device").
def token($names): test("(^|[-_])(" + $names + ")([-_]|$)");

def environment:
  if token("dev|development") then "dev"
  elif token("stage|staging|stg") then "stage"
  elif token("prod|production|prd") then "prod"
  elif token("test|qa") then "test"
  else "" end;

def env_rank: {"dev": 0, "stage": 1, "test": 2, "prod": 3}[.] // 4;

split("\n")
| map(select(length > 0) | split("\t") | {project: .[0], path: .[1]})
| group_by(.project)
| map({
    project: .[0].project,
    environment: (.[0].project | environment),
    references: length,
    sources: ([.[].path] | unique | .[:$max_sources])
  })
| sort_by([(.environment | env_rank), -.references, .project])
