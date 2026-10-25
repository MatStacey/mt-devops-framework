# Pivot "column<TAB>key<TAB>value" lines into a key x column table.
# Variables: columns  comma-separated column order (default: first-seen order)
#            mark     cell text when the value is empty (default: "x")
#            empty    cell text when the key is absent from a column (default: "-")
#            header   top-left header cell (default: "KEY")
#            diff_only  1 to print only keys whose cells are not identical in every column
#                       (an absent key counts as different)
#            flag     text put before the key of a differing row (default: none)
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
  fflush()
  for (key in keys) {
    differs = 0
    line = ""
    for (i = 1; i <= column_count; i++) {
      present = ((column_order[i], key) in cell)
      text = present ? cell[column_order[i], key] : empty
      line = line OFS text
      if (i > 1 && (!present || !first_present || text != first_text)) differs = 1
      if (i == 1) {
        first_present = present
        first_text = text
      }
    }
    if (diff_only == 1 && !differs) continue
    label = (differs && flag != "") ? flag " " key : key
    print label line | "sort -t '\t' -k1,1"
  }
}
