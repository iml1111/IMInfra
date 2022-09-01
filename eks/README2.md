# EKS 2



## Helm

- https://whchoi98.gitbook.io/k8s/eks-2/helm
- https://nyeongnyeong.tistory.com/258



## Cluster Auto-scaling

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

- 먼저, OIDC Provider를 만들어야 함. `README.md` 문서 참고.

- 그다음 `cluster-autoscaler-policy.json`을 생성해주어야 함.

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
kubectl apply -f ./cluster_autoscaler.yml
// CA 포드가 실행중인 노드를 제거하지 못하게 방지하도록 annotation 추가
kubectl -n kube-system \
    annotate deployment.apps/cluster-autoscaler \
    cluster-autoscaler.kubernetes.io/safe-to-evict="false"
// 얘는 공식문서에는 적혀있는게 가이드에는 없음. 할까말까?
kubectl annotate serviceaccount cluster-autoscaler \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/AmazonEKSClusterAutoscalerRole
```

오토 스케일링 로그는 여기에서 확인할 수 있음.

```
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler
```





## 로그 통합 관리

k9s에서 각 파드별로는 되는 것 같은데, 통합은 어떻게 해야 하는가?

## 리소스 대시보드



# References

- https://eksctl.io/introduction/
- https://catalog.us-east-1.prod.workshops.aws/workshops/9c0aa9ab-90a9-44a6-abe1-8dff360ae428/ko-KR/10-intro
- https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/what-is-eks.html
- https://whchoi98.gitbook.io/k8s/
- https://awskocaptain.gitbook.io/aws-builders-eks/