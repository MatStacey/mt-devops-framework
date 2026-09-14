# shellcheck shell=bash
# ------------------------------------------
# Google Style Code Formatting
# ------------------------------------------

#######################################
# Formats Python, Shell, and Java source according to Google Style Guides.
# Uses yapf for Python, shfmt for Shell scripts, and google-java-format
# for Java.
# Outputs:
#   Writes formatting status updates to STDOUT.
# Returns:
#   0 on success.
#######################################
google-fmt() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  echo "🔍 Linting and formatting Python scripts (Ruff)..."
  if command -v ruff > /dev/null 2>&1; then
    ruff check --fix .
    ruff format .
  fi

  echo "🎨 Formatting Python scripts (Google Python Style)..."
  if command -v yapf > /dev/null 2>&1; then
    yapf -r -i --style="{based_on_style: google, column_limit: 88, spaces_before_comment: 2}" .
    echo "✅ Python formatting complete."
  else
    echo "⚠️ 'yapf' not found. Run 'bootstrap' to install it."
  fi

  echo "🎨 Formatting Shell scripts (Google Shell Style Guide)..."
  if command -v shfmt > /dev/null 2>&1; then
    # Google Shell Style Guide: 2-space indents (-i 2), switch case indent (-ci), and space after redirects (-sr)
    shfmt -i 2 -ci -sr -w .
    echo "✅ Shell script formatting complete."
  else
    echo "⚠️ 'shfmt' not found."
  fi

  echo "🎨 Formatting Java source (Google Java Format)..."
  if command -v google-java-format > /dev/null 2>&1; then
    local -a java_files=()
    while IFS= read -r -d '' f; do java_files+=("$f"); done < <(
      find . -name "*.java" -not -path "*/target/*" -not -path "*/build/*" -print0 2> /dev/null
    )
    if [ "${#java_files[@]}" -gt 0 ]; then
      google-java-format --replace "${java_files[@]}"
      echo "✅ Java formatting complete (${#java_files[@]} file(s))."
    else
      echo "ℹ️  No .java files found."
    fi
  else
    echo "⚠️ 'google-java-format' not found. Run 'bootstrap' to install it."
  fi
}
