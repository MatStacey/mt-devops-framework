# Normalises an ARP/neighbour table into "ip<TAB>mac<TAB>neighbour" rows.
# Run with -v format=windows|macos|linux for the output of `arp.exe -a`,
# `arp -an` or `ip -4 neigh show`. Keeps only complete unicast entries.
function normalise_mac(raw,    parts, count, i, octet, result) {
  gsub(/-/, ":", raw)
  count = split(tolower(raw), parts, ":")
  if (count != 6) return ""
  result = ""
  for (i = 1; i <= 6; i++) {
    octet = parts[i]
    if (octet !~ /^[0-9a-f]{1,2}$/) return ""
    if (length(octet) == 1) octet = "0" octet
    result = result (i > 1 ? ":" : "") octet
  }
  return result
}

function usable_ip(ip,    octets) {
  if (ip !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) return 0
  split(ip, octets, ".")
  if (octets[1] >= 224 && octets[1] <= 239) return 0
  if (octets[4] == 255) return 0
  return 1
}

function emit(ip, raw_mac,    mac) {
  if (!usable_ip(ip)) return
  mac = normalise_mac(raw_mac)
  if (mac == "" || mac == "ff:ff:ff:ff:ff:ff" || mac == "00:00:00:00:00:00") return
  print ip "\t" mac "\tneighbour"
}

format == "windows" && $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
  emit($1, $2)
}

format == "macos" && $2 ~ /^\([0-9.]+\)$/ {
  ip = $2
  gsub(/[()]/, "", ip)
  emit(ip, $4)
}

format == "linux" && $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
  state = $NF
  if (state == "FAILED" || state == "INCOMPLETE") next
  for (i = 2; i < NF; i++) {
    if ($i == "lladdr") emit($1, $(i + 1))
  }
}
