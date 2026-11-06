# 운영 서버: t4g.micro 한 대 + Elastic IP. 실사용자가 쓰는 서비스라 가장 조심할 것.
# plan에 이 인스턴스의 -/+(replace)가 보이면 절대 apply하지 않는다.

import {
  to = aws_instance.app
  id = "i-0042815e2f7ff1caa"
}

import {
  to = aws_eip.app
  id = "eipalloc-0c22dc09d94242dd7"
}

import {
  to = aws_eip_association.app
  id = "eipassoc-0513a4a5695e68ebf"
}
