# 1단계에서 손으로 만든 인프라를 import해서 관리한다(새로 만드는 게 아님).
# 실행은 AWS CloudShell(서울)에서: 콘솔 로그인 권한을 그대로 쓰므로 PC에 키가 남지 않는다.
#
# state는 S3 버킷 mysite-tfstate-ddonni에 있다. 이 버킷만은 콘솔에서 손으로 만들었다
# (장부를 둘 곳을 Terraform으로 만들 수는 없음). 버전 관리 켬, 퍼블릭 차단.

terraform {
  required_version = ">= 1.11" # S3 backend의 use_lockfile(DynamoDB 없이 잠금)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "mysite-tfstate-ddonni"
    key          = "mysite/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
    encrypt      = true
  }
}

# 서버·네트워크·버킷은 서울
provider "aws" {
  region = "ap-northeast-2"
}

# 바깥 감시 Lambda·EventBridge는 도쿄(서버와 다른 리전)
provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}
