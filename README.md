# MT DevOps Framework

[![Release](https://github.com/MatStacey/mt-devops-framework/actions/workflows/release.yml/badge.svg)](https://github.com/MatStacey/mt-devops-framework/actions/workflows/release.yml)
[![Latest Release](https://img.shields.io/github/v/release/MatStacey/mt-devops-framework)](https://github.com/MatStacey/mt-devops-framework/releases/latest)
[![License: MIT](https://img.shields.io/github/license/MatStacey/mt-devops-framework)](LICENSE)

A high-performance, fully modular Bash environment engineered specifically for Senior GCP, Platform, and DevOps Engineers. Originally built for Windows Subsystem for Linux (WSL2), it now natively supports macOS (Darwin) and standard Linux distributions.

This configuration adheres to DRY principles, relies on native Bash and standalone Python script execution for zero-latency loading, and aggregates modern CLI tools for Google Cloud Platform, Kubernetes, Terraform, and Python development.

## 🚀 Recent Updates & Enhancements

- Added `bb-deployments`: the latest deployment of each Bitbucket environment, or the history of one (`-e`, `-n`), with commit, branch, build number and who triggered it.
- Added `gcl-run-compare`: compares one Cloud Run service across projects (image, service account, scaling, networking, probes, env var names, secret references) and marks the rows that differ. Environment values are never shown. `kv_matrix.awk` gains `diff_only` and `flag`.
- Added `gcl-firestore`: read-only Firestore access over REST with `get` (field masks), `query` (a `--where` builder or a raw structured query, default limit 100) and `count`, returning plain JSON with `_id`.
- Added `gcl-scheduler`: lists Cloud Scheduler jobs across projects and locations (the configured scan regions by default), describes a job without exposing bodies or header values, and pauses or resumes it after confirmation. Permission errors now also name pause/resume-style permissions.
- Added `gcl-metric-read`: reads Cloud Monitoring time series for any metric over a time window (alignment, reducer, group-by, `--align window` for one total per series) and lists metric types by prefix. Adds shared REST helpers (`__mt_gcl_rest`, `__mt_gcl_rest_collect`) for upcoming GCP commands.
- `gcl-bq-query` now dry-runs every query first and refuses one estimated to scan more than a cap (`gcp.bq_max_bytes_billed`, default 10 GiB; set in `mt-wizard-gcp`). New `--max-bytes` and `--dry-run` options; the real run carries `--maximum_bytes_billed`.
- `mt-grep-repos` can search remote-tracking branches without checking them out: `-b <ref-glob>` or `-B` for all, with `-u` to merge identical hits across branches.
- `bb-pipelines` now shows each step's start and end time and each run's duration in the list view.
- `gcp-iam-show` now accepts repeated `-p` and a `-m/--member` filter: for one member it lists their roles, and across several projects it prints a role x project matrix. Adds a generic `lib/awk/kv_matrix.awk` pivot. Without the new flags, output is unchanged.
- Added `gcl-audit-changes`: lists who changed what in one or more GCP projects during a time window (relative or absolute), from the Admin Activity audit log, merged across projects and sorted by time. Also adds shared helpers in `33-gcp-read-only.sh` for upcoming GCP commands.
- Replaced employer workspace, project and Jira-key examples in docstrings and test fixtures with generic placeholders. No behavior change.
- `mt-suggest` no longer records your working directory in the public backlog issue, only whether you were in a work or personal repository. The team instruction block in `docs/TEAM_INTEGRATION.md` now files only reusable, new gaps (at most 5 per session), and no longer tells agents to run interactive commands that hang.
- Hardened the new Atlassian/GCP/HTTP commands after a code review and live runs: request timeouts and safer credential handling in `mt-http`, a tighter read-only guard for `gcl-bq-query`, fuller secret redaction in `bb-pipelines --log`, and Confluence table/macro conversion fixes. Option parsers across the framework no longer loop forever on a trailing flag with no value.
- Added Bitbucket tooling: `bb-pr` (PR metadata, diff, diffstat, comments), `bb-pipelines` (runs, steps, redacted log tails), and `bb-env`/`bb-var` (deployment environments and pipeline variables). `git-raise-pr` now creates the pull request through the Bitbucket API instead of only opening a browser.
- Added Confluence reading: `conf-get` (page as plain text), `conf-folder` and `conf-search`, via the scoped-token gateway.
- Added read-only GCP wrappers: `gcl-gcs-summary`, `gcl-run-log-summary`, `gcl-bq-query` and `gcl-wif-describe`, plus `gcl-auth-check` (also reported by `mt-doctor`) to detect an expired gcloud login before a long task fails.
- Added `mt-http`, an authenticated HTTP client that keeps credentials off the command line and out of every message.
- Added developer helpers: `ruff-check` (read-only lint), `uv-pytest`, `git-diff-all` (tracked and untracked changes in one diff) and `mt-test-all`.
- `mt-dump` no longer writes private (`40-private/`, `lib/private/`) commands into the generated reference; `--private` is now `--internal`. Documentation moved into a top-level `docs/` folder.
- Added `-j` / `--json` support to `mt-doctor` and `docker-ls` for machine-readable output.

---

## 📋 Prerequisites

Before installing this terminal environment, ensure your local workstation meets the following baseline requirements:

* **Operating System:** Officially supports WSL2 (Debian/Ubuntu), macOS (via Homebrew), and native Linux.
* **IDE (Optional):** Both **Visual Studio Code** and **JetBrains IntelliJ** are natively supported for launcher integration (`ide`, `git-clone-ide`, configurable via `mt-set-default-ide`). If using VS Code on Windows, ensure the **WSL Extension** is installed.
* **VSCode Extension Pack & Companion:** If your `DEFAULT_IDE` is VS Code, it is highly recommended to install the standardized extension pack (linting, formatting, and infrastructure integrations like Terraform and Checkov) plus the **MT DevOps Framework Companion** -- a real extension giving command-palette access to the full `mt-` catalog, an activity bar view (Jobs/Repo Radar/Secrets/Status/Doctor/Docker/Kubernetes), a `@mtdevops` AI chat participant, and an Explorer "Copy for LLM" action. Both are released from the same repository: [MatStacey/mt-devops-vscode-extension-pack](https://github.com/MatStacey/mt-devops-vscode-extension-pack).
* **Git:** Required to clone the initial repository and handle ongoing AI-assisted profile synchronization.

---

## 🚀 Key Features

* **Cross-Platform Compatibility:** Native OS detection dynamically maps clipboard (`pbcopy`, `clip.exe`), file explorer (`open`, `explorer.exe`), and package manager (`brew`, `apt`) utilities based on your host architecture.
* **Zero-Lag Dynamic Prompt:** Real-time, color-coded Git status, Kubernetes context, and GCP project/account tracking optimized for minimal latency by prioritizing native file reads over subshells where possible. Includes OSC 8 clickable hyperlinking for Git branches and GCP consoles.
* **Asynchronous Update Checks:** Silently checks for system package updates, as well as upstream terminal profile updates, in the background on a configurable TTL timer without blocking terminal initialization.
* **Decoupled Python Configuration:** A dedicated standalone Python manager (`lib/python/config_manager.py`) reads `config.yaml` (in `${XDG_CONFIG_HOME:-~/.config}/mt-devops-framework/`) to dynamically inject customizable directory paths, model/provider settings, and remote repository URLs directly into the shell environment.
* **Secrets Manager with Lifecycle Tracking:** API keys and tokens are never stored in `config.yaml`. They live in `~/secrets/secrets.sh` — a plain `export VAR="value"` file outside the dotfiles repo entirely, sourced automatically on shell startup. The interactive `mt-secrets` menu manages Gemini, Claude, Bitbucket, and Docker Hub credentials, tracking created/expiry/last-used dates per secret with color-coded expired/expiring/active status.
* **Modular Theme Engine:** Color themes are fully externalized into standalone files under `~/.bash.d/config/themes/`, allowing custom aesthetic definitions and instant switching (`mt-set-theme`).
* **Automated Bootstrapping:** Built-in `bootstrap` function automatically resolves and installs required APT/Homebrew packages, Python linters (`ruff`, `checkov`), formatters (`yapf`, `shfmt`), modern CLI binaries (`yq`, `eza`, `batcat`, `zoxide`), and heavier infrastructure tooling on demand -- Terraform, the Google Cloud CLI, `kubectl`, GitHub CLI, Ookla Speedtest, and Claude Code.
* **Multi-Provider AI Architecture:** Consult universal AI via the `ai` command with support for **Gemini**, **Claude**, and **Local LLMs** (via Ollama or any OpenAI-compatible endpoint). Background workflows like `git-ai-push-all` dynamically respect your active `DEFAULT_AI` setting.
* **Multi-Threaded Validation:** The `tf-val-all` command leverages `xargs -P` with configurable thread limits to concurrently validate and run Checkov security scans across all Terraform modules. `tf-ai-iam` complements it with AI-driven analysis (and optional script generation) of the IAM permissions a Terraform codebase actually requires.
* **Interactive Command Center:** `mt-menu` is an fzf-driven master menu fronting nearly the entire framework -- fifteen categories deep, from secrets and Git to Kubernetes and AI -- for anyone who'd rather browse than memorize commands.
* **Bulk Repository Management:** `mt-clone` bulk-clones an entire Bitbucket workspace/project with type/language/date/age filters, disk-space checks, and an fzf exclusion picker; `mt-bulk-update` then keeps every local repo under `VCS_ROOT` fast-forward-updated in one pull-only, never-force pass.
* **AI-Powered VCS Insight:** `mt-radar` builds an AI- and heuristic-driven dashboard of every repo under `VCS_ROOT` -- auto-detecting CI/CD provider, build tool, test framework, and stack, plus an AI-generated one-line description -- browsable via a live fzf preview pane.
* **Self-Healing Lifecycle Tooling:** `mt-doctor` gives a report-only health check (version drift, sync config, Git state); `mt-migrate-symlink` performs a one-time cutover to a single symlinked copy of the framework so `~/.bash.d` and the repo checkout can never drift apart; `mt-uninstall` offers a full, backup-first removal wizard.
* **Ad Hoc Utilities:** `mt-http-server` serves a directory over HTTP with optional Basic Auth and a WSL LAN bridge (Windows portproxy + firewall rule); `mt-backup`/`mt-restore` handle zip/rar/tar archives; `mt-speedtest` wraps the Ookla CLI; and `mt-jobs` tracks every framework command that's been backgrounded.
* **Atlassian Tooling:** `bb-pr`, `bb-pipelines`, `bb-env`/`bb-var` and a Bitbucket-aware `git-raise-pr` cover pull requests, pipeline runs/logs, deployment environments and variables from the terminal; `conf-get`, `conf-folder` and `conf-search` read Confluence pages and search spaces. Secured values and credentials are never printed. Required secrets are listed under [Secrets](#-secrets).
* **Read-Only GCP Inspection:** `gcl-auth-check` (is my login still valid?), `gcl-gcs-summary`, `gcl-run-log-summary` (log lines counted by template), `gcl-bq-query` (single `SELECT`/`WITH` only) and `gcl-wif-describe`. Permission denials are reported as such, with the missing permission named.
* **Authenticated HTTP:** `mt-http` is a curl-style client with basic/bearer auth, JSON pretty-printing, timeouts, and credential masking on every output path.
* **Developer Workflow Helpers:** `mt-test-all` (bats + pytest, optional lint), `ruff-check`, `uv-pytest`, `git-diff-all`, `git-review-prs`, `mt-grep-repos`, `mt-conftest` and `mt-html-check`.
* **Repo Scaffolding:** `mt-blueprint` bootstraps a new repository from templates, injecting a CI/CD pipeline that matches your configured `CICD_PROVIDER`.

---

## 🛠️ Setup & Installation

This environment is designed to work out-of-the-box on a fresh WSL2 Debian/Ubuntu instance or macOS machine.

### 1. Clone the Repository

Clone the repository into a permanent directory. The installation script will automatically bind this location as your synchronized workspace -- since every merge to `main` is released automatically, cloning the default branch always gets you the latest release, with real Git history attached from the start (required for `mt-push-update`/`mt-get-update` to work correctly later).

```bash
git clone https://github.com/MatStacey/mt-devops-framework.git ~/vcs/personal/mt-devops-framework
cd ~/vcs/personal/mt-devops-framework
```

### 2. Run the Installer

Execute the installation script. This safely backs up your default `.bashrc`, copies over the modular `.bash.d/` structure, and dynamically scaffolds your local configurations.

```bash
./install.sh

```

**Prefer a guided setup?** Run `./install-wizard.sh` instead. It does everything `install.sh` does, then walks you through choosing an install type (Full, or Custom to pick individual optional tools like Terraform, the Google Cloud CLI, kubectl, and Speedtest), configuring each settings category, and setting up AI -- all via simple prompts, no extra dependencies required to run the wizard itself.

### 3. Automated Bootstrapping

At the end of the installation, you will be prompted to bootstrap system dependencies:
`🔍 Would you like to run 'bootstrap' to install system dependencies (jq, fzf, PyYAML, terraform, etc.) now? [Y/n]`

Press **Enter** (or `Y`). The system will automatically update your package manager, install core binaries, and configure isolated Python linters via `pipx`.

### 4. Interactive Setup

Initialize the dynamic prompt, custom themes, and run the automated setup wizard to configure your environment:

```bash
reload
mt-setup

```

The interactive wizard will seamlessly guide you through setting your default IDE, AI provider, and Git synchronization repository. To add your AI provider's API key, run `mt-add-gemini-key` or `mt-add-claude-key` — both write directly and safely to `~/secrets/secrets.sh` (created with restrictive permissions, entirely outside the git-tracked repo), so your key is never typed into a git-visible file.

### 5. Keeping Your Profile Updated

If you have linked your environment to a remote Git repository, you can easily pull the latest configuration changes across multiple workstations. Simply run:

```bash
mt-get-update

```

This command securely fetches your upstream commits and safely synchronizes them into your local `~/.bash.d/` workspace.

Run `mt-doctor` any time to check the health of your setup -- see [Troubleshooting & Debugging](#-troubleshooting--debugging) below.

### 6. Contributing / Becoming a Collaborator

If you don't have direct write access to this repository, run:

```bash
mt-become-collaborator
```

This forks the repository to your own GitHub account and points `mt-push-update` at your fork automatically, so your changes land as Pull Requests against the upstream repo instead of failing to push directly. It also offers to run `gh auth login` for you if the GitHub CLI isn't authenticated yet.

To make a change: on a machine cut over with `mt-migrate-symlink` (check with `mt-doctor`), `~/.bash.d` is a symlink into the repo checkout, so edit either path -- there is only one copy. On an older machine where `~/.bash.d` is a separate deployed copy, edit `~/.bash.d/` directly and not the repo clone, because `mt-push-update` syncs one-way from `~/.bash.d/` into the repo. Then run:

```bash
mt-push-update
```

This formats, commits, pushes to your fork, and raises the Pull Request for you.

---

## 🐳 Docker & Dev Container Integration

This framework includes a fully functional `Dockerfile` and `.devcontainer` configuration, allowing you to instantly spin up a pristine, isolated development environment without installing local dependencies.

When launched, the Dev Container automatically builds the base image, installs all framework tooling, and securely sideloads the latest release of both the [MT DevOps VSCode Extension Pack and the MT DevOps Framework Companion](https://github.com/MatStacey/mt-devops-vscode-extension-pack) directly from GitHub.

### 📋 Dev Container Prerequisites

* **Docker Desktop** (or a standard Docker Engine setup).
* **Visual Studio Code**.
* The **Dev Containers** extension (`ms-vscode-remote.remote-containers`) installed in VS Code.

### 🚀 Launch Steps

1. Download or clone this repository to your local machine.
2. Open the `mt-devops-framework` folder in Visual Studio Code.
3. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS) to open the Command Palette.
4. Type and select **Dev Containers: Reopen in Container**.
5. VS Code will build the image, initialize the framework, fetch the latest extension pack and companion `.vsix` releases, and drop you into a ready-to-use terminal!

---

## 📂 Repository Structure

| Path | Description |
| --- | --- |
| `.bash.d/` | The framework itself; deployed to `~/.bash.d`. Modules are loaded in directory-number order (see below). |
| `docs/` | `TEAM_INTEGRATION.md` and the generated `TECHNICAL_REFERENCE.md`. |
| `tests/` | `bats` suites for bash (`tests/bash/`) and `pytest` for Python (`tests/python/`). |
| `COMMANDS.md` | Generated index of every alias and function (kept at the repo root for the VS Code extension pack). |
| `install.sh`, `install-wizard.sh`, `.bashrc` | Installation entry points. |
| `Dockerfile`, `.devcontainer/` | Dev Container image and configuration. |
| `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE` | Contribution guide, vulnerability reporting policy, MIT license. |

### Modules in `.bash.d/`

| Module | Description |
| --- | --- |
| `00-system/` | OS detection, path definitions, package management, the `mt-setup` wizard, the `mt-secrets` credential manager (expiry/last-used tracking), async update checks, `mt-doctor` health diagnostics, and the `mt-uninstall` removal wizard. |
| `01-ui/` | Color variables and the dynamic terminal prompt. |
| `02-utilities/` | General purpose aliases, Docker handlers (including auto-versioned image build/tag/push to Google Artifact Registry and Docker Hub), path launchers, centralized `mt-log`, `mt-http-server` (with WSL LAN bridging and Basic Auth), `mt-http` (authenticated HTTP client), `mt-backup`/`mt-restore`, `mt-speedtest`, `mt-jobs`, `mt-test-all` and `mt-html-check`. |
| `03-mytools/` | The core documentation engine, your LLM context extractors, the `mt-menu` interactive command center, `mt-blueprint` repo scaffolding, `mt-suggest` backlog capture, and Python helpers (`ruff-check`, `uv-pytest`). |
| `10-infra/` | GCP authentication/project switchers (`gcl-auth-check`), read-only GCP inspection wrappers, concurrent Terraform validation plus AI-driven IAM analysis (`tf-ai-iam`), `mt-conftest`, interactive Kubernetes tooling, Helm release management, local Minikube lifecycle tooling, and a Docker-to-Helm deploy bridge (`docker-deploy`). |
| `20-vcs/` | Git wrappers (including `git-diff-all`, `git-review-prs`, and a `git-raise-pr` that creates GitHub and Bitbucket PRs), AI-assisted commit automation (`git-ai-push-all`), profile syncing (including the one-time `mt-migrate-symlink` cutover), the `mt-radar` insight dashboard, bulk repo cloning/updating/searching, and GCP project discovery and IAM advice. |
| `25-atlassian/` | Bitbucket Cloud (`bb-pr`, `bb-pipelines`, `bb-env`/`bb-var`, and the PR-creation helper behind `git-raise-pr`) and Confluence Cloud (`conf-get`, `conf-folder`, `conf-search`) API helpers, built on `mt-http`. |
| `30-ai/` | API integrations for Google Gemini, Anthropic Claude, local OpenAI-compatible endpoints, and debugging tools (`mt-ai-debug`). |
| `40-private/` | *(User-created, optional)* Local-only scripts, functions, and aliases -- sourced automatically like any other module, but excluded from `mt-push-update` sync, from generated documentation, and never overwritten by `mt-get-update`. |
| `config/` | Framework-shipped, git-tracked assets: AI configuration and prompts (`config/ai/`), export schemas, themes (`config/themes/`) and `dependencies.sh`. User settings live outside the tree, in `${XDG_CONFIG_HOME:-~/.config}/mt-devops-framework/`. |
| `lib/` | Helper files by language -- `awk/`, `jq/`, `python/`, `sed/`, `windows/` -- plus `templates/`, `blueprints/` and `registry/`. `lib/private/` *(user-created, optional)* mirrors `40-private/` for non-bash supporting assets. |

**Looking for a specific command?** [`COMMANDS.md`](COMMANDS.md) is a lean, auto-regenerated index of every alias and function (kept current by `mt-push-update`). [`docs/TECHNICAL_REFERENCE.md`](docs/TECHNICAL_REFERENCE.md) is the full generated reference with descriptions for everything, produced on demand by `mt-dump` (private modules are never included).

**Rolling this out across a team?** [`docs/TEAM_INTEGRATION.md`](docs/TEAM_INTEGRATION.md) has a copy-paste `CLAUDE.md` instruction block for making this framework the default terminal tooling on every implementation project, plus the `mt-suggest` backlog loop for capturing workflow gaps as they're found instead of quietly working around them.

---

## 🔐 Secrets

Credentials are plain `export` lines in `~/secrets/secrets.sh` (never in `config.yaml` or the repo). The `mt-add-*` commands write them for you and `mt-secrets` tracks expiry and last use.

| Variable(s) | Used by | Set with |
| --- | --- | --- |
| `GEMINI_API_KEY`, `CLAUDE_API_KEY` | `ai`, AI-assisted commits and summaries | `mt-add-gemini-key`, `mt-add-claude-key` |
| `BITBUCKET_EMAIL`, `BITBUCKET_API_KEY` | `bb-*`, `git-raise-pr`, `mt-clone` | `mt-add-bitbucket-secret` |
| `CONFLUENCE_EMAIL`, `CONFLUENCE_API_TOKEN`, `CONFLUENCE_SITE` (e.g. `yourorg.atlassian.net`) | `conf-*` | `mt-add-confluence-secret` |

---

## 🐛 Troubleshooting & Debugging

If you encounter missing commands, broken aliases, or stale environment variables, use the following built-in tools to resolve issues quickly:

* **`mt-doctor`:** Start here for anything that feels off. A report-only health check covering installed version vs. the latest release, sync configuration, and the sync repo's Git state (stuck branches, open PRs, an in-progress merge, uncommitted changes). Never changes anything, so it's always safe to run first.
* **`reload`:** Instantly re-sources your `~/.bashrc` without needing to restart your terminal session. Perfect for testing quick alias changes.
* **`mt-refresh-caches`:** Forcefully clears and rebuilds all background caches, including `.env.cache`, `mytools` indexes, and system update markers. Use this if your `mt` menu is missing newly added tools or configuration variables aren't persisting.
* **`bootstrap`:** Re-scans your host machine for missing dependencies (like `jq`, `fzf`, or Python linters) and installs them via `apt` or `brew`.
* **`sys-install`:** Installs all pending system OS updates and clears the pending-update marker from your prompt.
* **`sys-update`:** Manually triggers a standard OS package update check (`apt` or `brew` based on your OS).

---

## ❓ FAQ

**Q: Why didn't my new configuration variable apply immediately?**
**A:** The environment uses a high-performance cache to ensure zero-lag loading. If you manually edited `config.yaml` outside of the `mt-` configuration functions, run `mt-refresh-caches` to regenerate the environment cache.

**Q: How do I backup my custom profile modifications?**
**A:** First, ensure you have linked a remote repository using `mt-add-sync-url` or the `mt-setup` wizard. Then, run `mt-push-update`. This uses AI (if enabled) to group your changes into systematic commits and pushes them to your remote repository. For a quick local archive of any directory (not just this framework), use `mt-backup`/`mt-restore` instead -- unrelated to Git and useful for anything you want a fast zip/tar snapshot of.

**Q: I am getting an "Argument list too long" error when using the AI tools.**
**A:** This issue was resolved by utilizing temporary payload files. If you are experiencing this on an older version, run `mt-get-update` to automatically pull down the latest codebase fixes.

**Q: How do I add scripts that should stay local and never get pushed to the shared repo?**
**A:** Add them under `~/.bash.d/40-private/` (bash scripts, functions, and aliases -- sourced automatically like any other module) or `~/.bash.d/lib/private/` (supporting non-bash assets). Both are excluded from `mt-push-update`'s sync, the pre-push ShellCheck gate, and `mt-get-update`'s deploy sync, so they're never pushed to the repo and never overwritten by an update.