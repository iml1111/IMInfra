# 06_EKS

## Get Started

```shell
# setup
terraform apply -auto-approve
aws eks --region ap-northeast-2 update-kubeconfig --name $(terraform output -raw cluster_name)
## cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
## k8s dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl apply -f eks-admin-service-account.yaml


# test 
kubectl get sa -A
kubectl create namespace ingress-sample
kubectl apply -f ./sample.yml
## dashboard
kubectl -n kubernetes-dashboard create token admin-user
kubectl proxy
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```
# TODO

# References
- https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
- https://github.com/terraform-aws-modules/terraform-aws-eks
- https://github.com/terraform-aws-modules/terraform-aws-vpc
- https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/examples/complete-vpc/main.tf

## IAM Service Account
- https://github.com/terraform-aws-modules/terraform-aws-iam/tree/v5.10.0/modules/iam-role-for-service-accounts-eks
- https://github.com/terraform-aws-modules/terraform-aws-iam/blob/v5.10.0/examples/iam-role-for-service-accounts-eks/main.tf

## aws-load-balancer-controller
- https://andrewtarry.com/posts/terraform-eks-alb-setup/

## Karpenter
- https://karpenter.sh/v0.22.0/getting-started/getting-started-with-terraform/
- https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v19.5.1/examples/karpenter/main.tf