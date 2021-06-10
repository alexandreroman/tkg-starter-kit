terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "1.3.2"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

data "aws_route53_zone" "primary" {
  name = var.domain
}

resource "aws_iam_user" "dns_challenge" {
  name = "dns-challenge"
}

resource "aws_iam_user_policy" "dns_challenge_policy" {
  name = "dns-challenge-policy"
  user = aws_iam_user.dns_challenge.name
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "route53:GetChange",
        "Resource": "arn:aws:route53:::change/*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ],
        "Resource": "arn:aws:route53:::hostedzone/*"
      },
      {
        "Effect": "Allow",
        "Action": "route53:ListHostedZonesByName",
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "dns_challenge" {
  user = aws_iam_user.dns_challenge.name
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  chart      = "https://charts.jetstack.io/charts/cert-manager-v1.2.0.tgz"

  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = true
  }
  set {
    name  = "ingressShim.defaultIssuerName"
    value = "letsencrypt-dns"
  }
  set {
    name  = "ingressShim.defaultIssuerKind"
    value = "ClusterIssuer"
  }
  set {
    name  = "ingressShim.defaultIssuerGroup"
    value = "cert-manager.io"
  }
}

resource "kubernetes_secret" "route53" {
  depends_on = [ helm_release.cert_manager ]

  metadata {
    name      = "route53-secret"
    namespace = "cert-manager"
  }

  data = {
    secret-access-key = aws_iam_access_key.dns_challenge.secret
  }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [ helm_release.cert_manager ]

  create_duration = "30s"
}

resource "kubectl_manifest" "cert_manager_issuer" {
  # There's a bug with the cert-manager deployment: the ClusterIssuer cannot be deployed
  # right after cert-manager, because of a certificate error with the mutating webhook.
  # Adding some delay before deploying the ClusterIssuer works for now.
  depends_on = [ time_sleep.wait_30_seconds ]

  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    server: ${var.letsencrypt_prod ? "https://acme-v02.api.letsencrypt.org/directory" : "https://acme-staging-v02.api.letsencrypt.org/directory"}
    email: ${var.letsencrypt_issuer_email}
    privateKeySecretRef:
      name: issuer-account-key
    solvers:
      - selector:
        dnsZones:
        - "${var.domain}"
        dns01:
          route53:
            region: ${var.aws_region}
            accessKeyID: ${aws_iam_access_key.dns_challenge.id}
            secretAccessKeySecretRef:
              name: route53-secret
              key: secret-access-key
            hostedZoneID: ${data.aws_route53_zone.primary.zone_id}
YAML
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
  }
}

resource "kubernetes_secret" "dockerhub" {
  metadata {
    name = "regcreds"
    namespace = "external-dns"
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

resource "helm_release" "external_dns" {
  depends_on = [ kubernetes_secret.dockerhub, kubernetes_namespace.external_dns ]

  name      = "external-dns"
  chart     = "https://charts.bitnami.com/bitnami/external-dns-5.0.3.tgz"
  namespace = "external-dns"

  set {
    name  = "global.imagePullSecrets"
    value = "{ regcreds }"
  }
  set {
    name  = "aws.credentials.accessKey"
    value = var.aws_access_key
  }
  set {
    name  = "aws.credentials.secretKey"
    value = var.aws_secret_key
  }
  set {
    name  = "aws.region"
    value = var.aws_region
  }
  set {
    name  = "aws.zoneType"
    value = "public"
  }
  set {
    name  = "policy"
    value = "sync"
  }
  set {
    name  = "sources[0]"
    value = "service"
  }
  set {
    name  = "sources[1]"
    value = "ingress"
  }
  set {
    name  = "sources[2]"
    value = "contour-httpproxy"
  }
}
