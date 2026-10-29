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
