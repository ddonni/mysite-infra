# 서울 네트워크: 1-2(2026-10-06)에 콘솔로 직접 만든 VPC.
# 퍼블릭 서브넷 하나에 EC2 한 대, 인터넷은 IGW로, 열린 포트는 보안 그룹에서 80/443뿐.
#
# 손대지 않는 것: 메인 라우팅 테이블(어느 서브넷에도 안 붙음), default 보안 그룹(아무도 안 씀).
# 둘 다 VPC를 만들 때 AWS가 자동으로 만든 것.

import {
  to = aws_vpc.main
  id = "vpc-088e56f47123f1685"
}

import {
  to = aws_subnet.public
  id = "subnet-09e474cb662497f94"
}

import {
  to = aws_internet_gateway.main
  id = "igw-0da0a2a66e788aa62"
}

import {
  to = aws_route_table.public
  id = "rtb-06952266f5aed47ce"
}

import {
  to = aws_route_table_association.public
  id = "subnet-09e474cb662497f94/rtb-06952266f5aed47ce"
}

import {
  to = aws_security_group.web
  id = "sg-05d107d03f8de8f52"
}
