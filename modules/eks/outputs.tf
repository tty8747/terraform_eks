output "eks" {
  value = aws_eks_cluster.eks
}

output "eks_node_group" {
  value = aws_eks_node_group.internal
}

output "aws_eks_cluster_auth" {
  value = data.aws_eks_cluster_auth.eks
}
