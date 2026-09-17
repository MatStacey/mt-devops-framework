# shellcheck shell=bash
# ------------------------------------------
# Version Control (Git) - Remote-Ref Inspection
# ------------------------------------------
# ~/.bash.d/20-vcs/59-git-remote-inspect.sh

#######################################
# Git: Diff two refs -- typically two remote-tracking branches -- without
# checking either out locally. Uses the three-dot form ('refA...refB',
# changes on refB since it diverged from refA), which is what a code
# review comparing a feature branch against its base almost always
# means, not a literal two-ref diff ('refA..refB').
# Usage: git-remote-diff <refA> <refB> [-- <path>...]
#
# Examples:
#   git-remote-diff origin/master origin/feature/x
#   git-remote-diff origin/master origin/feature/x -- src/
#######################################
git-remote-diff() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local ref_a="$1" ref_b="$2"
  if [[ -z "$ref_a" || -z "$ref_b" ]]; then
    echo "Usage: git-remote-diff <refA> <refB> [-- <path>...]" >&2
    return 1
  fi
  shift 2

  git diff "${ref_a}...${ref_b}" "$@"
}

#######################################
# Git: Show a file's content as of a specific ref without checking that
# ref out -- a thin, discoverable wrapper over 'git show <ref>:<path>'.
# Usage: git-remote-show <ref>:<path>
#
# Examples:
#   git-remote-show origin/feature/x:src/main.py
#######################################
git-remote-show() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  if [[ -z "$1" ]]; then
    echo "Usage: git-remote-show <ref>:<path>" >&2
    return 1
  fi

  git show "$1"
}

#######################################
# Git: Count pattern matches across one or more refs without checking
# any of them out -- a thin, discoverable wrapper over
# 'git grep -c <pattern> <ref>...'.
# Usage: git-remote-grep <pattern> <ref> [<ref>...]
#
# Examples:
#   git-remote-grep TODO origin/master origin/feature/x
#######################################
git-remote-grep() {
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mt-help "${FUNCNAME[0]}"
    return 0
  fi

  local pattern="$1"
  if [[ -z "$pattern" ]]; then
    echo "Usage: git-remote-grep <pattern> <ref> [<ref>...]" >&2
    return 1
  fi
  shift

  if [[ "$#" -eq 0 ]]; then
    echo "Usage: git-remote-grep <pattern> <ref> [<ref>...]" >&2
    return 1
  fi

  git grep -c "$pattern" "$@"
}
