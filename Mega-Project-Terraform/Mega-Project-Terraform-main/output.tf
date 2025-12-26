# output.tf

output "cluster_id" {
  value = aws_eks_cluster.devopsshack1.id
}

output "node_group_id" {
  value = aws_eks_node_group.devopsshack1_node_group.id
}

output "vpc_id" {
  value = aws_vpc.devopsshack1_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.devopsshack1_subnet[*].id
}


