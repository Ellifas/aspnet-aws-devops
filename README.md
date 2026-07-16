# NextFit DevOps Challenge

Projeto desenvolvido para o desafio técnico de DevOps, com foco em provisionamento de infraestrutura em cloud, containerização, deploy em Kubernetes, exposição HTTP e boas práticas operacionais.

A aplicação utilizada é uma API ASP.NET Core 8 containerizada com Docker, publicada no Amazon ECR e implantada em um cluster Amazon EKS provisionado com Terraform. A exposição pública foi realizada com Istio Ingress Gateway, utilizando `Gateway` e `VirtualService` para rotear o tráfego até a aplicação.

---

## Arquitetura

Fluxo principal da solução:

```text
Internet
  ↓
AWS Load Balancer
  ↓
Istio Ingress Gateway
  ↓
Istio Gateway
  ↓
Istio VirtualService
  ↓
Kubernetes Service ClusterIP
  ↓
Pod ASP.NET Core
  ↓
Imagem Docker publicada no Amazon ECR
```

Componentes utilizados:

```text
Terraform  -> provisionamento da infraestrutura AWS
AWS VPC    -> rede do cluster
Amazon EKS -> cluster Kubernetes gerenciado
Amazon ECR -> registry privado da imagem Docker
Docker     -> build da aplicação ASP.NET Core
Helm       -> empacotamento e deploy da aplicação
Istio      -> ingress gateway e roteamento HTTP
Kubernetes -> Deployment, Service, probes e recursos
```

---

## Estrutura do projeto

```text
nextfit-devops-challenge/
├── app/
│   └── NextFit.App/
│       ├── Dockerfile
│       ├── Program.cs
│       ├── NextFit.App.csproj
│       ├── appsettings.json
│       └── appsettings.Development.json
│
├── infra/
│   └── infra/
│       └── aws/
│           ├── main.tf
│           ├── outputs.tf
│           ├── providers.tf
│           ├── variables.tf
│           ├── versions.tf
│           ├── terraform.tfvars.example
│           └── terraform.tfvars
│
├── k8s/
│   ├── helm/
│   │   └── nextfit-app/
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       ├── values-local.yaml
│   │       ├── values-aws.yaml
│   │       ├── values-aws-free-tier.yaml
│   │       ├── values-aws-istio-free-tier.yaml
│   │       └── templates/
│   │
│   └── istio/
│       ├── ingressgateway-values-local.yaml
│       ├── ingressgateway-values-aws.yaml
│       ├── ingressgateway-values-aws-free-tier.yaml
│       ├── ingressgateway-values-aws-public-free-tier.yaml
│       └── istiod-values-aws-free-tier.yaml
│
├── .gitignore
└── README.md
```

> Observação: durante a execução do desafio, a infraestrutura Terraform ficou em `infra/infra/aws`. Em uma organização futura, esse diretório poderia ser simplificado para `infra/aws`, mas a estrutura atual foi mantida para evitar alterações em um ambiente já validado.

---

## Aplicação

A aplicação foi desenvolvida em ASP.NET Core 8 e expõe os seguintes endpoints:

```http
GET /
GET /version
GET /health/live
GET /health/ready
```

Exemplo de resposta do endpoint `/`:

```json
{
  "service": "nextfit-challenge",
  "status": "running",
  "environment": "Production",
  "timestampUtc": "2026-07-16T06:04:47.6581653Z"
}
```

Endpoint de versão:

```json
{
  "application": "NextFit.App",
  "framework": ".NET 8",
  "version": "0.1.0"
}
```

Endpoint de readiness:

```text
Healthy
```

---

## Docker

A aplicação possui um `Dockerfile` multi-stage build, utilizando:

```text
mcr.microsoft.com/dotnet/sdk:8.0-alpine
mcr.microsoft.com/dotnet/aspnet:8.0-alpine
```

Boas práticas aplicadas no container:

```text
- imagem baseada em Alpine
- multi-stage build
- execução com usuário não-root
- porta interna 8080
- publicação em modo Release
```

Build local:

```bash
cd app/NextFit.App

docker build -t nextfit-app:local .
```

Execução local:

```bash
docker run --rm -p 8080:8080 nextfit-app:local
```

Teste local:

```bash
curl http://localhost:8080/
curl http://localhost:8080/version
curl http://localhost:8080/health/ready
```

---

## Infraestrutura AWS com Terraform

A infraestrutura foi provisionada com Terraform.

Recursos criados:

```text
- VPC
- Subnets públicas
- Subnets privadas
- NAT Gateway
- Amazon EKS
- Managed Node Group
- Amazon ECR
- Security Groups
- Add-ons básicos do EKS
```

Diretório da infraestrutura:

```bash
cd infra/infra/aws
```

Inicialização:

```bash
terraform init
```

Validação:

```bash
terraform validate
```

Planejamento:

```bash
terraform plan
```

Aplicação:

```bash
terraform apply
```

Configuração do kubeconfig:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name nextfit-challenge-dev
```

---

## Ajustes para Free Tier

O ambiente foi executado com restrições de Free Tier da AWS. Por isso, foram aplicados ajustes de sizing para reduzir consumo de CPU, memória e quantidade de pods.

Configuração utilizada no Managed Node Group:

```hcl
node_instance_types = ["t3.micro"]
node_min_size       = 1
node_desired_size   = 2
node_max_size       = 2
```

Ajustes aplicados:

```text
- 2 nodes t3.micro
- CoreDNS com 1 réplica
- aplicação com 1 réplica
- HPA desabilitado no ambiente AWS Free Tier
- PDB desabilitado no ambiente AWS Free Tier
- remoção do eks-pod-identity-agent, pois não havia Pod Identity Association em uso
- Istio com requests/limits reduzidos
- Istio Ingress Gateway com 1 réplica
```

Essas decisões foram tomadas para manter a solução executável dentro das limitações do ambiente de teste.

Em produção, a recomendação seria:

```text
- nodes maiores
- múltiplas réplicas da aplicação
- múltiplas réplicas do CoreDNS
- HPA habilitado
- PDB habilitado
- Istio com alta disponibilidade
- Load Balancer com configuração produtiva
- observabilidade completa
- state remoto do Terraform em S3 com lock em DynamoDB
```

---

## Amazon ECR

A imagem da aplicação foi publicada no Amazon ECR.

Repositório utilizado:

```text
879816410626.dkr.ecr.us-east-1.amazonaws.com/nextfit-challenge-dev/nextfit-app
```

Login no ECR:

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 879816410626.dkr.ecr.us-east-1.amazonaws.com
```

Build da imagem:

```bash
docker build --platform linux/amd64 \
  -t nextfit-app:0.1.0 \
  ./app/NextFit.App
```

Tag da imagem:

```bash
docker tag nextfit-app:0.1.0 \
  879816410626.dkr.ecr.us-east-1.amazonaws.com/nextfit-challenge-dev/nextfit-app:0.1.0
```

Push para o ECR:

```bash
docker push \
  879816410626.dkr.ecr.us-east-1.amazonaws.com/nextfit-challenge-dev/nextfit-app:0.1.0
```

Imagem utilizada no EKS:

```text
879816410626.dkr.ecr.us-east-1.amazonaws.com/nextfit-challenge-dev/nextfit-app:0.1.0
```

---

## Deploy com Helm

A aplicação foi empacotada em um Helm Chart.

Diretório do chart:

```text
k8s/helm/nextfit-app
```

Deploy no EKS com Istio:

```bash
helm upgrade --install nextfit-app k8s/helm/nextfit-app \
  -n nextfit \
  --create-namespace \
  -f k8s/helm/nextfit-app/values-aws-istio-free-tier.yaml
```

Validação:

```bash
kubectl -n nextfit get deploy,pod,svc -o wide
```

Resultado validado:

```text
deployment.apps/nextfit-app   1/1
pod/nextfit-app               1/1 Running
service/nextfit-app           ClusterIP
```

A aplicação ficou exposta internamente via Service `ClusterIP`:

```text
service/nextfit-app   ClusterIP   172.20.178.42   <none>   80/TCP
```

Endpoint interno:

```text
nextfit-app   10.42.21.197:8080
```

---

## Boas práticas Kubernetes

O Deployment da aplicação inclui:

```text
- livenessProbe
- readinessProbe
- resources.requests
- resources.limits
- securityContext
- execução como usuário não-root
- readOnlyRootFilesystem
- capabilities drop ALL
```

Exemplo de probes:

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: http

readinessProbe:
  httpGet:
    path: /health/ready
    port: http
```

Exemplo de resources:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

No ambiente AWS Free Tier, os valores foram ajustados para viabilizar a execução com `t3.micro`.

---

## Istio

O Istio foi utilizado como diferencial para exposição da aplicação.

Componentes instalados:

```text
- istio-base
- istiod
- istio-ingressgateway
```

Instalação do `istio-base`:

```bash
helm upgrade --install istio-base istio/base \
  -n istio-system \
  --wait \
  --timeout 5m
```

Instalação do `istiod`:

```bash
helm upgrade --install istiod istio/istiod \
  -n istio-system \
  -f k8s/istio/istiod-values-aws-free-tier.yaml \
  --wait \
  --timeout 10m
```

Instalação do Ingress Gateway:

```bash
helm upgrade --install istio-ingressgateway istio/gateway \
  -n istio-ingress \
  -f k8s/istio/ingressgateway-values-aws-public-free-tier.yaml
```

Validação do control plane:

```bash
kubectl -n istio-system get pods
```

Resultado:

```text
NAME                      READY   STATUS    RESTARTS   AGE
istiod-5dd7777b6f-8q6ln   1/1     Running   0          35m
```

Validação do ingress gateway:

```bash
kubectl -n istio-ingress get deploy,pod,svc -o wide
```

Resultado:

```text
deployment.apps/istio-ingressgateway   1/1
pod/istio-ingressgateway               1/1 Running
service/istio-ingressgateway           LoadBalancer
```

Load Balancer público criado:

```text
a2b994de2f99040e8b9f347aac380514-467497939.us-east-1.elb.amazonaws.com
```

---

## Gateway e VirtualService

A aplicação foi exposta via recursos do Istio:

```text
Gateway
VirtualService
```

Validação:

```bash
kubectl -n nextfit get gateways.networking.istio.io
```

Resultado:

```text
NAME              AGE
nextfit-gateway   11m
```

Validação do VirtualService:

```bash
kubectl -n nextfit get virtualservices.networking.istio.io
```

Resultado:

```text
NAME          GATEWAYS              HOSTS   AGE
nextfit-app   ["nextfit-gateway"]   ["*"]   11m
```

Fluxo do roteamento:

```text
Istio Gateway
  ↓
VirtualService nextfit-app
  ↓
Service nextfit-app.nextfit.svc.cluster.local
  ↓
Pod nextfit-app
```

---

## Endpoint público

Endpoint público da aplicação:

```text
http://a2b994de2f99040e8b9f347aac380514-467497939.us-east-1.elb.amazonaws.com
```

Teste do endpoint `/`:

```bash
curl -v http://a2b994de2f99040e8b9f347aac380514-467497939.us-east-1.elb.amazonaws.com/
```

Resultado:

```http
HTTP/1.1 200 OK
server: istio-envoy
content-type: application/json; charset=utf-8
```

Resposta:

```json
{
  "service": "nextfit-challenge",
  "status": "running",
  "environment": "Production",
  "timestampUtc": "2026-07-16T06:04:47.6581653Z"
}
```

Teste do endpoint `/version`:

```bash
curl -v http://a2b994de2f99040e8b9f347aac380514-467497939.us-east-1.elb.amazonaws.com/version
```

Resultado:

```http
HTTP/1.1 200 OK
server: istio-envoy
content-type: application/json; charset=utf-8
```

Resposta:

```json
{
  "application": "NextFit.App",
  "framework": ".NET 8",
  "version": "0.1.0"
}
```

Teste do endpoint `/health/ready`:

```bash
curl -v http://a2b994de2f99040e8b9f347aac380514-467497939.us-east-1.elb.amazonaws.com/health/ready
```

Resultado:

```http
HTTP/1.1 200 OK
server: istio-envoy
content-type: text/plain
```

Resposta:

```text
Healthy
```

O header abaixo confirma que o tráfego passou pelo Istio Ingress Gateway:

```http
server: istio-envoy
```

---

## Evidências do cluster

Nodes EKS:

```text
NAME                           STATUS   ROLES    VERSION
ip-10-42-20-38.ec2.internal    Ready    <none>   v1.33.13-eks-8f14419
ip-10-42-21-208.ec2.internal   Ready    <none>   v1.33.13-eks-8f14419
```

Istio control plane:

```text
NAME                      READY   STATUS    RESTARTS
istiod-5dd7777b6f-8q6ln   1/1     Running   0
```

Istio ingress gateway:

```text
deployment.apps/istio-ingressgateway   1/1
pod/istio-ingressgateway               1/1 Running
service/istio-ingressgateway           LoadBalancer
```

Aplicação:

```text
deployment.apps/nextfit-app   1/1
pod/nextfit-app               1/1 Running
service/nextfit-app           ClusterIP
```

Imagem da aplicação no EKS:

```text
879816410626.dkr.ecr.us-east-1.amazonaws.com/nextfit-challenge-dev/nextfit-app:0.1.0
```

Endpoint da aplicação:

```text
nextfit-app   10.42.21.197:8080
```

---

## Observações sobre estabilidade do Load Balancer

Durante os testes, o Load Balancer público resolveu para mais de um IP. Em alguns momentos, um dos caminhos apresentou timeout temporário enquanto o outro respondia corretamente.

Foi validado que os endpoints funcionaram publicamente com:

```text
HTTP/1.1 200 OK
server: istio-envoy
```

Para estabilizar os testes em ambiente Free Tier com apenas uma réplica do ingress gateway, foi utilizado o IP saudável com `curl --connect-to`, preservando o header `Host` original:

```bash
HOST="a2b994de2f99040e8b9f347aac380514-467497939.us-east-1.elb.amazonaws.com"

curl -v --connect-to "$HOST:80:52.203.24.112:80" "http://$HOST/"
curl -v --connect-to "$HOST:80:52.203.24.112:80" "http://$HOST/version"
curl -v --connect-to "$HOST:80:52.203.24.112:80" "http://$HOST/health/ready"
```

Essa validação retornou `200 OK` para os três endpoints.

Em um ambiente produtivo, a recomendação seria utilizar mais réplicas do ingress gateway, nodes maiores, configuração de alta disponibilidade e ajustes específicos no Load Balancer.

---

## Segurança

Boas práticas aplicadas:

```text
- execução do container como usuário não-root
- readOnlyRootFilesystem
- allowPrivilegeEscalation: false
- drop de Linux capabilities
- uso de ECR privado
- scan on push habilitado no ECR
- workloads em subnets privadas
- exposição externa centralizada pelo Istio Ingress Gateway
```

Pontos recomendados para produção:

```text
- HTTPS no Istio Gateway
- TLS termination com certificado válido
- secrets gerenciados por AWS Secrets Manager ou External Secrets Operator
- IAM Roles for Service Accounts ou EKS Pod Identity quando necessário
- NetworkPolicies
- logs centralizados
- métricas e tracing
- Terraform state remoto com S3 e DynamoDB Lock
```

---

## Comandos úteis

Ver nodes:

```bash
kubectl get nodes -o wide
```

Ver aplicação:

```bash
kubectl -n nextfit get deploy,pod,svc -o wide
```

Ver Istio:

```bash
kubectl -n istio-system get pods
kubectl -n istio-ingress get deploy,pod,svc -o wide
```

Ver Gateway e VirtualService:

```bash
kubectl -n nextfit get gateways.networking.istio.io
kubectl -n nextfit get virtualservices.networking.istio.io
```

Ver endpoint interno:

```bash
kubectl -n nextfit get endpoints nextfit-app
```

Testar endpoint público:

```bash
curl http://a2b994de2f99040e8b9f347aac380514-467497939.us-east-1.elb.amazonaws.com/
curl http://a2b994de2f99040e8b9f347aac380514-467497939.us-east-1.elb.amazonaws.com/version
curl http://a2b994de2f99040e8b9f347aac380514-467497939.us-east-1.elb.amazonaws.com/health/ready
```

---

## Limpeza dos recursos

Atenção: o ambiente AWS pode gerar custo, principalmente por causa de EKS, EC2, NAT Gateway e Load Balancer.

Remover aplicação:

```bash
helm uninstall nextfit-app -n nextfit || true
```

Remover Istio Gateway:

```bash
helm uninstall istio-ingressgateway -n istio-ingress || true
```

Remover Istio control plane:

```bash
helm uninstall istiod -n istio-system || true
helm uninstall istio-base -n istio-system || true
```

Remover namespaces:

```bash
kubectl delete namespace nextfit --ignore-not-found=true
kubectl delete namespace istio-ingress --ignore-not-found=true
kubectl delete namespace istio-system --ignore-not-found=true
```

Destruir infraestrutura AWS:

```bash
cd infra/infra/aws
terraform destroy
```

---

## Pontos de melhoria

Melhorias futuras possíveis:

```text
- GitHub Actions para build e push automático da imagem
- deploy automatizado via pipeline
- remote state no Terraform
- HTTPS no Istio Gateway
- observabilidade com Prometheus e Grafana
- logs centralizados
- tracing distribuído
- HPA habilitado em ambiente com sizing adequado
- múltiplas réplicas da aplicação
- múltiplas réplicas do ingressgateway
- PodDisruptionBudget em produção
```

---

## Resumo técnico

Este projeto entrega:

```text
- aplicação ASP.NET Core 8
- Dockerfile multi-stage
- publicação da imagem no Amazon ECR
- infraestrutura AWS com Terraform
- cluster EKS gerenciado
- deploy Kubernetes com Helm
- Service interno ClusterIP
- health checks com liveness/readiness
- requests e limits
- Istio instalado no cluster
- Istio Ingress Gateway
- Gateway e VirtualService
- endpoint público via AWS Load Balancer
```

O endpoint público foi validado com sucesso e respondeu `200 OK` passando pelo Istio Envoy, confirmando o funcionamento da arquitetura proposta.
