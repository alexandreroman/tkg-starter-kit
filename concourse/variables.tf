variable "dockerhub_user" {
  type = string
}

variable "dockerhub_password" {
  type = string
}

variable "domain" {
  type = string
}

variable "admin_password" {
  type = string
  default = "changeme"
}

variable "kube_config" {
  type    = string  
}

