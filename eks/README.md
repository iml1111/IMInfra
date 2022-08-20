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

eks워크샵에 다루는 샘플 템플릿임. 개인적으로 이쪽이 좀 더 프로덕션에 가깝다고 생각함.
그외에 더 다양한 템플릿은 myeks 깃허브에서 확인 가능함.
(NEW_VPC3AZ.yml의 경우, 기존 VPC3AZ에서 퍼블릭 서브넷이 6개로 증가한 예제임.)
```
aws cloudformation deploy \
  --stack-name "my-eks-vpc-stack" \
  --template-file ./vpc/VPC3AZ.yml \
  --capabilities CAPABILITY_NAMED_IAM 
```
위 `VPC3AZ.yml`로 생성한 경우,
3개의 AZ에 각각 퍼블릭/프라이빗 서브넷이 1개씩 배치된 총 6개의 서브넷과 
미래에 TGW(trasit gateway)를 위한 서브넷 총 3개가 생겨나게 됨.
그외에 클러스터를 위한 보안그룹이 추가로 1개 더 생겨남.



## EKS Cluster & 노드그룹 생성하기

eks 클러스터를 생성하기 위해 사전에 설정한 값들을 yml에서 써줄 필요가 있음.

### 노드 그룹의 SSH 키 및 KMS Encryption 설정
필요한 경우, 얘들도 해줄 필요가 있는데 없어도 된다면 일단 나중에 하기로 함 (TODO)
ssh 키의 경우 SSM을 사용해서 웹 console을 통해서도 접속이 가능하기 때문에 꼭 할 필요는 없음.
- [eks 인증/자격증명 및 환경 구성](https://awskocaptain.gitbook.io/aws-builders-eks/2.)
```
# 생성된 값들을 참조해서 CLUSTER*.yml을 작성한 후, 적절한 클러스터 config 실행.
# 해당 예제는 VPC3AZ.yml과 대응됨.
eksctl create cluster --config-file=./cluster/CLUSTER3AZ.yml

# 만약 반대로 클러스터를 죽이고 싶다면,
eksctl delete cluster --name <CLUSTER_NAME>
```
위 예제 `CLUSTER3AZ.yml`로 실행시킨 경우,
퍼블릭/프라이빗 노드 그룹(총 2개의 그룹)이 3개의 AZ에 포진된 형태로 형성됨.
노드 그룹의 각 캐퍼시티는 현재는 2 ~ 4개 사이이며, t2.medium 인스턴스를 사용함.


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
# nodeport-sample이라는 이름의 네임스페이스 생성
kubectl create namespace nodeport-sample

# 현재 존재하는 네임스페이스 조회
kubectl get namespace

# 만약 yml에 네임스페이스가 선언되어 있다면 -n을 스킵해도 됨.
kubectl -n nodeport-sample apply -f ./deployment/hello_flask.yml
kubectl apply -f ./deployment/hello_flask.yml

# 배포된 pod 확인해보기
kubectl -n nodeport-sample get pods -o wide
```





# References

- https://eksctl.io/introduction/
- https://catalog.us-east-1.prod.workshops.aws/workshops/9c0aa9ab-90a9-44a6-abe1-8dff360ae428/ko-KR/10-intro
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html
- https://whchoi98.gitbook.io/k8s/
- https://awskocaptain.gitbook.io/aws-builders-eks/
