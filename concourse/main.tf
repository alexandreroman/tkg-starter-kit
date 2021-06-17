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

resource "kubernetes_namespace" "concourse" {
  metadata {
    name = "concourse"
  }
}

resource "kubernetes_secret" "dockerhub" {
  metadata {
    name      = "regcreds"
    namespace = "concourse"
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

resource "helm_release" "concourse" {
  depends_on = [kubernetes_secret.dockerhub, kubernetes_namespace.concourse]

  name      = "concourse"
  chart     = "https://concourse-charts.storage.googleapis.com/concourse-14.6.2.tgz"
  namespace = "concourse"

  set {
    name  = "imagePullSecrets"
    value = "{ regcreds }"
  }
  set {
    name  = "web.ingress.enabled"
    value = true
  }
  set {
    name  = "web.ingress.hosts"
    value = "{ concourse.${var.domain} }"
  }
  set {
    name  = "web.ingress.annotations.ingress\\.kubernetes\\.io/force-ssl-redirect"
    value = "true"
    type  = "string"
  }
  set {
    name  = "web.ingress.annotations.kubernetes\\.io/tls-acme"
    value = "true"
    type  = "string"
  }
  set {
    name  = "web.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "contour"
    type  = "string"
  }
  set {
    name  = "web.ingress.tls[0].secretName"
    value = "concourse-web-tls"
  }
  set {
    name  = "web.ingress.tls[0].hosts[0]"
    value = "concourse.${var.domain}"
  }
  set {
    name  = "secrets.localUsers"
    value = "admin:${var.admin_password}"
  }
  set {
    name = "concourse.web.auth.mainTeam.config"
    value = yamlencode({
      "roles" : [
        { "name" : "owner", "local" : { "users" : ["admin"] } }
      ]
    })
  }
  set {
    name  = "concourse.web.auth.mainTeam.localUser"
    value = "admin"
  }
  set {
    name  = "concourse.web.externalUrl"
    value = "https://concourse.${var.domain}"
  }
}
