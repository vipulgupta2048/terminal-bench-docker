#!/bin/bash
# =============================================================================
# Build Docker Image for Terminal-Bench Agent
# =============================================================================
#
# This script builds a pre-built Docker image with your agent installed.
#
# USAGE:
#   ./build-image.sh                    # Build with default name
#   ./build-image.sh my-custom-name     # Build with custom image name
#
# TESTING:
#   docker run -it my-agent-image bash  # Interactive testing
#
# NOTE:
# This is OPTIONAL. Harbor creates fresh containers automatically.
# Use this for:
# - Debugging your agent setup
# - Speeding up benchmark runs (skip install step)
# - Testing installation scripts
#
# =============================================================================

set -e

# Configuration
IMAGE_NAME="${1:-my-agent-image}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            Building Terminal-Bench Agent Image               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Image name: $IMAGE_NAME"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build the image
# Use --platform for Apple Silicon Macs (Terminal-Bench runs on linux/amd64)
if [[ "$(uname -m)" == "arm64" ]]; then
    echo "Detected Apple Silicon, building for linux/amd64..."
    docker build \
        --platform linux/amd64 \
        -t "$IMAGE_NAME" \
        -f "$SCRIPT_DIR/Dockerfile" \
        "$SCRIPT_DIR"
else
    docker build \
        -t "$IMAGE_NAME" \
        -f "$SCRIPT_DIR/Dockerfile" \
        "$SCRIPT_DIR"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Build Complete!"
echo ""
echo "Image: $IMAGE_NAME"
echo ""
echo "To test interactively:"
echo "  docker run -it $IMAGE_NAME bash"
echo ""
echo "To use with Harbor, specify the image in your config:"
echo "  environment:"
echo "    type: docker"
echo "    image: $IMAGE_NAME"
echo "════════════════════════════════════════════════════════════════"
