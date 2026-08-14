#!/usr/bin/env bash
set -euo pipefail

# Build and push a multi-arch konflate container image.
#
# Usage:
#   ./hack/build-image.sh [TAG]
#
# The script resolves the pinned Go and Node versions from mise (falling back to
# .mise/config.toml) and stamps the binary with the supplied tag and current Git
# revision.
#
# Environment variables:
#   REGISTRY       Container registry (default: ghcr.io)
#   REPOSITORY     Image repository (default: fhoekstra/konflate)
#   TAG            Image tag (default: current Git branch name with / replaced by -)
#   PLATFORMS      Comma-separated platforms (default: linux/amd64,linux/arm64)
#   PUSH           Push the image when true (default: true)
#   LOAD           Load the image into the local daemon when true (default: false;
#                  incompatible with multi-platform builds, so set PLATFORMS to one)
#   BUILDER_NAME   docker buildx builder name (default: multiarch)
#   GO_VERSION     Go toolchain version (default: resolved from mise)
#   NODE_VERSION   Node toolchain version (default: resolved from mise)
#   REVISION       Git revision to stamp into the binary (default: HEAD)

DOCKER="${DOCKER:-docker}"
REGISTRY="${REGISTRY:-ghcr.io}"
REPOSITORY="${REPOSITORY:-fhoekstra/konflate}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
PUSH="${PUSH:-true}"
LOAD="${LOAD:-false}"
BUILDER_NAME="${BUILDER_NAME:-multiarch}"

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    sed -n 's/^# //p' "$0"
    exit 0
fi

if ! command -v "$DOCKER" >/dev/null 2>&1; then
    echo "error: '$DOCKER' not found in PATH" >&2
    exit 1
fi

if [[ "$PUSH" == "true" && "$LOAD" == "true" ]]; then
    echo "error: PUSH and LOAD cannot both be true (docker cannot load a multi-platform build)" >&2
    exit 1
fi

if command -v mise >/dev/null 2>&1; then
    GO_VERSION="${GO_VERSION:-$(mise config get tools.go)}"
    NODE_VERSION="${NODE_VERSION:-$(mise config get tools.node)}"
else
    GO_VERSION="${GO_VERSION:-$(sed -n 's/^go = "\(.*\)"$/\1/p' .mise/config.toml)}"
    NODE_VERSION="${NODE_VERSION:-$(sed -n 's/^node = "\(.*\)"$/\1/p' .mise/config.toml)}"
fi

if [[ -z "$GO_VERSION" || -z "$NODE_VERSION" ]]; then
    echo "error: could not resolve GO_VERSION or NODE_VERSION from mise or .mise/config.toml" >&2
    exit 1
fi

TAG="${1:-${TAG:-$(git rev-parse --abbrev-ref HEAD | tr / -)}}"
VERSION="$TAG"
REVISION="${REVISION:-$(git rev-parse HEAD)}"

if ! "$DOCKER" buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
    echo "Creating buildx builder '$BUILDER_NAME'..."
    "$DOCKER" buildx create --name "$BUILDER_NAME" --driver docker-container --use
else
    "$DOCKER" buildx use "$BUILDER_NAME"
fi

"$DOCKER" buildx inspect --bootstrap

BUILD_ARGS=(
    --file ./Dockerfile
    --platform "$PLATFORMS"
    --build-arg "GO_VERSION=$GO_VERSION"
    --build-arg "NODE_VERSION=$NODE_VERSION"
    --build-arg "VERSION=$VERSION"
    --build-arg "REVISION=$REVISION"
    --tag "$REGISTRY/$REPOSITORY:$TAG"
)

if [[ "$LOAD" == "true" ]]; then
    BUILD_ARGS+=(--load)
fi

if [[ "$PUSH" == "true" ]]; then
    BUILD_ARGS+=(--push)
fi

echo "Building konflate $VERSION ($REVISION) for $PLATFORMS..."
"$DOCKER" buildx build "${BUILD_ARGS[@]}" .

echo "Built: $REGISTRY/$REPOSITORY:$TAG"
