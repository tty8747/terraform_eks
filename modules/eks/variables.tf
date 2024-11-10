variable "environment" {
  type    = string
  default = "stage"
}

variable "cluster_name" {
  type    = string
  default = "eks"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "subnet_ids" {
  type = list(string)
}

variable "cluster_log_types" {
  type    = list(string)
  default = ["api"]
}

variable "instance_types" {
  type    = list(string)
  default = ["t2.micro"]
}
