#!/bin/bash
# build-images.sh — Build and optionally push RASP Docker images.
#
# Usage:
#   ./scripts/build-images.sh              # build both images locally
#   ./scripts/build-images.sh --push       # build and push to GHCR
#   ./scripts/build-images.sh windgram     # build only windgram image
#   ./scripts/build-images.sh wrf --push   # build and push wrf-compiled only
#
# Environment:
#   REGISTRY    — container registry (default: ghcr.io/nw-paragliding)
#   PLATFORMS   — target platforms (default: linux/arm64,linux/amd64)
#   WRF_VERSION — WRF version tag (default: 4.5.2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults
REGISTRY="${REGISTRY:-ghcr.io/nw-paragliding}"
PLATFORMS="${PLATFORMS:-linux/arm64,linux/amd64}"
WRF_VERSION="${WRF_VERSION:-4.5.2}"
VERSION=$(cat "${REPO_ROOT}/VERSION" | tr -d '[:space:]')

WRF_IMAGE="${REGISTRY}/wrf-compiled:${WRF_VERSION}"
WINDGRAM_IMAGE="${REGISTRY}/windgram:${VERSION}"
WINDGRAM_LATEST="${REGISTRY}/windgram:latest"

PUSH=""
TARGET=""

# Parse args
for arg in "$@"; do
    case "$arg" in
        --push) PUSH="--push" ;;
        wrf) TARGET="wrf" ;;
        windgram) TARGET="windgram" ;;
        *) echo "Unknown arg: $arg"; exit 1 ;;
    esac
done

# Ensure buildx builder exists
ensure_builder() {
    if ! docker buildx inspect rasp-builder >/dev/null 2>&1; then
        echo "Creating buildx builder 'rasp-builder'..."
        docker buildx create --name rasp-builder --use --bootstrap
    else
        docker buildx use rasp-builder
    fi
}

build_wrf() {
    echo ""
    echo "============================================================"
    echo "  Building wrf-compiled (${WRF_VERSION})"
    echo "  Image:     ${WRF_IMAGE}"
    echo "  Platforms: ${PLATFORMS}"
    echo "============================================================"
    echo ""

    local load_or_push="${PUSH}"
    # If not pushing, load locally (only works for single platform)
    if [ -z "${load_or_push}" ]; then
        load_or_push="--load"
        # --load only supports single platform
        local plat
        plat=$(uname -m)
        if [ "$plat" = "aarch64" ] || [ "$plat" = "arm64" ]; then
            PLATFORMS="linux/arm64"
        else
            PLATFORMS="linux/amd64"
        fi
        echo "  (local build — single platform: ${PLATFORMS})"
    fi

    docker buildx build \
        --platform "${PLATFORMS}" \
        -f "${REPO_ROOT}/docker/Dockerfile.wrf" \
        --build-arg WRF_VERSION="${WRF_VERSION}" \
        -t "${WRF_IMAGE}" \
        ${load_or_push} \
        "${REPO_ROOT}"
}

build_windgram() {
    echo ""
    echo "============================================================"
    echo "  Building windgram (${VERSION})"
    echo "  Image:     ${WINDGRAM_IMAGE}"
    echo "  Base:      ${WRF_IMAGE}"
    echo "  Platforms: ${PLATFORMS}"
    echo "============================================================"
    echo ""

    local load_or_push="${PUSH}"
    if [ -z "${load_or_push}" ]; then
        load_or_push="--load"
        local plat
        plat=$(uname -m)
        if [ "$plat" = "aarch64" ] || [ "$plat" = "arm64" ]; then
            PLATFORMS="linux/arm64"
        else
            PLATFORMS="linux/amd64"
        fi
        echo "  (local build — single platform: ${PLATFORMS})"
    fi

    docker buildx build \
        --platform "${PLATFORMS}" \
        -f "${REPO_ROOT}/docker/Dockerfile.windgram" \
        --build-arg WRF_IMAGE="${WRF_IMAGE}" \
        --build-arg VERSION="${VERSION}" \
        -t "${WINDGRAM_IMAGE}" \
        -t "${WINDGRAM_LATEST}" \
        ${load_or_push} \
        "${REPO_ROOT}"
}

# Main
if [ -z "${TARGET}" ] || [ "${TARGET}" = "wrf" ]; then
    if [ -n "${PUSH}" ]; then
        ensure_builder
    fi
    build_wrf
fi

if [ -z "${TARGET}" ] || [ "${TARGET}" = "windgram" ]; then
    if [ -n "${PUSH}" ]; then
        ensure_builder
    fi
    build_windgram
fi

echo ""
echo "Done."
