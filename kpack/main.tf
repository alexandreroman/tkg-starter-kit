terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.11.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.3.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kube_config
}

resource "kubernetes_namespace" "kpack" {
  metadata {
    name = "kpack"
  }
}


resource "kubernetes_secret" "dockerhub" {
  depends_on = [kubernetes_namespace.kpack]
  metadata {
    name      = "regcreds"
    namespace = "kpack"
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

data "kubectl_file_documents" "manifests" {
  #TODO Download the file from github https://github.com/pivotal/kpack/releases/download/v0.3.1/release-0.3.1.yaml
  content = file("kpack/release-${var.kpack_version}.yaml")
}

resource "kubectl_manifest" "kpack_yaml" {
  depends_on = [kubernetes_secret.dockerhub]
  count      = length(data.kubectl_file_documents.manifests.documents)
  yaml_body  = element(data.kubectl_file_documents.manifests.documents, count.index)
}

resource "kubernetes_secret" "harbor_registry_credentials" {
  depends_on = [kubernetes_namespace.kpack]
  metadata {
    name      = "harbor-registry-credentials"
    namespace = "kpack"
  }
  data = {
    ".dockerconfigjson" = <<DOCKER
{
  "auths": {
    "https://harbor.${var.domain}": {
      "auth": "${base64encode("admin:${var.admin_password}")}"
    }
  }
}
DOCKER
  }
  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_service_account" "harbor-service-account" {
  metadata {
    name      = "harbor-service-account"
    namespace = "kpack"
  }
  secret {
    name = kubernetes_secret.harbor_registry_credentials.metadata.0.name
  }
  image_pull_secret {
    name = kubernetes_secret.harbor_registry_credentials.metadata.0.name
  }
}

data "kubectl_path_documents" "kpackmanifests" {
  pattern = "kpack/yaml/*.yaml"
  vars = {
    domain = var.domain
  }
}

resource "kubectl_manifest" "apply_kpack_configuration" {
  depends_on         = [kubernetes_service_account.harbor-service-account]
  override_namespace = "kpack"
  count              = length(data.kubectl_path_documents.kpackmanifests.documents)
  yaml_body          = element(data.kubectl_path_documents.kpackmanifests.documents, count.index)
}
