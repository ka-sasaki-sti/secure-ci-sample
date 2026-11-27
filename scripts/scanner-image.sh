#!/usr/bin/env bash
# .github/scanners/Dockerfile から、名前（AS の後ろ）に対応するイメージ参照を返す。
# usage: scripts/scanner-image.sh trivy
set -euo pipefail
name="${1:?usage: $0 <name>}"
ref=$(awk -v n="$name" '$1 == "FROM" && $3 == "AS" && $4 == n { print $2 }' \
  "$(dirname "$0")/../.github/scanners/Dockerfile")
if [[ -z "$ref" || "$ref" != *@sha256:* ]]; then
  echo "scanner '$name' が見つからないか、digest で固定されていません" >&2
  exit 1
fi
echo "$ref"
