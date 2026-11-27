#!/usr/bin/env bash
# 同じタイトルの Issue が開いていればコメントを足し、なければ新規に起票する（毎晩同じ Issue が増えないように）。
# usage: scripts/open-issue.sh <title> <label> <body-file>
set -euo pipefail
title="$1" label="$2" body="$3"
existing=$(gh issue list --state open --label "$label" --json number,title \
  --jq ".[] | select(.title == \"$title\") | .number" | head -1)
if [[ -n "$existing" ]]; then
  gh issue comment "$existing" --body-file "$body"
  echo "updated #$existing"
else
  gh issue create --title "$title" --label "$label" --body-file "$body"
fi
