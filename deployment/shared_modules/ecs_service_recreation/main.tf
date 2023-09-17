data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "${var.app_name}-${var.environment}-lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
  lifecycle {ignore_changes = [permissions_boundary]}
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:UpdateService"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name   = "${var.app_name}-${var.environment}-lambda-exec-policy"
  role   = aws_iam_role.lambda_execution_role.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "ecs_task_restart" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.app_name}-${var.environment}-ecs-task-restart"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda.lambda_handler"
  runtime       = "python3.8"
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  environment {
    variables = {
      ecs_cluster = var.ecs_cluster
      ecs_service = var.ecs_service
    }
  }
}

resource "aws_cloudwatch_event_rule" "everyday" {
  name                = "${var.app_name}-${var.environment}-everyday"
  schedule_expression = "rate(24 hours)"
}

resource "aws_cloudwatch_event_target" "ecs_task_check" {
  rule      = aws_cloudwatch_event_rule.everyday.name
  target_id = "${var.app_name}-${var.environment}-ecs-task-check"
  arn       = aws_lambda_function.ecs_task_restart.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_task_restart.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.everyday.arn
}
