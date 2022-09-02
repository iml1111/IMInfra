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
    --policy-document ./policy/cluster-autoscaler-policy.json
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
// 토큰 조회하기
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep eks-admin | awk '{print $1}')
// 대쉬보드 접속을 위한 프록시 실행하기
kubectl proxy --port=8080 --address=0.0.0.0 --disable-filter=true &
```

### **Prometheus-Grafana**

- [k8s workshop](https://whchoi98.gitbook.io/k8s/observability/prometheus-grafana)
- [Promtheus Getting started on Docker](https://wjdqudgnsdlqslek.tistory.com/44)
- [Prometheus & Grafana 간단 연동하기](https://benlee73.tistory.com/60)



## 로그 통합 관리

- https://whchoi98.gitbook.io/k8s/observability/efk-logging
- https://whchoi98.gitbook.io/k8s/observability/container-insights

k9s에서 각 파드별로는 되는 것 같은데, 통합은 어떻게 해야 하는가?



# References

- [Promtheus Getting started on Docker](https://wjdqudgnsdlqslek.tistory.com/44)
- [Prometheus & Grafana 간단 연동하기](https://benlee73.tistory.com/60)

- https://eksctl.io/introduction/
- https://catalog.us-east-1.prod.workshops.aws/workshops/9c0aa9ab-90a9-44a6-abe1-8dff360ae428/ko-KR/10-intro
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html
- https://whchoi98.gitbook.io/k8s/
- https://awskocaptain.gitbook.io/aws-builders-eks/