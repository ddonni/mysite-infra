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

# ---- 아래는 generate-config-out 결과를 다듬은 것 ----
# 바꾸면 서버를 지우고 다시 만드는(-/+) 값: ami, subnet_id, availability_zone, private_ip,
# associate_public_ip_address, root_block_device.encrypted 등. 그래서 ami·서브넷·디스크는 지금 값 그대로 적고,
# AWS가 정하는 값(사설 IP, 네트워크 인터페이스, CPU 옵션 등)은 적지 않는다.

resource "aws_instance" "app" {
  ami                    = "ami-05cd5f557a0769fae" # Ubuntu 24.04 arm64 (1-5에서 고른 것)
  instance_type          = "t4g.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = "mysite-ec2-role" # S3 사진 PutObject·백업, SSM. 역할은 아직 Terraform 밖
  tags                   = { Name = "mysite-server" }

  # IMDSv2만 허용(토큰 없는 메타데이터 요청 거부)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # T4g 기본값. 기준 CPU를 넘겨 오래 쓰면 추가 요금이 붙을 수 있음 → 비용 확인 대상
  credit_specification {
    cpu_credits = "unlimited"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    iops        = 3000
    throughput  = 125
    encrypted   = false # 만들 때 암호화 안 함. 바꾸려면 디스크 교체가 필요(-/+) → 별도 작업
  }

  lifecycle {
    prevent_destroy = true
  }
}

# 고정 공인 IP. 인스턴스와의 연결은 아래 association이 따로 맡는다.
resource "aws_eip" "app" {
  domain = "vpc"

  lifecycle {
    prevent_destroy = true # 지우면 IP가 바뀌고 DuckDNS·HTTPS가 깨짐
  }
}

resource "aws_eip_association" "app" {
  allocation_id = aws_eip.app.id
  instance_id   = aws_instance.app.id
}
