#!/usr/bin/env python3
import boto3

cf = boto3.client('cloudformation')
s3 = boto3.client('s3')

stacks = [
    'aws-ses-migration-dev-dev-phase-1-infrastructure-foundation',
    'aws-ses-migration-dev-dev-phase-2-dkim-system'
]

print("削除に失敗したS3バケットを確認中...")

for stack_name in stacks:
    try:
        print(f"\nStack: {stack_name}")
        resources = cf.describe_stack_resources(StackName=stack_name)['StackResources']

        for resource in resources:
            if (resource['ResourceType'] == 'AWS::S3::Bucket' and
                'FAILED' in resource.get('ResourceStatus', '')):

                bucket_name = resource['PhysicalResourceId']
                print(f"  失敗したバケット: {resource['LogicalResourceId']} -> {bucket_name}")

                # バケットの中身を確認
                try:
                    objects = s3.list_objects_v2(Bucket=bucket_name)
                    if 'Contents' in objects:
                        print(f"    オブジェクト数: {len(objects['Contents'])}")
                        for obj in objects['Contents'][:5]:  # 最初の5個だけ表示
                            print(f"      - {obj['Key']}")
                        if len(objects['Contents']) > 5:
                            print(f"      ... and {len(objects['Contents']) - 5} more objects")
                    else:
                        print("    バケットは空です")
                except Exception as e:
                    print(f"    バケット確認エラー: {e}")

    except Exception as e:
        print(f"  スタック情報取得エラー: {e}")
