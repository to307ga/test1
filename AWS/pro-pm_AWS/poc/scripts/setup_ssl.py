#!/usr/bin/env python3
"""
SSL設定自動配置スクリプト

企業環境でのSSL証明書問題を解決するため、
仮想環境にsitecustomize.pyを自動配置します。
"""
import os
import sys
from pathlib import Path

def create_sitecustomize():
    """SSL設定用のsitecustomize.pyを仮想環境に配置"""

    # 仮想環境のsite-packagesディレクトリを取得
    site_packages = Path(sys.executable).parent.parent / "Lib" / "site-packages"

    if not site_packages.exists():
        print(f"❌ site-packagesディレクトリが見つかりません: {site_packages}")
        return False

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

# Sceptre/Pythonライブラリの廃止警告を無効化
warnings.filterwarnings('ignore', category=DeprecationWarning)
warnings.filterwarnings('ignore', message='.*is deprecated.*')

# 環境変数も設定
os.environ['PYTHONHTTPSVERIFY'] = '0'
os.environ['CURL_CA_BUNDLE'] = ''
os.environ['REQUESTS_CA_BUNDLE'] = ''
'''

    sitecustomize_path = site_packages / "sitecustomize.py"

    try:
        sitecustomize_path.write_text(sitecustomize_content, encoding='utf-8')
        print(f"✅ SSL設定ファイルを作成しました: {sitecustomize_path}")
        return True
    except Exception as e:
        print(f"❌ SSL設定ファイルの作成に失敗しました: {e}")
        return False

def main():
    """メイン実行関数"""
    print("企業環境SSL設定セットアップを開始します...")

    # 仮想環境内での実行確認
    if not hasattr(sys, 'real_prefix') and not (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        print("⚠️  仮想環境内で実行してください")
        print("実行例: uv run python scripts/setup_ssl.py")
        return False

    print(f"仮想環境: {sys.prefix}")

    success = create_sitecustomize()

    if success:
        print("\n🎉 セットアップ完了！")
        print("次回から 'uv run sceptre' コマンドでSSL証明書エラーが発生しません。")

    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
