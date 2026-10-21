#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${SING_BOX_VERSION:-1.13.14}"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
  echo "ANDROID_HOME or ANDROID_SDK_ROOT is required." >&2
  exit 1
fi
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "ANDROID_NDK_HOME is required." >&2
  exit 1
fi
if ! java --version 2>&1 | rg -q 'openjdk 17'; then
  echo "OpenJDK 17 is required by the pinned libbox build." >&2
  exit 1
fi

git clone --depth 1 --branch "v${version}" \
  https://github.com/SagerNet/sing-box.git \
  "${work_dir}/sing-box"

(
  cd "${work_dir}/sing-box"
  go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.12
  go install github.com/sagernet/gomobile/cmd/gobind@v0.1.12
  gomobile init
  go run ./cmd/internal/build_libbox -target android
)

install -d "${project_root}/app/android/app/libs"
install -m 0644 \
  "${work_dir}/sing-box/libbox.aar" \
  "${project_root}/app/android/app/libs/libbox.aar"
sha256sum "${project_root}/app/android/app/libs/libbox.aar" \
  > "${project_root}/app/android/app/libs/libbox.aar.sha256"

echo "Pinned libbox Android archive built and checksummed."
