#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_root}"

unsafe_paths=(
  "binConfigs/config.json"
  "binConfigs/configPre.json"
  "guiConfigs/guiNConfig.json"
)

failed=0
for path in "${unsafe_paths[@]}"; do
  if git ls-files --error-unmatch "${path}" >/dev/null 2>&1; then
    echo "BLOCKED: credential-shaped runtime file is tracked: ${path}" >&2
    failed=1
  fi
done

if ((failed)); then
  echo "Create a clean repository history before connecting this project to Codex Cloud." >&2
  exit 1
fi

if git grep -IEn \
  '(vless|vmess|trojan|ss)://|"(uuid|password|private_key)"[[:space:]]*:[[:space:]]*"[^"]+"' \
  -- ':!docs/**' |
  rg -v '00000000-0000-0000-0000-000000000000|secret-credential' |
  rg -q '.'; then
  echo "BLOCKED: possible proxy credential found in tracked content." >&2
  exit 1
fi

echo "Tracked files passed the Codex Cloud safety check."
