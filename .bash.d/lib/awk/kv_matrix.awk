# Pivot "column<TAB>key<TAB>value" lines into a key x column table.
# Variables: columns  comma-separated column order (default: first-seen order)
#            mark     cell text when the value is empty (default: "x")
#            empty    cell text when the key is absent from a column (default: "-")
#            header   top-left header cell (default: "KEY")
BEGIN {
  FS = OFS = "\t"
  if (mark == "") mark = "x"
  if (empty == "") empty = "-"
  if (header == "") header = "KEY"
  column_count = split(columns, column_order, ",")
  for (i = 1; i <= column_count; i++) known[column_order[i]] = 1
}
$1 == "" { next }
{
  if (!($1 in known)) {
    known[$1] = 1
    column_order[++column_count] = $1
  }
  keys[$2] = 1
  cell[$1, $2] = ($3 == "" ? mark : $3)
}
END {
  line = header
  for (i = 1; i <= column_count; i++) line = line OFS column_order[i]
  print line
  for (key in keys) {
    line = key
    for (i = 1; i <= column_count; i++) {
      line = line OFS (((column_order[i], key) in cell) ? cell[column_order[i], key] : empty)
    }
    print line | "sort -t '\t' -k1,1"
  }
}
