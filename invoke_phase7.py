#!/usr/bin/env python3
import boto3
import json

def invoke_lambda():
    # Lambda クライアントを作成
    lambda_client = boto3.client('lambda', region_name='ap-northeast-1')

    # ペイロード
    payload = {
        "action": "phase_manager",
        "phase": "7",
        "domain": "goo.ne.jp",
        "environment": "dev",
        "projectName": "aws-ses-migration",
        "dkimSeparator": "gooid-21-dev"
    }

    try:
        # Lambda 関数を実行
        response = lambda_client.invoke(
            FunctionName='arn:aws:lambda:ap-northeast-1:007773581311:function:aws-ses-migration-dev-dkim-manager',
            Payload=json.dumps(payload)
        )

        # レスポンスを読み取り
        response_payload = response['Payload'].read()

        print("Status Code:", response['StatusCode'])
        print("Response:", response_payload.decode('utf-8'))

        # レスポンスをファイルに保存
        with open('phase7-dev-response-boto3.json', 'w') as f:
            f.write(response_payload.decode('utf-8'))

        return response_payload.decode('utf-8')

    except Exception as e:
        print(f"Error: {e}")
        return None

if __name__ == "__main__":
    invoke_lambda()
