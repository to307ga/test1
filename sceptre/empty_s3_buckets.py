#!/usr/bin/env python3
import boto3

s3 = boto3.client('s3')

buckets_to_empty = [
    'aws-ses-migration-dev-dkim-certificates',
    'aws-ses-migration-dev-lambda-layers',
    'aws-ses-migration-dev-cryptography-layer-007773581311'
]

print("S3バケットを空にしています...")

for bucket_name in buckets_to_empty:
    try:
        print(f"\nバケット: {bucket_name}")

        # オブジェクト一覧を取得
        response = s3.list_objects_v2(Bucket=bucket_name)

        if 'Contents' not in response:
            print("  既に空です")
            continue

        # オブジェクトを削除
        objects_to_delete = [{'Key': obj['Key']} for obj in response['Contents']]

        print(f"  {len(objects_to_delete)}個のオブジェクトを削除中...")

        # バッチ削除
        s3.delete_objects(
            Bucket=bucket_name,
            Delete={'Objects': objects_to_delete}
        )

        print("  削除完了")

        # バージョニングが有効な場合、バージョンも削除
        try:
            versions = s3.list_object_versions(Bucket=bucket_name)
            if 'Versions' in versions and versions['Versions']:
                version_objects = [{'Key': v['Key'], 'VersionId': v['VersionId']}
                                 for v in versions['Versions']]
                if version_objects:
                    print(f"  {len(version_objects)}個のバージョンを削除中...")
                    s3.delete_objects(
                        Bucket=bucket_name,
                        Delete={'Objects': version_objects}
                    )
                    print("  バージョン削除完了")
        except Exception as e:
            print(f"  バージョン削除エラー（無視可能）: {e}")

    except Exception as e:
        print(f"  エラー: {e}")

print("\nS3バケットの削除が完了しました。")
print("次はCloudFormationスタックの削除を再実行してください。")
