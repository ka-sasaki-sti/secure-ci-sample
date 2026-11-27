#!/usr/bin/env bash
# Trivy の JSON を読み、「止めるべきもの」だけで CI を落とす。
#
#   ① CISA KEV（実際に悪用が確認された脆弱性）に載っている  → 修正版がなくても止める
#   ② CRITICAL かつ修正版がある                             → 止める（直せるのに直していない）
#   ③ HIGH 以上の設定ミス / 秘密情報                         → 止める
#
# それ以外（HIGH の脆弱性など）は SARIF として Security タブに出し、Dependabot と nightly で追う。
#
# usage: scripts/vuln-gate.sh trivy-*.json
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: $0 trivy-result.json..." >&2
  exit 2
fi

KEV_URL="${KEV_URL:-https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# KEV が取れなければ失敗させる（黙って通さない）
curl -fsSL --retry 3 "$KEV_URL" -o "$work/kev.json"
jq -r '.vulnerabilities[].cveID' "$work/kev.json" | LC_ALL=C sort -u > "$work/kev.txt"

jq -rs '[.[] | .Results[]?.Vulnerabilities[]?.VulnerabilityID] | .[]' "$@" \
  | LC_ALL=C sort -u > "$work/found.txt"

status=0
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"

# ① KEV
LC_ALL=C comm -12 "$work/kev.txt" "$work/found.txt" > "$work/kev-hits.txt"
if [[ -s "$work/kev-hits.txt" ]]; then
  echo "::error::CISA KEV（悪用確認済み）の脆弱性を検出しました"
  echo "### ❌ CISA KEV に載っている脆弱性" >> "$summary"
  while read -r cve; do
    jq -r --arg c "$cve" '.vulnerabilities[] | select(.cveID == $c)
      | "- \(.cveID)  \(.vendorProject) / \(.product)  KEV追加日=\(.dateAdded)"' "$work/kev.json" \
      | tee -a "$summary"
  done < "$work/kev-hits.txt"
  status=1
fi

# ② CRITICAL かつ修正版あり
jq -rs '[.[] | .Results[]? | .Target as $t | .Vulnerabilities[]?
        | select(.Severity == "CRITICAL" and (.FixedVersion // "") != "")
        | "- \(.VulnerabilityID)  \(.PkgName) \(.InstalledVersion) -> \(.FixedVersion)  (\($t))"]
        | unique[]' "$@" > "$work/critical.txt"
if [[ -s "$work/critical.txt" ]]; then
  echo "::error::修正版のある CRITICAL 脆弱性を検出しました"
  { echo "### ❌ 修正版のある CRITICAL 脆弱性"; cat "$work/critical.txt"; } >> "$summary"
  cat "$work/critical.txt"
  status=1
fi

# ③ 設定ミス（HIGH 以上）と秘密情報
jq -rs '[.[] | .Results[]? | .Target as $t
        | ( .Misconfigurations[]? | select(.Status == "FAIL" and (.Severity == "HIGH" or .Severity == "CRITICAL"))
            | "- [misconfig] \(.ID) \(.Title)  (\($t))" ),
          ( .Secrets[]? | "- [secret] \(.RuleID)  \($t):\(.StartLine)" )]
        | unique[]' "$@" > "$work/config.txt"
if [[ -s "$work/config.txt" ]]; then
  echo "::error::重大な設定ミスまたは秘密情報を検出しました"
  { echo "### ❌ 重大な設定ミス / 秘密情報"; cat "$work/config.txt"; } >> "$summary"
  cat "$work/config.txt"
  status=1
fi

if [[ $status -eq 0 ]]; then
  total=$(wc -l < "$work/found.txt")
  echo "gate passed（検出 CVE ${total} 件。止める条件に該当なし）"
  echo "### ✅ gate passed（検出 CVE ${total} 件。止める条件に該当なし）" >> "$summary"
fi
exit "$status"
