variable "install_monitoring_stack" {
  description = "Install Prometheus and Grafana in EKS using kube-prometheus-stack Helm chart"
  type        = bool
  default     = true
}
