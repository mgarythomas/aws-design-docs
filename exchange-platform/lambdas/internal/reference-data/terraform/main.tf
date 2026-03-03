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
variable "db_instance_identifier" {}
variable "dmz_vpce_id" { description = "The ID of the VPC Endpoint mapped to the DMZ" }

provider "aws" {
  region = var.region
}

# 1. Internal API Gateway (Private)
resource "aws_api_gateway_rest_api" "internal_api" {
  name        = "reference-data-internal-api"
  description = "Private API Gateway for Core Reference Data Logic"
  
  endpoint_configuration {
    types = ["PRIVATE"]
  }

  body = templatefile("../../../../api-contracts/internal/v1/reference-data.yaml", {
    region        = var.region
    coreLambdaArn = aws_lambda_function.core_lambda.arn
  })
}

# Resource Policy: Only allow traffic originating from the DMZ VPC Endpoint
resource "aws_api_gateway_rest_api_policy" "internal_api_policy" {
  rest_api_id = aws_api_gateway_rest_api.internal_api.id
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.internal_api.execution_arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = var.dmz_vpce_id
          }
        }
      }
    ]
  })
}

resource "aws_api_gateway_deployment" "internal_deployment" {
  rest_api_id = aws_api_gateway_rest_api.internal_api.id
  triggers = {
    redeployment = sha1(aws_api_gateway_rest_api.internal_api.body)
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "internal_stage" {
  deployment_id = aws_api_gateway_deployment.internal_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.internal_api.id
  stage_name    = "v1"
}

# 2. Core Lambda Function & Role
resource "aws_iam_role" "core_lambda_role" {
  name = "reference-data-core-lambda-role"
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
  role       = aws_iam_role.core_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "core_lambda" {
  function_name = "reference-data-core"
  role          = aws_iam_role.core_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename         = "dummy.zip"
  source_code_hash = filebase64sha256("dummy.zip")

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.core_lambda_sg.id]
  }

  environment {
    variables = {
      # Lambda points to the RDS Proxy endpoint, not the DB directly
      DB_HOST = aws_db_proxy.rds_proxy.endpoint
      DB_USER = "db_ro_user"
    }
  }
}

resource "aws_lambda_permission" "apigw_internal_lambda" {
  statement_id  = "AllowExecutionFromPrivateAPIGW"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.core_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.internal_api.execution_arn}/*/*"
}

resource "aws_security_group" "core_lambda_sg" {
  name        = "core-lambda-sg"
  description = "Security group for the Core Database Lambda"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. RDS Proxy Setup for connection multiplexing
resource "aws_iam_role" "rds_proxy_role" {
  name = "rds-proxy-secrets-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
    }]
  })
}

resource "aws_secretsmanager_secret" "db_secret" {
  name = "reference-data-db-credentials"
}

resource "aws_db_proxy" "rds_proxy" {
  name                   = "reference-data-rds-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy_role.arn
  vpc_security_group_ids = [aws_security_group.rds_proxy_sg.id]
  vpc_subnet_ids         = var.private_subnet_ids

  auth {
    auth_scheme = "SECRETS"
    description = "DB Credentials"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db_secret.arn
  }
}

resource "aws_db_proxy_target" "db_target" {
  db_instance_identifier = var.db_instance_identifier
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = "default"
}

# Allow Lambda -> RDS Proxy -> DB
resource "aws_security_group" "rds_proxy_sg" {
  name        = "rds-proxy-sg"
  vpc_id      = var.vpc_id
  
  ingress {
    description     = "Allow PG connections from Core Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.core_lambda_sg.id]
  }
}
