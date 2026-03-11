#!/bin/bash
# Generate Documentation.docc extension stubs for new types
# Usage: ./scripts/generate-doc-stubs.sh TypeName1 TypeName2 ...

set -e

DOCS_DIR="Documentation.docc/Extensions"

if [ $# -eq 0 ]; then
  echo "Usage: $0 TypeName1 TypeName2 ..."
  echo "No types provided, nothing to generate."
  exit 0
fi

# Create Extensions directory if needed
mkdir -p "$DOCS_DIR"

created=0
skipped=0

for type in "$@"; do
  # Skip empty or whitespace-only
  type=$(echo "$type" | xargs)
  [ -z "$type" ] && continue

  stub_file="$DOCS_DIR/$type.md"

  if [ -f "$stub_file" ]; then
    echo "skip: $stub_file already exists"
    ((skipped++))
    continue
  fi

  cat > "$stub_file" << EOF
# \`\`$type\`\`

@Metadata {
  @DocumentationExtension(mergeBehavior: append)
}

## Overview

<!-- TODO: Add description of $type -->

## Topics

### Creating $type

<!-- TODO: Add initializer links -->

### Instance Methods

<!-- TODO: Add method links -->

### Instance Properties

<!-- TODO: Add property links -->
EOF

  echo "created: $stub_file"
  ((created++))
done

echo ""
echo "Summary: $created created, $skipped skipped"
