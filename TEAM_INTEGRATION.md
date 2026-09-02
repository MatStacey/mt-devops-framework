# Team Integration Playbook

This framework only compounds in value if it's actually the thing reached
for first -- not a side tool that gets bypassed the moment something isn't
already covered. This page is the concrete mechanism for making that true
across every implementation project a team works on, not just this repo.

It covers three things: the behavior to instruct Claude Code (and any
specialist subagents) to adopt, where that instruction needs to live to
actually take effect, and the backlog loop that turns "couldn't do this
with the framework" into the framework actually growing.

## The goal

Treat this framework as the team's own internal utility -- one that's
continuously built, enriched, and improved by whoever's using it, the same
way a team owns and maintains its own internal libraries. The target end
state: it's the one-stop-shop for terminal operations across every project,
onboarding gets faster because conventions live in one place instead of
being reinvented per-repo, and improvement compounds because every gap
found on any project feeds back into the same tool everyone else already
has installed.

## The instruction block

Paste this into the `CLAUDE.md` of every implementation project you want
this behavior active in (see "Where this needs to live" below for why
per-project, and what to do if you're also running dedicated subagents).

```markdown
## Terminal Tooling: MT DevOps Framework

This machine has the MT DevOps Framework installed (`~/.bash.d`, commands
prefixed `mt-`). Treat it as the default way to run commands and perform
actions in a terminal on this project, not just a tool that's available:

- **Before reaching for a raw shell command or writing a one-off script**,
  check whether an `mt-` command already covers it: `mt-search -i` (fuzzy
  interactive search across every registered command/alias), `mt-help
  <topic>`, or `mt-menu` for the full interactive catalog. Prefer the
  framework command when one exists and fits, over a raw equivalent.
- **When no framework command exists for something you're doing --
  especially if it's the kind of thing that'll come up again** -- don't
  just solve it ad hoc and move on. Run `mt-suggest "<short description>"`
  to log it as a backlog candidate (works from any directory; add
  `--context "..."` for what you were doing). This is meant to be
  near-zero-friction -- one line, not a stop-and-write-a-full-issue
  moment.
- This applies the same way whether you're the primary session or a
  specialist subagent working a piece of the task -- the backlog is
  shared infrastructure, not something only the "main" agent maintains.
```

## Where this needs to live

- **Every implementation project's own `CLAUDE.md`, committed to the repo.**
  This is the reliable mechanism -- it's what Claude Code actually loads
  every session, for the primary agent and (per the project's own
  subagent definitions) any specialist subagents that read project
  context. Global (`~/.claude/CLAUDE.md`) instructions apply only on the
  machine they're set on, so they don't propagate to teammates unless
  each of them sets it up too -- the committed, per-repo route is what
  makes this a *team* convention rather than a personal habit.
- **If a project defines its own specialist subagents** (`.claude/agents/*.md`
  files -- e.g. a project-specific architect/platform/release-engineer
  split), it's worth explicitly checking whether they inherit the
  project's `CLAUDE.md` or need the instruction block repeated in their
  own definitions. Don't assume silently -- verify once per project setup,
  since getting it wrong means a subagent quietly falls back to raw shell
  commands without anyone noticing.
- If you want this active as your own personal default across projects
  that haven't adopted it yet, `~/.claude/CLAUDE.md` (global, this machine
  only) is the fallback -- just don't rely on it as the team-wide
  mechanism.

## The backlog loop

1. **Capture** -- `mt-suggest` files a `workflow-gap`-labeled issue against
   this repo the moment a gap is noticed, from wherever the gap actually
   showed up. Low friction is the entire point: a line of context, not a
   fully-written feature request.
2. **Accumulate** -- gaps land in the
   [open `workflow-gap` issues](https://github.com/MatStacey/mt-devops-framework/issues?q=is%3Aopen+label%3Aworkflow-gap)
   without needing anyone to stop and triage in the moment.
3. **Triage** -- during the recurring self-audit (see
   [CONTRIBUTING.md](CONTRIBUTING.md#recurring-self-audit), roughly
   quarterly): close what's already been solved, promote genuinely
   valuable ones into properly scoped `bug`/`enhancement` issues, drop
   what turned out not to matter.
4. **Build** -- prioritized issues get implemented the normal way (see
   [CONTRIBUTING.md](CONTRIBUTING.md)), and the next time anyone hits that
   same gap, the framework already covers it.

The loop only works if step 1 actually happens in the moment instead of
getting silently worked around -- that's what the instruction block above
is for.
