variable "dockerhub_user" {
  type = string
}

variable "dockerhub_password" {
  type = string
}

variable "kpack_version" {
  type    = string
  default = "0.3.1"
}

variable "kube_config" {
  type = string
}

variable "domain" {
  type = string
}

variable "admin_password" {
  type    = string
  default = "changeme"
}
