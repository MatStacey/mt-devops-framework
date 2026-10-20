.[]
| select(.deleted | not)
| "[\(.id)] \(.user.display_name) @ \(.inline.path // "general")\(if .inline.to then ":\(.inline.to)" else "" end) (\(.created_on))\n\(.content.raw)\n"
