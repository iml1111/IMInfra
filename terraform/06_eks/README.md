# 06_EKS

## Get Started

```shell
# setup
terraform apply -auto-approve
aws eks --region ap-northeast-2 update-kubeconfig --name $(terraform output -raw cluster_name)
# metric-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# aws-lb serviceaccounts
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
kubectl apply -f https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.3/v2_4_3_full.yaml

# test 
kubectl get sa -A
kubectl create namespace ingress-sample
kubectl apply -f ./sample.yml
```
# TODO
- 로드 밸런서 연동이 안됨. 이것도 헬름으로 바꾸는게 좋을려나?

# References
- https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
- https://github.com/terraform-aws-modules/terraform-aws-eks
- https://github.com/terraform-aws-modules/terraform-aws-vpc
- https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/examples/complete-vpc/main.tf

## IAM Service Account
- https://github.com/terraform-aws-modules/terraform-aws-iam/tree/v5.10.0/modules/iam-role-for-service-accounts-eks
- https://github.com/terraform-aws-modules/terraform-aws-iam/blob/v5.10.0/examples/iam-role-for-service-accounts-eks/main.tf

## Karpenter
- https://karpenter.sh/v0.22.0/getting-started/getting-started-with-terraform/
- https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v19.5.1/examples/karpenter/main.tf