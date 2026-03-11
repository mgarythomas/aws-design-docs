variable "kubernetes_namespace" {
  description = "The namespace to install the notification service into"
  type        = string
  default     = "notification-system"
}

variable "replica_count" {
  description = "Number of replicas for the notification service"
  type        = number
  default     = 2
}

variable "nlb_arn" {
  description = "The ARN of the Network Load Balancer (NLB) to attach to the API Gateway VPC Link. This NLB should route to your internal EKS Ingress."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to all AWS resources"
  type        = map(string)
  default = {
    Environment = "Internal"
    Service     = "Notification"
    ManagedBy   = "Terraform"
  }
}
