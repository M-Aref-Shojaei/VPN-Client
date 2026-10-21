#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Apple libbox must be built on macOS with Xcode installed." >&2
  exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${SING_BOX_VERSION:-1.13.14}"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

git clone --depth 1 --branch "v${version}" \
  https://github.com/SagerNet/sing-box.git \
  "${work_dir}/sing-box"

(
  cd "${work_dir}/sing-box"
  go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.12
  go install github.com/sagernet/gomobile/cmd/gobind@v0.1.12
  gomobile init
  go run ./cmd/internal/build_libbox -target apple
)

rm -rf "${project_root}/app/apple/Libbox.xcframework"
install -d "${project_root}/app/apple"
cp -R \
  "${work_dir}/sing-box/Libbox.xcframework" \
  "${project_root}/app/apple/Libbox.xcframework"

echo "Pinned libbox Apple framework built."
