import os
import re

def translate_readme(file_path):
    """README.mdファイルの日本語を英語に翻訳"""

    # 日本語→英語の対応辞書（よく使われるパターン）
    translations = {
        'Dev環境 デプロイ手順書': 'Dev Environment Deployment Guide',
        '概要': 'Overview',
        '開発・テスト環境用のAWS SESインフラストラクチャをデプロイするための手順書です。': 'A guide for deploying AWS SES infrastructure for development and testing environments.',
        '前提条件': 'Prerequisites',
        'デプロイメント手順': 'Deployment Procedure',
        'コンフィグ設定': 'Configuration Settings',
        '基本設定': 'Basic Configuration',
        'セキュリティ設定': 'Security Configuration',
        'モニタリング設定': 'Monitoring Configuration',
        'AWS認証情報の設定': 'AWS Credentials Configuration',
        'Sceptreツールのインストール': 'Sceptre Tool Installation',
        '環境別設定値': 'Environment-specific Configuration Values',
        'ドメイン名': 'Domain Name',
        'プロジェクトコード': 'Project Code',
        '環境名': 'Environment Name',
        'プロジェクト': 'Project',
        '管理者': 'Administrator',
        '読み取り専用': 'Read-only',
        'モニタリング': 'Monitoring',
        'ユーザー': 'User',
        'メール': 'Email',
        '電話番号': 'Phone Number',
        'スタック': 'Stack',
        'デプロイ': 'Deploy',
        'デプロイする': 'deploy',
        'デプロイされる': 'deployed',
        'デプロイ完了': 'Deployment Complete',
        'エラー': 'Error',
        'エラーが発生': 'An error occurred',
        '実行': 'Execute',
        '実行する': 'execute',
        '実行します': 'execute',
        '確認': 'Verify',
        '確認する': 'verify',
        '設定': 'Configuration',
        '設定する': 'configure',
        '設定値': 'Configuration value',
        '作成': 'Create',
        '作成する': 'create',
        '削除': 'Delete',
        '削除する': 'delete',
        '更新': 'Update',
        '更新する': 'update',
        '注意': 'Note',
        '重要': 'Important',
        '警告': 'Warning',
        '手順': 'Procedure',
        'ステップ': 'Step',
        'コマンド': 'Command',
        'ファイル': 'File',
        'フォルダ': 'Folder',
        'ディレクトリ': 'Directory',
        'パス': 'Path',
        'バージョン': 'Version',
        'タグ': 'Tag',
        'リソース': 'Resource',
        'サービス': 'Service',
        'コンポーネント': 'Component',
        'インフラストラクチャ': 'Infrastructure',
        'アカウント': 'Account',
        'アクセス': 'Access',
        'アクセス権': 'Access permissions',
        'ロール': 'Role',
        'ポリシー': 'Policy',
        'セキュリティ': 'Security',
        'ネットワーク': 'Network',
        'ログ': 'Log',
        'ログイン': 'Login',
        'ログアウト': 'Logout',
        'データ': 'Data',
        'バックアップ': 'Backup',
        'リストア': 'Restore',
        'テスト': 'Test',
        'テストする': 'test',
        '検証': 'Validation',
        '検証する': 'validate',
        '必要': 'Required',
        '必要な': 'required',
        '任意': 'Optional',
        '任意の': 'optional',
        '推奨': 'Recommended',
        '推奨する': 'recommend',
        '成功': 'Success',
        '成功した': 'successful',
        '失敗': 'Failed',
        '失敗した': 'failed',
        '完了': 'Complete',
        '完了した': 'completed',
        '開始': 'Start',
        '開始する': 'start',
        '停止': 'Stop',
        '停止する': 'stop',
        '継続': 'Continue',
        '継続する': 'continue',
        '中止': 'Cancel',
        '中止する': 'cancel',
    }

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 翻訳を適用
    for japanese, english in translations.items():
        content = content.replace(japanese, english)

    # より複雑なパターンを正規表現で処理
    # 例: 「～する」「～します」パターン
    content = re.sub(r'(\w+)します', r'\1', content)
    content = re.sub(r'(\w+)する', r'\1', content)

    # バックアップファイルを作成
    backup_path = file_path.replace('.md', '_backup.md')
    with open(backup_path, 'w', encoding='utf-8') as f:
        with open(file_path, 'r', encoding='utf-8') as orig:
            f.write(orig.read())

    # 翻訳済みファイルを保存
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f'Translated: {file_path}')
    print(f'Backup created: {backup_path}')

# READMEファイルを翻訳
readme_files = [
    'config/dev/README.md',
    'config/prod/README.md'
]

for file_path in readme_files:
    if os.path.exists(file_path):
        translate_readme(file_path)
    else:
        print(f'File not found: {file_path}')
