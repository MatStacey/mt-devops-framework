# shellcheck shell=bash
# ------------------------------------------
# Utilities: Background Job Registry
# ------------------------------------------
# ~/.bash.d/02-utilities/34-jobs.sh

#######################################
# System: Submit a task to the background job registry
#######################################
__mt_bg_run() {
  local job_name="$1" log_file="$2" cmd_string="$3"
  local job_id
  job_id="job_$(date +%s)_${RANDOM}"
  local jobs_file="$CACHE_DIR/.mt_jobs.tsv"

  # Ensure log directory and job tracking directories exist BEFORE subshell redirects
  mkdir -p "$(dirname "$log_file")" "$(dirname "$jobs_file")"
  touch "$jobs_file"

  (
    local start_time
    start_time=$(date +%s)
    echo "${job_id}|${BASHPID}|${job_name}|${start_time}||RUNNING|${log_file}|${cmd_string}" >> "$jobs_file"
    eval "$cmd_string" > "$log_file" 2>&1
    local exit_code=$?
    local end_time
    end_time=$(date +%s)
    local status="SUCCESS"
    [ $exit_code -ne 0 ] && status="FAILED"
    local tmp
    tmp=$(mktemp)
    awk -F'|' -v id="$job_id" -v e="$end_time" -v s="$status" 'BEGIN{OFS="|"} $1==id { $5=e; $6=s } {print $0}' "$jobs_file" > "$tmp" && mv "$tmp" "$jobs_file"
  ) &
  disown
  echo -e "${CB_GREEN}🚀 Background job started: ${job_name}${C_RESET}"
  echo -e "${C_DIM}Monitor logs: tail -f $log_file${C_RESET}"
  echo -e "${C_DIM}Manage jobs : mt-jobs -i${C_RESET}"
}

#######################################
# System: Stop one background job, dispatching to a job-type-specific stop
# path when the registered PID is a wrapper rather than the real work
# process. mt-http-server is the only job type that needs this today --
# its server runs as an un-exec'd child of the wrapper (see
# 31-http-server.sh) specifically so the wrapper can run idle-timeout/LAN
# bridge cleanup after the server exits. SIGKILLing the wrapper PID orphans
# the still-running, still-listening server instead of stopping it, since
# SIGKILL can't be trapped and the child is never reparented back to it.
# Arguments:
#   $1 - Registered job PID (the wrapper PID for most job types)
#   $2 - Job name
#######################################
__mt_jobs_stop_pid() {
  local pid="$1" name="$2"
  if [ "$name" = "mt-http-server" ]; then
    mt-http-server --stop > /dev/null 2>&1
  else
    kill -9 "$pid" 2> /dev/null
  fi
}

#######################################
# System: Kill every RUNNING job and mark it CANCELLED in the jobs file
# Globals (read, set by mt-jobs):
#   jobs_file, current_time
#######################################
__mt_jobs_purge() {
  echo -e "${CB_RED}🛑 Purging all running background jobs...${C_RESET}"
  local tmp_m
  tmp_m=$(mktemp)
  local count=0
  local j_id j_pid j_name j_start j_end j_status j_log j_cmd
  while IFS='|' read -r j_id j_pid j_name j_start j_end j_status j_log j_cmd; do
    [ -z "$j_id" ] && continue
    if [ "$j_status" = "RUNNING" ]; then
      __mt_jobs_stop_pid "$j_pid" "$j_name"
      j_status="CANCELLED"
      j_end=$current_time
      ((count++))
    fi
    echo "${j_id}|${j_pid}|${j_name}|${j_start}|${j_end}|${j_status}|${j_log}|${j_cmd}" >> "$tmp_m"
  done < "$jobs_file"
  mv "$tmp_m" "$jobs_file"
  echo -e "${CB_GREEN}✅ Purged ${count} running job(s).${C_RESET}"
}

#######################################
# System: Drop every finished (non-RUNNING) job and its log from history
# Globals (read, set by mt-jobs):
#   jobs_file
#######################################
__mt_jobs_clean() {
  echo -e "${CB_YELLOW}🧹 Cleaning completed job history...${C_RESET}"
  local tmp_c
  tmp_c=$(mktemp)
  local count=0
  local j_id j_pid j_name j_start j_end j_status j_log j_cmd
  while IFS='|' read -r j_id j_pid j_name j_start j_end j_status j_log j_cmd; do
    [ -z "$j_id" ] && continue
    if [ "$j_status" != "RUNNING" ]; then
      [ -f "$j_log" ] && rm -f "$j_log"
      ((count++))
    else
      echo "${j_id}|${j_pid}|${j_name}|${j_start}|${j_end}|${j_status}|${j_log}|${j_cmd}" >> "$tmp_c"
    fi
  done < "$jobs_file"
  mv "$tmp_c" "$jobs_file"
  echo -e "${CB_GREEN}✅ Removed ${count} finished job(s) from history.${C_RESET}"
}

#######################################
# System: Mark RUNNING jobs whose PID no longer exists as ORPHANED
# Globals (read, set by mt-jobs):
#   jobs_file, current_time
#######################################
__mt_jobs_reap_orphans() {
  local tmp_jobs
  tmp_jobs=$(mktemp)
  local j_id j_pid j_name j_start j_end j_status j_log j_cmd
  while IFS='|' read -r j_id j_pid j_name j_start j_end j_status j_log j_cmd; do
    [ -z "$j_id" ] && continue
    if [ "$j_status" = "RUNNING" ]; then
      if ! kill -0 "$j_pid" 2> /dev/null; then
        j_status="ORPHANED"
        j_end=$current_time
      fi
    fi
    echo "${j_id}|${j_pid}|${j_name}|${j_start}|${j_end}|${j_status}|${j_log}|${j_cmd}" >> "$tmp_jobs"
  done < "$jobs_file"
  mv "$tmp_jobs" "$jobs_file"
}

#######################################
# System: Restart one job by ID -- replays its original command via a
# fresh background job. mt-http-server is special-cased the same way
# the interactive menu always has: its port/auth/idle-timeout came from
# env vars local to the original launch and were never persisted in the
# jobs file, so replaying its bare argv would silently come back on
# defaults -- its own -b flag re-reads the same config the original run
# used instead.
# Arguments:
#   $1 - Job ID
# Globals (read, set by mt-jobs):
#   jobs_file
# Returns:
#   0 on success, 1 if the job ID isn't found
#######################################
__mt_jobs_restart_by_id() {
  local target_id="$1"
  local sel_data
  sel_data=$(grep "^${target_id}|" "$jobs_file" | head -n 1)
  if [ -z "$sel_data" ]; then
    echo -e "${CB_RED}🚨 No job found with ID: ${target_id}${C_RESET}"
    return 1
  fi

  local j_id j_pid j_name j_start j_end j_status j_log j_cmd
  IFS='|' read -r j_id j_pid j_name j_start j_end j_status j_log j_cmd <<< "$sel_data"

  if [ "$j_name" = "mt-http-server" ]; then
    mt-http-server --stop
    mt-http-server -b
  else
    local new_log
    new_log="$LOG_DIR/indexer_$(date +%s).log"
    __mt_bg_run "${j_name}" "$new_log" "$j_cmd"
  fi
}

#######################################
# System: Stop one RUNNING job by ID, marking it CANCELLED. A no-op
# (with a message, not an error) if the job isn't currently RUNNING.
# Arguments:
#   $1 - Job ID
# Globals (read, set by mt-jobs):
#   jobs_file, current_time
# Returns:
#   0 on success, 1 if the job ID isn't found
#######################################
__mt_jobs_stop_by_id() {
  local target_id="$1"
  local sel_data
  sel_data=$(grep "^${target_id}|" "$jobs_file" | head -n 1)
  if [ -z "$sel_data" ]; then
    echo -e "${CB_RED}🚨 No job found with ID: ${target_id}${C_RESET}"
    return 1
  fi

  local j_id j_pid j_name j_start j_end j_status j_log j_cmd
  IFS='|' read -r j_id j_pid j_name j_start j_end j_status j_log j_cmd <<< "$sel_data"

  if [ "$j_status" != "RUNNING" ]; then
    echo -e "${CB_YELLOW}⚠️  Job '${j_name}' is not running (status: ${j_status}).${C_RESET}"
    return 0
  fi

  __mt_jobs_stop_pid "$j_pid" "$j_name"
  local tmp_m
  tmp_m=$(mktemp)
  awk -F'|' -v id="$j_id" -v e="$current_time" 'BEGIN{OFS="|"}$1==id{$5=e;$6="CANCELLED"}{print $0}' "$jobs_file" > "$tmp_m" && mv "$tmp_m" "$jobs_file"
  echo -e "${CB_GREEN}✅ Job '${j_name}' cancelled.${C_RESET}"
}

#######################################
# System: Remove one job's history entry (and its log file) by ID,
# regardless of its status.
# Arguments:
#   $1 - Job ID
# Globals (read, set by mt-jobs):
#   jobs_file
# Returns:
#   0 on success, 1 if the job ID isn't found
#######################################
__mt_jobs_remove_by_id() {
  local target_id="$1"
  local sel_data
  sel_data=$(grep "^${target_id}|" "$jobs_file" | head -n 1)
  if [ -z "$sel_data" ]; then
    echo -e "${CB_RED}🚨 No job found with ID: ${target_id}${C_RESET}"
    return 1
  fi

  local j_id j_pid j_name j_start j_end j_status j_log j_cmd
  IFS='|' read -r j_id j_pid j_name j_start j_end j_status j_log j_cmd <<< "$sel_data"

  local tmp_m
  tmp_m=$(mktemp)
  grep -v "^${j_id}|" "$jobs_file" > "$tmp_m" && mv "$tmp_m" "$jobs_file"
  [ -f "$j_log" ] && rm -f "$j_log"
  echo -e "${CB_GREEN}✅ Removed '${j_name}' from job history.${C_RESET}"
}

#######################################
# System: Render the jobs table into a tab-delimited temp file for display/fzf
# Globals (read, set by mt-jobs):
#   jobs_file, current_time
# Globals (written):
#   tmp_out -- path to the rendered table
#######################################
__mt_jobs_render_table() {
  tmp_out=$(mktemp)

  local j_id j_pid j_name j_start j_end j_status j_log j_cmd
  while IFS='|' read -r j_id j_pid j_name j_start j_end j_status j_log j_cmd; do
    [ -z "$j_id" ] && continue

    local t_start="-"
    [ -n "$j_start" ] && t_start=$(date -d "@$j_start" +"%H:%M:%S" 2> /dev/null || date -r "$j_start" +"%H:%M:%S" 2> /dev/null)
    local t_end="-"
    [ -n "$j_end" ] && t_end=$(date -d "@$j_end" +"%H:%M:%S" 2> /dev/null || date -r "$j_end" +"%H:%M:%S" 2> /dev/null)

    local end_calc="${j_end:-$current_time}"
    local diff=$((end_calc - j_start))
    local dur
    dur=$(printf "%02dm %02ds" $((diff / 60)) $((diff % 60)))

    local color="${CB_CYAN}"
    [ "$j_status" = "SUCCESS" ] && color="${CB_GREEN}"
    [ "$j_status" = "FAILED" ] || [ "$j_status" = "ORPHANED" ] && color="${CB_RED}"
    [ "$j_status" = "CANCELLED" ] && color="${CB_YELLOW}"

    local p_name
    p_name=$(printf "%-22s" "${j_name:0:22}")
    local p_start
    p_start=$(printf "%-10s" "$t_start")
    local p_end
    p_end=$(printf "%-10s" "$t_end")
    local p_dur
    p_dur=$(printf "%-10s" "$dur")

    # Store RAW j_id first separated by tabs so fzf can extract it perfectly
    echo -e "${j_id}	${p_name} ${C_DIM}${p_start}${C_RESET} ${C_DIM}${p_end}${C_RESET} ${C_DIM}${p_dur}${C_RESET} ${color}${j_status}${C_RESET}" >> "$tmp_out"
  done < "$jobs_file"
}

#######################################
# System: Print the rendered jobs table (non-interactive mode) and clean up
# Globals (read, set by mt-jobs):
#   tmp_out
#######################################
__mt_jobs_print_table() {
  printf "
${CB_BLUE}%-22s %-10s %-10s %-10s %-12s${C_RESET}
" "NAME" "START" "END" "DURATION" "STATUS"
  echo -e "${CB_BLUE}-------------------------------------------------------------------${C_RESET}"
  cut -f2- "$tmp_out"
  echo -e "
${C_DIM}Run 'mt-jobs -i' to interact, 'mt-jobs -c' to clean history.${C_RESET}"
  rm -f "$tmp_out"
}

#######################################
# System: fzf-select a job from the rendered table, then run the chosen action
# Globals (read, set by mt-jobs):
#   tmp_out, jobs_file, current_time
#######################################
__mt_jobs_interactive_select() {
  local selected
  selected=$(fzf < "$tmp_out" --ansi --delimiter="	" --with-nth=2 --prompt="Select Job > ")
  rm -f "$tmp_out"

  [ -z "$selected" ] && return 0

  local sel_id
  sel_id=$(echo "$selected" | cut -f1)

  local sel_data
  sel_data=$(grep "^${sel_id}|" "$jobs_file" | head -n 1)

  [ -z "$sel_data" ] && {
    echo -e "${CB_RED}🚨 Error resolving job details for ID: ${sel_id}${C_RESET}"
    return 1
  }

  local j_id j_pid j_name j_start j_end j_status j_log j_cmd
  IFS='|' read -r j_id j_pid j_name j_start j_end j_status j_log j_cmd <<< "$sel_data"

  echo -e "
${CB_BLUE}▶ Selected Job: ${j_name} (${j_id})${C_RESET}"
  local options=("1. View Logs (cat)")
  [ "$j_status" = "RUNNING" ] && options+=("2. Tail Logs (live)")
  [ "$j_status" = "RUNNING" ] && options+=("3. Cancel Job (kill)")
  options+=("4. Restart Job")
  options+=("5. Clear Selected Job History")
  options+=("6. Clear ALL Job History")

  local action
  action=$(printf '%s
' "${options[@]}" | fzf --prompt="Select Action > ")

  case "$action" in
    1*)
      if [ -f "$j_log" ]; then
        echo -e "${CB_CYAN}--- LOGS ($j_log) ---${C_RESET}"
        cat "$j_log"
        echo -e "${CB_CYAN}---------------------${C_RESET}"
      else
        echo -e "${CB_RED}🚨 Log file missing ($j_log).${C_RESET}"
      fi
      ;;
    2*)
      [ -f "$j_log" ] && tail -f "$j_log" || echo -e "${CB_RED}🚨 Log file missing ($j_log).${C_RESET}"
      ;;
    3*)
      __mt_jobs_stop_by_id "$j_id"
      ;;
    4*)
      __mt_jobs_restart_by_id "$j_id"
      ;;
    5*)
      __mt_jobs_remove_by_id "$j_id"
      ;;
    6*)
      true > "$jobs_file"
      echo -e "${CB_GREEN}✅ All job history cleared.${C_RESET}"
      ;;
  esac
}

#######################################
# System: List and manage MT background jobs
# Usage: mt-jobs [-i|--interactive] [-p|--purge] [-c|--clean] [-w|--watch]
#                [--restart <job_id>] [--stop <job_id>] [--remove <job_id>]
# Options:
#   -i, --interactive     fzf-pick a job, then an action to run against it
#   -p, --purge           Kill every RUNNING job (marks them CANCELLED)
#   -c, --clean           Drop every finished (non-RUNNING) job and its log
#   -w, --watch           Live-refreshing table view (Ctrl+C to exit)
#   --restart <job_id>    Replay one job's original command as a new job
#   --stop <job_id>       Cancel one RUNNING job by ID
#   --remove <job_id>     Drop one job's history entry (and log) by ID
#   -h, --help            Show this help menu
#######################################
mt-jobs() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local jobs_file="$CACHE_DIR/.mt_jobs.tsv"
  local interactive=false do_purge=false do_clean=false watch=false
  local restart_id="" stop_id="" remove_id=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -i | --interactive) interactive=true ;;
      -p | --purge) do_purge=true ;;
      -c | --clean) do_clean=true ;;
      -w | --watch) watch=true ;;
      --restart)
        restart_id="$2"
        shift
        ;;
      --stop)
        stop_id="$2"
        shift
        ;;
      --remove)
        remove_id="$2"
        shift
        ;;
      *)
        echo -e "${CB_RED}🚨 Unknown option: $1${C_RESET}"
        return 1
        ;;
    esac
    shift
  done

  if [ -n "$restart_id" ]; then
    __mt_jobs_restart_by_id "$restart_id"
    return $?
  fi

  if [ -n "$stop_id" ]; then
    local current_time
    current_time=$(date +%s)
    __mt_jobs_stop_by_id "$stop_id"
    return $?
  fi

  if [ -n "$remove_id" ]; then
    __mt_jobs_remove_by_id "$remove_id"
    return $?
  fi

  if [ "$do_purge" = true ]; then
    local current_time
    current_time=$(date +%s)
    __mt_jobs_purge
    return 0
  fi

  if [ "$do_clean" = true ]; then
    __mt_jobs_clean
    return 0
  fi

  if [ "$watch" = true ]; then
    local current_time
    while true; do
      if [ ! -f "$jobs_file" ] || [ ! -s "$jobs_file" ]; then
        printf '\033[H\033[2J'
        echo -e "${CB_YELLOW}⚠️ No background jobs found.${C_RESET}"
        echo -e "${C_DIM}Watching for jobs... Press Ctrl+C to exit.${C_RESET}"
        sleep 1
        continue
      fi

      current_time=$(date +%s)
      __mt_jobs_reap_orphans

      printf '\033[H\033[2J'
      echo -e "${CB_BLUE}📊 MT Background Jobs — Live${C_RESET}"
      echo -e "${C_DIM}Refreshing every second • Press Ctrl+C to exit${C_RESET}"
      echo

      __mt_jobs_render_table
      __mt_jobs_print_table

      sleep 1
    done
  fi

  if [ ! -f "$jobs_file" ] || [ ! -s "$jobs_file" ]; then
    echo -e "${CB_YELLOW}⚠️ No background jobs found.${C_RESET}"
    return 0
  fi

  local current_time
  current_time=$(date +%s)

  __mt_jobs_reap_orphans

  local tmp_out
  __mt_jobs_render_table

  if [ "$interactive" = false ]; then
    __mt_jobs_print_table
    return 0
  fi

  __mt_jobs_interactive_select
}
