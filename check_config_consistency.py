#!/usr/bin/env python3
"""
AWS SES NOT DNS AUTO - 設定ファイル整合性チェック
"""

import yaml
import os
from pathlib import Path

def check_config_consistency():
    """
    設定ファイルの整合性をチェックする
    """
    print("=== 設定ファイル整合性チェック ===\n")
    
    base_dir = Path("sceptre")
    templates_dir = base_dir / "templates"
    
    # テンプレートファイル一覧
    templates = list(templates_dir.glob("*.yaml"))
    print(f"📁 テンプレートファイル ({len(templates)}個):")
    for template in templates:
        print(f"   - {template.name}")
    
    # 各環境の設定チェック
    environments = ["dev", "prod"]
    
    for env in environments:
        print(f"\n🌍 環境: {env}")
        config_dir = base_dir / "config" / env
        
        if not config_dir.exists():
            print(f"   ❌ 設定ディレクトリが存在しません: {config_dir}")
            continue
            
        config_files = list(config_dir.glob("*.yaml"))
        print(f"   📄 設定ファイル ({len(config_files)}個):")
        
        for config_file in config_files:
            print(f"     - {config_file.name}")
            
            # 設定ファイル内容確認
            try:
                with open(config_file, 'r', encoding='utf-8') as f:
                    config = yaml.safe_load(f)
                
                # テンプレートパス確認
                template_path = config.get('template', {}).get('path')
                if template_path:
                    full_template_path = templates_dir / template_path.replace('../templates/', '')
                    if full_template_path.exists():
                        print(f"       ✅ テンプレート: {template_path}")
                    else:
                        print(f"       ❌ テンプレート見つからず: {template_path}")
                
                # パラメータ確認
                parameters = config.get('parameters', {})
                if parameters:
                    enhanced_params = ['BufferSize', 'BufferInterval', 'CompressionFormat', 'AdminIPRange', 'OperatorIPRange']
                    found_enhanced = [p for p in enhanced_params if p in parameters]
                    if found_enhanced:
                        print(f"       ✅ 拡張パラメータ: {', '.join(found_enhanced)}")
                    else:
                        if config_file.name == 'base.yaml':
                            print(f"       ⚠️  拡張パラメータ未設定")
                
            except Exception as e:
                print(f"       ❌ 設定読み込みエラー: {e}")
    
    # enhanced-kinesis 特別チェック
    print(f"\n🔧 Enhanced Kinesis 設定チェック:")
    
    for env in environments:
        enhanced_config = base_dir / "config" / env / "enhanced-kinesis.yaml"
        enhanced_template = templates_dir / "enhanced-kinesis.yaml"
        
        print(f"   {env}環境:")
        print(f"     設定ファイル: {'✅' if enhanced_config.exists() else '❌'} {enhanced_config.name}")
        print(f"     テンプレート: {'✅' if enhanced_template.exists() else '❌'} {enhanced_template.name}")
    
    # 推奨事項
    print(f"\n💡 推奨事項:")
    print(f"   1. 全環境でenhanced-kinesis設定を確認")
    print(f"   2. base.yamlの拡張パラメータを確認") 
    print(f"   3. テンプレート間の依存関係を確認")
    
    print(f"\n✅ 整合性チェック完了")

if __name__ == "__main__":
    try:
        check_config_consistency()
    except Exception as e:
        print(f"❌ エラーが発生しました: {e}")
        import traceback
        traceback.print_exc()
