# Extracts every top-level `resource "<type>" "<label>" {` declaration from
# Terraform files, plus the string-literal value of a fixed set of
# identifying attributes (name, account_id, ...) declared directly in that
# resource's own block -- the live name a deployed resource actually has,
# which is rarely its Terraform label. Attributes set from a variable,
# local, or interpolation (anything containing "${", "var.", "local.", ...)
# are skipped: only a plain quoted literal is trustworthy without
# evaluating the Terraform.
#
# Output (tab-separated, one line per resource occurrence):
#   <type> <label> [<attr> <value>]...
#
# Heuristic, not an HCL parser: assumes the one-line declaration style, and
# tracks block depth by counting braces outside quoted strings, so an
# attribute inside a nested block (e.g. a `template { name = ... }`) is not
# mistaken for the resource's own.

BEGIN {
  n = split("name account_id dataset_id secret_id repository_id service api_id gateway_id workload_identity_pool_id", wanted_list, " ")
  for (i = 1; i <= n; i++) wanted[wanted_list[i]] = 1
}

function flush() {
  if (rtype == "") return
  line = rtype "\t" label
  for (i = 1; i <= n; i++) {
    k = wanted_list[i]
    if (k in attrs) line = line "\t" k "\t" attrs[k]
  }
  print line
  rtype = ""
  delete attrs
}

FNR == 1 { flush(); depth = 0 }

{
  raw = $0
  stripped = raw
  gsub(/"[^"]*"/, "", stripped)
  opens = gsub(/\{/, "{", stripped)
  closes = gsub(/\}/, "}", stripped)

  if (depth == 0 && match(raw, /^[[:space:]]*resource[[:space:]]+"[A-Za-z0-9_]+"[[:space:]]+"[A-Za-z0-9_-]+"/)) {
    flush()
    decl = substr(raw, RSTART, RLENGTH)
    split(decl, parts, "\"")
    rtype = parts[2]
    label = parts[4]
    delete attrs
    depth = opens - closes
    next
  }

  if (rtype != "" && depth == 1 && match(raw, /^[[:space:]]*[a-z_]+[[:space:]]*=[[:space:]]*"[^"]*"[[:space:]]*(#.*)?$/)) {
    key = raw
    sub(/^[[:space:]]*/, "", key)
    sub(/[[:space:]]*=.*/, "", key)
    if ((key in wanted) && !(key in attrs)) {
      val = raw
      sub(/^[^"]*"/, "", val)
      sub(/".*$/, "", val)
      if (val != "" && val !~ /\$\{|%\{|var\.|local\./) attrs[key] = val
    }
  }

  depth += opens - closes
  if (depth <= 0) {
    flush()
    depth = 0
  }
}

END { flush() }
