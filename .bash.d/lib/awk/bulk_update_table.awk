# mt-bulk-update summary table renderer
# Input: pipe-delimited rows of REPOSITORY|BRANCH|UPDATE|PUSHED|AHEAD|BEHIND
# Expects color vars via -v: blue green yellow red dim rst cyan

function pad(str, len,    out) {
  if (length(str) > len) return substr(str, 1, len - 3) "..."
  out = str
  while (length(out) < len) out = out " "
  return out
}

BEGIN {
  FS = "|"
  printf "%s%-45s %-20s %-14s %-8s %-7s %-7s%s\n", blue, "REPOSITORY", "BRANCH", "UPDATE", "PUSHED", "AHEAD", "BEHIND", rst
  printf "%s%s%s\n", blue, "-----------------------------------------------------------------------------------------------------", rst
}
{
  repo = pad($1, 45)

  branch_raw = $2
  branch_color = (branch_raw == "main" || branch_raw == "master") ? green : yellow
  branch = pad(branch_raw, 20)

  update_raw = $3
  update_color = dim
  if (update_raw == "UPDATED" || update_raw == "CREATED") update_color = green
  else if (update_raw == "DIVERGED" || update_raw == "UNAVAILABLE") update_color = yellow
  else if (update_raw == "FETCH FAILED" || update_raw == "STASH CONFLICT") update_color = red
  update = pad(update_raw, 14)

  pushed_raw = $4
  pushed_color = dim
  if (pushed_raw == "Yes") pushed_color = green
  else if (pushed_raw == "No") pushed_color = yellow
  pushed = pad(pushed_raw, 8)

  ahead_raw = $5
  ahead_color = (ahead_raw + 0 > 0) ? cyan : dim
  ahead = pad(ahead_raw, 7)

  behind_raw = $6
  behind_color = (behind_raw + 0 > 0) ? yellow : dim
  behind = pad(behind_raw, 7)

  printf "%s%s%s %s%s%s %s%s%s %s%s%s %s%s%s %s%s%s\n", rst, repo, rst, branch_color, branch, rst, update_color, update, rst, pushed_color, pushed, rst, ahead_color, ahead, rst, behind_color, behind, rst
}
