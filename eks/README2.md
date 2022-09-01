# EKS 2

## Helm

## Node 레벨 Auto-scaling

- https://whchoi98.gitbook.io/k8s/eks-2/autoscaling#ca-node

클러스터 오토스케일링은 AWS의 Auto Scaling Group과 연계하여 제공함.  먼저 현재 구성된 완전관리형 노드의 오토스케일링 그룹 상태 확인.

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

서비스 어카운트를 통해 모든 포드의 컨테이너에 AWS 권한을 제공하여 CA 포드가 AWS API를 호출할 수 있도록 할 수 있음.

먼저, OIDC Provider를 만들어야 함. `README.md` 문서 참고.





## 로그 통합 관리

k9s에서 각 파드별로는 되는 것 같은데, 통합은 어떻게 해야 하는가?

## 리소스 대시보드



# References

- https://eksctl.io/introduction/
- https://catalog.us-east-1.prod.workshops.aws/workshops/9c0aa9ab-90a9-44a6-abe1-8dff360ae428/ko-KR/10-intro
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html
- https://whchoi98.gitbook.io/k8s/
- https://awskocaptain.gitbook.io/aws-builders-eks/