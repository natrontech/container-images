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

echo "🏗️  Building container: $CONTAINER_NAME"
echo "📁 Context: ./$CONTAINER_NAME"
echo "🏷️  Image: $IMAGE_NAME"
echo "🔖 SHA: $SHORT_SHA"
echo ""

if docker buildx inspect multiarch-builder >/dev/null 2>&1; then
    echo "🔧 Using existing buildx builder: multiarch-builder"
else
    docker buildx create --name multiarch-builder --use >/dev/null 2>&1 || true
fi

docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t "${IMAGE_NAME}:latest" \
    -t "${IMAGE_NAME}:sha-${SHORT_SHA}" \
    -t "${IMAGE_NAME}:test" \
    --load \
    "./${CONTAINER_NAME}" 2>/dev/null || {
    echo "⚠️  Multi-arch --load not supported, building for current platform only"
    docker buildx build \
        -t "${IMAGE_NAME}:latest" \
        -t "${IMAGE_NAME}:sha-${SHORT_SHA}" \
        -t "${IMAGE_NAME}:test" \
        --load \
        "./${CONTAINER_NAME}"
}

echo "✅ Build completed successfully!"
echo ""
echo "🧪 Testing container..."

if command -v dive >/dev/null 2>&1; then
    echo "📊 Running dive analysis..."
    dive "${IMAGE_NAME}:test" --ci
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
    echo "✅ Push completed!"
fi

echo ""
echo "🎉 Container test completed for: $CONTAINER_NAME"
echo "🐳 Run locally with: docker run --rm -it ${IMAGE_NAME}:test"
