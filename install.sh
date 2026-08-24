#!/usr/bin/env bash
set -e

HOME_DIR="$HOME"
TARGET_BASHD="$HOME_DIR/.bash.d"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Starting installation of MT DevOps Framework..."

# 1. Backup existing .bashrc if it exists and isn't a symlink/our file
if [ -f "$HOME_DIR/.bashrc" ] && [ ! -L "$HOME_DIR/.bashrc" ]; then
  echo "📦 Backing up existing .bashrc to ~/.bashrc.bak..."
  cp "$HOME_DIR/.bashrc" "$HOME_DIR/.bashrc.bak"
fi

# 2. Sync core bashrc and modular directory
echo "📂 Copying .bashrc and .bash.d/ structure..."
rsync -a "$REPO_DIR/.bashrc" "$HOME_DIR/"
mkdir -p "$TARGET_BASHD"
# --delete would otherwise wipe any local-only files matching these
# patterns (*private*.sh, *.local.sh, *.local) plus the generated env
# cache — exclude all of them alongside config.yaml. Note: API keys and
# other real secrets live entirely outside .bash.d, in
# ~/vcs/secrets/secrets.sh, so they are never touched by this sync at all.
#
# data/cache/.vcs_hub.json is also excluded: it's the accumulated result
# of `mt-hub --index` scanning the user's repos (including AI-generated
# summaries), not framework state -- unlike the other caches under
# data/cache/, it isn't cheaply auto-regenerated, so an update should
# never silently discard it.
#
# config/secrets_metadata.yaml is excluded for the same reason: it's
# mt-secrets' tracked created/expiry/last-used dates for each secret,
# genuine user state with no source to regenerate from (unlike
# config.yaml, it has no .tpl to reseed from either) -- discarding it
# silently on every update would erase a user's expiry-tracking history.
rsync -a --delete \
  --exclude 'config/config.yaml' \
  --exclude 'config/.env.cache' \
  --exclude 'config/*_token.sh' \
  --exclude 'config/secrets_metadata.yaml' \
  --exclude 'data/cache/.vcs_hub.json' \
  --exclude '*private*.sh' \
  --exclude '*.local.sh' \
  --exclude '*.local' \
  "$REPO_DIR/.bash.d/" "$TARGET_BASHD/"

# 3. Scaffold config.yaml from template if missing
CONFIG_FILE="$TARGET_BASHD/config/config.yaml"
TEMPLATE_FILE="$TARGET_BASHD/lib/templates/config.yaml.tpl"
if [ ! -s "$CONFIG_FILE" ] && [ -f "$TEMPLATE_FILE" ]; then
  echo "⚙️ Scaffolding initial config.yaml from template..."
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cp "$TEMPLATE_FILE" "$CONFIG_FILE"

  # Automatically bind dotfiles_dir/sync_repo_dir to the directory where
  # install.sh was executed. Matches on the value itself (not a specific
  # key) so it rebinds both paths.* keys that default to this same path.
  echo "🔗 Binding sync repository path to extraction directory..."
  sed -i "s|~/vcs/personal/mt-devops-framework|$REPO_DIR|g" "$CONFIG_FILE"
fi

echo "✅ Files successfully synced to home directory."

# 4. Source OS detection + bootstrap helpers. Always runs -- both this
# script's own dependency check below and install-wizard.sh (which
# sources this file with MT_INSTALL_WIZARD=1 to reuse the sync above
# while driving its own interactive dependency selection instead) need
# OS_FAMILY/the dependency arrays/the installer functions available.
source "$TARGET_BASHD/00-system/00-os.sh"
source "$TARGET_BASHD/00-system/04-bootstrap.sh"

mkdir -p "$HOME/.bash.d/data/cache" "$HOME/.bash.d/data/logs" "$HOME/.bash.d/config"

if [ -z "${MT_INSTALL_WIZARD:-}" ]; then
  echo "🔍 Checking for missing system dependencies..."
  MISSING_DEPS_CHECK=()
  if [ "$OS_FAMILY" = "macos" ]; then
    MISSING_DEPS_CHECK=("${BREW_DEPENDENCIES[@]}")
  else
    MISSING_DEPS_CHECK=("${APT_DEPENDENCIES[@]}")
    MISSING_DEPS_CHECK+=("yq:yq") # Linux manually checks yq since it bypasses APT
  fi
  MISSING_DEPS_CHECK+=("${PYTHON_DEPENDENCIES[@]}" "${COMPLEX_DEPENDENCIES[@]}")

  # Utilize the framework's native checker
  MISSING_LIST=($(__get_missing_deps "${MISSING_DEPS_CHECK[@]}"))

  if [ ${#MISSING_LIST[@]} -gt 0 ]; then
    echo -e "\n\033[1;33m⚠️ Missing required dependencies detected: ${MISSING_LIST[*]}\033[0m"
    read -p "🔍 Would you like to run 'bootstrap' to install them now? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      bootstrap
    else
      echo "💡 You can run 'bootstrap' anytime later from your terminal."
    fi
  else
    echo "✅ All system dependencies are already satisfied."
  fi

  echo -e "\n🎉 Installation complete! Run 'source ~/.bashrc' or open a new terminal session to activate your environment."
fi
