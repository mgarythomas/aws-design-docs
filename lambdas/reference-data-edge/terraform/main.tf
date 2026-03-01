terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" { default = "ap-southeast-2" }
variable "vpc_id" {}
variable "private_subnet_ids" { type = list(string) }

provider "aws" {
  region = var.region
}

# 1. DMZ Edge Lambda Role & Function
resource "aws_iam_role" "edge_lambda_role" {
  name = "reference-data-edge-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.edge_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "edge_lambda" {
  function_name = "reference-data-edge"
  role          = aws_iam_role.edge_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  # Placeholder zip, in practice your CI/CD builds and uploads this
  filename         = "dummy.zip" 
  source_code_hash = filebase64sha256("dummy.zip")

  # Deploy the DMZ lambda into the DMZ private subnets
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.edge_lambda_sg.id]
  }

  environment {
    variables = {
      # The edge lambda needs to know the Internal VPC Endpoint DNS to forward traffic manually via HTTPS
      INTERNAL_API_ENDPOINT = aws_vpc_endpoint.internal_api_gateway.dns_entry[0].dns_name
    }
  }
}

# 2. VPC Interface Endpoint (PrivateLink for API Gateway)
# This allows the Edge Lambda to securely call the Internal API Gateway over the AWS Backbone
resource "aws_security_group" "vpce_sg" {
  name        = "vpce-apigw-sg"
  description = "Allow HTTPS from Edge Lambda into VPCE"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.edge_lambda_sg.id]
  }
}

resource "aws_security_group" "edge_lambda_sg" {
  name        = "edge-lambda-sg"
  description = "Security group for the DMZ edge lambda"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "internal_api_gateway" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce_sg.id]
}

# 3. DMZ API Gateway setup (Public)
resource "aws_api_gateway_rest_api" "dmz_api" {
  name        = "reference-data-dmz-api"
  description = "Public API Gateway for Reference Data"
  body        = templatefile("../openapi.yaml", {
    region        = var.region
    edgeLambdaArn = aws_lambda_function.edge_lambda.arn
  })
}

resource "aws_api_gateway_deployment" "dmz_deployment" {
  rest_api_id = aws_api_gateway_rest_api.dmz_api.id
  triggers = {
    redeployment = sha1(aws_api_gateway_rest_api.dmz_api.body)
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "dmz_stage" {
  deployment_id = aws_api_gateway_deployment.dmz_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.dmz_api.id
  stage_name    = "v1"
  
  # Enable Caching
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5" # 0.5 GB cache size
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGW"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.edge_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.dmz_api.execution_arn}/*/*"
}

output "dmz_api_url" {
  value = aws_api_gateway_stage.dmz_stage.invoke_url
}
output "vpc_endpoint_id" {
  value = aws_vpc_endpoint.internal_api_gateway.id
}
