terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.1.2"
    }
  }
}

provider "kubernetes" {
  config_path = var.kube_config
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config
  }
}

resource "helm_release" "kubeapps" {
  name             = "kubeapps"
  chart            = "https://charts.bitnami.com/bitnami/kubeapps-5.2.2.tgz"
  namespace        = "kubeapps"
  create_namespace = true

  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.hostname"
    value = "appcatalog.${var.domain}"
  }
  set {
    name  = "ingress.certManager"
    value = "true"
  }
  set {
    name  = "ingress.tls"
    value = "true"
  }
  set {
    name  = "frontend.replicaCount"
    value = "1"
  }
  set {
    name  = "ingress.annotations.ingress\\.kubernetes\\.io/force-ssl-redirect"
    value = "true"
    type  = "string"
  }
}

resource "kubernetes_service_account" "kubeapps_operator" {
  metadata {
    name = "kubeapps-operator"
  }
}

resource "kubernetes_cluster_role_binding" "kubeapps_operator" {
  depends_on = [helm_release.kubeapps]

  metadata {
    name = "kubeapps-operator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "kubeapps-operator"
    namespace = "default"
  }
}

module "credentials" {
  source = "matti/resource/shell"
  #TODO Manage kubeconfig variable.
  command = <<EOT
    KUBECONFIG=${var.kube_config} kubectl get secret $(KUBECONFIG=${var.kube_config} kubectl get serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' && echo
  EOT
}

output "token" {
  value = module.credentials.stdout
}
