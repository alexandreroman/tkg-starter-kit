terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.3.0"
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

resource "kubernetes_namespace" "harbor" {

  metadata {
    name = "harbor"
  }
}

resource "kubernetes_secret" "dockerhub" {
  depends_on = [kubernetes_namespace.harbor]
  
  metadata {
    name      = "regcreds"
    namespace = "harbor"
  }
  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "index.docker.io": {
      "auth": "${base64encode("${var.dockerhub_user}:${var.dockerhub_password}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
}

resource "helm_release" "harbor" {
  depends_on = [kubernetes_secret.dockerhub, kubernetes_namespace.harbor]

  name      = "harbor"
  chart     = "https://helm.goharbor.io/harbor-1.7.2.tgz"
  namespace = "harbor"

  set {
    name  = "imagePullSecrets[0].name"
    value = "regcreds"
  }
  set {
    name  = "expose.ingress.hosts.core"
    value = "harbor.${var.domain}"
  }
  set {
    name  = "expose.ingress.annotations.kubernetes\\.io/tls-acme"
    value = "true"
    type  = "string"
  }
  set {
    name  = "expose.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "contour"
    type  = "string"
  }
  set {
    name  = "expose.ingress.annotations.ingress\\.kubernetes\\.io/force-ssl-redirect"
    value = "true"
    type  = "string"
  }
  set {
    name  = "expose.ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = "harbor.${var.domain}"
  }
  set {
    name  = "expose.tls.certSource"
    value = "secret"
  }
  set {
    name  = "expose.tls.secret.secretName"
    value = "harbor-tls"
  }
  set {
    name  = "externalURL"
    value = "https://harbor.${var.domain}"
  }
  set {
    name  = "harborAdminPassword"
    value = var.admin_password
  }
  set {
    name  = "notary.enabled"
    value = false
  }
  set {
    name  = "persistence.persistentVolumeClaim.registry.size"
    value = "60Gi"
  }
  set {
    name  = "persistence.persistentVolumeClaim.chartmuseum.size"
    value = "10Gi"
  }
  set {
    name  = "persistence.persistentVolumeClaim.database.size"
    value = "10Gi"
  }
  set {
    name  = "persistence.persistentVolumeClaim.redis.size"
    value = "2Gi"
  }
  set {
    name  = "database.maxOpenConns"
    value = 300
  }
}
