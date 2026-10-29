# 바깥 감시(도쿄): EventBridge 규칙이 5분마다 Lambda mysite-health-monitor를 실행.
# 첫 import 연습 대상 — 잘못돼도 감시가 몇 분 멈출 뿐 서비스에는 영향 없음.

import {
  provider = aws.tokyo
  to       = aws_cloudwatch_event_rule.health_monitor
  id       = "each-5minutes"
}
