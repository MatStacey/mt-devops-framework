# mt-repos summary table renderer
# Input: pipe-delimited rows of TYPE|CONTEXT|REPOSITORY|BRANCH|REMOTE URL|PATH
# Expects vars via -v: home wsl_distro, colors blue green yellow dim rst magenta cyan

function pad(str, len) {
  if (length(str) > len) return substr(str, 1, len - 3) "..."
  return str sprintf("%*s", len - length(str), "")
}

BEGIN {
  FS = "|"
  printf "%s%-10s %-32s %-30s %-18s %-42s %s%s\n", blue, "TYPE", "CONTEXT", "REPOSITORY", "BRANCH", "REMOTE URL", "PATH", rst
  printf "%s%s%s\n", blue, "-----------------------------------------------------------------------------------------------------------------------------------------", rst
}
{
  type = pad($1, 10)
  context = pad($2, 32)
  repo = pad($3, 30)

  branch_raw = $4
  branch = pad(branch_raw, 18)
  branch_color = (branch_raw == "main" || branch_raw == "master") ? green : yellow

  remote_raw = $5
  remote_color = (remote_raw == "No remote") ? dim : rst
  remote_disp = pad(remote_raw, 42)

  # Robust URL transformation for both SSH (git@) and HTTPS
  web_url = remote_raw
  if (web_url ~ /^git@/) {
    sub(/^git@/, "", web_url)
    sub(/:/, "/", web_url)
    web_url = "https://" web_url
  }
  sub(/\.git$/, "", web_url)

  if (web_url ~ /^http/) {
    remote_linked = "\033]8;;" web_url "\033\\" remote_disp "\033]8;;\033\\"
  } else {
    remote_linked = remote_disp
  }

  path_full = $6
  path_disp = path_full
  if (index(path_disp, home) == 1) {
    path_disp = "~" substr(path_disp, length(home) + 1)
  }

  if (wsl_distro != "") {
    file_url = "file://wsl.localhost/" wsl_distro path_full
  } else {
    file_url = "file://" path_full
  }

  path_linked = "\033]8;;" file_url "\033\\" path_disp "\033]8;;\033\\"

  printf "%s%s%s %s%s%s %s%s%s %s%s%s %s%s%s %s\n", magenta, type, rst, dim, context, rst, cyan, repo, rst, branch_color, branch, rst, remote_color, remote_linked, rst, path_linked
}
