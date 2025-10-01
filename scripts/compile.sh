#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build}"

cmake -S "$REPO_ROOT" -B "$BUILD_DIR" "$@"
cmake --build "$BUILD_DIR"
