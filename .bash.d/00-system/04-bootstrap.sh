# shellcheck shell=bash disable=SC2119,SC2120
# ------------------------------------------
# System & Environment Bootstrap
# ------------------------------------------
# ~/.bash.d/00-system/04-bootstrap.sh

if [ -f "$HOME/.bash.d/config/dependencies.sh" ]; then
  source "$HOME/.bash.d/config/dependencies.sh"
fi

#######################################
# System: Filter list of dependencies to return missing packages
# Arguments:
#   $@ - Dependency definitions (command:package)
# Outputs:
#   Prints one missing package name per line to STDOUT (nothing if none are
#   missing -- callers read this via `mapfile -t`, which requires
#   one-per-line output; a space-joined single line, or printf with no
#   arguments, both leave a phantom empty element in the resulting array)
#######################################
__get_missing_deps() {
  local missing=()
  for dep in "$@"; do
    local cmd="${dep%%:*}"
    local pkg="${dep##*:}"

    if [ "$cmd" = "python_yaml" ]; then
      python3 -c "import yaml" > /dev/null 2>&1 || missing+=("$pkg")
    else
      command -v "$cmd" > /dev/null 2>&1 || missing+=("$pkg")
    fi
  done
  [ ${#missing[@]} -gt 0 ] && printf '%s\n' "${missing[@]}"
  return 0
}

#######################################
# System: Bootstrap APT dependencies on Debian/WSL
#######################################
__bootstrap_apt() {
  local apt_deps
  mapfile -t apt_deps < <(__get_missing_deps "${APT_DEPENDENCIES[@]}")

  if [ ${#apt_deps[@]} -gt 0 ]; then
    echo -e "\n📦 Installing standard APT dependencies: ${apt_deps[*]}..."
    sudo apt-get update && sudo apt-get install -y "${apt_deps[@]}"
  else
    echo "✅ All standard APT dependencies are satisfied."
  fi
}

#######################################
# System: Bootstrap Homebrew dependencies on macOS
#######################################
__bootstrap_brew() {
  if ! command -v brew > /dev/null 2>&1; then
    echo -e "\n🍺 Homebrew not found. Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  if ! command -v brew > /dev/null 2>&1; then
    echo "🚨 Homebrew installation failed or 'brew' is still not on PATH. Skipping Homebrew bootstrap."
    return 1
  fi

  local brew_deps
  mapfile -t brew_deps < <(__get_missing_deps "${BREW_DEPENDENCIES[@]}")

  if [ ${#brew_deps[@]} -gt 0 ]; then
    echo -e "\n📦 Installing standard Homebrew dependencies: ${brew_deps[*]}..."
    brew install "${brew_deps[@]}"
  else
    echo "✅ All standard Homebrew dependencies are satisfied."
  fi

  command -v bat > /dev/null 2>&1 && export BAT_BIN="bat"
}

#######################################
# System: Bootstrap Python tooling dependencies via pipx/pip3
#######################################
__bootstrap_python() {
  local pip_deps
  mapfile -t pip_deps < <(__get_missing_deps "${PYTHON_DEPENDENCIES[@]}")

  if [ ${#pip_deps[@]} -gt 0 ]; then
    echo -e "\n🐍 Installing Python tooling (${pip_deps[*]})..."
    if command -v pipx > /dev/null 2>&1; then
      for pkg in "${pip_deps[@]}"; do pipx install "$pkg" 2> /dev/null || pip3 install --user "$pkg"; done
    else
      pip3 install --user "${pip_deps[@]}"
    fi
  else
    echo "✅ All Python CLI dependencies are satisfied."
  fi
}

#######################################
# System: Download and install yq binary on Linux
#######################################
__bootstrap_yq() {
  [ "$OS_FAMILY" = "macos" ] && return 0

  if ! command -v yq > /dev/null 2>&1; then
    echo -e "\n⚙️ Installing 'yq'..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod a+x /usr/local/bin/yq
    echo "✅ yq installed."
  fi
}

#######################################
# System: Install Ookla Speedtest CLI
#######################################
__install_speedtest() {
  echo -e "\n📦 Installing Ookla Speedtest CLI..."

  if [ "$OS_FAMILY" = "macos" ]; then
    if command -v brew > /dev/null 2>&1; then
      brew install speedtest
    else
      echo "🚨 Homebrew is required to install Speedtest on macOS."
      return 1
    fi

  elif command -v apt-get > /dev/null 2>&1; then
    local arch
    arch="$(dpkg --print-architecture)"

    if [ "$arch" != "amd64" ]; then
      echo "🚨 Unsupported architecture for Ookla Speedtest: $arch"
      return 1
    fi

    # We hard coded version to 1.2.0.84-1.ea6b6773cf because the Ookla packagecloud.io repository was returning 404s for Ubuntu Noble/Jammy, so we switched to downloading a known-good .deb directly.
    local version="1.2.0.84-1.ea6b6773cf"
    local url="https://packagecloud.io/ookla/speedtest-cli/packages/ubuntu/jammy/speedtest_${version}_amd64.deb/download.deb"
    local tmpdir
    tmpdir="$(mktemp -d)"

    echo "📥 Downloading Ookla Speedtest CLI..."

    if ! curl -fsSL -o "$tmpdir/speedtest.deb" "$url"; then
      echo "🚨 Failed to download Ookla Speedtest CLI."
      rm -rf "$tmpdir"
      return 1
    fi

    echo "📦 Installing Ookla Speedtest CLI..."

    if sudo apt-get install -y "$tmpdir/speedtest.deb"; then
      rm -rf "$tmpdir"
      echo "✅ Ookla Speedtest CLI installed successfully."
    else
      echo "🚨 Speedtest installation failed."
      rm -rf "$tmpdir"
      return 1
    fi

  else
    echo "🚨 Unsupported platform for Ookla Speedtest CLI."
    return 1
  fi

  if command -v speedtest > /dev/null 2>&1; then
    echo "✅ Speedtest is available at: $(command -v speedtest)"
  else
    echo "🚨 Speedtest installation failed."
    return 1
  fi
}

#######################################
# System: Install eza (a modern ls replacement) -- absent from a bare
# Debian/Ubuntu APT repo, so Linux needs the project's own third-party
# repo added first. macOS already covers this via a plain BREW_DEPENDENCIES
# entry, since eza is a standard homebrew-core formula there.
#######################################
__install_eza() {
  echo -e "\n📦 Installing eza..."

  if [ "$OS_FAMILY" = "macos" ]; then
    if command -v brew > /dev/null 2>&1; then
      brew install eza
    else
      echo "🚨 Homebrew is required to install eza on macOS."
      return 1
    fi

  elif command -v apt-get > /dev/null 2>&1; then
    sudo mkdir -p /etc/apt/keyrings
    if ! curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg; then
      echo "🚨 Failed to add the eza repository's signing key."
      return 1
    fi
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt-get update > /dev/null 2>&1
    if ! sudo apt-get install -y eza; then
      echo "🚨 eza installation failed."
      return 1
    fi

  else
    echo "🚨 Unsupported platform for eza."
    return 1
  fi

  if command -v eza > /dev/null 2>&1; then
    echo "✅ eza is available at: $(command -v eza)"
  else
    echo "🚨 eza installation failed."
    return 1
  fi
}

#######################################
# System: Install Terraform via HashiCorp's official APT repo (Linux) or
# the hashicorp/tap Homebrew tap (macOS) -- required since Terraform's
# BSL license removed it from both apt's default repos and homebrew-core.
#######################################
__install_terraform() {
  echo -e "\n📦 Installing Terraform..."

  if [ "$OS_FAMILY" = "macos" ]; then
    if command -v brew > /dev/null 2>&1; then
      brew tap hashicorp/tap
      brew install hashicorp/tap/terraform
    else
      echo "🚨 Homebrew is required to install Terraform on macOS."
      return 1
    fi

  elif command -v apt-get > /dev/null 2>&1; then
    local codename=""
    [ -f /etc/os-release ] && codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    if [ -z "$codename" ]; then
      echo "🚨 Could not detect the OS codename required for HashiCorp's APT repo."
      return 1
    fi

    if ! curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg; then
      echo "🚨 Failed to add HashiCorp's repository signing key."
      return 1
    fi
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${codename} main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
    sudo apt-get update > /dev/null 2>&1
    if ! sudo apt-get install -y terraform; then
      echo "🚨 Terraform installation failed."
      return 1
    fi

  else
    echo "🚨 Unsupported platform for Terraform."
    return 1
  fi

  if command -v terraform > /dev/null 2>&1; then
    echo "✅ Terraform is available at: $(command -v terraform)"
  else
    echo "🚨 Terraform installation failed."
    return 1
  fi
}

#######################################
# System: Install the Google Cloud CLI via Google's official APT repo
# (Linux) or the google-cloud-sdk cask (macOS)
#######################################
__install_gcloud() {
  echo -e "\n📦 Installing Google Cloud CLI..."

  if [ "$OS_FAMILY" = "macos" ]; then
    if command -v brew > /dev/null 2>&1; then
      brew install --cask google-cloud-sdk
    else
      echo "🚨 Homebrew is required to install the Google Cloud CLI on macOS."
      return 1
    fi

  elif command -v apt-get > /dev/null 2>&1; then
    if ! curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg; then
      echo "🚨 Failed to add Google Cloud's repository signing key."
      return 1
    fi
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
    sudo apt-get update > /dev/null 2>&1
    if ! sudo apt-get install -y google-cloud-cli; then
      echo "🚨 Google Cloud CLI installation failed."
      return 1
    fi

  else
    echo "🚨 Unsupported platform for the Google Cloud CLI."
    return 1
  fi

  if command -v gcloud > /dev/null 2>&1; then
    echo "✅ gcloud is available at: $(command -v gcloud)"
  else
    echo "🚨 Google Cloud CLI installation failed."
    return 1
  fi
}

#######################################
# System: Install kubectl via a direct binary download from Kubernetes'
# own stable-release endpoint (Linux) or the standard Homebrew formula
# (macOS) -- avoids pinning to one versioned APT repo, matching the same
# direct-download approach __bootstrap_yq already uses for yq.
#######################################
__install_kubectl() {
  echo -e "\n📦 Installing kubectl..."

  if [ "$OS_FAMILY" = "macos" ]; then
    if command -v brew > /dev/null 2>&1; then
      brew install kubectl
    else
      echo "🚨 Homebrew is required to install kubectl on macOS."
      return 1
    fi

  elif command -v curl > /dev/null 2>&1; then
    local arch
    arch="$(dpkg --print-architecture 2> /dev/null || uname -m)"
    [ "$arch" = "x86_64" ] && arch="amd64"
    [ "$arch" = "aarch64" ] && arch="arm64"

    local version
    version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    if [ -z "$version" ]; then
      echo "🚨 Could not resolve the latest stable kubectl version."
      return 1
    fi

    local tmpfile
    tmpfile="$(mktemp)"
    if ! curl -fsSL -o "$tmpfile" "https://dl.k8s.io/release/${version}/bin/linux/${arch}/kubectl"; then
      echo "🚨 Failed to download kubectl."
      rm -f "$tmpfile"
      return 1
    fi
    sudo install -o root -g root -m 0755 "$tmpfile" /usr/local/bin/kubectl
    rm -f "$tmpfile"

  else
    echo "🚨 Unsupported platform for kubectl."
    return 1
  fi

  if command -v kubectl > /dev/null 2>&1; then
    echo "✅ kubectl is available at: $(command -v kubectl)"
  else
    echo "🚨 kubectl installation failed."
    return 1
  fi
}

#######################################
# System: Check and report missing external dependencies
#######################################
__bootstrap_external() {
  local missing_external
  mapfile -t missing_external < <(__get_missing_deps "${EXTERNAL_DEPENDENCIES[@]}")

  for dep in "${missing_external[@]}"; do
    case "$dep" in
      speedtest)
        __install_speedtest
        ;;
      eza)
        __install_eza
        ;;
      terraform)
        __install_terraform
        ;;
      gcloud)
        __install_gcloud
        ;;
      kubectl)
        __install_kubectl
        ;;
      *)
        echo "⚠️ No installer defined for external dependency: $dep"
        ;;
    esac
  done
}

#######################################
# System: Check and report missing complex dependencies
#######################################
__bootstrap_check_complex() {
  local missing_complex
  mapfile -t missing_complex < <(__get_missing_deps "${COMPLEX_DEPENDENCIES[@]}")

  if [ ${#missing_complex[@]} -gt 0 ]; then
    echo -e "\n⚠️  The following tools are missing and require manual repo config:"
    for dep in "${missing_complex[@]}"; do echo "  - $dep"; done
  fi
}

#######################################
# System: Install the GitHub CLI and Claude Code if either is missing --
# shared by bootstrap() and install-wizard.sh so this logic exists once
#######################################
__bootstrap_gh_and_claude() {
  if ! command -v gh > /dev/null 2>&1; then
    echo -e "${CB_BLUE}📦 Installing GitHub CLI...${C_RESET}"
    if command -v apt-get > /dev/null 2>&1; then
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null 2>&1
      sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update > /dev/null 2>&1
      sudo apt-get install -y gh > /dev/null 2>&1
    else
      echo -e "${CB_YELLOW}⚠️ apt-get not found. Please install GitHub CLI manually.${C_RESET}"
    fi
  fi

  if ! command -v claude > /dev/null 2>&1; then
    if command -v npm > /dev/null 2>&1; then
      echo -e "${CB_BLUE}📦 Installing Claude Code...${C_RESET}"
      sudo npm install -g @anthropic-ai/claude-code > /dev/null 2>&1
    else
      echo -e "${CB_YELLOW}⚠️ npm not found. Skipping Claude Code install. (Please install Node.js first)${C_RESET}"
    fi
  fi
}

#######################################
# System: Bootstrap missing dependencies (Debian/WSL via APT, macOS via Homebrew)
# Usage: bootstrap [OPTIONS]
# Options:
#   -h, --help    Show this help menu
#######################################
bootstrap() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  echo "🔍 Scanning system for missing dependencies..."

  if [ "$OS_FAMILY" = "macos" ]; then
    __bootstrap_brew
  else
    __bootstrap_apt
  fi
  __bootstrap_python
  __bootstrap_yq
  __bootstrap_external
  __bootstrap_check_complex

  echo -e "\n🎉 Environment bootstrap complete!"

  __bootstrap_gh_and_claude
}

#######################################
# System: Notify if missing dependencies are detected
# Notes:
#   The actual scan (in particular its `python3 -c "import yaml"` check) costs
#   ~20ms, so it's run in the background at most once per
#   UPDATE_CHECK_TTL_SEC and its result cached, the same pattern used by
#   __check_updates/__check_profile_updates in 02-update-check.sh.
#######################################
__check_missing_deps() {
  if [[ $- != *i* ]]; then return; fi

  local pending_file="$HOME/.bash.d/data/cache/.deps_pending"
  local cache_file="$HOME/.bash.d/data/cache/.deps_check_cache"
  local current_time
  current_time=$(date +%s)
  mkdir -p "$HOME/.bash.d/data/cache" 2> /dev/null

  if [ -f "$pending_file" ]; then
    echo -e "\n${C_YELLOW}⚠️  Missing required dependencies detected in your environment:${C_RESET}"
    while IFS= read -r dep; do
      [ -n "$dep" ] && echo "  - $dep"
    done < "$pending_file"
    echo -e "${C_YELLOW}   Run ${C_BOLD}bootstrap${C_UNBOLD} to install them.${C_RESET}"
    return
  fi

  local last_check=0
  if [ -f "$cache_file" ]; then
    last_check=$(command cat "$cache_file")
  fi

  local ttl="${UPDATE_CHECK_TTL_SEC:-43200}"

  if ((current_time - last_check >= ttl)); then
    (
      local to_check=()
      if [ "$OS_FAMILY" = "macos" ]; then
        to_check=("${BREW_DEPENDENCIES[@]}")
      else
        to_check=("${APT_DEPENDENCIES[@]}")
        to_check+=("yq:yq")
      fi
      to_check+=(
        "${PYTHON_DEPENDENCIES[@]}"
        "${COMPLEX_DEPENDENCIES[@]}"
        "${EXTERNAL_DEPENDENCIES[@]}"
      )
      local missing_list
      mapfile -t missing_list < <(__get_missing_deps "${to_check[@]}")

      if [ ${#missing_list[@]} -gt 0 ]; then
        printf '%s\n' "${missing_list[@]}" > "$pending_file"
      else
        date +%s > "$cache_file"
      fi
    ) &
    disown
  fi
}

#######################################
# System: Updates system packages (APT on Debian/WSL, Homebrew on macOS)
# Usage: sys-update [OPTIONS]
# Options:
#   -h, --help    Show this help menu
#######################################
sys-update() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  if [ "$OS_FAMILY" = "macos" ]; then
    if ! command -v brew > /dev/null 2>&1; then
      echo "🚨 Homebrew not found. Run 'bootstrap' first."
      return 1
    fi
    brew update && brew upgrade
  else
    sudo apt update && sudo apt upgrade
  fi
}

#######################################
# System: Updates system packages and clears pending-update marker
# Usage: sys-install [OPTIONS]
# Options:
#   -h, --help    Show this help menu
#######################################
sys-install() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi
  sys-update
  rm -f "$HOME/.bash.d/data/cache/.update_pending"
}

__check_missing_deps
