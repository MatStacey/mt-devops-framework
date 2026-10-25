# Select the deployments to print from the repository's deployment list.
# Variables: environments (array of {uuid,name}), env_uuid (selected environment UUID or ""),
#            count (number, used when env_uuid is set)
# Output: array of {env,state,started_on,commit,pipeline_uuid}, newest first
# (one latest entry per environment when env_uuid is empty).
def environment_name: . as $uuid | ($environments | map(select(.uuid == $uuid)) | .[0].name) // "?";
def row:
  {
    env: (.environment.uuid | environment_name),
    environment_uuid: .environment.uuid,
    state: ([.state.name, .state.status.name] | map(select(. != null)) | join("/")),
    started_on: (.state.started_on // ""),
    commit: ((.release.commit.hash // .deployable.commit.hash // "") | .[0:12]),
    pipeline_uuid: (.release.pipeline.uuid // .deployable.pipeline.uuid // "")
  };

map(row)
| if $env_uuid != "" then
    map(select(.environment_uuid == $env_uuid)) | sort_by(.started_on) | reverse | .[0:$count]
  else
    group_by(.environment_uuid) | map(sort_by(.started_on) | last) | sort_by(.env)
  end
