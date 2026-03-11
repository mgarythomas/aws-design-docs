terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# 1. Deploy the Notification Service to EKS using the existing Helm chart
# This inherently creates the Deployment, Service, and the ALB Ingress.
resource "helm_release" "notification_service" {
  name             = "notification-service"
  chart            = "../helm/notification-service"
  namespace        = var.kubernetes_namespace
  create_namespace = true

  set {
    name  = "ingress.enabled"
    value = "true"
  }

  # Allow dynamically overriding values, e.g., the replica count
  set {
    name  = "replicaCount"
    value = var.replica_count
  }
}

# 2. AWS API Gateway VPC Link for Internal Routing
# When deploying an internal API Gateway to an EKS Ingress, the standard
# approach is to use a VPC Link connected to an internal Network Load Balancer (NLB).
resource "aws_api_gateway_vpc_link" "internal_vpc_link" {
  name        = "notification-service-internal-vpc-link"
  description = "VPC Link for Notification Service Internal API Gateway"
  target_arns = [var.nlb_arn]

  tags = var.tags
}

# 3. Define the Internal AWS API Gateway REST API using the OpenAPI spec
resource "aws_api_gateway_rest_api" "internal_api" {
  name        = "notification-service-internal-api"
  description = "Internal API Gateway for Notification Service (EKS Backend)"

  # Inject the VPC Link ID into the OpenAPI spec dynamically
  body = templatefile("${path.module}/../../api/internal/api-spec.yaml", {
    vpc_link_id = aws_api_gateway_vpc_link.internal_vpc_link.id
  })

  endpoint_configuration {
    types = ["PRIVATE"]
  }

  tags = var.tags
}

# 4. Create a stage and deployment for the API Gateway
resource "aws_api_gateway_deployment" "internal_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.internal_api.id

  triggers = {
    redeployment = sha1(templatefile("${path.module}/../../api/internal/api-spec.yaml", {
      vpc_link_id = aws_api_gateway_vpc_link.internal_vpc_link.id
    }))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "internal_api_stage" {
  deployment_id = aws_api_gateway_deployment.internal_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.internal_api.id
  stage_name    = "v1"

  tags = var.tags
}
