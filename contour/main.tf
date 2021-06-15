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

resource "kubernetes_namespace" "contour" {
  metadata {
    name = "contour"
  }
}

resource "kubernetes_secret" "dockerhub" {
  depends_on = [kubernetes_namespace.contour]

  metadata {
    name      = "regcreds"
    namespace = "contour"
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

resource "helm_release" "contour" {
  depends_on = [kubernetes_secret.dockerhub, kubernetes_namespace.contour]

  name      = "contour"
  chart     = "https://charts.bitnami.com/bitnami/contour-4.1.3.tgz"
  namespace = "contour"

  set {
    name  = "contour.image.pullSecrets"
    value = "{ regcreds }"
  }
}
