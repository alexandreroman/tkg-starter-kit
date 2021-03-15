terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "1.3.2"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "jenkins" {
  name  = "jenkins"
  chart = "https://github.com/jenkinsci/helm-charts/releases/download/jenkins-3.2.4/jenkins-3.2.4.tgz"

  namespace        = "jenkins"
  create_namespace = true

  set {
    name  = "controller.adminPassword"
    value = var.admin_password
  }
  set {
    name  = "controller.ingress.enabled"
    value = true
  }
  set {
    name  = "controller.ingress.hostName"
    value = "jenkins.${var.domain}"
  }
  set {
    name  = "controller.ingress.annotations.ingress\\.kubernetes\\.io/force-ssl-redirect"
    value = "true"
    type  = "string"
  }
  set {
    name  = "controller.ingress.annotations.kubernetes\\.io/tls-acme"
    value = "true"
    type  = "string"
  }
  set {
    name  = "controller.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "contour"
    type  = "string"
  }
  set {
    name  = "controller.ingress.tls[0].secretName"
    value = "jenkins-tls"
  }
  set {
    name  = "controller.ingress.tls[0].hosts[0]"
    value = "jenkins.${var.domain}"
  }
  set {
    name  = "controller.additionalPlugins[0]"
    value = "adoptopenjdk:1.3"
  }
  set {
    name  = "controller.additionalPlugins[1]"
    value = "generic-webhook-trigger:1.72"
  }
  set {
    name  = "controller.additionalPlugins[2]"
    value = "nodejs:1.4.0"
  }
  set {
    name  = "controller.additionalPlugins[3]"
    value = "file-operations:1.11"
  }
  set {
    name  = "controller.numExecutors"
    value = 3
  }
  set {
    name  = "controller.JCasC.authorizationStrategy"
    value = "loggedInUsersCanDoAnything"
  }
  set {
    name  = "controller.JCasC.configScripts.jenkins"
    value = yamlencode({
      jenkins: {
        systemMessage: "Welcome to Jenkins powered by VMware Tanzu!"
      }
    })
  }
  set {
    name  = "controller.JCasC.configScripts.adoptopenjdk"
    value = yamlencode({
      tool: {
        jdk: {
          installations: [
            { name: "jdk-11", properties: [{
              installSource: {
                installers: [{
                  adoptOpenJdkInstaller: {
                    id: "jdk-11.0.10+9"
                  }
                }]
              }
            }
          ]}
        ]}
      }
    })
  }
  set {
    name  = "controller.JCasC.configScripts.mvn"
    value = yamlencode({
      tool: {
        maven: {
          installations: [
            { name: "Maven 3", properties: [{
              installSource: {
                installers: [{
                  maven: {
                    id: "3.6.3"
                  }
                }]
              }
            }
          ]}
        ]}
      }
    })
  }
  set {
    name  = "controller.JCasC.configScripts.nodejs"
    value = yamlencode({
      tool: {
        nodejs: {
          installations: [
            { name: "NodeJS 14", properties: [{
              installSource: {
                installers: [{
                  nodeJSInstaller: {
                    id: "14.16.0",
                    npmPackagesRefreshHours: 72
                  }
                }]
              }
            }
          ]}
        ]}
      }
    })
  }
}
