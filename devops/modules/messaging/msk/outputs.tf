output "msk_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.mediscribe.arn
}

output "msk_bootstrap_brokers" {
  description = "Comma-separated list of MSK bootstrap brokers"
  value       = aws_msk_cluster.mediscribe.bootstrap_brokers
}

output "msk_bootstrap_brokers_tls" {
  description = "Comma-separated list of MSK bootstrap brokers (TLS)"
  value       = aws_msk_cluster.mediscribe.bootstrap_brokers_tls
}

output "msk_zookeeper_connect_string" {
  description = "Zookeeper connection string (if needed)"
  value       = aws_msk_cluster.mediscribe.zookeeper_connect_string
}

output "msk_cluster_name" {
  description = "Name of the MSK cluster"
  value       = aws_msk_cluster.mediscribe.cluster_name
}
