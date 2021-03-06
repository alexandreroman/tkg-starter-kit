variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "domain" {
  type = string
}

variable "letsencrypt_issuer_email" {
  type = string
}

variable "letsencrypt_prod" {
  type    = bool
  default = false
}

variable "dockerhub_user" {
  type = string
}

variable "dockerhub_password" {
  type = string
}

resource "random_string" "harbor_admin_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_string" "concourse_admin_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_string" "jenkins_admin_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}
