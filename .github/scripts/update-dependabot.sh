#!/bin/bash
set -e

DEPENDABOT_FILE=".github/dependabot.yml"
TEMP_FILE=$(mktemp)

cat > "$TEMP_FILE" << 'EOF'
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: ":seedling:"
    groups:
      github-actions:
        patterns:
          - "*"

EOF

for dir in */; do
  if [[ -f "${dir}Dockerfile" ]]; then
    container_name=$(basename "$dir")
    cat >> "$TEMP_FILE" << EOF
  - package-ecosystem: "docker"
    directory: "/${container_name}"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: ":robot:"
    groups:
      docker-dependencies:
        patterns:
          - "*"

EOF
  fi
done

mv "$TEMP_FILE" "$DEPENDABOT_FILE"
echo "Updated $DEPENDABOT_FILE with all container directories"
