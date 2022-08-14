# EKS

## Requirements
아래 툴들은 알아서 설치합시다.

- AWS CLI
- kubectl
- eksctl

## VPC
먼저 cloud formation으로 적절한 VPC 세팅을 구축합니다.
이미 만들어진 다양한 VPC 템플릿이 있는데 이 중에서 적절한 걸 골라서 해봅시다.

### EKS_DOC_SAMPLE_VPC.yml
[EKS 클러스터 도큐먼트 링크](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/getting-started-console.html)
EKS 도큐먼트에서 공개되어 있는 VPC 생성 템플릿임. 아래와 같은 명령어로 실행가능함.
region 및 stack_name에 적절한 이름을 넣어서 실행가능함.
```
aws cloudformation create-stack \
  --region ap-northeast-2 \
  --stack-name my-eks-vpc-stack \
  --template-file EKS_DOC_SAMPLE_VPC.yml
```

### VPC[*]AZ.yml
eks워크샵에 다루는 샘플 템플릿임. 개인적으로 이쪽이 좀 더 프로덕션에 가깝다고 생각함.
(NEW_VPC3AZ.yml의 경우, 기존 VPC3AZ에서 퍼블릭 서브넷이 6개로 증가한 예제임.)
```
aws cloudformation deploy \
  --stack-name "my-eks-vpc-stack" \
  --template-file "VPC3AZ.yml" \
  --capabilities CAPABILITY_NAMED_IAM 
```