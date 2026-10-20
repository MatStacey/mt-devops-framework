s/[[:alnum:]._+-]+@[[:alnum:].-]+/EMAIL/g
s/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/UUID/g
s/\b[0-9a-fA-F]{12,}\b/HEX/g
s#https?://[^[:space:]]+#URL#g
s/[A-Za-z0-9+\/_=-]{24,}/TOKEN/g
s/"[^"]*"/"S"/g
s/'[^']*'/'S'/g
s/[0-9]+/N/g
