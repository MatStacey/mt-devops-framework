"#\(.id) \(.title)",
"State:     \(.state)",
"Author:    \(.author.display_name)",
"Branch:    \(.source.branch.name) -> \(.destination.branch.name)",
"Created:   \(.created_on)   Updated: \(.updated_on)",
"Reviewers: \([.participants[]? | select(.role == "REVIEWER") | .user.display_name + (if .approved then " (approved)" else "" end)] | join(", "))",
"URL:       \(.links.html.href)",
"",
(.description // "")
