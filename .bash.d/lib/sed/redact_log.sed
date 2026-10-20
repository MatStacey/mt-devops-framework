s/(Authorization:[[:space:]]*(Bearer|Basic)[[:space:]]+)[^[:space:]]+/\1***/Ig
s/((pass(word)?|secret|token|api[_-]?key|access[_-]?key|private[_-]?key)[A-Za-z0-9_]*[[:space:]]*[=:][[:space:]]*)[^[:space:]'"]+/\1***/Ig
s/AKIA[0-9A-Z]{16}/***/g
s/(gh[pousr]_|glpat-|xox[abp]-)[A-Za-z0-9_-]+/***/g
s#(://[^/:@[:space:]]+:)[^@[:space:]]+@#\1***@#g
