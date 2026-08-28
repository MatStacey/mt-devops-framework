# Scrapes one specific command's "Options:" doc-comment block for its flag
# tokens -- a tab-completion fallback for commands with no dedicated
# completion function registered. Scoped to the exact target the same way
# mt_help.awk is, since a file can define several commands, each with its
# own Options block.
# Input: a framework .sh source file. Expects var via -v: target (exact
# command/alias name, e.g. mt-export).
# Output: one flag token per line (e.g. -e, --element).

/^#######################################/ { next }
/^#/ {
  line = substr($0, 2)
  sub(/^[ \t]/, "", line)
  doc = doc line "\n"
  next
}
$0 ~ "^alias " target "=" { matched = 1; exit }
$0 ~ "^" target "\\(\\)[ \t]*\\{" { matched = 1; exit }
{ doc = "" }
END {
  if (!matched) { exit }
  in_opts = 0
  n = split(doc, lines, "\n")
  for (i = 1; i <= n; i++) {
    l = lines[i]
    if (l ~ /^Options:/) { in_opts = 1; continue }
    if (in_opts && l ~ /^[A-Za-z]+:/) { in_opts = 0 }
    if (in_opts) {
      sub(/^[ \t]+/, "", l)
      m = split(l, parts, /[ \t]+/)
      for (j = 1; j <= m; j++) {
        if (parts[j] !~ /^-/) { break }
        gsub(/,$/, "", parts[j])
        print parts[j]
      }
    }
  }
}
