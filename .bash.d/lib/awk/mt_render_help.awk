# ~/.bash.d/lib/awk/mt_render_help.awk
# Used by mt-help's __render_help to split a target function/alias's
# docstring from its source code. Distinct from mt_help.awk: this one
# strips the "#######" fence and leading "# " comment markers from the
# docstring and emits doc/code as two separate blocks (delimited by
# ---MT_CODE_DELIMITER---) for colorized interactive display, whereas
# mt_help.awk emits the raw, unstripped comment+code block used to build
# COMMANDS.md -- they serve different consumers, not the same one twice.
BEGIN { flag = 0; doc = ""; code = "" }
!flag && /^#######################################/ { next }
!flag && /^#/ {
    line = substr($0, 2)
    sub(/^[ \t]/, "", line)
    doc = doc line "\n"
    next
}
$0 ~ "^alias " target "=" { code = $0 "\n"; exit }
$0 ~ "^" target "\\(\\)[ \t]*\\{" { code = $0 "\n"; flag = 1; next }
flag { code = code $0 "\n"; if ($0 ~ /^}$/) exit }
{ if (!flag) { doc = ""; code = "" } }
END { print doc; print "---MT_CODE_DELIMITER---"; print code }
