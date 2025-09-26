#!/usr/bin/env python3
"""
BYODKIM登録スクリプト - 確実な動作版
"""

import boto3
import re
import os

# SSL証明書検証無効化
os.environ['PYTHONHTTPSVERIFY'] = '0'

# AWS クライアント
sesv2 = boto3.client('sesv2', region_name='ap-northeast-1', verify=False)
s3 = boto3.client('s3', region_name='ap-northeast-1', verify=False)

def get_s3_private_key():
    """S3からDKIM私鍵を取得"""
    try:
        response = s3.get_object(
            Bucket='aws-ses-migration-prod-dkim-certificates',
            Key='private_keys/goo.ne.jp/gooid-21-pro-20250912-1/private_key_20250912_030712.pem'
        )
        return response['Body'].read().decode('utf-8')
    except Exception as e:
        print(f"S3エラー: {e}")
        return None

def convert_pem_to_base64(pem_content):
    """PEMからBase64 DERに変換"""
    # \n文字列を実際の改行に置換
    pem_content = pem_content.replace('\\n', '\n')

    # PEMヘッダー・フッターを除去
    base64_content = re.sub(r'-----BEGIN PRIVATE KEY-----\n?', '', pem_content)
    base64_content = re.sub(r'\n?-----END PRIVATE KEY-----', '', base64_content)

    # 改行とスペースを除去
    base64_content = re.sub(r'\s', '', base64_content)

    return base64_content

def main():
    """メイン処理"""
    print("=== BYODKIM登録スクリプト開始 ===")

    # S3から私鍵を取得
    pem_content = get_s3_private_key()
    if not pem_content:
        print("❌ S3から私鍵を取得できませんでした")
        return

    print(f"✅ S3から私鍵取得成功: {len(pem_content)} characters")
    print(f"内容プレビュー: {pem_content[:50]}...")

    # Base64に変換
    private_key_base64 = convert_pem_to_base64(pem_content)
    print(f"✅ Base64変換完了: {len(private_key_base64)} characters")
    print(f"Base64プレビュー: {private_key_base64[:50]}...")

    # 正規表現チェック
    pattern = r'^[a-zA-Z0-9+/]+={0,2}$'
    if not re.match(pattern, private_key_base64):
        print("❌ Base64形式が正規表現に適合しません")
        print(f"不正文字を確認: {repr(private_key_base64[:100])}")
        return

    print("✅ Base64形式が正規表現に適合しています")

    # BYODKIM登録実行
    try:
        print("🚀 BYODKIM登録を実行中...")

        response = sesv2.put_email_identity_dkim_signing_attributes(
            EmailIdentity='goo.ne.jp',
            SigningAttributesOrigin='EXTERNAL',
            SigningAttributes={
                'DomainSigningSelector': 'gooid-21-pro-20250912-1',
                'DomainSigningPrivateKey': private_key_base64
            }
        )

        print("✅ BYODKIM登録成功！")

        # DKIM有効化
        enable_response = sesv2.put_email_identity_dkim_attributes(
            EmailIdentity='goo.ne.jp',
            SigningEnabled=True
        )

        print("✅ DKIM署名有効化成功！")

        # 結果確認
        verify_response = sesv2.get_email_identity(EmailIdentity='goo.ne.jp')
        dkim_attrs = verify_response['DkimAttributes']

        print(f"\n📋 最終結果:")
        print(f"SigningAttributesOrigin: {dkim_attrs['SigningAttributesOrigin']}")
        print(f"SigningEnabled: {dkim_attrs['SigningEnabled']}")
        print(f"Status: {dkim_attrs['Status']}")

        if dkim_attrs['SigningAttributesOrigin'] == 'EXTERNAL':
            print("🎉 BYODKIM登録が正常に完了しました！")
        else:
            print("⚠️ SigningAttributesOriginがEXTERNALではありません")

    except Exception as e:
        print(f"❌ BYODKIM登録エラー: {str(e)}")

if __name__ == "__main__":
    main()
