#!/usr/bin/env python3
"""
AWS SES NOT DNS AUTO - Enhanced CloudFormation Template Validation Script
東京リージョン特化の高度なKinesis設定検証
"""

import boto3
import json
import sys
import traceback
from datetime import datetime

def validate_enhanced_template():
    """
    Enhanced CloudFormation template validation with KMS encryption and advanced Kinesis features
    """
    print("\n=== AWS SES NOT DNS AUTO - Enhanced Template Validation ===")
    print(f"実行時刻: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    try:
        # CloudFormation クライアント作成 (東京リージョン)
        cf_client = boto3.client('cloudformation', region_name='ap-northeast-1')
        
        # テンプレートファイルパス
        template_path = 'sceptre/templates/base.yaml'
        
        print(f"\n1. テンプレート読み込み: {template_path}")
        
        with open(template_path, 'r', encoding='utf-8') as f:
            template_body = f.read()
        
        print("   ✓ テンプレートファイル読み込み完了")
        
        # CloudFormation構文検証
        print("\n2. CloudFormation構文検証中...")
        
        try:
            response = cf_client.validate_template(TemplateBody=template_body)
            print("   ✓ CloudFormation構文検証: 成功")
            
            # パラメータ情報表示
            parameters = response.get('Parameters', [])
            print(f"   - パラメータ数: {len(parameters)}")
            
            # 新機能パラメータ確認
            enhanced_params = [
                'BufferSize', 'BufferInterval', 'CompressionFormat',
                'AdminIPRange', 'OperatorIPRange'
            ]
            
            found_enhanced = []
            for param in parameters:
                param_name = param.get('ParameterKey', '')
                if param_name in enhanced_params:
                    found_enhanced.append(param_name)
            
            if found_enhanced:
                print(f"   ✓ 高度なKinesis設定パラメータ確認: {', '.join(found_enhanced)}")
            
        except Exception as e:
            print(f"   ✗ CloudFormation構文検証エラー: {str(e)}")
            return False
        
        # テンプレート内容解析
        print("\n3. テンプレート機能解析...")
        
        # KMS暗号化機能確認
        if 'KinesisFirehoseKMSKey' in template_body:
            print("   ✓ KMS暗号化機能: 実装済み")
        else:
            print("   ✗ KMS暗号化機能: 未実装")
        
        # 複数S3バケット構成確認
        s3_buckets = ['RawLogsBucket', 'MaskedLogsBucket', 'ErrorLogsBucket']
        found_buckets = []
        for bucket in s3_buckets:
            if bucket in template_body:
                found_buckets.append(bucket)
        
        if len(found_buckets) == 3:
            print(f"   ✓ 複数S3バケット構成: 完了 ({', '.join(found_buckets)})")
        else:
            print(f"   ⚠ 複数S3バケット構成: 部分的 ({', '.join(found_buckets)})")
        
        # 高度なKinesis設定確認
        kinesis_features = [
            'RawLogsFirehoseStream',
            'MaskedLogsFirehoseStream', 
            'DataTransformLambda',
            'BufferingHints'
        ]
        
        found_kinesis = []
        for feature in kinesis_features:
            if feature in template_body:
                found_kinesis.append(feature)
        
        print(f"   ✓ 高度なKinesis設定: {len(found_kinesis)}/{len(kinesis_features)} 機能実装")
        
        # gzip圧縮対応確認
        if 'gzip.compress' in template_body and 'gzip.decompress' in template_body:
            print("   ✓ gzip圧縮対応: 実装済み")
        else:
            print("   ⚠ gzip圧縮対応: Lambda関数内で確認必要")
        
        # 東京リージョン特化設定確認
        if 'ap-northeast-1' in template_body:
            print("   ✓ 東京リージョン特化設定: 確認済み")
        else:
            print("   ⚠ 東京リージョン特化設定: 確認必要")
        
        # データマスキング機能確認
        if 'mask_sensitive_data' in template_body:
            print("   ✓ データマスキング機能: 実装済み")
        else:
            print("   ✗ データマスキング機能: 未実装")
        
        # IAMロール・ポリシー確認
        iam_roles = [
            'KinesisTransformLambdaRole',
            'EnhancedDataFirehoseRole'
        ]
        
        found_roles = []
        for role in iam_roles:
            if role in template_body:
                found_roles.append(role)
        
        if found_roles:
            print(f"   ✓ 高度なIAMロール: {', '.join(found_roles)}")
        
        print("\n4. 改良機能完成度評価...")
        
        # 総合評価
        total_features = 6  # KMS, 複数S3, Kinesis, gzip, 東京リージョン, データマスキング
        completed_features = 0
        
        if 'KinesisFirehoseKMSKey' in template_body:
            completed_features += 1
        
        if len(found_buckets) == 3:
            completed_features += 1
        
        if len(found_kinesis) >= 3:
            completed_features += 1
        
        if 'gzip' in template_body:
            completed_features += 1
        
        if 'ap-northeast-1' in template_body:
            completed_features += 1
        
        if 'mask_sensitive_data' in template_body:
            completed_features += 1
        
        completion_rate = (completed_features / total_features) * 100
        
        print(f"   機能完成度: {completed_features}/{total_features} ({completion_rate:.1f}%)")
        
        if completion_rate >= 90:
            print("   ✓ 評価: 優秀 - 全機能が正常に実装されています")
        elif completion_rate >= 75:
            print("   ✓ 評価: 良好 - ほとんどの機能が実装されています")  
        elif completion_rate >= 50:
            print("   ⚠ 評価: 改善必要 - いくつかの機能が不足しています")
        else:
            print("   ✗ 評価: 要修正 - 多くの機能が不足しています")
        
        print("\n5. 推奨事項...")
        
        recommendations = []
        
        if completion_rate < 100:
            if 'KinesisFirehoseKMSKey' not in template_body:
                recommendations.append("- KMS暗号化機能の実装完了")
            
            if len(found_buckets) < 3:
                recommendations.append("- 複数S3バケット構成の完全実装")
            
            if len(found_kinesis) < 3:
                recommendations.append("- 高度なKinesis設定の追加実装")
        
        if not recommendations:
            print("   ✓ 全ての推奨機能が実装済みです")
        else:
            for rec in recommendations:
                print(f"   {rec}")
        
        print("\n=== 検証完了 ===")
        print(f"実行結果: {'成功' if completion_rate >= 75 else '要改善'}")
        
        return completion_rate >= 75
        
    except FileNotFoundError:
        print(f"   ✗ エラー: テンプレートファイルが見つかりません: {template_path}")
        return False
    except Exception as e:
        print(f"   ✗ 予期しないエラーが発生しました: {str(e)}")
        print("\nスタックトレース:")
        traceback.print_exc()
        return False

def main():
    """
    メイン実行関数
    """
    print("AWS SES NOT DNS AUTO - Enhanced Template Validation Tool")
    print("=" * 60)
    
    success = validate_enhanced_template()
    
    if success:
        print("\n🎉 テンプレート検証が正常に完了しました！")
        sys.exit(0)
    else:
        print("\n❌ テンプレート検証でエラーが発生しました。")
        sys.exit(1)

if __name__ == "__main__":
    main()
