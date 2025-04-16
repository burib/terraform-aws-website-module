
# IAM Role for Lambda@Edge
resource "aws_iam_role" "lambda_edge_auth_check" {
  name                 = "lambda-edge-auth-check-${var.environment}"
  permissions_boundary = "arn:aws:iam::${local.account_id}:policy/PermissionBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_edge_auth_check.name
}


# Combined IAM Policy for SSM and CloudWatch access
resource "aws_iam_role_policy" "lambda_edge_permissions" {
  name = "lambda-edge-permissions"
  role = aws_iam_role.lambda_edge_auth_check.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/auth/cognito/*"
        ]
      }
    ]
  })
}

# resource "null_resource" "wait_for_lambda_replication" {
#   triggers = {
#     function_version = aws_lambda_function.auth_check.version
#   }
#
#   provisioner "local-exec" {
#     when    = destroy
#     command = <<EOF
#       # wait 15 minutes for the replicas to be deleted
#       for i in {1..90}; do
#         echo "Waiting for Lambda@Edge replicas to be deleted... $((i*10))s of 900s elapsed"
#         sleep 10
#       done
#     EOF
#   }
# }

resource "aws_lambda_function" "auth_check" {
  filename         = data.archive_file.auth_check.output_path
  function_name    = "${local.sanitized_domain_name}-lambda-at-edge-auth-check-${var.environment}"
  source_code_hash = data.archive_file.auth_check.output_base64sha256
  role             = aws_iam_role.lambda_edge_auth_check.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  publish          = true # Required for Lambda@Edge
  timeout          = 5    # Lambda@Edge has a 5-second timeout limit
  description      = "checks if jwt token exists, if not expired and if its valid one issued by cognito."

  # Add depends_on for deletion order
  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution_role]

  lifecycle {
    create_before_destroy = true
  }

  timeouts {
    delete = "60m"
  }
}

# Create the Lambda code
data "archive_file" "auth_check" {
  type        = "zip"
  output_path = "${path.module}/auth_check.zip"

  source {
    content = templatefile("${path.module}/functions/lambda_at_edge/auth_check.tpl.py", {
      cognito_client_id             = var.cognito_client_id
      auth_domain                   = var.cognito_domain
      protected_paths               = jsonencode(var.protected_paths)
      cognito_token_issuer_endpoint = var.cognito_token_issuer_endpoint
    })
    filename = "index.py"
  }
}
