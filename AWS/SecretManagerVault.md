
[t-tomonaga@gooid-21-pro-pm-101 test-ansible]$ aws secretsmanager put-secret-value \
>   --secret-id ansible/vault-password \
>   --secret-string '{"password":"idp@y2O22"}' \
>   --region ap-northeast-1
{
    "ARN": "arn:aws:secretsmanager:ap-northeast-1:910230630316:secret:ansible/vault-password-Y45AQH",
    "Name": "ansible/vault-password",
    "VersionId": "3f32960b-72eb-4f08-899c-5d7aa8cb06b5",
    "VersionStages": [
        "AWSCURRENT"
    ]
}

[t-tomonaga@gooid-21-pro-pm-101 test-ansible]$ aws secretsmanager get-secret-value \
  --secret-id ansible/vault-password \
  --region ap-northeast-1 \
  --query SecretString \
  --output text
{"password":"idp@y2O22"}












