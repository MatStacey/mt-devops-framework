include "bb_report_annotations";
# Input (slurped): [statuses, reports, {report uuid: annotations}].
# Variables: max (annotations shown per report).
# Output: "status<TAB>state<TAB>name<TAB>description<TAB>url" rows, then
# "report<TAB>result<TAB>title<TAB>report_type<TAB>link" rows, each failed
# report followed by its indented annotations. URLs lose any userinfo.
def strip_userinfo: sub("^(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)[^/@]*@"; "\(.scheme)");
def cell: tostring | gsub("[\t\r\n]+"; " ");

.[0] as $statuses
| .[1] as $reports
| .[2] as $annotations
| ($statuses[] | "status\t\(.state // "-")\t\((.name // .key // "-") | cell)\t\((.description // "-") | cell)\t\((.url // "-") | strip_userinfo | cell)"),
  ($reports[]
    | "report\t\(.result // "-")\t\((.title // "-") | cell)\t\(.report_type // "-")\t\((.link // "-") | strip_userinfo | cell)",
      (($annotations[.uuid] // empty) | annotation_rows($max)))
