# mysite-infra

mysite 백엔드(FastAPI + PostgreSQL + WebSocket)를 Render 무료 플랜에서 AWS의 직접 운영하는 리눅스 서버로 옮기는 프로젝트.

- 진행 단계: [ROADMAP.md](ROADMAP.md)
- 측정 기록: [MEASUREMENTS.md](MEASUREMENTS.md)
- 장애·문제 기록: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## 구성도

(1-12에서 작성)

## 선택 근거

### 계정 접근: IAM 사용자 + Admin 그룹 + MFA (1-1)

- **IAM Identity Center 대신 IAM 사용자**: Identity Center는 여러 AWS 계정에 한 번 로그인(SSO)하고 임시 자격 증명을 발급해 주는 서비스다. 계정 하나, 사용자 하나인 개인 프로젝트에서는 그 이점이 거의 없고 Organizations 설정까지 필요해서 IAM 사용자를 골랐다. 대신 IAM 사용자는 오래 쓰는 비밀번호를 갖게 되므로, 그 단점은 MFA로 보완한다.
- **사람과 기계의 권한 분리**: `AdministratorAccess`는 콘솔에서 인프라를 직접 만드는 **사람(나)** 에게만 준다. 이 사용자는 콘솔 전용이라 액세스 키를 만들지 않는다. 서버(EC2)나 배포(GitHub Actions) 같은 **기계**에는 장기 액세스 키를 쓰지 않고, 필요한 권한만 담은 IAM 역할을 준다(EC2 인스턴스 프로파일, GitHub OIDC). 최소 권한 원칙은 이 기계용 권한에 적용한다.
- **넓은 권한을 지키는 장치**:
  - 예방: 루트와 IAM 사용자 모두 MFA / IAM 사용자에 액세스 키 없음 / 루트는 일상적으로 쓰지 않고 루트 액세스 키도 없음 / 공용 PC(학원)에는 키를 저장하지 않고 쓰고 나면 로그아웃
  - 탐지: 예산 알림. 예방 장치가 뚫려도 비정상적인 청구액으로 알아챌 수 있다.

## 월 비용

(1-3 이후 실제 청구액 기록)

## 롤백·복구 방법

(1-9, 1-10에서 작성)
