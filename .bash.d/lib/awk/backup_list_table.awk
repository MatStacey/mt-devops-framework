# mt-backup listing table renderer
# Input: `ls -lth --time-style=+"%Y-%m-%d %H:%M:%S"` output, `total` line
# already stripped. Expects vars via -v: blue cyan yellow green rst
# (framework color codes).

BEGIN {
  printf "%s%-55s %-25s %-15s%s\n", blue, "FILENAME", "DATE CREATED", "SIZE", rst
  printf "%s%s%s\n", blue, "-------------------------------------------------------------------------------------------------", rst
}
{
  size = $5
  date_created = $6 " " $7
  name = ""
  # Support filenames with spaces just in case
  for (i = 8; i <= NF; i++) name = name (i == 8 ? "" : " ") $i
  printf "%s%-55s%s %s%-25s%s %s%-15s%s\n", cyan, name, rst, yellow, date_created, rst, green, size, rst
}
