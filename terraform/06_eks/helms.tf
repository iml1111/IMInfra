# https://gist.github.com/TylerWanner/8b38494bea6535fa10936c5a81678c78
# 이상하게 이 친구는 헬름으로 안깔림. README에 기재된 직접 설치로 ㄱㄱ
# resource "helm_release" "cert-manager" {
#   name             = "cert-manager"
#   namespace        = "cert-manager"
#   create_namespace = true
#   chart            = "cert-manager"
#   repository       = "https://charts.jetstack.io"
#   #version          = "v1.10.1"
#   values = [
#     file("cert_manager_values.yaml")
#   ]
# }

# https://developc.tistory.com/entry/Terraform%EC%9C%BC%EB%A1%9C-helm-chart-%EB%B0%B0%ED%8F%AC%ED%95%98%EA%B8%B0
resource "helm_release" "metrics_server" {
  namespace        = "kube-system"
  name             = "metrics-server"
  chart            = "metrics-server"
  # version          = "3.8.2"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  create_namespace = true
  
  set {
    name  = "replicas"
    value = 2
  }
}