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
export KUBECONFIG=/tmp/myconf
aws eks --region eu-central-1 update-kubeconfig --name eks-stage
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
5 В кластер добавить метрики, чтобы смотреть ресурсы


export TF_LOG_CORE=warn
terraform plan

Задача: в пустом аккаунте любого cloud провайдера (предпочтительно aws) запустить k8s (managed/self-hosted - на ваш выбор); реализовать автоскейлинг нод; запустить nginx c автоспейлингом подов; сделать его публично доступным.

Пометка: iaac можно использовать какую/какие угодно, на ваше усмотрение. Результат ожидаем увидеть в виде архива с iaac кодом.

Вопрос: что бы вы сделали, чтобы этот кластер стал production-ready? Ожидаем получить список пунктов

Идеального и вылизанного решения не требуем, важно чтобы работало. Вопросы/комментарии - возможны, но и задание и вопрос - крайне открытые, как именно вы будете делать - полностью ваш выбор)

how-to-create-aws-eks-cluster-step-by-step:
https://medium.com/@sanoj.sudo/how-to-create-aws-eks-cluster-step-by-step-a97420ede922
-->


```bash
export KUBECONFIG=/tmp/myconf
aws eks --region eu-central-1 update-kubeconfig --name eks-stage
helm repo add eks-charts https://aws.github.io/eks-charts
helm repo update
# helm install aws-load-balancer-controller eks-charts/aws-load-balancer-controller --set clusterName=eks-stage-stage --set region=eu-central-1 --set vpcId=vpc-0fefa9c664d9be1c0

kubectl --namespace kube-system create serviceaccount aws-load-balancer-controller
kubectl -n kube-system annotate serviceaccounts aws-load-balancer-controller "eks.amazonaws.com/role-arn=arn:aws:iam::619115920608:role/AmazonEKSLoadBalancerControllerRole"

helm install aws-load-balancer-controller eks-charts/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-stage \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId=vpc-083b71b7e227218d4


# Also: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/examples/echo_server/#deploy-the-echoserver-resources
kubectl create deployment game2048 --image=woodlee/docker-2048 --port 80 --replicas 2
kubectl expose deployment game2048 --port 80 --target-port 80 --protocol TCP
kubectl get ingressClass --all-namespaces
# kubectl create ingress game2048 --class=alb --annotation alb.ingress.kubernetes.io/scheme=internet-facing --annotation alb.ingress.kubernetes.io/load-balancer-name=eks-stage-stage  --annotation alb.ingress.kubernetes.io/target-type=ip --rule="/*=game2048:80"
kubectl create ingress game2048 --class=nginx --rule="/*=game2048:80"
kubectl get ing                          
    NAME       CLASS   HOSTS   ADDRESS                                                                      PORTS   AGE
    game2048   nginx   *       acc492abbfb96427795320aa80bc85bd-1976608275.eu-central-1.elb.amazonaws.com   80      20m

helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.1 \
  --set crds.enabled=true

kubectl create secret generic cloudflare-apikey-secret --from-literal \
  key=

cat <<EOF | k apply -f-
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    email: tty8747@gmail.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: cloudflare-apikey-secret
      key: apikey
    solvers:
      - http01:
          ingress:
            ingressClassName: nginx
EOF

cat <<EOF | k apply -f-
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: tty8747@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: cloudflare-apikey-secret
      key: apikey
    solvers:
      - http01:
          ingress:
            ingressClassName: nginx
EOF

helm install nginx ingress-nginx/ingress-nginx -n nginx --create-namespace

# For letsencrypt-staging
cat <<EOF | k apply -f-
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: game2048
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
spec:
  ingressClassName: nginx
  tls:
    - hosts:
      - www.aaaj.site
      secretName: myingress-cert
  rules:
    - host: www.aaaj.site
      http:
        paths:
        - backend:
            service:
              name: game2048
              port:
                number: 80
          path: /
          pathType: Prefix
EOF

# For letsencrypt-prod
cat <<EOF | k apply -f-
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: game2048
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
      - w3.aaaj.site
      secretName: w3.aaaj.site-cert
  rules:
    - host: w3.aaaj.site
      http:
        paths:
        - backend:
            service:
              name: game2048
              port:
                number: 80
          path: /
          pathType: Prefix
EOF
```
--> https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html




In the subnets sections → Tags → manage tags → key section — kubernetes.io/cluster/<cluster-name> → value —shared
https://engineering.chingari.io/configure-an-eks-cluster-using-terraform-and-an-aws-load-balancer-controller-5c6aa91bfdf6

aws eks describe-cluster --name <my-cluster> --query "cluster.identity.oidc.issuer" --output text
https://oidc.eks.eu-central-1.amazonaws.com/id/7ABFD5AA0D82CB7F69A12C4998C0369C

"Federated": "arn:aws:iam::619115920608:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/7ABFD5AA0D82CB7F69A12C4998C0369C"

"oidc.eks.eu-central-1.amazonaws.com/id/7ABFD5AA0D82CB7F69A12C4998C0369C:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
"oidc.eks.eu-central-1.amazonaws.com/id/7ABFD5AA0D82CB7F69A12C4998C0369C:aud": "sts.amazonaws.com"

internal subnets:
kubernetes.io/role/internal-elb: 1

public subnets:
kubernetes.io/role/elb: 1


Артур
https://www.youtube.com/watch?v=P4ymKRUYoB8
Service Mesh
https://www.youtube.com/live/m9DaD6FdY_4?si=hbKaPeuBqwLR5K0T&t=3499