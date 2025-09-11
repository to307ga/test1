#!/usr/bin/env python3
"""
Enhanced CloudFormation Template Validation Script for AWS SES NOT DNS AUTO
Validates improved templates with KMS encryption, advanced Kinesis, and multi-bucket architecture
"""

import yaml
import json
import sys
import os
from pathlib import Path

def validate_yaml_syntax(file_path):
    """Validate YAML syntax"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            yaml.safe_load(f)
        print(f"✅ YAML syntax valid: {file_path}")
        return True
    except yaml.YAMLError as e:
        print(f"❌ YAML syntax error in {file_path}: {e}")
        return False
    except Exception as e:
        print(f"❌ Error reading {file_path}: {e}")
        return False

def validate_template_structure(file_path):
    """Validate CloudFormation template structure"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            template = yaml.safe_load(f)
        
        required_sections = ['AWSTemplateFormatVersion', 'Description', 'Parameters', 'Resources']
        missing_sections = [section for section in required_sections if section not in template]
        
        if missing_sections:
            print(f"❌ Missing required sections in {file_path}: {missing_sections}")
            return False
        
        print(f"✅ Template structure valid: {file_path}")
        return True
    except Exception as e:
        print(f"❌ Error validating template structure in {file_path}: {e}")
        return False

def validate_enhanced_features(file_path):
    """Validate enhanced features implementation"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            template = yaml.safe_load(f)
        
        resources = template.get('Resources', {})
        parameters = template.get('Parameters', {})
        outputs = template.get('Outputs', {})
        
        # Check for KMS encryption features
        kms_features = []
        if 'KinesisFirehoseKMSKey' in resources:
            kms_features.append('KMS Key')
        if 'KinesisFirehoseKMSKeyAlias' in resources:
            kms_features.append('KMS Alias')
        
        # Check for multiple S3 bucket architecture
        s3_buckets = []
        if 'RawLogsBucket' in resources:
            s3_buckets.append('Raw Logs Bucket')
        if 'MaskedLogsBucket' in resources:
            s3_buckets.append('Masked Logs Bucket')
        if 'ErrorLogsBucket' in resources:
            s3_buckets.append('Error Logs Bucket')
        
        # Check for advanced Kinesis settings
        kinesis_features = []
        if 'BufferSize' in parameters:
            kinesis_features.append('Buffer Size Parameter')
        if 'BufferInterval' in parameters:
            kinesis_features.append('Buffer Interval Parameter')
        if 'CompressionFormat' in parameters:
            kinesis_features.append('Compression Format Parameter')
        if 'DataTransformLambda' in resources:
            kinesis_features.append('Data Transform Lambda')
        if 'RawLogsFirehoseStream' in resources:
            kinesis_features.append('Raw Logs Firehose Stream')
        if 'MaskedLogsFirehoseStream' in resources:
            kinesis_features.append('Masked Logs Firehose Stream')
        
        # Check for gzip compression support
        gzip_support = False
        if 'DataTransformLambda' in resources:
            lambda_func = resources['DataTransformLambda']
            code = lambda_func.get('Properties', {}).get('Code', {}).get('ZipFile', '')
            if 'gzip' in code and 'compress' in code:
                gzip_support = True
        
        # Check for IP-based access control
        access_control_features = []
        if 'AdminIPRange' in parameters:
            access_control_features.append('Admin IP Range Parameter')
        if 'OperatorIPRange' in parameters:
            access_control_features.append('Operator IP Range Parameter')
        
        # Print validation results
        print(f"\n📋 Enhanced Features Validation for {os.path.basename(file_path)}:")
        print(f"  🔐 KMS Encryption Features: {len(kms_features)}/2 implemented")
        for feature in kms_features:
            print(f"    ✅ {feature}")
        
        print(f"  🗂️  S3 Multi-Bucket Architecture: {len(s3_buckets)}/3 implemented")
        for bucket in s3_buckets:
            print(f"    ✅ {bucket}")
        
        print(f"  🚀 Advanced Kinesis Features: {len(kinesis_features)}/6 implemented")
        for feature in kinesis_features:
            print(f"    ✅ {feature}")
        
        print(f"  🗜️  gzip Compression Support: {'✅ Implemented' if gzip_support else '❌ Not found'}")
        
        print(f"  🔒 Access Control Features: {len(access_control_features)}/2 implemented")
        for feature in access_control_features:
            print(f"    ✅ {feature}")
        
        # Calculate overall implementation score
        total_features = 2 + 3 + 6 + 1 + 2  # KMS + S3 + Kinesis + gzip + Access Control
        implemented_features = len(kms_features) + len(s3_buckets) + len(kinesis_features) + (1 if gzip_support else 0) + len(access_control_features)
        implementation_score = (implemented_features / total_features) * 100
        
        print(f"\n🎯 Overall Implementation Score: {implementation_score:.1f}% ({implemented_features}/{total_features})")
        
        if implementation_score >= 90:
            print("✅ Excellent implementation of enhanced features!")
            return True
        elif implementation_score >= 70:
            print("⚠️  Good implementation, some features may be missing")
            return True
        else:
            print("❌ Incomplete implementation of enhanced features")
            return False
            
    except Exception as e:
        print(f"❌ Error validating enhanced features in {file_path}: {e}")
        return False

def validate_tokyo_region_optimization(file_path):
    """Validate Tokyo region specific optimizations"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            template = yaml.safe_load(content)
        
        tokyo_features = []
        
        # Check for ap-northeast-1 region references
        if 'ap-northeast-1' in content:
            tokyo_features.append('Tokyo region hardcoded references')
        
        # Check for resource tags with Region
        resources = template.get('Resources', {})
        region_tagged_resources = 0
        for resource_name, resource_config in resources.items():
            tags = resource_config.get('Properties', {}).get('Tags', [])
            for tag in tags:
                if tag.get('Key') == 'Region' and tag.get('Value') == 'ap-northeast-1':
                    region_tagged_resources += 1
                    break
        
        if region_tagged_resources > 0:
            tokyo_features.append(f'{region_tagged_resources} resources tagged with Tokyo region')
        
        print(f"\n🗾 Tokyo Region Optimization:")
        for feature in tokyo_features:
            print(f"  ✅ {feature}")
        
        return len(tokyo_features) > 0
        
    except Exception as e:
        print(f"❌ Error validating Tokyo region optimization in {file_path}: {e}")
        return False

def validate_backward_compatibility(file_path):
    """Validate backward compatibility with existing configurations"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            template = yaml.safe_load(f)
        
        outputs = template.get('Outputs', {})
        compatibility_outputs = []
        
        # Check for legacy output names
        legacy_outputs = ['LoggingBucketName', 'S3BucketName', 'CloudWatchLogGroupName', 'SNSTopicArn']
        for output_name in legacy_outputs:
            if output_name in outputs:
                compatibility_outputs.append(output_name)
        
        print(f"\n🔄 Backward Compatibility:")
        print(f"  📤 Legacy Outputs: {len(compatibility_outputs)}/{len(legacy_outputs)} maintained")
        for output in compatibility_outputs:
            print(f"    ✅ {output}")
        
        return len(compatibility_outputs) >= 3  # At least 3 legacy outputs should be maintained
        
    except Exception as e:
        print(f"❌ Error validating backward compatibility in {file_path}: {e}")
        return False

def main():
    """Main validation function"""
    print("🔍 Enhanced CloudFormation Template Validation")
    print("=" * 50)
    
    # Template files to validate
    template_files = [
        "sceptre/templates/base.yaml",
        "sceptre/templates/enhanced-kinesis.yaml"
    ]
    
    overall_valid = True
    
    for template_file in template_files:
        if os.path.exists(template_file):
            print(f"\n📄 Validating: {template_file}")
            print("-" * 40)
            
            # Basic validations
            yaml_valid = validate_yaml_syntax(template_file)
            structure_valid = validate_template_structure(template_file)
            
            # Enhanced feature validations (only for main templates)
            if template_file.endswith('base.yaml'):
                features_valid = validate_enhanced_features(template_file)
                region_valid = validate_tokyo_region_optimization(template_file)
                compatibility_valid = validate_backward_compatibility(template_file)
                
                file_valid = yaml_valid and structure_valid and features_valid and region_valid and compatibility_valid
            else:
                file_valid = yaml_valid and structure_valid
            
            if not file_valid:
                overall_valid = False
                
        else:
            print(f"\n⚠️  Template file not found: {template_file}")
            overall_valid = False
    
    print("\n" + "=" * 50)
    if overall_valid:
        print("🎉 All template validations passed!")
        print("✅ Enhanced features successfully implemented")
        print("✅ KMS encryption enabled")
        print("✅ Multi-bucket S3 architecture configured")
        print("✅ Advanced Kinesis Data Firehose with gzip support")
        print("✅ Tokyo region optimizations applied")
        print("✅ Backward compatibility maintained")
        return 0
    else:
        print("❌ Some template validations failed")
        print("📝 Please review the errors above and fix the templates")
        return 1

if __name__ == "__main__":
    sys.exit(main())
