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

# ---- 아래는 generate-config-out 결과를 다듬은 것 ----
# 초안에는 쓰지 않는 기능(IPv6, IPAM, Outposts)의 빈 값이 서로 충돌해서 plan이 에러를 냈다 → 전부 지움.
# 태그(Name)는 지우면 "태그 삭제"로 나오니 그대로. 운영 서버가 기대는 것들이라 실수로 지우지 못하게 막음.

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/24"
  tags       = { Name = "my-vpc-01" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/28"
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "my-subnet-01" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "my-internet-gateway" }
}

# VPC 안(10.0.0.0/24)으로 가는 local 경로는 AWS가 자동으로 넣으므로 적지 않음
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "public-my-route-table-01" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 들어오는 건 80/443뿐(SSH 없음 — 접속은 SSM). 나가는 건 전부 허용(업데이트, S3, 디스코드).
# description은 끝의 공백까지 콘솔 그대로: 이 값을 바꾸면 보안 그룹을 지우고 다시 만든다(-/+).
resource "aws_security_group" "web" {
  name        = "MySecurityGroup"
  description = "http, https inbound "
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    prevent_destroy = true
  }
}
