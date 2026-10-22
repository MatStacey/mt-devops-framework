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
  check whether an `mt-` command already covers it: `mt-search <keyword>`
  for a targeted lookup, `mt-list -f` for every documented function, or
  `mt-help <command>` for one command's usage. Prefer the framework
  command when one exists and fits, over a raw equivalent.
- **Run `mt-` commands as `bash -ic "<command>"`.** The Claude Code Bash
  tool doesn't load `~/.bashrc`, so a bare `mt-` command isn't found.
  Never run `mt-search -i`, `mt-search -v`, `mt-menu`, or `mt-suggest`
  without `-e`/`-b`: they wait for keyboard input and hang the session.
- **When no framework command exists for something you're doing**, run
  the raw command and note it as a gap candidate. Before finishing, file
  only the candidates that are all of:
  1. **Reusable** beyond this task and repo, not tied to one
     investigation's data, schema or project.
  2. **Worth wrapping**: more than a single well-known command with
     flags (e.g. loops across projects or regions, joins, redaction,
     safety guards), and not already solved by an established tool or by
     fixtures that belong in the repo's own tests.
  3. **New**: `gh issue list -R MatStacey/mt-devops-framework --label
     workflow-gap --state all --search "<keywords>"` finds no match. If
     one exists, comment on it instead.

  File with `mt-suggest -e "<short description>" --context "<what you
  were doing>"`, or `-b` for something broken in an existing `mt-`
  command (always worth filing). Merge related candidates into one issue
  and file at most 5 per session. Mention the skipped ones in your final
  reply.
- **The backlog is public.** Never put project IDs, bucket, job or host
  names, or data in the description or context. `mt-suggest` itself
  records only whether you were in a work or personal repository, not
  the path.
- **Specialist subagents** report gap candidates to the main session
  instead of filing them, so parallel subagents don't file duplicates.
```

## Where this needs to live

Two mechanisms, and which one fits depends on whether this is a single
person's multi-project machine or a convention shared across teammates'
own separate machines:

- **`~/.claude/CLAUDE.md` (global, this machine only).** Applies to every
  Claude Code session on this machine automatically, regardless of which
  project directory it's running in -- including projects that don't have
  a `.claude/` directory yet. This is the right default for a solo
  workspace with many personal/implementation projects under one root
  (e.g. `~/vcs/*`): it front-loads the behavior for repos not yet picked
  up, with zero per-repo setup. It does **not** propagate to anyone else's
  machine, so it's not sufficient on its own once real teammates are
  involved.
- **Every implementation project's own `CLAUDE.md`, committed to the
  repo.** This is what makes the convention travel with the repo itself
  -- anyone who clones it (any teammate, any machine) gets the same
  instruction without needing their own global config set up first. Use
  this once a project is actually shared with other people, on top of (not
  instead of) the global file.

Either way, **if a project defines its own specialist subagents**
(`.claude/agents/*.md` files -- e.g. a project-specific
architect/platform/release-engineer split), it's worth explicitly checking
whether they inherit the enclosing CLAUDE.md (global or project) or need
the instruction block repeated in their own definitions. Don't assume
silently -- verify once per project setup, since getting it wrong means a
subagent quietly falls back to raw shell commands without anyone noticing.

## The backlog loop

1. **Capture** -- `mt-suggest` files a `workflow-gap`-labeled issue against
   this repo from wherever the gap actually showed up. Low friction is
   the point: a line of context, not a fully-written feature request. But
   only gaps that pass the checks in the instruction block get filed, so
   triage isn't buried under one-offs.
2. **Accumulate** -- gaps land in the
   [open `workflow-gap` issues](https://github.com/MatStacey/mt-devops-framework/issues?q=is%3Aopen+label%3Aworkflow-gap)
   without needing anyone to stop and triage in the moment.
3. **Triage** -- during the recurring self-audit (see
   [CONTRIBUTING.md](../CONTRIBUTING.md#recurring-self-audit), roughly
   quarterly): close what's already been solved, promote genuinely
   valuable ones into properly scoped `bug`/`enhancement` issues, drop
   what turned out not to matter.
4. **Build** -- prioritized issues get implemented the normal way (see
   [CONTRIBUTING.md](../CONTRIBUTING.md)), and the next time anyone hits that
   same gap, the framework already covers it.

The loop only works if real gaps get filed instead of silently worked
around, and one-offs don't -- that's what the instruction block above is
for.
