#!/usr/bin/env python3
import boto3
import ssl
import urllib3

# SSL検証を無効化
ssl._create_default_https_context = ssl._create_unverified_context
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# CloudFormationクライアントを作成
cf = boto3.client('cloudformation', region_name='ap-northeast-1')

# dev環境のスタックを取得
try:
    stacks = cf.list_stacks(
        StackStatusFilter=[
            'CREATE_COMPLETE',
            'UPDATE_COMPLETE',
            'DELETE_FAILED',
            'ROLLBACK_COMPLETE'
        ]
    )['StackSummaries']

    dev_stacks = [s for s in stacks if 'dev' in s['StackName']]

    if dev_stacks:
        print("残存しているdev環境のスタック:")
        for stack in dev_stacks:
            print(f"  {stack['StackName']} - {stack['StackStatus']}")
    else:
        print("dev環境のスタックは見つかりませんでした。")

except Exception as e:
    print(f"エラー: {e}")
