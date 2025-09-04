#!/bin/bash
set -e

# Find all directories containing Dockerfiles
containers=()
for dir in */; do
  if [[ -f "${dir}Dockerfile" ]]; then
    container_name=$(basename "$dir")
    containers+=("$container_name")
  fi
done

echo "Discovered containers: ${containers[*]}"

# Convert to JSON array - handle empty array case
if [ ${#containers[@]} -eq 0 ]; then
  json_array='[]'
  matrix='{"include":[]}'
else
  # Create JSON array properly
  json_array="["
  for i in "${!containers[@]}"; do
    if [ $i -gt 0 ]; then
      json_array+=","
    fi
    json_array+="\"${containers[$i]}\""
  done
  json_array+="]"

  # Create matrix
  matrix='{"include":['
  for i in "${!containers[@]}"; do
    if [ $i -gt 0 ]; then
      matrix+=","
    fi
    matrix+="{\"container\":\"${containers[$i]}\"}"
  done
  matrix+=']}'
fi

echo "Generated JSON: ${json_array}"
echo "Generated matrix: ${matrix}"

# Validate JSON
echo "${json_array}" | python3 -m json.tool > /dev/null && echo "✅ JSON is valid" || echo "❌ JSON is invalid"
echo "${matrix}" | python3 -m json.tool > /dev/null && echo "✅ Matrix is valid" || echo "❌ Matrix is invalid"
