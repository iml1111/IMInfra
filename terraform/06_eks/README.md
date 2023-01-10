# 06_EKS

## Get Started

```shell
# setup
terraform apply -auto-approve
aws eks --region ap-northeast-2 update-kubeconfig --name $(terraform output -raw cluster_name)
# metric-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# aws-lb serviceaccounts
eksctl create iamserviceaccount \
--cluster=<cluster-name> \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
--override-existing-serviceaccounts \
--region ap-northeast-2 \
--approve
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
kubectl apply -f https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.3/v2_4_3_full.yaml

# test 
kubectl get nodes
kubectl create namespace ingress-sample
kubectl apply -f ./sample.yml
```
# TODO
- 서비스어카운트 자동화각 (07.data.tf도 같이 보자)
- 로드밸런서, 클러스터오토스케일러, 필요하면 더 알아보자.
https://github.com/terraform-aws-modules/terraform-aws-iam/tree/v5.10.0/modules/iam-role-for-service-accounts-eks


# References

- https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
- https://github.com/terraform-aws-modules/terraform-aws-eks

- https://github.com/terraform-aws-modules/terraform-aws-vpc
- https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/examples/complete-vpc/main.tf