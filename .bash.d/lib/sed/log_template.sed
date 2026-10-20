s/[[:alnum:]._+-]+@[[:alnum:].-]+/EMAIL/g
s/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/UUID/g
s/\b[0-9a-fA-F]{12,}\b/HEX/g
s/"[^"]*"/"S"/g
s/'[^']*'/'S'/g
s/[0-9]+/N/g
