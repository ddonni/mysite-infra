# 바깥 감시(도쿄): EventBridge 규칙이 5분마다 Lambda mysite-health-monitor를 실행.
# 첫 import 연습 대상 — 잘못돼도 감시가 몇 분 멈출 뿐 서비스에는 영향 없음.

import {
  provider = aws.tokyo
  to       = aws_cloudwatch_event_rule.health_monitor
  id       = "each-5minutes"
}

# generate-config-out으로 뽑은 코드에서 기본값(null, false, "default", {})과
# provider가 이미 정하는 region을 지움. description은 콘솔에 적힌 그대로(공백 두 칸까지).
resource "aws_cloudwatch_event_rule" "health_monitor" {
  provider            = aws.tokyo
  name                = "each-5minutes"
  description         = "5분마다 실행되게  하기"
  schedule_expression = "rate(5 minutes)"
  state               = "ENABLED"
}

# 규칙 → Lambda 연결, EventBridge가 Lambda를 불러도 된다는 허가, Lambda 실행 역할.
# 셋 다 콘솔이 트리거·함수를 만들 때 자동으로 만든 것이라 ID가 무작위.
import {
  provider = aws.tokyo
  to       = aws_cloudwatch_event_target.health_monitor
  id       = "each-5minutes/ca39ckwo5lz5now0dsdc"
}

import {
  provider = aws.tokyo
  to       = aws_lambda_permission.health_monitor_events
  id       = "mysite-health-monitor/lambda-04014522-1c56-4664-a0d9-91932e10bb79"
}

import {
  to = aws_iam_role.health_monitor # IAM은 리전이 없음(전역)
  id = "mysite-health-monitor-role-67xhtdin"
}

# 역할에 붙은 정책: 콘솔이 만든 CloudWatch Logs 쓰기 권한. 인라인 정책은 없음(확인함).
# 계정 ID는 공개 레포에 적지 않고 실행할 때 읽는다.
data "aws_caller_identity" "current" {}

locals {
  account_id             = data.aws_caller_identity.current.account_id
  health_monitor_log_arn = "arn:aws:iam::${local.account_id}:policy/service-role/AWSLambdaBasicExecutionRole-1ab51aa1-1f38-44e4-ad3a-49600b2cc63f"
}

import {
  to = aws_iam_policy.health_monitor_logs
  id = local.health_monitor_log_arn
}

import {
  to = aws_iam_role_policy_attachment.health_monitor_logs
  id = "mysite-health-monitor-role-67xhtdin/${local.health_monitor_log_arn}"
}

# ---- 아래는 generate-config-out 결과를 다듬은 것 ----
# 고친 방향: 기본값 지우기, 계정 ID는 local.account_id로, 서로 가리키는 값은
# 문자열 대신 참조(aws_xxx.yyy.name)로 → Terraform이 만드는 순서와 연결 관계를 안다.

locals {
  health_monitor_function_name = "mysite-health-monitor"
}

resource "aws_cloudwatch_event_target" "health_monitor" {
  provider  = aws.tokyo
  rule      = aws_cloudwatch_event_rule.health_monitor.name
  target_id = "ca39ckwo5lz5now0dsdc"
  arn       = aws_lambda_function.health_monitor.arn
}

resource "aws_lambda_permission" "health_monitor_events" {
  provider      = aws.tokyo
  statement_id  = "lambda-04014522-1c56-4664-a0d9-91932e10bb79"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.health_monitor.arn # 이 규칙만 부를 수 있음
}

resource "aws_iam_role" "health_monitor" {
  name = "mysite-health-monitor-role-67xhtdin"
  path = "/service-role/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 로그 그룹 하나에만 쓸 수 있는 최소 권한(콘솔이 만든 그대로)
resource "aws_iam_policy" "health_monitor_logs" {
  name = "AWSLambdaBasicExecutionRole-1ab51aa1-1f38-44e4-ad3a-49600b2cc63f"
  path = "/service-role/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:ap-northeast-1:${local.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:ap-northeast-1:${local.account_id}:log-group:/aws/lambda/${local.health_monitor_function_name}:*"]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "health_monitor_logs" {
  role       = aws_iam_role.health_monitor.name
  policy_arn = aws_iam_policy.health_monitor_logs.arn
}

# Lambda 함수 본체와 로그 그룹. 함수 코드는 monitor/lambda_function.py와 같아야 함.
import {
  provider = aws.tokyo
  to       = aws_lambda_function.health_monitor
  id       = "mysite-health-monitor"
}

import {
  provider = aws.tokyo
  to       = aws_cloudwatch_log_group.health_monitor
  id       = "/aws/lambda/mysite-health-monitor"
}

# 콘솔 편집기로 올렸던 코드를 레포의 파일로 대체: 이 파일이 바뀌면 apply 때 Lambda에 올라감.
# zip은 실행할 때 만들어지는 결과물이라 git에 넣지 않음(.gitignore의 .build/).
data "archive_file" "health_monitor" {
  type        = "zip"
  source_file = "${path.module}/../monitor/lambda_function.py"
  output_path = "${path.module}/.build/health_monitor.zip"
}

resource "aws_lambda_function" "health_monitor" {
  provider         = aws.tokyo
  function_name    = local.health_monitor_function_name
  role             = aws_iam_role.health_monitor.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  architectures    = ["arm64"]
  memory_size      = 128
  timeout          = 120 # 최악 100초(요청 20초×3 + 쉼 20초×2), lambda_function.py 맨 위 참고
  filename         = data.archive_file.health_monitor.output_path
  source_code_hash = data.archive_file.health_monitor.output_base64sha256

  # 환경 변수(HEALTH_URL, DISCORD_WEBHOOK_URL)는 콘솔에서 넣은 값을 그대로 둔다.
  # 웹훅 URL을 공개 레포에 적지 않으려고 Terraform이 보지 않게 함.
  # (다음 할 일: 웹훅을 SSM Parameter Store로 옮기고 코드에서 읽기)
  lifecycle {
    ignore_changes = [environment]
  }
}

resource "aws_cloudwatch_log_group" "health_monitor" {
  provider          = aws.tokyo
  name              = "/aws/lambda/${local.health_monitor_function_name}"
  retention_in_days = 30 # 콘솔 기본값은 0(무기한 보관). 5분마다 쌓이므로 30일만
}
