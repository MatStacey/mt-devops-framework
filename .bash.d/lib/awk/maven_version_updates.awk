# Parses the combined console output of `mvn versions:display-dependency-
# updates versions:display-property-updates versions:display-parent-updates`
# (all three goals run in one invocation, output concatenated) into TSV
# rows: scope<TAB>artifact<TAB>current<TAB>latest. Used by
# __mt_parse_maven_version_updates in 20-vcs/56-audit.sh.
#
# Confirmed against a real project's actual output (not just imagined
# formatting) that this plugin's report has more variation than a single
# "name .......... current -> latest" line:
#   - display-dependency-updates also emits a distinct pluginManagement-
#     of-plugins section (build-plugin updates, e.g. spring-boot-maven-
#     plugin) whose header happens to contain the same "newer versions"
#     substring as the plain dependency header -- so section detection
#     checks that more specific phrase first.
#   - The dependency and plugin sections use a dotted leader between name
#     and version ("name .......... current -> latest"); the parent
#     section instead uses a couple of plain spaces, no dots at all
#     ("name  current -> latest") -- so the separator can't be assumed to
#     be dots.
#   - A long name/version pair can wrap onto a second physical [INFO]
#     line with nothing on it but the version pair -- so a name-only line
#     (first whitespace-token contains ":", the shape of a groupId:
#     artifactId coordinate; no " -> " yet) is buffered and glued onto
#     the next line before parsing.
# Given all of that, name/version extraction never assumes a specific
# separator: whatever whitespace-delimited token sits immediately before
# " -> " is the current version (versions never contain whitespace);
# everything before it, with trailing dots/spaces trimmed off, is the
# name -- this holds for both the dotted and plain-space styles.
BEGIN { scope = ""; pending_name = "" }
/pluginManagement of plugins/ { scope = "plugin"; pending_name = ""; next }
/newer versions/ { scope = "dependency"; pending_name = ""; next }
/version propert/ { scope = "property"; pending_name = ""; next }
/parent/ && /updates/ { scope = "parent"; pending_name = ""; next }

/^\[INFO\]/ {
  line = $0
  sub(/^\[INFO\][[:space:]]*/, "", line)
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
  if (line == "" || scope == "") { next }

  if (index(line, " -> ") > 0) {
    full = line
    if (pending_name != "") {
      full = pending_name " " line
      pending_name = ""
    }

    arrow_idx = index(full, " -> ")
    left = substr(full, 1, arrow_idx - 1)
    latest = substr(full, arrow_idx + 4)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", latest)

    ntok = split(left, toks, /[[:space:]]+/)
    if (ntok >= 1 && latest != "") {
      current = toks[ntok]
      name = ""
      for (i = 1; i < ntok; i++) {
        name = (name == "") ? toks[i] : name " " toks[i]
      }
      gsub(/[[:space:].]+$/, "", name)
      if (name != "" && current != "") {
        print scope "\t" name "\t" current "\t" latest
      }
    }
  } else {
    # A candidate wrapped name: only buffer lines shaped like a real
    # groupId:artifactId coordinate (colon in the first token), not
    # incidental descriptive sentences the plugin also prints per section
    # (e.g. "The parent project has a newer version:" or "This project
    # does not have any properties associated with versions.").
    split(line, first_tok, /[[:space:]]+/)
    if (index(first_tok[1], ":") > 0) {
      pending_name = line
    }
  }
}
