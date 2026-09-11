#!/usr/bin/env bash

LOCK_FILE="/tmp/.mt_vsix_installed"
REPO="MatStacey/mt-devops-vscode-extension-pack"

# 1. Fast idempotency check (avoids calling the CLI repeatedly)
if [ -f "$LOCK_FILE" ]; then
  echo "✅ Extensions already processed for this session. Skipping."
  exit 0
fi

# 2. Wait for VS Code Server to finish injecting the 'code' CLI into PATH
echo "⏳ Waiting for VS Code CLI..."
for _ in {1..60}; do
  if command -v code > /dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! command -v code > /dev/null 2>&1; then
  echo "🚨 Error: 'code' CLI not found. VS Code Server is too slow to start."
  exit 1
fi

# 3. Bypass GitHub API Rate Limits by querying the release web redirect
echo "📦 Resolving latest release of ${REPO}..."
LATEST_URL=$(curl -Ls -o /dev/null -w "%{url_effective}" "https://github.com/${REPO}/releases/latest")
TAG=$(basename "$LATEST_URL")

if [[ "$TAG" != v* ]]; then
  echo "🚨 Error: Could not determine latest release tag (Got: $TAG)."
  exit 1
fi

# Extract version number without the 'v' prefix (e.g., v0.0.5 -> 0.0.5)
VERSION="${TAG#v}"

#######################################
# Installs one package's VSIX from the resolved release, skipping it if
# already installed. Never aborts the whole script on one package's
# failure -- each package is independent, so a transient download issue
# on one shouldn't block the other.
# Arguments:
#   $1 - Package name (matches both the VSIX filename prefix and, as a
#        substring, the installed extension ID)
#######################################
install_vsix() {
  local package_name="$1"

  if code --list-extensions | grep -qi "$package_name"; then
    echo "✅ ${package_name} is already installed. Skipping."
    return 0
  fi

  local vsix_url="https://github.com/${REPO}/releases/download/${TAG}/${package_name}-${VERSION}.vsix"
  echo "⬇️ Downloading ${vsix_url}..."
  local tmp_vsix
  tmp_vsix=$(mktemp --suffix=.vsix)

  if ! curl -L -# --fail "$vsix_url" -o "$tmp_vsix"; then
    echo "🚨 Error: Could not download ${package_name} from ${vsix_url}."
    rm -f "$tmp_vsix"
    return 1
  fi

  echo "⚙️ Installing ${package_name}..."
  code --install-extension "$tmp_vsix" --force
  rm -f "$tmp_vsix"
  echo "✅ ${package_name} installed successfully!"
}

install_vsix "mt-devops-vscode-extension-pack"
install_vsix "mt-devops-companion"

touch "$LOCK_FILE"
