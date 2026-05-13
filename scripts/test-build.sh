#!/bin/bash
set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <container-name> [--push]"
    echo ""
    echo "Examples:"
    echo "  $0 tcp-forwarder          # Build and test locally"
    echo "  $0 tcp-forwarder --push   # Build and push to registry"
    echo ""
    echo "Available containers:"
    for dir in */; do
        if [[ -f "${dir}Dockerfile" ]]; then
            container_name=$(basename "$dir")
            echo "  - $container_name"
        fi
    done
    exit 1
fi

CONTAINER_NAME="$1"
PUSH_FLAG="$2"
IMAGE_NAME="ghcr.io/natrontech/container-images/${CONTAINER_NAME}"
SHORT_SHA=$(git rev-parse --short HEAD)

if [[ ! -d "$CONTAINER_NAME" ]]; then
    echo "Error: Directory '$CONTAINER_NAME' does not exist"
    exit 1
fi

if [[ ! -f "${CONTAINER_NAME}/Dockerfile" ]]; then
    echo "Error: No Dockerfile found in '$CONTAINER_NAME/' directory"
    exit 1
fi

PLATFORMS="linux/amd64,linux/arm64"
if [[ -f "${CONTAINER_NAME}/PLATFORMS" ]]; then
    PLATFORMS=$(cat "${CONTAINER_NAME}/PLATFORMS" | tr -d '[:space:]')
fi

VERSION=""
if [[ -f "${CONTAINER_NAME}/VERSION" ]]; then
    VERSION=$(cat "${CONTAINER_NAME}/VERSION" | tr -d '[:space:]')
fi

VERSION_TAGS=()
if [[ -n "$VERSION" ]]; then
    VERSION_TAGS=(-t "${IMAGE_NAME}:${VERSION}")
fi

echo "🏗️  Building container: $CONTAINER_NAME"
echo "📁 Context: ./$CONTAINER_NAME"
echo "🏷️  Image: $IMAGE_NAME"
echo "🔖 SHA: $SHORT_SHA"
echo "🖥️  Platforms: $PLATFORMS"
[[ -n "$VERSION" ]] && echo "📌 Version: $VERSION"
echo ""

PLATFORM_COUNT=$(echo "${PLATFORMS}" | tr ',' '\n' | wc -l | tr -d '[:space:]')

if [[ "${PLATFORM_COUNT}" -gt 1 ]]; then
    echo "⚠️  Multi-platform build (${PLATFORMS}) — --load requires a single platform, building for current platform only"
    docker buildx build \
        -t "${IMAGE_NAME}:latest" \
        -t "${IMAGE_NAME}:sha-${SHORT_SHA}" \
        -t "${IMAGE_NAME}:test" \
        "${VERSION_TAGS[@]}" \
        --load \
        "./${CONTAINER_NAME}"
else
    docker buildx build \
        --platform "${PLATFORMS}" \
        -t "${IMAGE_NAME}:latest" \
        -t "${IMAGE_NAME}:sha-${SHORT_SHA}" \
        -t "${IMAGE_NAME}:test" \
        "${VERSION_TAGS[@]}" \
        --load \
        "./${CONTAINER_NAME}"
fi

echo "✅ Build completed successfully!"
echo ""
echo "🧪 Testing container..."

if command -v dive >/dev/null 2>&1; then
    echo "📊 Running dive analysis..."
    DIVE_ARGS=(--ci)
    if [[ -f "${CONTAINER_NAME}/.dive-ci.yaml" ]]; then
        DIVE_ARGS+=(--ci-config "${CONTAINER_NAME}/.dive-ci.yaml")
    fi
    dive "${IMAGE_NAME}:test" "${DIVE_ARGS[@]}"
else
    echo "💡 Install 'dive' for container analysis: brew install dive"
fi

echo "🔍 Container info:"
docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

if [[ "$PUSH_FLAG" == "--push" ]]; then
    echo ""
    echo "🚀 Pushing to registry..."
    docker push "${IMAGE_NAME}:latest"
    docker push "${IMAGE_NAME}:sha-${SHORT_SHA}"
    [[ -n "$VERSION" ]] && docker push "${IMAGE_NAME}:${VERSION}"
    echo "✅ Push completed!"
fi

echo ""
echo "🎉 Container test completed for: $CONTAINER_NAME"
echo "🐳 Run locally with: docker run --rm -it ${IMAGE_NAME}:test"
