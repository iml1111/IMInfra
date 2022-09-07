# EKS 2



## Helm

- https://whchoi98.gitbook.io/k8s/eks-2/helm
- https://nyeongnyeong.tistory.com/258

헬름 설치 및 기본 사용법

```
// 헬름 설치 및 차트 Repo 업데이트
brew install kubernetes-helm
helm version --short
helm repo add stable https://charts.helm.sh/stable
helm repo update
// 사용할 수 있는 차트들 확인
$ helm search
helm search repo stable
helm search repo nginx
// 차트를 이용해 MySQL 설치 (--name 옵션은 차트 이름을 지정)
$ helm install stable/mysql --name=my-sql
helm install helm-nginx bitnami/nginx --namespace helm-test
// 설치된 Helm 삭제하기
helm uninstall helm-nginx -n helm-test
// 현재 실행중인 차트 상태 확인
$ helm ls
// 현재 클러스터에 설치된 헬름 목록
helm list -n helm-test
// 실행중인 차트 삭제
$ helm del my-mysql
```

### Chart 직접 만들기

차트도 사용자가 직접 만든 후, 클라우드 오브젝트 스토리지(S3 등)을 통해 배포할 수 있는 듯함.

현재 공부 목적에는 벗어나므로 일단은 스킵...

```
// 기본 구조의 차트 생성
$ helm create <CHART_NAME>
├── charts
├── Chart.yaml
├── templates
│   ├── deployment.yaml
│   ├── _helpers.tpl
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt
│   ├── serviceaccount.yaml
│   ├── service.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml
```



## Cluster Auto-scaling

- https://whchoi98.gitbook.io/k8s/eks-2/autoscaling#ca-node

클러스터 오토스케일링은 AWS의 Auto Scaling Group과 연계하여 제공함.  이는 직접 콘솔 GUI 환경에서도 쉽게 바꿔줄 수도 있지만 CLI 환경에서도 아래와 같이 자동화시키는 것도 가능함.

먼저 현재 구성된 완전관리형 노드의 오토스케일링 그룹 상태 확인.

```
aws autoscaling \
    describe-auto-scaling-groups \
    --query "AutoScalingGroups[? Tags[? (Key=='eks:cluster-name') && Value=='CLUSTER_NAME']].[AutoScalingGroupName, MinSize, MaxSize,DesiredCapacity]" \
    --output table
```

아래와 같은 방법으로 ASG의 사양을 변경하면 끝임. (즉, EKS보다는 ASG 설정 자체를 변경하는 느낌임)

```
export ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[? Tags[? (Key=='eks:cluster-name') && Value=='CLUSTER_NAME']].AutoScalingGroupName" --output text | awk '{ print $2 }')
aws autoscaling \
    update-auto-scaling-group \
    --auto-scaling-group-name ${ASG_NAME} \
    --min-size 3 \
    --desired-capacity 3 \
    --max-size 4
```

### Service Account 기반으로 Auto-scaling 세팅하기

서비스 어카운트를 통해 모든 포드의 컨테이너에 AWS 권한을 제공하여 CA 포드가 AWS API를 호출할 수 있도록 할 수 있음. **이를 통해 사람이 직접 ASG 값을 수정하지 않고 오직 POD replica 수에 의존하여 자동적으로 Node 수도 변경되도록 설정 가능**.

- 먼저, OIDC Provider를 만들어야 함. `README.md` 문서 참고.

- 그다음 `cluster-autoscaler-policy.json`을 생성해주어야 함. `policy/` 경로 참고.

그다음 이걸로 새로운 정책을 만들어줌.

```
aws iam create-policy \
    --policy-name AmazonEKSClusterAutoscalerPolicy \
    --policy-document file://./policy/cluster-autoscaler-policy.json
```

마지막으로 해당 정책을 attach시켜 service account를 만들어 줌.

```
eksctl create iamserviceaccount \
  --cluster=my-cluster \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=arn:aws:iam::111122223333:policy/AmazonEKSClusterAutoscalerPolicy \
  --override-existing-serviceaccounts \
  --approve
```

**윗부분도 마찬가지로 eksctl config yml에서 쇼트컷을 제공함. `with-oidc.yml` 참고.**

```
// 확인
kubectl -n kube-system describe sa cluster-autoscaler
```

CA pod를 다운받아서 배포해주면 됨.

```
curl -O https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
kubectl apply -f cluster-autoscaler-autodiscover.yaml
// CA 포드가 실행중인 노드를 제거하지 못하게 방지하도록 annotation 추가
kubectl -n kube-system \
    annotate deployment.apps/cluster-autoscaler \
    cluster-autoscaler.kubernetes.io/safe-to-evict="false"
// 얘들은 공식문서에는 적혀있는게 가이드에는 없음. 할까말까?
kubectl annotate serviceaccount cluster-autoscaler \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/AmazonEKSClusterAutoscalerRole
kubectl -n kube-system edit deployment.apps/cluster-autoscale
// spec.containers.commad: 마지막에 이거 추가
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
```

오토 스케일링 로그는 여기에서 확인할 수 있음.

```
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler
```



## k8s 대시보드

- https://whchoi98.gitbook.io/k8s/observability/k8s-dashboard
- [k8s Dashboard git](https://github.com/kubernetes/dashboard)

k8s 대시보드는  웹 기반 쿠버네티스 유저 인터페이스임. 클러스터 파드 배포, 에러 트러블슈팅, 롤링 업데이트 등 거의 모든 액션을 웹에서 수행할 수 있도록 도와줌.

- 대시보드를 위해서는 먼저 **metric-server**가 설치되어야 함. `README.md` 참고.

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.6.1/aio/deploy/recommended.yaml
// 확인 방법
kubectl -n kubernetes-dashboard get svc -o wide
```

기본적으로는 설치해도 대시보드 사용자의 권한이 제한되어 있기에 이를 관리자 권한 수준으로 만들 필요가 있음.

자세한 역할 바인딩 정보는 `eks-admin-service-account.yaml` 참고.

```
kubectl apply -f sa/eks-admin-service-account.yaml
```

### 대시보드 접속하기

kubernetes dashboard는 ClusterIP 타입으로 서비스 배포되기 때문에 외부에서 접근 불가능함. 때문에 무조건 `kubectl proxy` 명령어를 통해서만 접속이 가능함.

```
// 토큰 조회하기, 여기서 뜨는 토큰 복사해두기
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')
// 대쉬보드 접속을 위한 프록시 실행하기
kubectl proxy --port=8080 --address=0.0.0.0 --disable-filter=true
// 프록시로 클러스터 대시보드에 접속하기
http://localhost:8080/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### **Prometheus-Grafana**

- [k8s workshop](https://whchoi98.gitbook.io/k8s/observability/prometheus-grafana)
- [Promtheus Getting started on Docker](https://wjdqudgnsdlqslek.tistory.com/44)
- [Prometheus & Grafana 간단 연동하기](https://benlee73.tistory.com/60)

### 프로메테우스 세팅하기

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl create namespace prometheus
helm upgrade -i prometheus prometheus-community/prometheus \
    --namespace prometheus \
    --set alertmanager.persistentVolume.storageClass="gp2",server.persistentVolume.storageClass="gp2"
// 배포 확인하기
kubectl -n prometheus get all
// 프록시로 접근하기
kubectl port-forward -n prometheus deploy/prometheus-server 8081:9090
http://localhost:8081/targets
```

프로메테우스의 데이터 저장주기는 기본 저장주기는 [15일](https://prometheus.io/docs/prometheus/latest/storage/#operational-aspects)이라고 함. 필요하다면 옵션을 통해 조절할 수 있을 듯.

### 그라파나 구성하기

```
kubectl create namespace grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana \
    --namespace grafana \
    --set persistence.storageClassName="gp2" \
    --set persistence.enabled=true \
    --set adminPassword='password' \
    --values ./grafana.yml \
    --set service.type=LoadBalancer
// 배포 확인하기ㅡ 여기서 도메인 복사해서 접근하기
kubectl -n grafana get all
```

그 후, [이 링크](https://whchoi98.gitbook.io/k8s/observability/prometheus-grafana#7.cluster-monitoring)를 따라서 import 설정 수행하기.



## 로그 통합 관리 (EFK)

- https://whchoi98.gitbook.io/k8s/observability/efk-logging

EFK란 Elasticsearch + Fluentd + Kibana의 조합을 일컫는다. 모든 파드에서 발생하는 로그를 통합하여 관리할 수 있다.

- OIDC Provider 설정하기 `README.md` 참고.

플런트 비트를 사용하기 위한 정책 생성하기. `fluent-bit-policy.json` 참고 

(리전, 아이디, ES 도메인 작성 필요)

```
aws iam create-policy   \
  --policy-name fluent-bit-policy \
  --policy-document file://./policy/fluent-bit-policy.json
```

마찬가지로 해당 정책을 바탕으로 서비스 어카운트도 생성해주기.

```
eksctl create iamserviceaccount \
    --name fluent-bit \
    --namespace fluent-bit \
    --cluster <CLUSTER_NAME> \
    --attach-policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/fluent-bit-policy" \
    --approve \
    --override-existing-serviceaccounts
// 확인
kubectl -n fluent-bit describe serviceaccounts fluent-bit
```

### ES(ElasitcSearch) 설치 및 세팅하기

AWS OpenSearch에 직접 들어가서 할 수도 있겠지만 일단 여기서는 CLI에서 해보도록 하겠음. 최대한 라이트한 옵션에서 실행시켜 보도록 함. 모든 옵션은 라이브에서 약간의 다운타임 혹은 무중단으로 업데이트가 가능한 것 같음!

```
aws es create-elasticsearch-domain \
  --cli-input-json  file://./es_light.json
```

클러스터의 fluent ARN 서비스 어카운트가 ES API를 통해 Backend 권한을 받아 접근할 수 있도록 설정 해주어야 함.

```
export FLUENTBIT_ROLE=$(eksctl get iamserviceaccount --cluster <CLUSTER_NAME> --namespace fluent-bit -o json | jq '.[].status.roleARN' -r)
export ES_ENDPOINT=$(aws es describe-elasticsearch-domain --domain-name ${ES_DOMAIN_NAME} --output text --query "DomainStatus.Endpoint")
// 권한 부여
curl -sS -u 'imiml:!Pasword123' \
    -X PATCH \
    https://${ES_ENDPOINT}/_opendistro/_security/api/rolesmapping/all_access\?pretty \
    -H 'Content-Type: application/json' \
    -d'
[
  {
    "op": "add", "path": "/backend_roles", "value": ["'${FLUENTBIT_ROLE}'"]
  }
]
'
```

그 후, `fluentbit.yml`을 실행시켜서 Daemonset를 세팅해준다. 데몬셋이기 때문에 추후에 노드가 늘어나도 자동으로 생겨나며 관리됨.

```
kubectl apply -f ./fluentbit.yml
// 배포 확인하기
kubectl -n fluent-bit get all
```

그 후, [키바나](https://whchoi98.gitbook.io/k8s/observability/efk-logging#kibana-.)에 들어가서 대시보드 세팅후 탐색하기.



## Container Insights (CW)

- https://whchoi98.gitbook.io/k8s/observability/container-insights
- https://docs.aws.amazon.com/ko_kr/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-logs-FluentBit.html

AWS의 CW에서 지원하는 자체 메트릭 수집 및 로깅 서비스임. 좀더 AWS에 의존하게 되겠지만 매니지드 서비스이기에 안정성이 확보된다고 보면 됨.

```
STACK_NAME=$(eksctl get nodegroup --cluster <CLUSTER_NAME> -o json | jq -r '.[].StackName')
echo $STACK_NAME
```



**[TODO] 노드 그룹이 추가되어도 모니터링이 될까?**



## 쿠버네티스 크론잡



# References

- [Promtheus Getting started on Docker](https://wjdqudgnsdlqslek.tistory.com/44)
- [Prometheus & Grafana 간단 연동하기](https://benlee73.tistory.com/60)

- https://eksctl.io/introduction/
- https://catalog.us-east-1.prod.workshops.aws/workshops/9c0aa9ab-90a9-44a6-abe1-8dff360ae428/ko-KR/10-intro
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html
- https://whchoi98.gitbook.io/k8s/
- https://awskocaptain.gitbook.io/aws-builders-eks/