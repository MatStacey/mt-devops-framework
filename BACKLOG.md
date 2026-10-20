# Backlog: Triage & Implementation Plan

> Produced by a lead-developer review of the open issue list on **2026-10-19**.
> Intended to be executed by an agent in a fresh session: work the tiers in
> order, one issue (or one consolidated cluster) per PR.

Read this file and [CONTRIBUTING.md](CONTRIBUTING.md) before starting. The
"Ground rules" section below is not optional — most items here are small, and
getting them wrong is almost always a convention violation rather than a logic
error.

---

## 1. What this review changed

The open list was 35 issues. 33 of them were filed by `mt-suggest` during real
work, which makes the list an accurate record of friction but a poor backlog:
the same gap gets captured several times from different working directories,
and gaps discovered while working on unrelated private projects get filed here
regardless of whether this framework is the right home for them.

**Closed as out of scope (9):** #340, #341, #342, #343, #344, #345, #346, #347,
#348 — all captured while building `mst-video-finder-win`, a private Windows
application that now lives in its own standalone repository. Windows
Search / `SystemIndex` probing, WinUI scaffolding and Windows-host .NET build
tooling belong with that app, not in a GCP/Platform DevOps shell framework.
Five of the nine (#342, #343, #344, #345, #347) described the same Windows
Search probe capability.

**Re-scoped (1):** #247 bundled a generic authenticated-HTTP wrapper with
Windows Start-Menu hotkey management. The hotkey half was dropped (same
rationale as above); the HTTP half was kept and promoted to P1 because five
other open issues depend on it.

**Remaining: 26 open issues, ≈20 units of work** after the duplicate
consolidation in section 4.

---

## 2. Ground rules for the implementing agent

### Conventions that are load-bearing

- **Edit `.bash.d/`, and pick the directory number by dependency, not by
  theme.** `.bashrc` sources `find -L ~/.bash.d -name "*.sh" | sort`, so the
  numbered prefixes *are* the load order. A helper that other modules call at
  load time must sort before them.
- **No inline multi-line Python/AWK/templates inside a bash function.** Extract
  to `lib/python/`, `lib/awk/`, `lib/templates/` and invoke from bash, so
  `ruff`/`shellcheck` can actually lint it.
- **Every command needs the `#####` docstring header** (`# <Category>: <desc>`,
  `# Usage:`, `# Options:`). It is not decoration — `lib/awk/mytools.awk`
  parses it to build the `mytools` TSV index, which is what feeds `mt-help`,
  `mt-fzf`, `mt-run`, `mt-search` and `mt-dump`. A command without it is
  invisible to the entire discovery surface.
- **Secrets come from `~/secrets/secrets.sh`, never `config.yaml`.** Follow the
  existing pattern: guard on the variable being set (see
  `.bash.d/20-vcs/54-clone.sh:333` for the canonical missing-credential
  guard), and record usage with
  `python3 "$SECRETS_MANAGER" touch "<VAR>" 2>/dev/null` (see
  `54-clone.sh:353`).
- **Register user-facing commands in `mt-menu`** (`.bash.d/03-mytools/09-menu.sh`)
  under the right category.

### Checks to run before every commit

```bash
find .bash.d -type f -name "*.sh" -print0 \
  | xargs -0 shellcheck -e SC1090,SC1091,SC2119,SC2120,SC2207,SC2015,SC2317,SC2016,SC2129,SC2028,SC1003
shellcheck -e SC1090,SC1091,SC2119,SC2120,SC2207,SC2015,SC2317,SC2016,SC2129,SC2028,SC1003 install.sh .bashrc
shfmt -d -i 2 -ci -sr .
ruff check .
python3 -m pytest tests/python/ -v
bats tests/bash/
```

Once **P1-1** lands, this is just `mt-test-all`.

### Two traps specific to this backlog

1. **Do not run `mt-dump` to regenerate the committed docs until P0-1 is
   fixed.** On a machine with `~/.bash.d/40-private/` populated it will
   re-introduce private commands into the public reference. This already
   happened; see P0-1.
2. **`mt-suggest` provenance is evidence, not scope.** An issue's "Discovered
   while" line says where the friction was felt. Several of these were felt
   while working on private projects that are not this framework's concern —
   check the working directory before building.

---

## 3. Priorities

### P0 — Repository hygiene (do first)

#### P0-1 · Stop `mt-dump` leaking private modules into the public reference · **M** · *(no issue — found during this review)*

`.bash.d/docs/TECHNICAL_REFERENCE.md` is generated and committed. `mt-dump`
builds it from the live shell's function index, which includes modules loaded
from `~/.bash.d/40-private/` — gitignored, and excluded from
`mt-push-update`'s sync and ShellCheck gate, but **not** from the doc
generator. The committed, public file therefore carried the complete source of
17 private commands (6 video-finder `find-*`, 11 `mt-homelab-*`).

The two commits accompanying this plan removed that content, but the generator
will recreate it on the next run. No credentials were exposed — the leak was
command surface, docstrings and one local filesystem path.

**Root cause, precisely:**
- `.bash.d/03-mytools/05-mytools.sh:34` — `__rebuild_mytools_cache` runs
  `find -L "$bashd_dir" -name "*.sh"` with no private-path exclusion, so the
  TSV index (5th column = source filename) includes private rows.
- `mt-dump` consumes those rows for both the alias section
  (`awk -F'\t' '$1 == "alias"'`) and the function sections, then locates source
  to inline via `grep -rlE "^${name}\(\)" "$HOME/.bash.d/"` — also unfiltered.

**Fix in `mt-dump` only, not in `__rebuild_mytools_cache`.** Filtering the
shared cache would also strip private commands from `mytools`, `mt-fzf`,
`mt-run` and `mt-search`, where the owner legitimately wants them locally. The
asymmetry is the point: discoverable locally, never written to a tracked file.

**Steps**

1. In `mt-dump`, filter both the alias and function passes on the TSV's 5th
   column, dropping rows whose source path matches `*/40-private/*` or
   `*/lib/private/*`. Reuse the exclusion list already in
   `.bash.d/20-vcs/52-git-sync.sh:184` rather than writing a third copy —
   consider hoisting it to a single shared helper.
2. Constrain the `src_file` lookup to the same non-private set, so a
   public-named function defined privately cannot pull private source in.
3. Suppress category headings that end up empty after filtering (the
   video-finder content occupied three whole categories).
4. Rename the existing `--private` flag to `--internal` (keep `--private` as a
   deprecated alias). It currently means "include `_`/`__`-prefixed internal
   helpers", which reads as if it controls `40-private/` inclusion and does
   not. Filtering of `40-private/` must be unconditional, with no opt-out flag.
5. Add `tests/bash/test_mt_dump.bats`. `tests/bash/test_mt_alias.bats` already
   establishes the fake-`$HOME`-with-`40-private/` harness — copy it: seed a
   public and a private command, run `mt-dump -d`, assert the private name
   appears nowhere in the output.
6. Add a CI guard to the `Lint & Format Check` job in
   `.github/workflows/release.yml`: assert that every `#### \`name\`` in
   `TECHNICAL_REFERENCE.md` has a matching `^name()` definition in tracked
   `.bash.d/`. That invariant holds as of this plan's commits and catches any
   future leak at PR time, whatever its cause. There is precedent for
   doc-drift gating in the existing `Check whether COMMANDS.md changed` step.
7. Only then regenerate the reference and commit it.

**Acceptance:** with `40-private/` populated, `mt-dump` output contains no
private command name or source line; the new bats test and CI guard both fail
if that regresses.

**Note on history:** the leaked content remains in git history (introduced by
`344e289`, last refreshed by `ee2b3c6`) and in the 2 existing forks. Given that
no credentials were involved, a history rewrite of a public repo is likely
disproportionate — but that is the owner's call, and it cannot be undone later
by any amount of forward-fixing. Decide explicitly rather than by default.

---

### P1 — Foundation and quick wins

Do these before the service wrappers. P1-1 is the tool used to validate
everything after it; P1-2 is the substrate five P2 items build on. The rest are
each under an hour and remove friction felt weekly.

#### P1-1 · `mt-test-all` — run the full bats + pytest suite · **S** · #310

Every item in this plan ends with "run the checks". Build the one-command
runner first and the rest of the work gets cheaper.

1. Add to `.bash.d/03-mytools/` (it is framework tooling, not a utility).
2. Run `python3 -m pytest tests/python/` and `bats tests/bash/`, plus
   `shellcheck`/`shfmt`/`ruff` behind a `--lint` flag, with the exact
   suppression list CI uses — read it from one place so it cannot drift from
   `release.yml`.
3. Aggregate exit codes: run everything, report a per-suite summary, exit
   non-zero if any failed. Do not stop at the first failure.
4. Support `-j`/`--json` for machine-readable output — `mt-doctor` and
   `docker-ls` already set that precedent.

**Acceptance:** `mt-test-all` passes on a clean tree; returns non-zero with a
deliberately broken test; JSON output parses with `jq`.

#### P1-2 · Authenticated HTTP request helper · **M** · #247

The substrate for #283, #326, #349, #350, #352, #353 — every one of which
currently hand-rolls `curl` with auth. Build it once, properly.

1. New module under `.bash.d/02-utilities/` (e.g. `37-http-client.sh`), plus an
   internal `__mt_http` for other modules to call. Number it so service
   wrappers that need it load later.
2. Support: method, custom headers, basic auth, bearer auth, request body,
   query-parameter encoding, `-L` following, JSON pretty-printing via `jq` when
   the response is JSON.
3. **Redact credentials from every error path and any verbose/debug output.**
   This is the one place in the backlog where a mistake writes a secret to a
   terminal or a log, and `.bash.d/02-utilities/35-logging.sh` may persist it.
4. Report HTTP status distinctly from transport failure — `#337` exists
   precisely because a permission denial was indistinguishable from a broken
   command.
5. Encode the auth lesson from #353: for Atlassian, basic auth against the site
   URL returns 401; the scoped-token gateway
   (`api.atlassian.com/ex/confluence/...`) must be used instead. Make the
   helper steer callers to the working form rather than leaving each to
   rediscover it.
6. Add `tests/bash/test_http_client.bats` — argument assembly and redaction are
   testable without network by stubbing `curl`.

**Acceptance:** authenticated GET and POST against a local stub; no credential
appears in output or logs on success, failure or verbose paths.

#### P1-3 · `gcl-auth-check` — is the active gcloud token actually usable · **S** · #331

`gcloud auth list` shows accounts but not reauth-needed state, so a
non-interactive session looks healthy and then fails mid-task. This is a
precondition for every P3 item; build it first so they can call it.

1. Add to `.bash.d/10-infra/30-gcp-config.sh`.
2. Probe with a cheap authenticated call (e.g.
   `gcloud auth print-access-token`), and treat reauth-required as its own exit
   state — distinct from "no account" and "account present and valid".
3. Exit codes must be scriptable; print the remedy (`gcloud auth login`) on
   failure.
4. Wire into `mt-doctor` as a check, respecting its `--json` mode.

**Acceptance:** correct, distinct results for valid session, expired/reauth
session, and no active account.

#### P1-4 · Non-modifying Python lint check · **S** · #330

Today only `ruff-fmt` exists and it **rewrites files**, so there is no way to
check Python without mutating the tree — bad before a review, worse in CI-like
use.

1. Add `ruff-check` next to `ruff-fmt` in `.bash.d/03-mytools/07-formatting.sh`.
2. Run `ruff check` + `ruff format --check`, aggregate exit codes, never write.
3. Cross-reference it from `ruff-fmt`'s docstring so the destructive one is not
   the only discoverable option.

**Acceptance:** non-zero on a badly formatted file with the file left
byte-identical.

#### P1-5 · `uv`-based pytest with coverage · **S** · #329

1. Add to `.bash.d/03-mytools/` or alongside the Python helpers.
2. `uv sync --frozen` then `pytest --cov`; fail clearly if `uv` is absent or
   the project has no lockfile, rather than falling back silently to a
   different interpreter.
3. Pass through extra pytest args.

**Acceptance:** runs green in a `uv` project; actionable error outside one.

#### P1-6 · Working-tree diff including untracked files · **S** · #351

Filed because a review agent had to stitch together `git status`, `git diff`
and `cat` to see uncommitted work.

1. Add to `.bash.d/20-vcs/50-git.sh`.
2. Combine tracked diff with untracked file contents in one output — the
   `git add --intent-to-add` trick on a temporary index is cleaner than
   concatenating `cat` output, and keeps everything in real diff format.
3. **Must not mutate the user's index.** Use a scratch index
   (`GIT_INDEX_FILE`) and verify `git status` is unchanged afterwards.
4. Respect `.gitignore`; support `--stat`.

**Acceptance:** shows tracked and untracked changes in one diff; `git status`
byte-identical before and after.

---

### P2 — Atlassian / Bitbucket tier

Six issues, all from real day-job work, all currently solved by raw `curl`.
Build on P1-2; share one auth/error/redaction path. Suggested home: a new
`.bash.d/10-infra/` or `.bash.d/20-vcs/` module per service, numbered after
P1-2's.

| Order | Issue(s) | Command | Effort | Notes |
|---|---|---|---|---|
| P2-1 | #349 | `bb-pr` | M | PR metadata, diff, diffstat, comments by repo + PR number |
| P2-2 | #339 | fix `git-raise-pr` | M | Closest thing to a bug in the list — see below |
| P2-3 | #352 (closes #338) | `bb-pipelines` | M | Runs, per-step result, redacted log tail |
| P2-4 | #283 (closes #350, #353) | `conf-get` / `conf-search` | M | Page + folder reads, CQL search, storage→text |
| P2-5 | #326 | `bb-env` / `bb-var` | S | Deployment environments and pipeline variables |

**P2-2 is the priority inside this tier.** `git-raise-pr` is an existing,
documented command that only pushes the branch and opens a browser, then prints
"gh CLI not found" on Bitbucket — a half-working advertised feature is worse
than a missing one. Fix it to create the PR through the Bitbucket API using the
same credentials the rest of this tier uses, and keep the browser-open as a
fallback rather than the happy path.

**Per-item steps** (apply to each row):

1. Call `__mt_http` from P1-2; add no second auth implementation.
2. Guard on `BITBUCKET_EMAIL`/`BITBUCKET_API_KEY` (or
   `CONFLUENCE_EMAIL`/`CONFLUENCE_API_TOKEN`) up front with the
   `54-clone.sh:333` pattern; `touch` the secret after a successful call.
3. Encode the API's sharp edges once: pipeline UUIDs need their braces
   URL-encoded, log endpoints need redirect-following (#352), and Confluence
   needs the scoped-token gateway (#353).
4. **Redact credentials and truncate log tails by default.** #352 asks for a
   *redacted* tail specifically; CI logs are a common accidental-secret vector.
5. Convert storage-format HTML to text in `lib/python/`, not a heredoc
   (#283, #350, #353).
6. Close the consolidated duplicates listed in section 4 as part of the PR.

**Acceptance per item:** works against a real repo/space; clear, actionable
error on missing credentials, 401, 403 and 404; no credential in any output.

---

### P3 — GCP read-only wrappers

One consistent family. All read-only, all low risk. Each should call P1-3's
auth check first and report a permission denial as a permission denial.

| Order | Issue | Command | Effort | Notes |
|---|---|---|---|---|
| P3-1 | #332 | GCS prefix / object-count listing | S | `gcloud storage ls` wrapper |
| P3-2 | #336 | Cloud Run log summary by message template | M | Count by template, never print payloads |
| P3-3 | #337 | `bq query` wrapper, read-only aggregates | M | Must surface `bigquery.jobs.create` denial clearly |
| P3-4 | #325 | WIF pools, SA/project IAM policy, Redis describe | M | Reuse `gcl-iam-keys`/`gcp-iam-show` where they overlap |

**Steps:** add to `.bash.d/10-infra/31-gcp-services.sh` (or `32-gcp-survey.sh`
for the survey-shaped ones); enforce read-only by construction — no wrapper in
this tier should be able to mutate, and #337 in particular must reject
non-`SELECT` statements rather than trusting the caller. #336 exists because
log payloads were being dumped to find a count: aggregate without printing
payloads, since Cloud Run logs can carry customer data.

---

### P4 — Developer-workflow utilities

| Order | Issue | Command | Effort | Notes |
|---|---|---|---|---|
| P4-1 | #277 | multi-repo grep/find | M | Combined `grep -rIl` + `find` across `VCS_ROOT`; parallelise like `tf-val-all` does |
| P4-2 | #323 | PR review helper | S | List open PRs + diff vs base. Mostly `gh` glue; overlaps P2-1's shape — share the output format |
| P4-3 | #308 | `conftest` wrapper | S | Validate/test against OPA policies; add `conftest` to `dependencies.sh` |
| P4-4 | #299 | HTML tag-balance + anchor validation | S | Pure `lib/python/`; the one item here with no external dependency |

---

### P5 — Python test-harness research

Highest effort and highest uncertainty in the backlog. All three were filed
during one silent-failure review of a single repository, so the evidence that
they generalise is thin. Build P5-1, use it on a second real project, and only
then decide whether P5-2 is worth it.

- **P5-1 · #333 (absorbs #335) · L** — run an ad-hoc stubbed Python repro
  script against a repo venv, hermetically and with no network. #335 is the
  same harness plus fixtures for GCP clients and `httpx.MockTransport`; treat
  it as P5-1's fixture library, not a separate command.
- **P5-2 · #334 · XL** — mutation-probe a pytest suite against scratch copies
  of `src`. Prefer configuring an existing mutation-testing tool over
  maintaining a bespoke mutation engine; if nothing fits, keep the mutation
  list in `lib/python/` and version it.

**Guard rail:** both operate on scratch copies. Make it impossible to mutate or
run against the real working tree — assert the scratch path is outside the repo
before executing, and fail closed.

---

### P6 — Arch Linux support · **XL** · #246 · *separate track*

The only issue in the list serving other users rather than the author's own
workflow, and the only one that already carries a complete implementation plan
(a `PKG_MANAGER` global, a `PACMAN_DEPENDENCIES` array, pacman branches through
`04-bootstrap.sh`, `install.sh`, `install-wizard.sh` and `02-update-check.sh`,
and an AUR-helper policy). The design in the issue is sound; follow it rather
than re-deriving it.

**Keep it off the critical path and give it its own PR.** It touches every
dependency-install and system-update path in the framework, including
`install.sh` — the highest-blast-radius code here — and it cannot be verified
on the primary dev machine. The issue's own plan calls for validating package
names in a throwaway `archlinux:latest` container; do that, and re-run the
existing bats suite on Debian/WSL to prove `PKG_MANAGER` resolves to `apt`
exactly as before.

Two things the issue flags that must not be skipped: confirm the `bats` package
name against real Arch repos (it may be AUR-only), and add the Arch container
CI job as the stated follow-up, since Arch otherwise joins macOS at the
untested tier.

---

## 4. Duplicates to close as part of the work

Close these with a pointer to the PR that implements the surviving issue — do
not implement them separately:

| Close | When | Superseded by |
|---|---|---|
| #338 | P2-3 lands | #352 (runs + steps + logs, a superset) |
| #350 | P2-4 lands | #283 (same Confluence read capability) |
| #353 | P2-4 lands | #283 — but port its gateway/401 finding into the implementation first |
| #335 | P5-1 lands | #333 (same harness; #335 is its fixture library) |

---

## 5. Explicitly out of scope

- **Windows-host application tooling** — Windows Search/`SystemIndex`
  probing, WinUI/.NET scaffolding, Windows-host build and probe runners
  (#340–#348, closed). This framework targets GCP/Platform/DevOps work from
  WSL, macOS and Linux; it is not the home for a private Windows app's build
  tooling.
- **Private local integrations** — anything whose only consumer lives in
  `~/.bash.d/40-private/` or a private standalone repository. Such commands
  belong in `40-private/`, which exists for exactly this and is excluded from
  sync. P0-1 is what makes that boundary actually hold.
- **Filing a public issue for the P0-1 leak.** It is tracked here instead,
  deliberately: a public issue describing which private commands were exposed
  in a public repository advertises the thing it is trying to clean up.
