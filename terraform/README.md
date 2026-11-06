# terraform/

1단계에서 콘솔로 **직접 만든** 운영 인프라를 Terraform으로 옮긴 코드다. 새로 만든 것이 아니라 `import`로 장부(state)에 등록했고, 지금 `terraform plan`은 **No changes**다. 옮기는 동안 서버는 한 번도 재시작되지 않았다.

| 파일 | 리전 | 관리하는 것 |
|---|---|---|
| [versions.tf](versions.tf) | — | Terraform·provider 버전, S3 backend, 서울/도쿄 provider |
| [network.tf](network.tf) | 서울 | VPC, 퍼블릭 서브넷, 인터넷 게이트웨이, 라우팅 테이블(+연결), 보안 그룹(80/443만) |
| [ec2.tf](ec2.tf) | 서울 | 운영 서버 EC2(t4g.micro, IMDSv2만), Elastic IP(+연결) |
| [monitor.tf](monitor.tf) | 도쿄 | 바깥 감시: EventBridge 5분 규칙 → Lambda(코드는 [../monitor/lambda_function.py](../monitor/lambda_function.py)), 실행 역할·로그 정책·로그 그룹 |

## 실행 방법

AWS **CloudShell**(서울)에서 실행한다. 콘솔에 로그인한 임시 권한을 쓰므로 PC에 액세스 키를 남기지 않는다.

```bash
cd ~/mysite-infra/terraform
git pull
terraform init          # 처음 한 번, provider를 추가했을 때
terraform plan -out=tf.tfplan
terraform apply tf.tfplan
```

- **plan에 `-/+`(교체)나 `destroy`가 보이면 apply하지 않는다.** 운영 서버, Elastic IP, VPC, 서브넷, 보안 그룹에는 `prevent_destroy`가 걸려 있어서 그런 plan은 에러로 멈춘다.
- state는 S3 버킷 `mysite-tfstate-ddonni`(버전 관리, `use_lockfile` 잠금)에 있다. 이 버킷만 콘솔에서 손으로 만들었다(장부를 둘 곳을 Terraform으로 만들 수는 없음).
- 공개 레포라 계정 ID는 `data.aws_caller_identity`로 읽고, 디스코드 웹훅이 든 Lambda 환경 변수는 Terraform이 보지 않는다(`ignore_changes`).

## import한 방법

1. `import` 블록에 실제 리소스 ID를 적는다.
2. `terraform plan -generate-config-out=generated.tf`로 Terraform이 실제 설정을 읽어 쓴 **초안**을 받는다.
3. 초안을 다듬어 진짜 파일로 옮긴다.
   - 쓰지 않는 기능(IPv6, IPAM, Outposts)의 빈 값은 서로 충돌해서 그대로는 plan도 되지 않는다 → 지운다.
   - 바꾸면 교체되는 값(AMI, 서브넷, 디스크 암호화, 보안 그룹 설명)은 지금 값 그대로 적는다.
   - AWS가 정하는 값(사설 IP, 네트워크 인터페이스)은 적지 않는다.
   - 서로 가리키는 값은 문자열 대신 참조(`aws_vpc.main.id`)로 → 만드는 순서와 관계를 Terraform이 안다.
4. `plan`이 `N to import, 0 to change`인지 확인하고 apply → 다시 `plan`이 **No changes**.

## 아직 밖에 있는 것

- EC2 역할(`mysite-ec2-role`), GitHub Actions 배포 역할(OIDC), S3 버킷 두 개(사진·백업)
- 서버 **안**의 설정(Nginx, systemd 유닛, 백업 스크립트) — Terraform이 아니라 user-data나 Ansible의 영역
