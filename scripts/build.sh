#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
REMOTE_URL="${LOGOS_CORE_REMOTE_URL:-https://github.com/logos-co/logos-core-poc.git}"
REMOTE_REF="${LOGOS_CORE_REMOTE_REF:-}"
REMOTE_DIR="${LOGOS_CORE_REMOTE_DIR:-${REPO_ROOT}/.deps/logos-core-poc}"
REMOTE_UPDATE=1

USE_LOCAL=0
SKIP_BUILD=0
CLEAN_BUILD=0
CONFIG_ARGS=()

while (($#)); do
    case "$1" in
        --use-local)
            USE_LOCAL=1
            ;;
        --clean)
            CLEAN_BUILD=1
            ;;
        --configure-only)
            SKIP_BUILD=1
            ;;
        --skip-build)
            SKIP_BUILD=1
            ;;
        --remote-url)
            shift
            if [ $# -eq 0 ]; then
                echo "[build.sh] --remote-url requires a value" >&2
                exit 1
            fi
            REMOTE_URL="$1"
            ;;
        --remote-ref)
            shift
            if [ $# -eq 0 ]; then
                echo "[build.sh] --remote-ref requires a value" >&2
                exit 1
            fi
            REMOTE_REF="$1"
            ;;
        --remote-dir)
            shift
            if [ $# -eq 0 ]; then
                echo "[build.sh] --remote-dir requires a value" >&2
                exit 1
            fi
            REMOTE_DIR="$1"
            ;;
        --no-remote-update)
            REMOTE_UPDATE=0
            ;;
        --help|-h)
            cat <<'USAGE'
Usage: scripts/build.sh [options] [CMake configure args]

Options:
  --use-local       Use local symlinks (same as running local.sh first).
  --clean           Remove the build directory before configuring.
  --skip-build      Configure only; skip the build step.
  --configure-only  Alias for --skip-build.
  --remote-url URL  Override the remote Logos Core repository URL.
  --remote-ref REF  Checkout a specific branch or tag from the remote repository.
  --remote-dir DIR  Directory where the remote repository should be cloned (default: .deps/logos-core-poc).
  --no-remote-update  Skip updating an existing remote checkout.
  -h, --help        Show this message.

All remaining arguments are passed to `cmake -S . -B build`.
Set LOGOS_VENDOR_MODE=local in the environment as an alternative to --use-local.
Set LOGOS_VENDOR_MODE=remote to force remote checkout explicitly.
USAGE
            exit 0
            ;;
        *)
            CONFIG_ARGS+=("$1")
            ;;
    esac
    shift
done

if [ "${LOGOS_VENDOR_MODE:-}" = "local" ]; then
    USE_LOCAL=1
elif [ "${LOGOS_VENDOR_MODE:-}" = "remote" ]; then
    USE_LOCAL=0
fi

ensure_remote_checkout() {
    if ! command -v git >/dev/null 2>&1; then
        echo "[build.sh] git is required to fetch remote dependencies." >&2
        exit 1
    fi

    local clone_dir="${REMOTE_DIR}"

    if [[ "${clone_dir}" != /* ]]; then
        clone_dir="${REPO_ROOT}/${clone_dir}"
    fi

    if [ -e "${clone_dir}" ] && [ ! -d "${clone_dir}" ]; then
        rm -rf "${clone_dir}"
    fi

    mkdir -p "$(dirname "${clone_dir}")"
    clone_dir="$(cd "$(dirname "${clone_dir}")" && pwd)/$(basename "${clone_dir}")"

    if [ ! -d "${clone_dir}/.git" ]; then
        echo "[build.sh] Cloning Logos Core from ${REMOTE_URL}"
        rm -rf "${clone_dir}"
        git clone "${REMOTE_URL}" "${clone_dir}"
        if [ -n "${REMOTE_REF}" ]; then
            if ! git -C "${clone_dir}" checkout "${REMOTE_REF}" >/dev/null 2>&1; then
                git -C "${clone_dir}" checkout -b "${REMOTE_REF}" "origin/${REMOTE_REF}"
            fi
        fi
    elif [ "${REMOTE_UPDATE}" -eq 1 ]; then
        echo "[build.sh] Updating Logos Core checkout"
        if [ -n "${REMOTE_REF}" ]; then
            git -C "${clone_dir}" fetch origin "${REMOTE_REF}"
        else
            git -C "${clone_dir}" fetch origin
        fi
        if [ -n "${REMOTE_REF}" ]; then
            if ! git -C "${clone_dir}" checkout "${REMOTE_REF}" >/dev/null 2>&1; then
                git -C "${clone_dir}" checkout -B "${REMOTE_REF}" "origin/${REMOTE_REF}"
            fi
            git -C "${clone_dir}" reset --hard "origin/${REMOTE_REF}"
        else
            git -C "${clone_dir}" pull --ff-only
        fi
    fi

    local resolved_clone
    resolved_clone="$(cd "${clone_dir}" && pwd)"
    LOGOS_CORE_ROOT="${resolved_clone}" "${SCRIPT_DIR}/local.sh"
}

if [ "${USE_LOCAL}" -eq 1 ]; then
    "${SCRIPT_DIR}/local.sh"
else
    ensure_remote_checkout
fi

if [ "${CLEAN_BUILD}" -eq 1 ] && [ -d "${BUILD_DIR}" ]; then
    echo "[build.sh] Removing existing build directory"
    rm -rf "${BUILD_DIR}"
fi

if [ "${#CONFIG_ARGS[@]}" -gt 0 ]; then
    cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" "${CONFIG_ARGS[@]}"
else
    cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}"
fi

if [ "${SKIP_BUILD}" -eq 0 ]; then
    cmake --build "${BUILD_DIR}"
fi
