#!/usr/bin/env bash
set -euo pipefail

# Package and push the konflate Helm chart to an OCI registry.
#
# Usage:
#   ./hack/push-chart.sh [TAG]
#
# The script packages charts/konflate and pushes it as an OCI artifact.
#
# Environment variables:
#   REGISTRY      OCI registry host (default: ghcr.io)
#   REPOSITORY    Chart repository path (default: home-operations/charts)
#   TAG           Chart version tag (default: version from Chart.yaml)
#   CHART_DIR     Path to the chart directory (default: charts/konflate)
#   HELM          Helm binary (default: helm)
#   KEEP_PACKAGE  Keep the packaged .tgz after push when true (default: false)

HELM="${HELM:-helm}"
REGISTRY="${REGISTRY:-ghcr.io}"
REPOSITORY="${REPOSITORY:-fhoekstra/charts}"
CHART_DIR="${CHART_DIR:-charts/konflate}"
KEEP_PACKAGE="${KEEP_PACKAGE:-false}"

cd "$(dirname "$0")/.."

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    sed -n 's/^# //p' "$0"
    exit 0
fi

if ! command -v "$HELM" >/dev/null 2>&1; then
    echo "error: '$HELM' not found in PATH" >&2
    exit 1
fi

if [[ ! -f "$CHART_DIR/Chart.yaml" ]]; then
    echo "error: Chart.yaml not found in '$CHART_DIR'" >&2
    exit 1
fi

CHART_VERSION="${1:-${TAG:-$(sed -n 's/^version: //p' "$CHART_DIR/Chart.yaml" | tr -d '[:space:]')}}"

if [[ -z "$CHART_VERSION" ]]; then
    echo "error: could not determine chart version (set TAG or supply as argument)" >&2
    exit 1
fi

echo "Packaging konflate chart (version $CHART_VERSION)..."
PKG_OUTPUT=$("$HELM" package "$CHART_DIR" --version "$CHART_VERSION" --app-version "$CHART_VERSION")
PKG_FILE=${PKG_OUTPUT##* }

echo "Pushing $PKG_FILE to oci://$REGISTRY/$REPOSITORY..."
"$HELM" push "$PKG_FILE" "oci://$REGISTRY/$REPOSITORY"

if [[ "$KEEP_PACKAGE" != "true" ]]; then
    rm -f "$PKG_FILE"
fi

echo "Pushed: oci://$REGISTRY/$REPOSITORY/konflate:$CHART_VERSION"
