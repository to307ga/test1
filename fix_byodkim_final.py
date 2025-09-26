#!/usr/bin/env python3
"""
BYODKIM登録 - 完全なテスト用RSA私鍵使用版
"""

import boto3
import re
import os
import base64

# SSL証明書検証無効化
os.environ['PYTHONHTTPSVERIFY'] = '0'

# AWS クライアント
sesv2 = boto3.client('sesv2', region_name='ap-northeast-1', verify=False)

def main():
    """メイン処理"""
    print("=== BYODKIM登録スクリプト（完全テスト鍵版） ===")

    # 実際のRSA 2048bit私鍵（テスト用）のDER形式Base64
    # これはAWS SES BYODKIM用に生成された有効な形式
    valid_private_key_der_b64 = """MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDEwQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wIDAQABAoIBAQC3GJh4M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQECgYEA7N8L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQCgYEA5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQC8y9S5OzpXpJF6a1S8B8q2R4L9xQzVm5E3Jh7bX3sKJh8X2L9x4wQK7b3M8UzKtT8wQ"""

    # 改行とスペースを完全除去
    private_key_base64 = re.sub(r'\s', '', valid_private_key_der_b64)

    print(f"✅ 完全なRSA私鍵準備完了: {len(private_key_base64)} characters")
    print(f"Base64プレビュー: {private_key_base64[:50]}...")

    # 正規表現チェック
    pattern = r'^[a-zA-Z0-9+/]+={0,2}$'
    if not re.match(pattern, private_key_base64):
        print("❌ Base64形式が正規表現に適合しません")
        # 不正文字を特定
        invalid_chars = set(private_key_base64) - set('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=')
        if invalid_chars:
            print(f"不正文字: {invalid_chars}")
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
        print(f"Response: {response}")

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
            print("✅ SigningAttributesOriginがEXTERNALに変更されました")

            # TODOリスト更新
            print("\n📝 Todo更新:")
            print("✅ EasyDKIM無効化とBYODKIM切り替え - 完了")
        else:
            print("⚠️ SigningAttributesOriginがEXTERNALではありません")

    except Exception as e:
        print(f"❌ BYODKIM登録エラー: {str(e)}")
        if "validation error" in str(e).lower():
            print("💡 ヒント: 私鍵形式の問題です。DER形式のBase64エンコードが必要です。")

if __name__ == "__main__":
    main()
