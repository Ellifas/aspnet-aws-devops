# NextFit DevOps Challenge

Este projeto foi desenvolvido como parte de um desafio técnico DevOps/Cloud, com o objetivo de demonstrar provisionamento, containerização, deploy em Kubernetes, exposição HTTP e boas práticas básicas de operação.

A solução foi construída de forma incremental para validar cada camada antes de avançar para cloud:

1. Aplicação ASP.NET Core 8.
2. Dockerfile multi-stage.
3. Deploy em Kubernetes local com K3s.
4. Empacotamento com Helm.
5. Probes, requests, limits e securityContext.
6. HPA e PDB.
7. Exposição HTTP via Istio Gateway.
8. Próxima etapa: provisionamento e deploy em AWS com Terraform, EKS e ECR.

---

## 1. Objetivo da solução

O objetivo é publicar uma aplicação ASP.NET Core em um cluster Kubernetes, deixando-a acessível por HTTP e demonstrando uma estrutura organizada de infraestrutura, deploy e operação.

A solução local usa K3s para validação prática dos manifests e do Helm Chart. A versão final do desafio será evoluída para AWS, usando Terraform para provisionar a infraestrutura e EKS como cluster Kubernetes gerenciado.

---

## 2. Arquitetura atual — ambiente local

```text
Usuário
  |
  v
http://192.168.0.20:30080
  |
  v
Istio Ingress Gateway
  |
  v
Istio Gateway
  |
  v
VirtualService
  |
  v
Service ClusterIP nextfit-app
  |
  v
Pods ASP.NET Core
```

A aplicação não é exposta diretamente. O Service da aplicação permanece como `ClusterIP`, e a entrada HTTP é feita pelo `istio-ingressgateway`.

---

## 3. Stack utilizada

* ASP.NET Core 8
* Docker
* Kubernetes
* K3s
* Helm
* Istio
* HPA
* PDB
* Terraform, na próxima etapa AWS
* AWS EKS/ECR, na próxima etapa AWS

---

## 4. Estrutura do projeto

```text
nextfit-devops-challenge/
├── app/
│   └── NextFit.App/
│       ├── Program.cs
│       ├── NextFit.App.csproj
│       ├── Dockerfile
│       └── .dockerignore
├── k8s/
│   ├── helm/
│   │   └── nextfit-app/
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/
│   │           ├── deployment.yaml
│   │           ├── service.yaml
│   │           ├── hpa.yaml
│   │           ├── pdb.yaml
│   │           ├── gateway.yaml
│   │           └── virtualservice.yaml
│   ├── istio/
│   │   └── ingressgateway-values.yaml
│   └── manifests/
│       ├── namespace.yaml
│       ├── deployment.yaml
│       └── service.yaml
└── README.md
```

---

## 5. Aplicação ASP.NET Core

A aplicação é uma Minimal API em ASP.NET Core 8.

Endpoints disponíveis:

```text
GET /
GET /version
GET /health/live
GET /health/ready
```

O endpoint `/` retorna uma resposta básica informando que a aplicação está em execução.

Os endpoints `/health/live` e `/health/ready` são utilizados pelas probes do Kubernetes.

---

## 6. Executar aplicação localmente

Entre na pasta da aplicação:

```bash
cd app/NextFit.App
```

Execute:

```bash
dotnet run
```

Teste:

```bash
curl http://localhost:PORTA/
curl http://localhost:PORTA/version
curl http://localhost:PORTA/health/live
curl http://localhost:PORTA/health/ready
```

---

## 7. Build da imagem Docker

Na raiz do projeto:

```bash
sudo docker build -t nextfit-app:local ./app/NextFit.App
```

Crie também uma tag compatível com o K3s/containerd:

```bash
sudo docker tag nextfit-app:local localhost/nextfit-app:local
```

Salve a imagem:

```bash
sudo docker save -o /var/tmp/nextfit-app-local.tar localhost/nextfit-app:local
```

Importe para o K3s:

```bash
sudo k3s ctr -n k8s.io images import /var/tmp/nextfit-app-local.tar
```

Valide:

```bash
sudo k3s ctr -n k8s.io images list | grep nextfit
```

---

## 8. Dockerfile

A aplicação utiliza Dockerfile multi-stage:

* A primeira etapa usa a imagem SDK do .NET 8 para restaurar dependências e publicar a aplicação.
* A segunda etapa usa apenas a imagem runtime do ASP.NET 8.
* A aplicação roda como usuário não-root.
* A porta interna usada é `8080`.

Essa abordagem reduz o tamanho da imagem final e evita levar ferramentas de build para o runtime.

---

## 9. Deploy com Helm

O deploy da aplicação é feito via Helm Chart.

Criar namespace:

```bash
kubectl create namespace nextfit --dry-run=client -o yaml | kubectl apply -f -
```

Instalar ou atualizar a aplicação:

```bash
helm upgrade --install nextfit-app k8s/helm/nextfit-app -n nextfit
```

Validar release:

```bash
helm list -n nextfit
helm status nextfit-app -n nextfit
```

Validar recursos:

```bash
kubectl -n nextfit get pods
kubectl -n nextfit get svc
kubectl -n nextfit get hpa
kubectl -n nextfit get pdb
```

---

## 10. Boas práticas aplicadas no Kubernetes

O Deployment da aplicação possui:

* 2 réplicas.
* Estratégia `RollingUpdate`.
* `livenessProbe`.
* `readinessProbe`.
* `resources.requests`.
* `resources.limits`.
* `securityContext`.
* Execução como usuário não-root.
* `allowPrivilegeEscalation: false`.
* Linux capabilities removidas.
* `readOnlyRootFilesystem`.
* Volume temporário em `/tmp`.

Essas configurações ajudam a tornar o deploy mais previsível, seguro e resiliente.

---

## 11. HPA

A aplicação possui `HorizontalPodAutoscaler`.

Configuração atual:

```text
minReplicas: 2
maxReplicas: 4
cpuUtilization: 70%
```

Validar:

```bash
kubectl -n nextfit get hpa
kubectl top pods -n nextfit
```

O HPA permite escalar horizontalmente a aplicação com base no consumo médio de CPU.

Em produção, seria interessante avaliar métricas mais aderentes ao comportamento real da aplicação, como latência, requisições por segundo, tamanho de fila ou métricas customizadas via Prometheus Adapter.

---

## 12. PDB

A aplicação possui `PodDisruptionBudget`.

Configuração atual:

```text
minAvailable: 1
```

Validar:

```bash
kubectl -n nextfit get pdb
```

O PDB evita que todos os pods da aplicação sejam removidos ao mesmo tempo durante operações voluntárias, como drain de node ou manutenção controlada.

---

## 13. Istio

O Istio foi utilizado para expor a aplicação via Gateway e VirtualService.

Componentes instalados:

```text
istio-base
istiod
istio-ingressgateway
```

Namespaces utilizados:

```text
istio-system
istio-ingress
nextfit
```

Validar Istio:

```bash
kubectl -n istio-system get pods
kubectl -n istio-ingress get pods
kubectl -n istio-ingress get svc
```

O `istio-ingressgateway` foi exposto como `NodePort` no ambiente local.

Portas configuradas:

```text
HTTP: 30080
HTTPS: 30443
Status: 32021
```

---

## 14. Exposição HTTP via Istio

A aplicação fica acessível por:

```text
http://192.168.0.20:30080
```

Testes:

```bash
curl http://192.168.0.20:30080/
curl http://192.168.0.20:30080/version
curl http://192.168.0.20:30080/health/ready
```

O fluxo é:

```text
192.168.0.20:30080
  -> istio-ingressgateway
  -> Gateway
  -> VirtualService
  -> Service nextfit-app
  -> Pods da aplicação
```

---

## 15. Recursos Istio da aplicação

Validar Gateway e VirtualService:

```bash
kubectl -n nextfit get gateway
kubectl -n nextfit get virtualservice
```

O `Gateway` define que o Istio aceita tráfego HTTP na porta 80.

O `VirtualService` define que as requisições com prefixo `/` devem ser encaminhadas para o Service interno da aplicação:

```text
nextfit-app.nextfit.svc.cluster.local
```

---

## 16. Troubleshooting

Ver pods:

```bash
kubectl -n nextfit get pods -o wide
```

Ver logs da aplicação:

```bash
kubectl -n nextfit logs deployment/nextfit-app -c app
```

Ver logs do sidecar Istio:

```bash
kubectl -n nextfit logs POD_NAME -c istio-proxy
```

Ver eventos:

```bash
kubectl -n nextfit get events --sort-by=.lastTimestamp
```

Ver detalhes de um pod:

```bash
kubectl -n nextfit describe pod POD_NAME
```

Ver Service e endpoints:

```bash
kubectl -n nextfit get svc
kubectl -n nextfit get endpoints nextfit-app
```

Ver Gateway e VirtualService:

```bash
kubectl -n nextfit describe gateway
kubectl -n nextfit describe virtualservice
```

Ver logs do Istio Ingress Gateway:

```bash
kubectl -n istio-ingress logs deployment/istio-ingressgateway
```

---

## 17. Rollout e rollback

Ver status do rollout:

```bash
kubectl -n nextfit rollout status deployment/nextfit-app
```

Ver histórico:

```bash
kubectl -n nextfit rollout history deployment/nextfit-app
```

Rollback via Kubernetes:

```bash
kubectl -n nextfit rollout undo deployment/nextfit-app
```

Rollback via Helm:

```bash
helm history nextfit-app -n nextfit
helm rollback nextfit-app REVISION -n nextfit
```

---

## 18. Decisões técnicas

### Por que ASP.NET Core Minimal API?

O foco do desafio é infraestrutura, Kubernetes e operação. Por isso, a aplicação foi mantida simples, com endpoints suficientes para validar funcionamento, versão e saúde.

### Por que Docker multi-stage?

Para separar build e runtime. A imagem final contém apenas o necessário para executar a aplicação, sem SDK e ferramentas de compilação.

### Por que Kubernetes?

O Kubernetes permite declarar o estado desejado da aplicação, controlar réplicas, realizar rolling updates, aplicar probes, controlar recursos e padronizar deploy.

### Por que Helm?

O Helm deixa os manifests parametrizáveis e reutilizáveis. A mesma estrutura pode ser usada em ambiente local e cloud, alterando apenas os valores.

### Por que HPA?

Para demonstrar elasticidade horizontal. A aplicação pode aumentar ou reduzir réplicas com base em consumo de CPU.

### Por que PDB?

Para proteger disponibilidade durante interrupções voluntárias, como manutenção ou drain de node.

### Por que Istio?

O Istio foi usado como diferencial para separar a camada de entrada da aplicação. O tráfego externo entra pelo Istio Ingress Gateway, e o roteamento é controlado por Gateway e VirtualService.

Essa base permite evoluções como:

* mTLS.
* retries.
* timeouts.
* circuit breaking.
* traffic shifting.
* canary release.
* políticas de autorização.

---

## 19. Limitações do ambiente local

A versão atual roda em K3s local e possui algumas limitações:

* Não possui domínio público.
* Não possui TLS configurado.
* Não usa Load Balancer cloud.
* A imagem é importada manualmente no containerd do K3s.
* Não há pipeline CI/CD.
* Não há observabilidade completa com Prometheus/Grafana.
* Não há gerenciamento externo de secrets.
* Não há provisionamento cloud nesta etapa.

Essas limitações serão tratadas ou documentadas na evolução para AWS.

---

## 20. Próxima etapa — AWS

A próxima etapa será provisionar a infraestrutura na AWS usando Terraform.

A arquitetura planejada para AWS é:

```text
Internet
  |
  v
AWS Load Balancer
  |
  v
Istio Ingress Gateway
  |
  v
Gateway / VirtualService
  |
  v
Service ClusterIP
  |
  v
Pods ASP.NET Core no EKS
```

Recursos planejados:

```text
VPC
Subnets públicas
Subnets privadas
EKS
Managed Node Group
ECR
Istio via Helm
Metrics Server
Deploy da aplicação via Helm
```

Fluxo esperado:

```text
Terraform cria infraestrutura AWS.
Docker build gera a imagem da aplicação.
Imagem é enviada para o ECR.
Helm faz deploy da aplicação no EKS.
Istio expõe a aplicação publicamente.
```

Comandos previstos:

```bash
cd infra/aws
terraform init
terraform validate
terraform plan
terraform apply
```

Configurar kubeconfig:

```bash
aws eks update-kubeconfig \
  --region REGION \
  --name CLUSTER_NAME
```

Build e push da imagem:

```bash
docker build -t nextfit-app:0.1.0 ./app/NextFit.App
docker tag nextfit-app:0.1.0 ECR_REPOSITORY_URL:0.1.0
docker push ECR_REPOSITORY_URL:0.1.0
```

Deploy:

```bash
helm upgrade --install nextfit-app k8s/helm/nextfit-app \
  -n nextfit \
  --set image.repository=ECR_REPOSITORY_URL \
  --set image.tag=0.1.0 \
  --set image.pullPolicy=IfNotPresent
```

---

## 21. Melhorias futuras

Para uma versão mais próxima de produção, eu evoluiria com:

* Terraform remote state em S3.
* Lock de state com DynamoDB.
* TLS com ACM.
* DNS com Route53.
* WAF.
* Observabilidade com Prometheus, Grafana e Loki ou CloudWatch.
* External Secrets Operator com AWS Secrets Manager.
* Pipeline CI/CD com GitHub Actions.
* OIDC entre GitHub Actions e AWS.
* Canary release com Istio.
* mTLS dentro da malha.
* Network Policies.
* Cluster Autoscaler ou Karpenter.
* Separação de ambientes: dev, staging e prod.

---

## 22. Como explicar a solução

A solução foi construída de forma incremental.

Primeiro validei a aplicação localmente. Depois criei o Dockerfile e rodei a aplicação em container. Em seguida, publiquei a aplicação em Kubernetes usando Deployment e Service. Depois evoluí os manifests para Helm, adicionando probes, requests, limits, securityContext, HPA e PDB.

Por fim, adicionei Istio para expor a aplicação por meio de Gateway e VirtualService. No ambiente local, o Istio Ingress Gateway foi exposto via NodePort na porta 30080. Na AWS, a ideia é manter a aplicação como ClusterIP e expor o Istio Ingress Gateway via Load Balancer.

A solução não tenta ser excessivamente complexa. Ela prioriza clareza, funcionamento e evolução progressiva para um ambiente cloud mais robusto.

---

## 23. Status atual

Funcional no ambiente local:

```text
Aplicação ASP.NET Core
Dockerfile
K3s
Helm Chart
Deployment
Service ClusterIP
LivenessProbe
ReadinessProbe
Requests/Limits
SecurityContext
HPA
PDB
Istio Gateway
VirtualService
Acesso via http://192.168.0.20:30080
```

Pendente para a entrega final:

```text
Terraform AWS
EKS
ECR
Push da imagem para registry cloud
Deploy no EKS
Exposição pública via Load Balancer/Istio
Documentação final com outputs reais da AWS
```
