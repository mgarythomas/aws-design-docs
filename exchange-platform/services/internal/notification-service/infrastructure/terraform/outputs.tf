output "internal_api_gateway_id" {
  description = "The ID of the internal API Gateway"
  value       = aws_api_gateway_rest_api.internal_api.id
}

output "internal_api_gateway_execution_arn" {
  description = "Execution ARN to be used in Lambda or VPC endpoint policies"
  value       = aws_api_gateway_rest_api.internal_api.execution_arn
}

output "internal_vpc_link_id" {
  description = "The ID of the VPC Link deployed for the internal API Gateway"
  value       = aws_api_gateway_vpc_link.internal_vpc_link.id
}
