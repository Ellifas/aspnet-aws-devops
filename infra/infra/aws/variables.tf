variable "project_name" {
  description = "Nome base dos recursos."
  type        = string
  default     = "nextfit-challenge"
}

variable "environment" {
  description = "Ambiente da entrega."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Região AWS."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR principal da VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "kubernetes_version" {
  description = "Versão Kubernetes do cluster EKS."
  type        = string
  default     = "1.33"
}

variable "node_instance_types" {
  description = "Tipos de instância para o Managed Node Group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Quantidade mínima de nodes."
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Quantidade desejada de nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Quantidade máxima de nodes."
  type        = number
  default     = 3
}