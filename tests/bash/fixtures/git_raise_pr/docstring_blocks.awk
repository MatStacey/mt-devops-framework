# Prints how many stacked docstring blocks sit directly above "fn() {":
# 0 if the line above is not a block delimiter, 2 if a second block
# ends right where the first one starts.
{ line[NR] = $0 }
$0 == fn "() {" {
  sep = "#######################################"
  if (line[NR - 1] != sep) { print 0; exit }
  j = NR - 2
  while (j > 0 && line[j] != sep) j--
  print (line[j - 1] == sep ? 2 : 1)
  exit
}
