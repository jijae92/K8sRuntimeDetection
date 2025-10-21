terraform {
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
}
provider "aws" { region = var.region }
variable "region" { type = string }
resource "aws_sns_topic" "falco_alerts" { name = "falco-alerts" }
output "sns_topic_arn" { value = aws_sns_topic.falco_alerts.arn }