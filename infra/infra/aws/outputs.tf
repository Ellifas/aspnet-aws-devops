output "aws_region" {
  description = "Região AWS usada."
  value       = var.aws_region
}

output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = module.eks.cluster_name
}

output "ecr_repository_url" {
  description = "URL do repositório ECR da aplicação."
  value       = aws_ecr_repository.app.repository_url
}

output "configure_kubeconfig" {
  description = "Comando para configurar kubeconfig local."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  description = "ID da VPC criada."
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Subnets privadas usadas pelo EKS."
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Subnets públicas usadas por Load Balancers."
  value       = module.vpc.public_subnets
}