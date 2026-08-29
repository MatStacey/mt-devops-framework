# ==========================================
# Mandatory Profile Ignores
# ==========================================

# Secrets & Configuration: config.yaml, .syncignore, and
# secrets_metadata.yaml live outside .bash.d entirely (in
# ${XDG_CONFIG_HOME:-~/.config}/mt-devops-framework/), so there's
# nothing under this repo's own tree left to ignore for them.

# Framework Caches & State Variables -- these, along with cache/logs/
# the version file, also live outside .bash.d entirely now (in
# ${XDG_CACHE_HOME:-~/.cache} / ${XDG_STATE_HOME:-~/.local/state}), so
# there's nothing under this repo's own tree left to ignore for them
# either.

# Python & Linters
__pycache__/
.ruff_cache/

# IDE & Editor
.vscode/
.vsclog

# Build Artifacts & Miscellaneous
*.zip
.dev

# AI Assistant Configurations
CLAUDE.md
.bash.d/config/github_token.sh
.bash.d/config/*_token.sh

# Local-Only User Content
.bash.d/40-private/
.bash.d/lib/private/
