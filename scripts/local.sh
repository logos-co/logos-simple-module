#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_CORE_ROOT="${REPO_ROOT}/../logos-core-poc"
CORE_ROOT="${LOGOS_CORE_ROOT:-${DEFAULT_CORE_ROOT}}"

if [ ! -d "${CORE_ROOT}" ]; then
    echo "[local.sh] LOGOS_CORE_ROOT '${CORE_ROOT}' does not exist." >&2
    echo "Set LOGOS_CORE_ROOT to the logos-core checkout or place it at '../logos-core-poc'." >&2
    exit 1
fi

CORE_ROOT="$(cd "${CORE_ROOT}" && pwd)"

LINK_TARGETS=(
    "vendor/LogosCore|${CORE_ROOT}/core"
    "vendor/LogosSDK|${CORE_ROOT}/SDK/cpp"
    "vendor/LogosCppGenerator|${CORE_ROOT}/SDK/cpp-generator"
    "vendor/SDK|${CORE_ROOT}/SDK"
)

create_link() {
    local link_path="$1"
    local target_path="$2"
    local abs_link_path="${REPO_ROOT}/${link_path}"

    mkdir -p "$(dirname "${abs_link_path}")"

    if [ -L "${abs_link_path}" ]; then
        local current
        current="$(readlink "${abs_link_path}")"
        if [ "${current}" = "${target_path}" ]; then
            echo "[local.sh] ${link_path} already points to ${target_path}"
            return
        fi
        rm "${abs_link_path}"
    elif [ -e "${abs_link_path}" ]; then
        rm -rf "${abs_link_path}"
    fi

    ln -s "${target_path}" "${abs_link_path}"
    echo "[local.sh] Linked ${link_path} -> ${target_path}"
}

for entry in "${LINK_TARGETS[@]}"; do
    link="${entry%%|*}"
    target="${entry#*|}"
    create_link "${link}" "${target}"
done

# Ensure nested SDK links exist when vendor/SDK is not a directory symlink
if [ ! -L "${REPO_ROOT}/vendor/SDK" ]; then
    SDK_LINKS=(
        "vendor/SDK/cpp|${CORE_ROOT}/SDK/cpp"
        "vendor/SDK/cpp-generator|${CORE_ROOT}/SDK/cpp-generator"
    )
    for entry in "${SDK_LINKS[@]}"; do
        link="${entry%%|*}"
        target="${entry#*|}"
        create_link "${link}" "${target}"
    done
fi

echo "[local.sh] Local vendor links ready."
