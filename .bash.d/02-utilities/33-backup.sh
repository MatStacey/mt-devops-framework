# shellcheck shell=bash
# ------------------------------------------
# Utilities: Backup & Restore
# ------------------------------------------
# ~/.bash.d/02-utilities/33-backup.sh

#######################################
# System: Warn and confirm before backing up an oversized payload
# Globals (read, set by mt-backup):
#   force, threshold_mb
# Returns:
#   0 to proceed, 1 if the user declined
#######################################
__mt_backup_check_size_warning() {
  mt-log INFO "Estimating backup payload size..."
  local est_size_mb
  est_size_mb=$(find . -type d \( -name .git -o -name node_modules -o -name __pycache__ -o -name .terraform -o -name venv -o -name .venv \) -prune -o -type f -exec ls -l {} + 2> /dev/null | awk '{s+=$5} END {print int(s/1048576)}')
  [ -z "$est_size_mb" ] && est_size_mb=0

  if [ "$force" = false ] && [ "$est_size_mb" -ge "$threshold_mb" ]; then
    echo -e "${CB_YELLOW}⚠️ Warning: Estimated payload is ${est_size_mb}MB, which exceeds the ${threshold_mb}MB limit.${C_RESET}"
    read -p "🚀 Proceed with backup? [y/N] " -n 1 -r < /dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${CB_RED}🛑 Aborted.${C_RESET}"
      return 1
    fi
  fi
}

#######################################
# System: List existing backups for the current directory's safe name
# Globals (read, set by mt-backup):
#   dest, expanded_base, safe_dir_name
#######################################
__mt_backup_list() {
  if [ ! -d "$dest" ]; then
    echo -e "${CB_YELLOW}⚠️ No backups found for '${safe_dir_name}' in ${expanded_base}.${C_RESET}"
    return 0
  fi

  echo -e "${CB_BLUE}🔍 Scanning '${dest}' for backups...${C_RESET}\n"

  local count
  count=$(find "$dest" -maxdepth 1 -type f | wc -l)

  if [ "$count" -eq 0 ]; then
    echo -e "${CB_YELLOW}⚠️ No backups found in $dest.${C_RESET}"
    return 0
  fi

  echo -e "${CB_CYAN}📦 Found $count backup(s) for '${safe_dir_name}':${C_RESET}\n"

  # ls -lth sorts by time (latest first), -h gives human-readable sizes
  local awk_script="$HOME/.bash.d/lib/awk/backup_list_table.awk"
  command ls -lth --time-style=+"%Y-%m-%d %H:%M:%S" "$dest" | grep -v '^total' |
    awk -v blue="$CB_BLUE" -v cyan="$CB_CYAN" -v yellow="$CB_YELLOW" -v green="$CB_GREEN" -v rst="$C_RESET" -f "$awk_script"
  echo ""
}

#######################################
# System: Create the backup archive (zip/rar/tar) and report the result
# Globals (read, set by mt-backup):
#   dest, safe_dir_name, format
#######################################
__mt_backup_create() {
  mkdir -p "$dest"

  # Format timestamps: [YYYY-MM-DD]_[HH-MM-SS]
  local date_part
  date_part=$(date +"%Y-%m-%d")
  local time_part
  time_part=$(date +"%H-%M-%S")

  local ext="$format"
  case "$format" in
    tz | tar.xz | txz) ext="tar.xz" ;;
    gzip | tar.gz | tgz) ext="tar.gz" ;;
    rar) ext="rar" ;;
    zip | *)
      ext="zip"
      format="zip"
      ;;
  esac

  local backup_file="${dest}/[${date_part}]_[${time_part}]_${safe_dir_name}_backup.${ext}"
  mt-log INFO "Backing up ${PWD} to ${backup_file}..."

  local success=0
  if [ "$format" = "zip" ]; then
    zip -q -r "$backup_file" . -x "*.git/*" -x "*node_modules/*" -x "*__pycache__/*" -x "*.terraform/*" -x "*venv/*" -x "*.venv/*"
    success=$?
  elif [ "$format" = "rar" ]; then
    if command -v rar > /dev/null 2>&1; then
      rar a -q -r -x"*\.git\*" -x"*node_modules\*" -x"*__pycache__\*" -x"*\.terraform\*" -x"*venv\*" -x"*\.venv\*" "$backup_file" .
      success=$?
    else
      echo -e "${CB_RED}🚨 Error: 'rar' is not installed. Please install it or use zip/gzip.${C_RESET}"
      return 1
    fi
  else
    local tar_flag="z"
    [ "$ext" = "tar.xz" ] && tar_flag="J"
    tar -c${tar_flag}f "$backup_file" --exclude=".git" --exclude="node_modules" --exclude="__pycache__" --exclude=".terraform" --exclude="venv" --exclude=".venv" .
    success=$?
  fi

  if [ $success -eq 0 ]; then
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    mt-log SUCCESS "Backup complete: ${backup_file} (${file_size})"

    # Construct correct clickable link for terminal (OSC 8) with clean WSL-to-Windows URI formatting
    local file_url="$dest"
    if [ "$OS_FAMILY" = "wsl" ] && command -v wslpath > /dev/null 2>&1; then
      local distro="${WSL_DISTRO_NAME:-Debian}"
      file_url="file://wsl.localhost/${distro}${dest}"
    else
      file_url="file://$dest"
    fi

    echo -e " 📂 Folder: \033]8;;${file_url}\033\\${dest}\033]8;;\033\\"
  else
    mt-log ERROR "Backup failed."
  fi
}

#######################################
# System: Create an archive backup of the current directory
# Usage: mt-backup [-f|--force] [-l|--list] [-o|--output format] [-d|--dir path]
# Options:
#   -l, --list     List existing backups for the current directory
#   -f, --force    Skip the size limit warning check
#   -o, --output   Archive format: zip (default), rar, tz, gzip
#   -d, --dir      Override the base destination directory
# Globals:
#   BACKUP_DIR
#######################################
mt-backup() {
  local force=false
  local list_mode=false
  local format="zip"

  local base_dest="${BACKUP_DIR:-/tmp/backups}"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -l | --list) list_mode=true ;;
      -f | --force) force=true ;;
      -o | --output)
        format="${2,,}"
        shift
        ;;
      -d | --dir)
        base_dest="$2"
        shift
        ;;
      -h | --help)
        mt-help "${FUNCNAME[0]}"
        return 0
        ;;
      -*)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
      *) base_dest="$1" ;;
    esac
    shift
  done

  local threshold_mb="${BACKUP_WARNING_MB:-500}"

  if ! [[ "$threshold_mb" =~ ^[0-9]+$ ]]; then
    echo -e "${CB_RED}🚨 Error: 'backup_warning_mb' in config.yaml is invalid ('$threshold_mb'). It must be a whole number.${C_RESET}"
    return 1
  fi

  if [ "$list_mode" = false ]; then
    __mt_backup_check_size_warning || return 1
  fi

  # Sanitize target directory name (strip dots, special chars)
  local raw_dir_name
  raw_dir_name=$(basename "$(realpath "$PWD")")
  local safe_dir_name
  safe_dir_name=$(echo "$raw_dir_name" | tr -d '.' | sed 's/[^a-zA-Z0-9]/_/g')

  # Resolve base destination, expanding ~ if present
  local expanded_base="${base_dest/#\~/$HOME}"
  local dest="${expanded_base}/${safe_dir_name}"

  if [ "$list_mode" = true ]; then
    __mt_backup_list
    return 0
  fi

  __mt_backup_create
}

#######################################
# System: Restore framework from a zip backup
# Usage: mt-restore [backup_file] [-i|--interactive]
# Options:
#   -i, --interactive  Choose a backup from an fzf menu
#######################################
mt-restore() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local selected_backup=""
  local backup_base_dir="${BACKUP_DIR:-$HOME/backups}"

  if [ -n "$1" ] && [ "$1" != "-i" ] && [ "$1" != "--interactive" ]; then
    if [ -f "$1" ]; then
      selected_backup="$1"
    elif [ -f "${backup_base_dir}/$1" ]; then
      selected_backup="${backup_base_dir}/$1"
    elif [ -f "${backup_base_dir}/bashd/$1" ]; then
      selected_backup="${backup_base_dir}/bashd/$1"
    else
      echo -e "${CB_RED}🚨 Backup file not found: $1${C_RESET}"
      return 1
    fi
  else
    echo -e "${CB_BLUE}🔍 Scanning for available backups in ${backup_base_dir}...${C_RESET}"
    local tmp_list
    tmp_list=$(mktemp)
    find "$backup_base_dir" -type f -name "*.zip" 2> /dev/null | sort -r > "$tmp_list"

    if [ ! -s "$tmp_list" ]; then
      echo -e "${CB_YELLOW}⚠️ No backup zip files found in ${backup_base_dir}.${C_RESET}"
      rm -f "$tmp_list"
      return 1
    fi

    selected_backup=$(fzf --prompt="Select Backup to Restore > " --header="Available Framework Backups" < "$tmp_list")
    rm -f "$tmp_list"

    [ -z "$selected_backup" ] && return 0
  fi

  echo -e "${CB_CYAN}📦 Selected Backup: ${selected_backup}${C_RESET}"
  read -r -p "🚀 Are you sure you want to restore this backup? [y/N] " -n 1
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${CB_RED}🛑 Restore aborted.${C_RESET}"
    return 0
  fi

  # 1. Pre-restore Safety Backup
  echo -e "${CB_BLUE}🛡️ Creating safety backup of current codebase before restoring...${C_RESET}"
  local pre_dest="${backup_base_dir}/pre-restore"
  mkdir -p "$pre_dest"
  local timestamp
  timestamp=$(date +"%Y%m%d_%H%M%S")
  local safety_file="${pre_dest}/pre_restore_safety_${timestamp}.zip"

  (
    cd "$HOME" || exit 1
    zip -q -r "$safety_file" .bash.d -x ".bash.d/.git/*" -x ".bash.d/data/cache/*" -x ".bash.d/node_modules/*" -x ".bash.d/**/__pycache__/*"
  )
  echo -e "${CB_GREEN}✅ Safety backup saved: ${safety_file}${C_RESET}"

  # 2. Extract selected backup
  echo -e "${CB_YELLOW}🔄 Restoring .bash.d directory...${C_RESET}"
  if ! unzip -q -o "$selected_backup" -d "$HOME/"; then
    echo -e "${CB_RED}🚨 Unzip failed during restore!${C_RESET}"
    return 1
  fi

  # 3. Sync to Git Workspace
  local git_repo_path="${DOTFILES_DIR:-$HOME/vcs/personal/mt-devops-framework}"
  if [ -d "$git_repo_path" ]; then
    echo -e "${CB_BLUE}🔄 Syncing restored files to Git workspace (${git_repo_path})...${C_RESET}"
    rsync -a -u --delete "$HOME/.bash.d/" "${git_repo_path}/.bash.d/"
  fi

  echo -e "${CB_GREEN}🎉 Restore complete! Rebuilding caches...${C_RESET}"
  mt-refresh-caches > /dev/null 2>&1
}
