#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_version="${FLUTTER_VERSION:-3.44.5}"
flutter_root="${HOME}/.local/share/flutter-${flutter_version}"

if ! command -v go >/dev/null 2>&1; then
  echo "Go is required by core/go.mod but is not installed." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  if [[ ! -x "${flutter_root}/bin/flutter" ]]; then
    archive="/tmp/flutter-linux-${flutter_version}.tar.xz"
    storage_base="${FLUTTER_STORAGE_BASE_URL:-https://storage.googleapis.com}"
    curl --fail --location --retry 3 \
      "${storage_base}/flutter_infra_release/releases/stable/linux/flutter_linux_${flutter_version}-stable.tar.xz" \
      --output "${archive}"
    mkdir -p "$(dirname "${flutter_root}")"
    tar -xf "${archive}" -C "$(dirname "${flutter_root}")"
    mv "$(dirname "${flutter_root}")/flutter" "${flutter_root}"
  fi
fi

export PATH="${flutter_root}/bin:${PATH}"
if [[ -x "${flutter_root}/bin/flutter" ]]; then
  mkdir -p "${HOME}/.local/bin"
  ln -sfn "${flutter_root}/bin/flutter" "${HOME}/.local/bin/flutter"
  ln -sfn "${flutter_root}/bin/dart" "${HOME}/.local/bin/dart"
fi

(cd "${project_root}/core" && go mod download)
(cd "${project_root}/app" && flutter pub get)

echo "Codex environment setup complete."
echo "Flutter is available through ${HOME}/.local/bin for later tasks."
