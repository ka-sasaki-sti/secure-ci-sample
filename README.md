# secure-ci-sample

[![ci](https://github.com/ka-sasaki-sti/secure-ci-sample/actions/workflows/ci.yml/badge.svg)](https://github.com/ka-sasaki-sti/secure-ci-sample/actions/workflows/ci.yml)
[![security](https://github.com/ka-sasaki-sti/secure-ci-sample/actions/workflows/security.yml/badge.svg)](https://github.com/ka-sasaki-sti/secure-ci-sample/actions/workflows/security.yml)
[![build](https://github.com/ka-sasaki-sti/secure-ci-sample/actions/workflows/build.yml/badge.svg)](https://github.com/ka-sasaki-sti/secure-ci-sample/actions/workflows/build.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/ka-sasaki-sti/secure-ci-sample/badge)](https://scorecard.dev/viewer/?uri=github.com/ka-sasaki-sti/secure-ci-sample)

FastAPI の小さな ToDo API に、**GitHub の無料機能と OSS だけ**でセキュリティ CI を組んだサンプルです。
公開リポジトリであれば、ここにあるものはすべて追加費用なしで動きます。

## 何を入れているか

| タイミング | ワークフロー | 内容 |
|---|---|---|
| PR / main | [`ci.yml`](.github/workflows/ci.yml) | テスト・リント（`uv sync --locked` でロックファイルどおりに入れる） |
| PR / main | [`security.yml`](.github/workflows/security.yml) | gitleaks（秘密情報）/ Semgrep（危険なコード＋独自ルール）/ Trivy（依存・設定ミス）/ zizmor（ワークフロー自体）/ Dependency Review |
| PR / main / 週次 | [`codeql.yml`](.github/workflows/codeql.yml) | CodeQL（Python と GitHub Actions） |
| PR / main / 毎日 | [`build.yml`](.github/workflows/build.yml) | イメージのビルド → Trivy → 起動して露出チェックと ZAP（DAST）→ main のみ GHCR へ push、出所証明と SBOM を署名つきで添付 |
| 毎晩 | [`nightly.yml`](.github/workflows/nightly.yml) | 公開中イメージの出所検証と再スキャン / 依存先の新着 CISA KEV / Python の EOL → Issue を起票 |
| 週次 / main | [`scorecard.yml`](.github/workflows/scorecard.yml) | OpenSSF Scorecard |
| Dependabot の PR | [`dependabot-automerge.yml`](.github/workflows/dependabot-automerge.yml) | patch 更新はチェックが通れば自動マージ |

### 何で CI を止めるか

[`scripts/vuln-gate.sh`](scripts/vuln-gate.sh) が Trivy の結果を読み、次の場合だけ失敗させます。

1. **CISA KEV**（実際に悪用が確認された脆弱性）に載っている — 修正版がなくても止める
2. **CRITICAL かつ修正版がある** — 直せるのに直していない
3. **HIGH 以上の設定ミス**、または**秘密情報**

それ以外は Security タブ（SARIF）・Dependabot・nightly の Issue で追います。

### サプライチェーン対策

- Action はすべて**コミット SHA で固定**（タグは書き換えられる）
- スキャナーのコンテナも**digest で固定**し、[`ci/scanners/Dockerfile`](ci/scanners/Dockerfile) に集約して Dependabot に更新させる
- Dependabot の通常更新は **7日寝かせる**（cooldown）。セキュリティ更新は即 PR
- ワークフローの権限は既定で `contents: read`。書き込みはジョブ単位で付与

## イメージの検証

```bash
gh attestation verify oci://ghcr.io/ka-sasaki-sti/secure-ci-sample:main \
  --repo ka-sasaki-sti/secure-ci-sample
```

## ローカルで動かす

```bash
uv sync
uv run pytest
uv run uvicorn app.main:app --reload
```
