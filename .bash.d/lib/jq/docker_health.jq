# Reduces `docker inspect <container>` (a one-element array) to a health
# diagnosis object: status, failing streak, the configured healthcheck
# (durations in seconds, 0 = Docker default), and the recent probe log with
# each probe's duration and whether it ran close to the configured timeout.
#
# Variables:
#   $default_timeout_sec  Docker's healthcheck timeout when none is configured
#   $warn_ratio           Fraction of the timeout at which a probe is flagged
#   $max_probes           Number of most recent probes to keep

# Docker stamps probes with the host's UTC offset ("...+01:00") or "Z". The
# offset is dropped: only the difference between two stamps is ever used.
def epoch:
  (sub("(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$"; "Z") | fromdate)
  + ((capture("\\.(?<f>[0-9]+)(Z|[+-][0-9]{2}:[0-9]{2})$").f // "0") | ("0." + .) | tonumber);

def seconds: (. // 0) / 1000000000;

.[0] as $c
| ($c.Config.Healthcheck // {}) as $cfg
| (($cfg.Timeout | seconds) as $t | if $t == 0 then $default_timeout_sec else $t end) as $timeout
| {
    name: ($c.Name | ltrimstr("/")),
    has_healthcheck: (($cfg.Test // ["NONE"]) != ["NONE"] and $c.State.Health != null),
    status: ($c.State.Health.Status // "none"),
    failing_streak: ($c.State.Health.FailingStreak // 0),
    config: {
      test: ($cfg.Test // null),
      interval_sec: ($cfg.Interval | seconds),
      timeout_sec: $timeout,
      retries: ($cfg.Retries // 0),
      start_period_sec: ($cfg.StartPeriod | seconds)
    },
    probes: [
      ($c.State.Health.Log // [])[-$max_probes:][]
      | ((.End | epoch) - (.Start | epoch)) as $duration
      | {
          start: .Start,
          duration_sec: (($duration * 100 | round) / 100),
          exit_code: .ExitCode,
          near_timeout: ($duration >= $timeout * $warn_ratio),
          output: (.Output | rtrimstr("\n"))
        }
    ]
  }
