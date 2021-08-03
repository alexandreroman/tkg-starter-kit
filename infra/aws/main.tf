terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.52"
    }
    local = {
      source = "hashicorp/local"
      version = ">= 2.1"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
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

resource "local_file" "k8s_file" {
    content = templatefile("k8s.tpl", {
      letsencrypt_issuer_email = var.letsencrypt_issuer_email,
      domain = var.domain,
      aws_dns_challenge_access = aws_iam_access_key.dns_challenge.id,
      aws_dns_challenge_secret = aws_iam_access_key.dns_challenge.secret,
      aws_region = var.aws_region,
      aws_zone_id = data.aws_route53_zone.primary.zone_id
    })
    filename        = "k8s.yml"
    file_permission = "0644"
}

resource "local_file" "values-external-dns_file" {
    content = templatefile("values-external-dns.tpl", {
      aws_access_key = var.aws_access_key,
      aws_secret_key = var.aws_secret_key,
      aws_region = var.aws_region,
    })
    filename        = "values-external-dns.yml"
    file_permission = "0644"
}
