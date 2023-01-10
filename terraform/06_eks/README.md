# 06_EKS

## Get Started

```shell
terraform apply -auto-approve
aws eks --region ap-northeast-2 update-kubeconfig --name $(terraform output -raw cluster_name)
kubectl get nodes
```
# TODO
- coredns ImagePullBackOff
https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/deploy-coredns-on-amazon-eks-with-fargate-automatically-using-terraform-and-python.html



# References

- https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
- https://github.com/terraform-aws-modules/terraform-aws-eks

- https://github.com/terraform-aws-modules/terraform-aws-vpc
- https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/examples/complete-vpc/main.tf