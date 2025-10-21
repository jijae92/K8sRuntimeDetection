variable "cluster_oidc_provider_arn" { type = string }
variable "namespace" { type = string, default = "falco" }
variable "service_account_name" { type = string, default = "falcosidekick" }

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals { type = "Federated", identifiers = [var.cluster_oidc_provider_arn] }
    condition {
      test = "StringEquals"
      variable = "oidc.eks.amazonaws.com/id/${replace(var.cluster_oidc_provider_arn, "arn:aws:iam::", "")}:sub"
      values = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "falcosidekick" {
  name = "falcosidekick-irsa"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "sns_publish" {
  role = aws_iam_role.falcosidekick.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["sns:Publish"],
      Resource = [aws_sns_topic.falco_alerts.arn]
    }]
  })
}

output "falcosidekick_role_arn" { value = aws_iam_role.falcosidekick.arn }