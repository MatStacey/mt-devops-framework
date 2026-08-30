# Contributing

This covers contributing a change back upstream via a Pull Request. If you're
looking to keep your *own* fork in sync instead, see the README's
["Contributing / Becoming a Collaborator"](README.md#6-contributing--becoming-a-collaborator)
section -- that's about `mt-become-collaborator` and one-way profile syncing,
a different concept from what's on this page.

## Getting a change into a PR

If you already have the framework installed, the fastest path is its own
tooling: edit files under `~/.bash.d/` (not the repo clone), then run
`mt-push-update`. It formats, lints, commits, pushes to your fork, and opens
the PR for you -- see the README section linked above if you haven't run
`mt-become-collaborator` yet.

If you don't have the framework installed, or you're changing something
outside `.bash.d/` (`install.sh`, `.github/workflows/`, this file), just use
a normal git workflow: fork, branch, commit, push, open a PR against `main`.

## Module load order

`.bashrc` sources every `.sh` file under `~/.bash.d/` in a single pass:

```bash
find -L "$HOME/.bash.d" -type f -name "*.sh" ... | sort
```

Since `find | sort` is plain lexical ordering, the numbered directory
prefixes (`00-system/`, `01-ui/`, `02-utilities/`, `03-mytools/`, `10-infra/`,
`20-vcs/`, `30-ai/`, `40-private/`) *are* the load order, not just a naming
convention. `00-system/00-config.sh` runs first and exports the globals
(`CONFIG_FILE`, `SECRETS_DIR`, colors aren't loaded yet at that point, etc.)
that later files depend on -- if you add a new module, pick a number that
reflects what it depends on already being loaded, not just where it feels
thematically closest.

## No inline code blocks

Multi-line Python, AWK, or template content never lives inside a bash
function as a heredoc or inline string -- it's extracted into its own file
under `lib/` (`lib/python/`, `lib/awk/`, `lib/templates/`) and invoked from
bash. This keeps each language's own tooling (`ruff`, `shellcheck`) actually
able to lint it, and keeps bash functions short enough to read. Look at any
existing function that shells out to `lib/python/*.py` or `lib/awk/*.awk` for
the pattern before adding a new one.

## Running the checks locally

CI (`.github/workflows/release.yml`) runs these on every PR; running them
yourself first saves a round trip:

```bash
# Bash lint -- same suppressions CI uses
find .bash.d -type f -name "*.sh" -print0 \
  | xargs -0 shellcheck -e SC1090,SC1091,SC2119,SC2120,SC2207,SC2015,SC2317,SC2016,SC2129,SC2028,SC1003
shellcheck -e SC1090,SC1091,SC2119,SC2120,SC2207,SC2015,SC2317,SC2016,SC2129,SC2028,SC1003 install.sh .bashrc

# Bash formatting -- Google Shell Style
shfmt -d -i 2 -ci -sr .

# Python lint
ruff check .

# Python tests
python3 -m pytest tests/python/ -v

# Bash tests
bats tests/bash/
```

`shellcheck`, `shfmt`, `ruff`, and `bats` are all in `dependencies.sh` --
run `bootstrap` to install anything missing. If your platform's package
manager doesn't ship a recent enough `bats`, vendor it locally instead of
skipping the check: `git clone https://github.com/bats-core/bats-core.git
&& bats-core/install.sh /some/local/dir`.

## Recurring self-audit

This project's found its highest-value bugs by periodically auditing its own
codebase rather than waiting for issues to arrive -- worth repeating roughly
quarterly rather than treating it as a one-off.
