#!/bin/bash
set -e

echo "🔍 Validating Container Images Repository..."

echo ""
echo "📁 Checking repository structure..."
required_files=(
    ".github/workflows/container-build.yml"
    ".github/workflows/cleanup.yml"
    ".github/workflows/scorecard.yml"
    "policy.cue"
    "README.md"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file"
    else
        echo "❌ $file (missing)"
        exit 1
    fi
done

echo ""
echo "🏗️ Discovering containers..."
containers=()
for dir in */; do
    if [[ -f "${dir}Dockerfile" ]]; then
        container_name=$(basename "$dir")
        containers+=("$container_name")
        echo "✅ Found container: $container_name"

        # Validate Dockerfile exists and is readable
        if [[ -r "${dir}Dockerfile" ]]; then
            echo "  ✅ Dockerfile is readable"
        else
            echo "  ❌ Dockerfile is not readable"
            exit 1
        fi
    fi
done

if [ ${#containers[@]} -eq 0 ]; then
    echo "❌ No containers found! Add at least one directory with a Dockerfile."
    exit 1
else
    echo "✅ Found ${#containers[@]} container(s): ${containers[*]}"
fi

echo ""
echo "🧪 Testing JSON generation..."
# Test the same logic as in the workflow
json_array="["
for i in "${!containers[@]}"; do
    if [ $i -gt 0 ]; then
        json_array+=","
    fi
    json_array+="\"${containers[$i]}\""
done
json_array+="]"

matrix='{"include":['
for i in "${!containers[@]}"; do
    if [ $i -gt 0 ]; then
        matrix+=","
    fi
    matrix+="{\"container\":\"${containers[$i]}\"}"
done
matrix+=']}'

echo "Generated JSON: ${json_array}"
echo "Generated matrix: ${matrix}"

# Validate JSON if python3 is available
if command -v python3 >/dev/null 2>&1; then
    echo "${json_array}" | python3 -m json.tool > /dev/null && echo "✅ JSON is valid" || (echo "❌ JSON is invalid" && exit 1)
    echo "${matrix}" | python3 -m json.tool > /dev/null && echo "✅ Matrix is valid" || (echo "❌ Matrix is invalid" && exit 1)
else
    echo "⚠️  Python3 not available, skipping JSON validation"
fi

echo ""
echo "🔗 Checking dependabot.yml sync..."
dependabot_ok=true
for container in "${containers[@]}"; do
    if grep -q "directory: \"/${container}\"" .github/dependabot.yml 2>/dev/null; then
        echo "  ✅ ${container} in dependabot.yml"
    else
        echo "  ❌ ${container} missing from dependabot.yml"
        echo "     Run: bash .github/scripts/update-dependabot.sh"
        dependabot_ok=false
    fi
done
if [[ "$dependabot_ok" == "false" ]]; then
    echo "❌ dependabot.yml is out of sync with discovered containers"
    exit 1
fi

echo ""
echo "📋 Registry URLs for containers:"
for container in "${containers[@]}"; do
    echo "  📦 ghcr.io/natrontech/container-images/${container}:nightly"
done

echo ""
echo "🎉 Repository validation completed successfully!"
echo ""
echo "🚀 Next steps:"
echo "  1. Commit and push changes to trigger the workflow"
echo "  2. Check GitHub Actions for build status"
echo "  3. Verify images are published to ghcr.io"
echo "  4. Test manual workflow dispatch"
