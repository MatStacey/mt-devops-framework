#!/usr/bin/env bash
# Interactive alternative to install.sh, for people who'd rather be walked
# through setup than run a plain script. Uses only bash builtins (read,
# case) for its own menu -- nothing is installed yet at this point, so it
# deliberately avoids depending on anything (fzf included) beyond what a
# bare shell already provides.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Plain ANSI codes, not the framework's CB_*/C_* theme vars -- those only
# exist once .bash.d has been sourced, which hasn't happened yet here.
WZ_BLUE='\033[1;34m'
WZ_GREEN='\033[1;32m'
WZ_CYAN='\033[1;36m'
WZ_RESET='\033[0m'

echo -e "${WZ_BLUE}==========================================================${WZ_RESET}"
echo -e "${WZ_BLUE}       MT DEVOPS FRAMEWORK - INTERACTIVE INSTALLER        ${WZ_RESET}"
echo -e "${WZ_BLUE}==========================================================${WZ_RESET}"
echo

echo -e "${WZ_CYAN}Syncing framework files...${WZ_RESET}"
export MT_INSTALL_WIZARD=1
# shellcheck source=/dev/null
source "$REPO_DIR/install.sh"

# install.sh runs under `set -e`, which persists into this script since it
# was sourced rather than executed. Turn it back off here -- the rest of
# this wizard reports individual step failures itself (each installer
# already does) rather than aborting the whole run over one optional step.
set +e

# Load the rest of the framework (functions, wizards, CB_*/C_* colors) the
# same way ~/.bashrc does, now that install.sh has synced it to disk.
while IFS= read -r -d '' f; do
  # shellcheck source=/dev/null
  source "$f"
done < <(find "$HOME/.bash.d" -type f -name "*.sh" -not -path "*/config/themes/*" -not -path "*/.dev/*" -not -name "install.sh" -print0 | sort -z)

echo
echo -e "${WZ_CYAN}--- Install Type ---${WZ_RESET}"
echo "1) Full    - Installs all core tools plus every optional extra (Terraform, Google Cloud CLI, kubectl, Speedtest)"
echo "2) Custom  - Choose which optional extras to install"
read -r -p "Select an option [1]: " install_type
install_type="${install_type:-1}"

want_terraform=false
want_gcloud=false
want_kubectl=false
want_speedtest=false

if [ "$install_type" = "2" ]; then
  echo
  echo -e "${WZ_CYAN}--- Custom Install: Optional Tools ---${WZ_RESET}"
  reply=""
  read -r -p "Install Terraform? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$ ]] && want_terraform=true
  read -r -p "Install Google Cloud CLI? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$ ]] && want_gcloud=true
  read -r -p "Install kubectl? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$ ]] && want_kubectl=true
  read -r -p "Install Ookla Speedtest CLI? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$ ]] && want_speedtest=true
else
  want_terraform=true
  want_gcloud=true
  want_kubectl=true
  want_speedtest=true
fi

echo
echo -e "${WZ_CYAN}--- Installing Core Dependencies ---${WZ_RESET}"
if [ "$OS_FAMILY" = "macos" ]; then
  __bootstrap_brew
else
  __bootstrap_apt
fi
__bootstrap_python
__bootstrap_yq
__install_eza
__bootstrap_gh_and_claude

[ "$want_terraform" = true ] && __install_terraform
[ "$want_gcloud" = true ] && __install_gcloud
[ "$want_kubectl" = true ] && __install_kubectl
[ "$want_speedtest" = true ] && __install_speedtest

echo
echo -e "${WZ_GREEN}✅ Dependency installation complete.${WZ_RESET}"

echo
echo -e "${WZ_CYAN}--- Configuration Setup ---${WZ_RESET}"
echo "config.yaml already has sensible defaults from the template. Answer"
echo "yes below to customize a category, or press Enter/no to keep its"
echo "defaults -- within each category you can also leave any individual"
echo "value blank to keep its current default."
echo
for pair in "System:mt-wizard-system" "Paths:mt-wizard-paths" "Git:mt-wizard-git" "Exports:mt-wizard-exports" "CI/CD:mt-wizard-cicd" "Docker:mt-wizard-docker"; do
  label="${pair%%:*}"
  func="${pair##*:}"
  reply=""
  read -r -p "Configure ${label}? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$ ]] && "$func"
done

echo
echo -e "${WZ_CYAN}--- AI Setup (optional) ---${WZ_RESET}"
reply=""
read -r -p "Set up AI integration now? [y/N]: " reply
if [[ "$reply" =~ ^[Yy]$ ]]; then
  mt-wizard-ai
  echo
  reply=""
  read -r -p "Add your Gemini API key now? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$ ]] && mt-add-gemini-key
  reply=""
  read -r -p "Add your Claude API key now? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]$ ]] && mt-add-claude-key
fi

echo
echo -e "${WZ_BLUE}==========================================================${WZ_RESET}"
echo -e "${WZ_GREEN}🎉 Installation complete!${WZ_RESET}"
echo -e "${WZ_BLUE}==========================================================${WZ_RESET}"
echo "Run 'source ~/.bashrc' or open a new terminal session to activate your environment."
echo "Then try 'mt menu' for the full interactive command menu."
