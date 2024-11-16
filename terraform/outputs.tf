output "aws_service_endpoint" {
    description = "Service endpoint from confluent_network to be inputted to AWS"
    value = confluent_network.aws_private_link.aws.private_link_endpoint_service
}