# AGENTS.md

## プロジェクトルール

### コマンド実行規則
- **必須**: すべての Python および Sceptre コマンドは `uv run` プレフィックスを付与してください。
- **Sceptre コマンドは必ず sceptre ディレクトリで実行してください。**
  - コマンド実行前に現在のディレクトリが sceptre か確認してください。
  - sceptre ディレクトリ外の場合は `cd sceptre` で移動してください。
  - sceptre ディレクトリ内の場合はそのままコマンドを実行してください。
  - sceptre は現在の作業ディレクトリで `config` ディレクトリを探します。
- Sceptre リソース変更系コマンド (create/update/delete/launch) には **必ず** `--yes` フラグを追加してください。
- Sceptre 読み取り専用コマンド (validate/status/describe/list/dump) には `--yes` フラグを**使用しないでください**。
- **コマンド例**:
  - プロジェクトルートから: `cd sceptre; uv run sceptre launch stack --yes`
  - sceptre ディレクトリから: `uv run sceptre launch stack --yes`
- 生の `python` や `sceptre` コマンドは絶対に使用しないでください。

### 言語ポリシー
- **日本語**: `.md` ファイルのみ日本語で記載してください。
- **英語**: `.yaml`, `.yml`, `.py`, `.json`, `.sh`, `.ps1` ファイルは英語のみで記載してください。
- CloudFormation テンプレートおよび Sceptre 設定は英語のみで記載してください。
