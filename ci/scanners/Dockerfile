# CI で使うスキャナーのコンテナイメージ一覧（このファイルでビルドはしない）。
#
# ワークフローに直接 image@sha256 を書くと Dependabot が更新してくれないため、
# Dockerfile 形式でここに集約し、Dependabot（docker）にタグと digest を更新させる。
# ワークフローからは scripts/scanner-image.sh <名前> で参照する。
#
# 2026年3月に Trivy の GitHub Action と Docker イメージが改ざんされた件を受けて、
# スキャナー自身もタグではなく digest で固定している。

FROM aquasec/trivy:0.76.2@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb AS trivy
FROM ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f AS gitleaks
FROM semgrep/semgrep:1.186.0@sha256:6e1b04340e60e910fbb4ddbf3c857ab0918f064417ad5ac530014ccb3cf8c8f1 AS semgrep
FROM ghcr.io/zizmorcore/zizmor:1.32.0@sha256:3014cc8f68f663935f69b3c3e0e41f5ce102b268d97db13db0f62208747f860d AS zizmor
# ZAP は版番号つきタグの更新が遅いため stable を digest で固定（四半期ごとに手動で見直す）
FROM ghcr.io/zaproxy/zaproxy:stable@sha256:9624669db72f54d86c4b46a7064518bd9bf79d8c61a4c31befa9923489f328af AS zap
