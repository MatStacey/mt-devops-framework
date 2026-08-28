# mt-hub fzf selection table renderer
# Input: pipe-delimited rows of TYPE|REPOSITORY|BRANCH|PATH
# Output: TAB-delimited PATH, then the padded, box-drawn display columns --
# the raw path is prepended as a hidden first field so fzf's --preview and
# the post-selection cd can recover it exactly. Matching against the
# visible " │ "-separated text isn't reliable since fzf's default
# field-splitting is whitespace-based and the box-drawing separator sits
# inside the padding.

function pad(str, len) {
  if (length(str) > len) return substr(str, 1, len - 3) "..."
  return str sprintf("%*s", len - length(str), "")
}

BEGIN { FS = "|" }
{
  printf "%s\t%s │ %s │ %s │ %s\n", $4, pad($1, 15), pad($2, 35), pad($3, 20), $4
}
