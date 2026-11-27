#!/usr/bin/env bash
# 外部から到達できてはいけないパスが、本当に閉じているかを外から叩いて確かめる。
# Drupal の install.php や公開ダッシュボードのように「そこにあること自体」が問題のものは、
# コードを読んでも見つからないので、動いているものに対して確認する。
#
# usage: scripts/exposure-check.sh http://localhost:8000
set -euo pipefail
TARGET="${1:?usage: $0 <base-url>}"

paths=(
  /docs /redoc /openapi.json          # API ドキュメント（本番では無効にしている）
  /install.php /core/install.php      # インストーラ
  /admin /console /manage             # 管理画面
  /actuator /debug /phpinfo.php       # デバッグ・内部情報
  /.env /.git/config /server-status   # 置き忘れ
)

fail=0
for p in "${paths[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$TARGET$p" || true)
  if [[ "$code" =~ ^2 ]]; then
    echo "::error::$p が到達可能です（HTTP $code）"
    fail=1
  else
    echo "ok  $p -> $code"
  fi
done

# サーバーのソフトウェア名・バージョンを返していないか
if curl -sI --max-time 10 "$TARGET/healthz" | grep -qi '^server:'; then
  echo "::error::Server ヘッダーでソフトウェア名を返しています"
  fail=1
fi
exit "$fail"
