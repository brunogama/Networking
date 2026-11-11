#!/bin/sh
set -eu

protected=false
for file in "$@"; do
  case "$file" in
    Package.swift|prek.toml|.swift-format|.swiftlint.yml|.swift-style.env|.github/*)
      protected=true
      ;;
  esac
done

[ "$protected" = true ] || exit 0

printf 'Commit blocked: review and approve changes to repository tooling configuration before committing:\n' >&2
for file in "$@"; do
  case "$file" in
    Package.swift|prek.toml|.swift-format|.swiftlint.yml|.swift-style.env|.github/*)
      printf '  %s\n' "$file" >&2
      ;;
  esac
done
exit 1
