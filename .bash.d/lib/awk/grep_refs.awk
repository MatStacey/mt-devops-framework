# Reformat "ref:path[:line:text]" lines from `git grep <refs>` for one repository.
# Variables: repo    repository path relative to the VCS root
#            strip   ref prefix to remove from displayed refs
#            unique  1 to merge identical hits found on several refs into one line
# Output:    repo/ref:rest   or, with unique, repo/ref1,ref2:rest
BEGIN { prefix_length = length(strip) }
{
  split_at = index($0, ":")
  if (split_at == 0) next
  ref = substr($0, 1, split_at - 1)
  rest = substr($0, split_at + 1)
  if (prefix_length > 0 && substr(ref, 1, prefix_length) == strip) ref = substr(ref, prefix_length + 1)
  if (unique != 1) {
    print repo "/" ref ":" rest
    next
  }
  if (rest in refs) {
    refs[rest] = refs[rest] "," ref
  } else {
    order[++count] = rest
    refs[rest] = ref
  }
}
END {
  for (i = 1; i <= count; i++) print repo "/" refs[order[i]] ":" order[i]
}
