# SSL証明書問題解消方法

## 問題の概要

企業環境でPythonからAWS APIにHTTPS接続する際に発生するSSL証明書検証エラーを解決する方法について説明します。

```
"SSL validation failed for https://cloudformation.ap-northeast-1.amazonaws.com/ 
[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1028)"
```

## 根本原因

企業環境では以下の要因でSSL証明書の検証が失敗します：

1. **プロキシサーバー**: 企業のプロキシが独自の証明書を挿入
2. **ファイアウォール**: SSL/TLSインスペクション機能
3. **証明書ストア**: システムの証明書ストアが企業用にカスタマイズされている
4. **中間証明書**: 必要な中間証明書が不足

## 解決方法

### 1. sitecustomize.py による根本的解決（推奨）

**⚠️ 重要**: `.venv`ディレクトリはgitで管理されないため、プロジェクトのセットアップ時に自動配置する仕組みが必要です。

#### 手動配置方法
**場所**: `.venv\Lib\site-packages\sitecustomize.py`

```bash
# プロジェクトセットアップ手順
git clone <repository>
cd <project>
uv sync
# この後、以下のファイルを手動作成
```

#### 自動配置方法（推奨）

**A. setupスクリプトを使用**

`scripts/setup_ssl.py` を作成：
```python
#!/usr/bin/env python3
import os
import sys
from pathlib import Path

def create_sitecustomize():
    """SSL設定用のsitecustomize.pyを仮想環境に配置"""
    
    # 仮想環境のsite-packagesディレクトリを取得
    site_packages = Path(sys.executable).parent.parent / "Lib" / "site-packages"
    
    sitecustomize_content = '''import ssl
import urllib3
import warnings
import os

# SSL検証を無効化
ssl._create_default_https_context = ssl._create_unverified_context

# urllib3の警告を無効化
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# SSL関連の警告を無効化
warnings.filterwarnings('ignore', message='Unverified HTTPS request')

# 環境変数も設定
os.environ['PYTHONHTTPSVERIFY'] = '0'
os.environ['CURL_CA_BUNDLE'] = ''
os.environ['REQUESTS_CA_BUNDLE'] = ''
'''
    
    sitecustomize_path = site_packages / "sitecustomize.py"
    
    try:
        sitecustomize_path.write_text(sitecustomize_content, encoding='utf-8')
        print(f"✅ SSL設定ファイルを作成しました: {sitecustomize_path}")
    except Exception as e:
        print(f"❌ SSL設定ファイルの作成に失敗しました: {e}")

if __name__ == "__main__":
    create_sitecustomize()
```

**B. uv run で直接実行**
```bash
# プロジェクトセットアップ完全版
git clone <repository>
cd <project>
uv sync                              # 仮想環境自動作成 + 依存関係インストール
uv run python scripts/setup_ssl.py  # SSL設定自動配置
```

#### `uv sync`の効果
- **仮想環境の自動作成**: `.venv`ディレクトリが自動生成される
- **依存関係の完全復元**: `pyproject.toml`と`uv.lock`から正確なバージョンで依存関係をインストール
- **クロスプラットフォーム対応**: Windows/Linux/macOSで同じ環境を再現
- **高速インストール**: 並列処理とキャッシュにより従来のpipより高速

#### `uv run`の利点
- **手動activate不要**: `.venv/Scripts/activate`を実行する必要がない
- **自動環境検出**: uvが自動的に`.venv`環境を検出・使用
- **子プロセス対応**: subprocess等で起動される子プロセスでも正しく動作
- **一貫したコマンド**: プラットフォーム問わず同じコマンドで実行可能

**新規参加者の体験**: 上記4行のコマンドだけで、手動でのactivateや環境変数設定なしに、直接`uv run sceptre`等のコマンドが使用可能になります。

**C. マニュアル設定（代替方法）**
直接ファイルを作成する場合：
```bash
# sitecustomize.pyを手動作成
# 場所: .venv/Lib/site-packages/sitecustomize.py
```

```python
import ssl
import urllib3
import warnings
import os

# SSL検証を無効化
ssl._create_default_https_context = ssl._create_unverified_context

# urllib3の警告を無効化
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# SSL関連の警告を無効化
warnings.filterwarnings('ignore', message='Unverified HTTPS request')

# 環境変数も設定
os.environ['PYTHONHTTPSVERIFY'] = '0'
os.environ['CURL_CA_BUNDLE'] = ''
os.environ['REQUESTS_CA_BUNDLE'] = ''
```

**特徴**:
- ✅ Pythonプロセス起動時に自動実行
- ✅ uvコマンド、pytest、すべてのPythonスクリプトに適用
- ✅ ユーザーが意識する必要なし
- ✅ git bashでもPowerShellでも有効

### 2. 仮想環境のactivateスクリプト修正（補助的）

#### PowerShell用: `.venv\Scripts\Activate.ps1`

ファイル末尾に追加：
```powershell
# SSL verification workaround for corporate environment
$env:PYTHONHTTPSVERIFY = "0"
$env:CURL_CA_BUNDLE = ""
$env:REQUESTS_CA_BUNDLE = ""
$env:PYTHONWARNINGS = "ignore:Unverified HTTPS request"
```

#### Bash用: `.venv\Scripts\activate`

ファイル末尾に追加：
```bash
# SSL verification workaround for corporate environment
export PYTHONHTTPSVERIFY=0
export CURL_CA_BUNDLE=""
export REQUESTS_CA_BUNDLE=""
export PYTHONWARNINGS="ignore:Unverified HTTPS request"
```

### 3. プロジェクト設定ファイル

#### `.env` ファイル
```env
PYTHONWARNINGS=ignore
PYTHONHTTPSVERIFY=0
CURL_CA_BUNDLE=
REQUESTS_CA_BUNDLE=
SSL_VERIFY=false
```

#### `pyproject.toml`
```toml
[tool.uv]
env = [
    "PYTHONHTTPSVERIFY=0",
    "CURL_CA_BUNDLE=",
    "REQUESTS_CA_BUNDLE=",
    "PYTHONWARNINGS=ignore:Unverified HTTPS request",
]
```

## 効果的な理由

### sitecustomize.pyが最も効果的な理由

1. **Pythonの起動プロセス**: 
   - sitecustomize.pyはPythonインタープリター起動時に自動実行される
   - すべてのモジュールimport前に実行されるため、ssl設定が確実に適用される

2. **uv runコマンドとの相性**:
   - uvは新しいPythonプロセスを起動する
   - 環境変数だけでは子プロセスに継承されない場合がある
   - sitecustomize.pyは各Pythonプロセスで確実に実行される

3. **包括的な対応**:
   - ssl._create_default_https_context の変更でPython標準ライブラリレベルで解決
   - urllib3の警告抑制でboto3、requests等の外部ライブラリに対応
   - 環境変数設定で古いライブラリにも対応

## 検証方法

### 1. 基本的なSSL接続テスト
```bash
uv run python -c "import boto3; boto3.client('cloudformation').list_stacks(); print('SSL connection successful!')"
```

### 2. 環境変数の確認
```bash
uv run python -c "import os; print('PYTHONHTTPSVERIFY:', os.environ.get('PYTHONHTTPSVERIFY'))"
```

### 3. sceptreコマンドの動作確認
```bash
uv run sceptre --help
uv run sceptre status dev
```

## トラブルシューティング

### 症状: 環境変数が設定されていない
**原因**: .envファイルやpyproject.tomlの設定だけでは不十分
**解決**: sitecustomize.pyを作成する

### 症状: git bashで効かない
**原因**: PowerShell用のActivate.ps1しか修正していない
**解決**: bashの`activate`スクリプトも修正する

### 症状: 子プロセスで効かない
**原因**: uvや subprocess で起動される子プロセスに環境変数が継承されない
**解決**: sitecustomize.pyでPythonレベルで設定する

## セキュリティに関する注意

- **開発環境専用**: この設定は開発環境でのみ使用する
- **本番環境では使用禁止**: SSL検証を無効化するため、本番環境では絶対に使用しない
- **企業ポリシー確認**: 企業のセキュリティポリシーに従って実装する

## まとめ

SSL証明書問題の解決には **sitecustomize.py** を使用するのが最も確実で包括的な方法です。この方法により：

- ✅ uv run sceptre が直接使用可能
- ✅ git bash、PowerShell両方で動作
- ✅ すべてのPythonスクリプトで自動適用
- ✅ 追加のコマンドライン引数不要
- ✅ 環境変数設定の煩わしさなし

企業環境でのPython開発において、この設定により生産性が大幅に向上します。
