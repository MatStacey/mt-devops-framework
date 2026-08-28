# mt-cmd-history filter: keeps only shell history lines whose first word
# (after stripping any "sudo ::"-style prefix up to the last "::") is an
# exact framework function/alias name.
# Input: cleaned bash history lines (timestamp/line-number prefix already
# stripped). Expects var via -v: cmd_file (path to a newline-delimited
# list of known framework command names).

BEGIN {
  while ((getline line < cmd_file) > 0) {
    if (line != "") cmds[line] = 1
  }
  close(cmd_file)
}
{
  cmd = $1
  sub(/^.*::/, "", cmd)

  if (cmd in cmds) {
    print $0
  }
}
