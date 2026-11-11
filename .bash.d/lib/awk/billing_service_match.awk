# Matches billing services by display name (column 2, tab-separated).
# Prints the exact (case-insensitive) matches when there are any, otherwise
# every substring match. The search text arrives in the SERVICE_QUERY environment variable.
BEGIN {
  FS = "\t"
  query = tolower(ENVIRON["SERVICE_QUERY"])
}
{
  name = tolower($2)
  if (name == query) {
    exact[++exact_count] = $0
  } else if (index(name, query) > 0) {
    partial[++partial_count] = $0
  }
}
END {
  if (exact_count > 0) {
    for (i = 1; i <= exact_count; i++) print exact[i]
  } else {
    for (i = 1; i <= partial_count; i++) print partial[i]
  }
}
