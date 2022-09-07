# EKS

## Requirements

아래 툴들은 알아서 설치합시다.

- AWS CLI
- kubectl
- eksctl

## VPC 생성하기

먼저 cloud formation으로 적절한 VPC 세팅을 구축합니다.
이미 만들어진 다양한 VPC 템플릿이 있는데 이 중에서 적절한 걸 골라서 해봅시다.

### EKS_DOC_SAMPLE_VPC.yml
- [EKS 클러스터 도큐먼트 링크](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/getting-started-console.html)

EKS 도큐먼트에서 공개되어 있는 VPC 생성 템플릿임. 아래와 같은 명령어로 실행가능함.
region 및 stack_name에 적절한 이름을 넣어서 실행가능함.
```
aws cloudformation create-stack \
  --region ap-northeast-2 \
  --stack-name my-eks-vpc-stack \
  --template-file ./vpc/EKS_DOC_SAMPLE_VPC.yml
```

### VPC[*]AZ.yml
- [EKS 워크샵 VPC 설정 링크](https://awskocaptain.gitbook.io/aws-builders-eks/3.-vpc)
- [myeks 깃허브](https://github.com/whchoi98/myeks)

eks워크샵에 다루는 샘플 템플릿임. **개인적으로 이쪽이 좀 더 프로덕션에 가깝다고 생각**함.
그외에 더 다양한 템플릿은 myeks 깃허브에서 확인 가능함.
(NEW_VPC3AZ.yml의 경우, 기존 VPC3AZ에서 퍼블릭 서브넷이 6개로 증가한 예제임.) 

- 퍼블릭 서브넷이 6개로 증가하면 뭐가 좋을까?

```
aws cloudformation deploy \
  --stack-name "my-eks-vpc-stack" \
  --template-file ./vpc/VPC3AZ.yml \
  --capabilities CAPABILITY_NAMED_IAM
// 삭제하려면,
aws cloudformation delete-stack --stack-name <STACK-NAME>
```
위 `VPC3AZ.yml`로 생성한 경우,
3개의 AZ에 각각 퍼블릭/프라이빗 서브넷이 1개씩 배치된 총 6개의 서브넷과 
미래에 TGW(trasit gateway)를 위한 서브넷 총 3개가 생겨나게 됨.
그외에 클러스터를 위한 보안그룹이 추가로 1개 더 생겨남.



## EKS Cluster & 노드그룹 생성하기

eks 클러스터를 생성하기 위해 사전에 설정한 값들을 yml에서 써줄 필요가 있음.

### 노드 그룹의 SSH 키 및 KMS Encryption 설정
필요한 경우, 얘들도 해줄 필요가 있는데 없어도 된다면 일단 나중에 하기로 함 **(TODO)**
ssh 키의 경우 SSM을 사용해서 웹 console을 통해서도 접속이 가능하기 때문에 꼭 할 필요는 없음.

- [eks 인증/자격증명 및 환경 구성](https://awskocaptain.gitbook.io/aws-builders-eks/2.)
```
// 생성된 값들을 참조해서 CLUSTER*.yml을 작성한 후, 적절한 클러스터 config 실행.
// 해당 예제는 VPC3AZ.yml과 대응됨.
eksctl create cluster --config-file=./cluster/CLUSTER3AZ.yml
// 만약 반대로 클러스터를 죽이고 싶다면,
eksctl delete cluster --name <CLUSTER_NAME>
```
위 예제 `CLUSTER3AZ.yml`로 실행시킨 경우,
퍼블릭/프라이빗 노드 그룹(총 2개의 그룹)이 3개의 AZ에 포진된 형태로 형성됨.
노드 그룹의 각 캐퍼시티는 현재는 2 ~ 4개 사이이며, t2.medium 인스턴스를 사용

### 클러스터 설정 갱신하기

- [eksctl upgrade](https://eksctl.io/usage/cluster-upgrade/)
- [기본 add-on 업데이트하기](https://eksctl.io/usage/addon-upgrade/)
- [다양한 ClusterConfig 모음](https://github.com/weaveworks/eksctl/tree/main/examples)

원하는 만큼, 기존 클러스터 yml을 수정한 뒤, upgrade를 수행. 

**단 nodegroup에 대한 갱신 정보가 바뀌지는 않는 것 같음..**

```
eksctl upgrade cluster --config-file <cluster.yaml>
```

### 노드그룹 설정 변경하기

새로운 노드 그룹을 생성한 뒤, 아래의 명령어로 새로 만드는 것은 가능. 단, 기존의 노드 그룹의 사양 정보를 config 파일 수정만으로 변경하는 방법을 아직 모르겠음.

```
eksctl create nodegroup --config-file <CLUSTER.YML>
```

멱등성을 포기하고 `scale` 커맨드로 노드 그룹의 오토스케일링 사양을 변경하는 방법은 아래와 같음.

```
// Tony-Test 클러스터의 managed-ng-public-01 노드그룹에 2,2,4 오토스케일링 세팅.
eksctl scale nodegroup --name=managed-ng-public-01 --cluster=Tony-Test --nodes=2 --nodes-min=2 --nodes-max=4
```



## Cluster와 cli 연동 확인하기

해당 클러스터와 kubectl이 통신할 수 있도록 awscli를 통해 config 수정.
```
aws eks update-kubeconfig \
--region ap-northeast-2 \
--name <CLUSTER_NAME>
```
아래와 같은 느낌의 결과가 나온다면 클러스터의 접속에 성공한 것임.
만약 안될 경우, 클러스터를 만든 IAM 사용자와 현재 접속하려는 사용자가 일치하는지 확인 필요.
```
$ kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP 
kubernetes   ClusterIP   10.100.0.1   <none> 
```

## 다른 계정에서 EKS Cluster에 접근 권한 부여하기

초기 클러스터를 만든 당시에는 클러스터를 만든 본인 관리자 밖에 콘솔 및 cli에서 접근 못함.
추가적으로 IAM 사용자나 ROLE를 늘려주고 싶을 경우 2가지 방법이 있음.

먼저 아래의 명령어를 때려 봄.
```
kubectl describe configmap -n kube-system aws-auth
```
aws-auth라는 configmap이 이미 만들어져 있을수도 있고 아닐수도 있음.
대개 웹 콘솔에서 직접 클러스터를 만들었다면 없을 확률이 높음.

### aws-auth configmap이 없을 경우
동봉된 `aws-auth-cm.yml` 파일에 자신이 원하는 user 혹은 role 정보를 작성함.
- [User or Role 작성 참고 링크](https://aws.amazon.com/ko/premiumsupport/knowledge-center/eks-api-server-unauthorized-error/)
적절히 잘 작성을 완료해준 아래와 같이 실행하면 됨.
```
"""
이 안에 적절한 값을 써 넣어서 권한을 추가할 수 있다.
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
	  - userarn: arn:aws:iam::XXXXXXXXX:user/tony
	    username: tony
	    groups:
	      - system:masters
"""
kubectl apply -f ./configmap/aws-auth-cm.yaml
```

### aws-auth configmap이 있을 경우
에러가 뜨지 않을 경우, 아래의 명령어를 치면 Editor가 직접 나오게 됨.
해당 Editor에서 위에서 처음 만들때랑 같은 형식으로 수정해주고 저장해주면 됨.
저장할때는 `:wq`

```
kubectl edit configmap aws-auth --namespace kube-system
```


## Nodeport로 간단 로드밸런싱 서비스 배포하기
- [Nodeport 기반 배포](https://whchoi98.gitbook.io/k8s/eks-1/nodeport)
- [NodePort에 대한 개념 정리](https://yoonchang.tistory.com/49)

노드포트는 가장 쉽게 밖에 파드를 노출시킬 수 있는 방법입니다?(카더라)

노드 그룹에 첫번째 파드를 배포해봅시다.

```
// nodeport-sample이라는 이름의 네임스페이스 생성
// 앞으로 -n nodeport-sample 은 해당 네임스페이스에서 동작한다는 걸 의미함.
kubectl create namespace nodeport-sample
// 현재 존재하는 네임스페이스 조회
kubectl get namespace
// 만약 yml에 네임스페이스가 선언되어 있다면 -n을 스킵해도 됨.
kubectl -n nodeport-sample apply -f ./deployment/hello-flask.yml
kubectl apply -f ./deployment/hello-flask.yml
// 배포된 pod 확인해보기
kubectl -n nodeport-sample get pods -o wide
// 배포된 디플로이먼트(nodeport-sample) 확인해보기
kubectl get deployment hello-flask-deployment -n nodeport-sample
```
노드포트 서비스를 배포해보자.
```
kubectl apply -f ./service/hello-flask-nodeport.yml
kubectl -n nodeport-sample get svc -o wide
```
이제 접속을 해야하는데 노출된 Nodeport에 접근하려면 해당 EC2 IP에 직접 접근할 수 있음.
EC2 대시보드 접근 해야 함.

- [노드 포트 시험하기](https://whchoi98.gitbook.io/k8s/eks-1/nodeport#2.nodeport-service)

위 링크에서 시작하는 이미지 설명을 따라가서, 보안그룹을 설정해주어야 함. 

(맨처음 만든 노드그룹들은 해당 설령 퍼블릭이라도 어떤 포트도 외부에 열려있지 않기 때문임)

기존 보안그룹에 인바운드 규칙을 수정하는 것도 안될 것 없을 것 같지만 자체 관리를 위해 새로운 보안그룹을 생성해서 각각의 EC2에 추가해주는 걸 추천함. (안전!)

### 클러스터 내부에서 서비스로 통신하기

서비스 ymlkubectl get hpa 작성시에 `metadata.name`에 작성된 것을 호스트로, `spec.ports[].port` 를 포트로 해서 클러스터 내부의 서비스들도 접근할 수 있도록 할 수 있음.

- [Service(ClusterIP) 만들기 및 테스트](https://subicura.com/k8s/guide/service.html#service-clusterip-%E1%84%86%E1%85%A1%E1%86%AB%E1%84%83%E1%85%B3%E1%86%AF%E1%84%80%E1%85%B5)



## 파드 업데이트하기

어플리케이션의 업데이트란, 해당 이미지의 변경을 의미함.
- **이미지의 이름이나 태그가 바뀌지 않았는데 새로 pull받아서 리로드하는 방법이 있는지 아직 모르겠음**
```
// apply로 업데이트하기 (그냥 yml 파일 수정해서 apply 하면 됨, 가급적이면 이게 이상적일듯)
kubectl apply -f ./deployment/hello-flask.yml
// hello-flask-deployment 디플로이먼트의 <컨테이너>=<새로운_이미지>로 롤링 업데이트하기
kubectl set image deployment hello-flask-deployment hello-flask=iml1111/hello_flask -n nodeport-sample
// 해당 디플로이먼트의 업데이트 히스토리 조회
kubectl rollout history deployment hello-flask-deployment -n nodeport-sample
// 해당 디플로이먼트의 롤링 업데이트 상황 확인
kubectl rollout status deployment hello-flask-deployment -n nodeport-sample
```

모든 업데이트의 자동 정책은 롤링 업데이트됨.

- [디플로이먼트 업데이트](https://kubernetes.io/ko/docs/concepts/workloads/controllers/deployment/#%EB%94%94%ED%94%8C%EB%A1%9C%EC%9D%B4%EB%A8%BC%ED%8A%B8-%EC%97%85%EB%8D%B0%EC%9D%B4%ED%8A%B8)

### 업데이트가 실패하는 경우
당연히 yml 문법이 틀린 경우 애초에 업데이트 배포 자체가 실패하므로 패스.
그 외에, 업데이트하려는 docker image가 제대로 실행되지 않을 경우, `CrashLoopBackOff`라는 에러를 계속해서 겪을 수 있음. 이 경우, 그냥 다시 한번 `apply` 나 `set image`를 실행시켜서 덮어씌워주면 됨.

다행히 이 순간에도 기존 서비스에 영향을 끼치지는 못하는 듯.

- [포드가 CrashLoopBackOff 상태에 있음](https://aws.amazon.com/ko/premiumsupport/knowledge-center/eks-pod-status-troubleshooting/)

## ECR 프라이빗 레파지토리 & 서비스 배포 한번에 하기

ECR에 있으면 그냥 한번에 됨.

```
kubectl apply -f ./deployment/some-private.yml
```

`some-private.yml`에는 ECR에 있는 프라이빗 이미지와 해당 파드를 연결시킬 노드포트 서비스가 한번에 작성되어 있음. 걍 저거 한 줄 치면 바로 배포됨.

## 레플리카 파드 오토 스케일링하기

- [HorizontalPodAutoscaler 연습](https://kubernetes.io/ko/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/#%EB%8B%A4%EB%A5%B8-%EA%B0%80%EB%8A%A5%ED%95%9C-%EC%8B%9C%EB%82%98%EB%A6%AC%EC%98%A4)
- [[K8S] Kubernetes의 HPA를 활용한 오토스케일링(Auto Scaling)](https://medium.com/dtevangelist/k8s-kubernetes%EC%9D%98-hpa%EB%A5%BC-%ED%99%9C%EC%9A%A9%ED%95%9C-%EC%98%A4%ED%86%A0%EC%8A%A4%EC%BC%80%EC%9D%BC%EB%A7%81-auto-scaling-2fc6aca61c26)
- https://whchoi98.gitbook.io/k8s/eks-2/autoscaling

파드 오토스케일러라는게 존재하는 듯 함. 기존 디플로이먼트에는 전혀 영향을 끼치지 않고 독자적으로 동작하는 듯.

### metric-server 세팅하기

오토스케일링을 하기 위해서 노드의 CPU, Memory 메트릭을 수집할 수 있는 애드온 파드가 필요함. 다행히도 쿠버네티스 측에서 거의 반공식적으로 이걸 만들어서 지원함. 그냥 아래 블로그에서 시키는 대로 실행시켜서 세팅하면 됨.

- [HPA 세팅 실습, 개인적으로 얘가 설명 제일 잘함](https://saramin.github.io/2022-05-17-kubernetes-autoscaling/)
- [metric-server git](https://github.com/kubernetes-sigs/metrics-server#deployment)

```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# metrict-api-server 확인
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
kubectl top pod --all-namespaces
```

그 후, 스펙에 맞는 yml을 작성해준 뒤, 실행시켜줌.

```
kubectl apply -f ./podscaler/hello-flask.yml
// "hpa" 또는 "horizontalpodautoscaler" 둘 다 사용 가능
kubectl get hpa -n nodeport-sample
```

해당 코드를 실행시키면, `hello-flask-deployment` 에 연동되어 CPU 유틸라이제이션이 50%를 넘으면 1-10 사이에서 오토스케일링을 실행함.

### 트러블 슈팅 - [unknown]이 표기될 경우

반드시 디플로이먼트에 아래와 같이 명시를 해주어야 함. 이걸 하지 않으면 metric-server가 구축되어 있더라도 지표 수집을 수행하지 않아 unknown이 뜨게 되어 오토스케일링이 되지 않음;;;

```
 // 최소한 해당 pod에 CPU를 10% 이상은 할당해줬으면 좋겠다는 뜻.
        resources:
          requests:
            cpu: "100m"
```

## ALB Ingress 배포하기
- https://whchoi98.gitbook.io/k8s/5.eks-ingress/alb-ingress
- https://awskocaptain.gitbook.io/aws-builders-eks/6.-eks-ingress#ingress
- https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/deploy/installation/

### AWS LB IAM Policy 생성

ALB Controller IAM 역할을 생성하기 위한 정책.json 파일 다운로드 및 정책 생성.

- **이 과정은 계정당 한번은 꼭 해야 하는 듯 함 주의!**

```
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.3/docs/install/iam_policy.json
// Policy 뭐시기가 출력되면 생성 성공!
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json
```

### IAM OIDC Provider 및 정책을 연동한 Service Account 생성

이 자격 증명을 사용하여 AWS 서비스 자원들을 Kubernetes 자원들이 사용할 수 있다고 함. [withOIDC](https://eksctl.io/usage/schema/#iam-withOIDC)라는 옵션이 eksctl에 있던데 나중에 이걸로 한번에 되는지 확인 필요.

```
eksctl utils associate-iam-oidc-provider \
    --region ${AWS_REGION} \
    --cluster ${ekscluster_name} \
    --approve
아래의 명령어로 확인 가능.
aws eks describe-cluster --name ${ekscluster_name} --query "cluster.identity.oidc.issuer" --output text
aws iam list-open-id-connect-providers
```

- [eksctl serviceaccount config 예시](https://github.com/weaveworks/eksctl/blob/main/examples/13-iamserviceaccounts.yaml)

위에서 생성한 정책을 연동시킨 Service Account 생성하기. 단, 이것도 eksctl config에 예제가 존재하는 듯 하나 추후에 예제를 직접 생성해서 확인 필요.

```
eksctl create iamserviceaccount \
--cluster=<cluster-name> \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
--override-existing-serviceaccounts \
--region ap-northeast-2 \
--approve
// 아래 명령어로 생성 확인 가능
kubectl get serviceaccounts -n kube-system aws-load-balancer-controller -o yaml
// 아래의 명령어로 삭제 가능?
eksctl create iamserviceaccount \
--name=aws-load-balancer-controller \
--cluster=<cluster-name>
```

**`with-alb-controller.yml` 파일로 위의 과정을 스킵하고 한번에 만들 수 있는듯 함. 참고해보자.**

그다음은 인증서 관리자를 설치해준다.

```
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml
```

### AWS Loadbalancer Controller Pod 설치

load balancer controller pod 설치를 위한 yaml를 설치한다. 

```
wget https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.3/v2_4_3_full.yaml
```

- `cluster_name`을 자신의 클러스터명으로 변경한다. 
- 아까 이미 생성했으므로, `kind: ServiceAccount` 부분 전체를 주석친다.

```
kubectl apply -f v2_4_3_full.yaml
```

### Ingress로 ALB 시험해보기

이제 인그레스(=ALB)를 yml로 쉽게 만들어낼 수 있다. 바로 실험해보자.

```
kubectl create namespace ingress-sample
// public subnet 노드 그룹에 배포 및 서비스 연결
k apply -f ./deployment/hello-flask.yml
k apply -f ./service/hello-flask-nodeport.yml
k apply -f ingress/hello-flask.yml
// private subnet 노드 그룹에도 배포
k apply -f ./deployment/hello-flask-backnode.yml
k apply -f service/hello-flask-backnode-nodeport.yml
k apply -f ingress/hello-flask-backnode.yml
```
프라이빗 서브넷의 노드에도 이렇게 하면 충분히 접근이 가능하기 때문에 가급적이면 이쪽이 추천된다고 함. 물론 퍼블릭도 포트를 아예 막아버리면 접근을 못하긴 하는데 솔직히 이부분의 명확한 차이는 모르겠음.

TODO: 잉그레스 스펙 문서화 정리하기


# References

- https://eksctl.io/introduction/
- https://catalog.us-east-1.prod.workshops.aws/workshops/9c0aa9ab-90a9-44a6-abe1-8dff360ae428/ko-KR/10-intro
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html
- https://whchoi98.gitbook.io/k8s/
- https://awskocaptain.gitbook.io/aws-builders-eks/
