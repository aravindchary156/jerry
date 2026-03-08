data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

resource "kubernetes_namespace" "monitoring" {
  count = var.install_monitoring_stack ? 1 : 0

  metadata {
    name = "monitoring"
  }

  depends_on = [aws_eks_node_group.main]
}

resource "helm_release" "kube_prometheus_stack" {
  count      = var.install_monitoring_stack ? 1 : 0
  name       = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name
  version    = "69.8.2"

  timeout           = 1800
  cleanup_on_fail   = true
  dependency_update = true

  values = [
    yamlencode({
      grafana = {
        service = {
          type = "LoadBalancer"
        }
      }
      prometheus = {
        service = {
          type = "LoadBalancer"
        }
      }
    })
  ]

  depends_on = [aws_eks_node_group.main, kubernetes_namespace.monitoring]
}
