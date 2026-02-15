#!/bin/bash
# Test affected workspace packages in dependency order
# Usage: ./scripts/test-affected-packages.sh

set -e

# Define dependency order (leaf to root)
packages_ordered=(
  "MacroTemplateKit"
  "NetworkingMacros"
  "Networking"
)

# Get changed Swift files from staged changes
changed_files=$(git diff --cached --name-only 2>/dev/null | grep "\.swift$" || true)

if [ -z "$changed_files" ]; then
  echo "info: No Swift files changed, skipping tests"
  exit 0
fi

# Determine affected packages
declare -A affected
for file in $changed_files; do
  if [[ "$file" =~ ^Packages/([^/]+)/ ]]; then
    pkg="${BASH_REMATCH[1]}"
    affected[$pkg]=1
  fi
done

if [ ${#affected[@]} -eq 0 ]; then
  echo "info: No package source changes detected"
  exit 0
fi

echo "Affected packages: ${!affected[*]}"

# Test in dependency order
failed=0
for pkg in "${packages_ordered[@]}"; do
  if [ -n "${affected[$pkg]}" ]; then
    echo ""
    echo "Testing $pkg..."
    if [ -d "Packages/$pkg/Tests" ]; then
      if ! swift test --package-path "Packages/$pkg"; then
        echo "error: Tests failed for $pkg"
        failed=1
        break  # Fail fast
      fi
      echo "pass: $pkg tests passed"
    else
      echo "skip: $pkg has no tests"
    fi
  fi
done

exit $failed
