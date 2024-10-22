How to start:

Cloudflare
```bash
export TF_VAR_cloudflare_api_token=
```

AWS
```bash
aws --version
aws-cli/2.18.5 Python/3.12.6 Linux/6.8.0-45-generic exe/x86_64.ubuntu.22
```

```bash
aws configure --profile tty8747
AWS Access Key ID [None]: ****************7QNY
AWS Secret Access Key [None]: ****************TRZt
Default region name [None]: eu-central-1
Default output format [None]:

aws configure list --profile tty8747
      Name                    Value             Type    Location
      ----                    -----             ----    --------
   profile                  tty8747           manual    --profile
access_key     ****************7QNY shared-credentials-file    
secret_key     ****************TRZt shared-credentials-file    
    region             eu-central-1      config-file    ~/.aws/config
```

```bash
export TF_VAR_aws_access_key_id=
export TF_VAR_aws_secret_access_key=
```

Terraform
```bash
$ terraform --version
Terraform v1.9.7
on linux_amd64

terraform init
terraform plan
terraform apply --auto-approve
aws eks --region eu-central-1 update-kubeconfig --name myk8s
```

Infracost
```
infracost auth login
infracost breakdown --path . --format html --out-file infracost-infra.html --show-skipped
```

<!--
1 Хранить tfstate в s3 или dynamodb
2 Возможно расширить лимиты, если есть понимание сколько нод может понадобиться при нагрузке
3 порт 6443 управления кластером каким-то образом прикрыть или вывести в другую подсеть
4 Установить алёрты на предполагаемые бюджеты
-->
