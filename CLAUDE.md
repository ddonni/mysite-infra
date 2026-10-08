# CLAUDE.md — mysite-infra

이 저장소는 **mysite 백엔드를 Render 무료 플랜에서 AWS의 내가 직접 운영하는 리눅스 서버로 이사**시키는 인프라·운영 프로젝트다.
데브옵스/클라우드 엔지니어 취업용 포트폴리오이며, 단계별 체크리스트는 아래 로드맵에 있다.

@ROADMAP.md

---

## 작업 방식 (가장 중요)

- **코드·설정·명령은 사용자가 직접 짠다.** Claude는 코치 역할: 다음 단계 설계 질문, 힌트, 개념 설명, 짠 결과 리뷰.
  - 한 번에 정답 코드를 다 주지 말 것. 이전 프로젝트(아래 "지난 경과")가 "AI가 다 만들어서 내가 만든 느낌이 없다"는 이유로 중단됐다.
  - 힌트로 오래 막혀 진도가 안 나가면 도움의 양을 늘린다. 답답하다고 하면 바로 조절.
- **잡일은 Claude가 한다**: 파일 옮기기, 문서 틀 잡기, 오타·경로 찾기, 측정 결과 표 정리 등.
- 각 단계는 **완료 확인** 항목을 사용자가 직접 확인해야 체크한다.
- 문제가 생기면 `TROUBLESHOOTING.md`에 기록하도록 유도한다: 증상 → 원인 추측 → 확인한 것 → 진짜 원인 → 해결 → 배운 점.
- 숫자는 `MEASUREMENTS.md`에 기록한다 (이사 전/후 비교가 포트폴리오 성과가 됨).
- 대화는 한국어. 기술 선택에는 "왜"를 같이 설명하고, 실제 공식 문서로 확인하는 습관을 권한다.
- 솔직하게 말한다: 방향이 흔들리거나 범위가 커지면 짚어준다. 다만 특정 채용 공고에 과하게 맞추지 않는다 — 여러 공고에 공통으로 나오는 역량(리눅스, WEB/WAS, DB, 네트워크, 장애 처리 → IaC, CI/CD, 관측성, 쿠버네티스) 기준으로 코칭한다.

## 사용자 환경

- Windows + PowerShell. PC가 두 대: 집 PC, 학원(국비교육) PC.
- **학원 PC에는 AWS 액세스 키를 저장하지 않는다** (공용 PC). 학원에서는 콘솔 로그인·측정·공부 위주, AWS CLI/Terraform 작업은 집에서.
- 평일 저녁 위주로 작업 시간이 제한적이라 한 번에 끝낼 수 있는 크기로 쪼개서 안내한다.

## AWS 계정 상태

- 리전: 서울 `ap-northeast-2`
- **프리티어 크레딧 없음** (혜택 없는 일반 유료 계정으로 취급). Lambda·SQS 등 상시 무료 항목만 기대할 것.
- 예산 알림 이미 생성됨.
- 비용 주의: NAT 게이트웨이, EKS 사용 금지(비쌈). EC2 + 고정 IP + 디스크 대략 월 2만 원 안팎 예상 — 실제 청구액을 기록.

## 대상 앱 정보

### mysite-backend — https://github.com/ddonni/mysite-backend
- FastAPI(Python 3.12) + SQLAlchemy + Alembic 마이그레이션, pytest 테스트
- 실시간 동기화: WebSocket `/ws/rooms/{code}/pages/{n}` → **Nginx 프록시 시 WebSocket 설정 필요**
- REST: `/api/rooms/{code}/...` (방 코드 6자리 읽기 전용 + 비밀 토큰으로 수정)
- DB: PostgreSQL — 현재 Neon(2026-09-27에 Render 무료 DB에서 이전)
- 이미지: AWS S3 (boto3). 현재 Render 환경변수에 **장기 AWS 액세스 키**로 들어가 있음 → 권한 범위 점검 대상
- 환경변수: `DATABASE_URL`, `CORS_ORIGINS`(= `https://ddonni.github.io`), `S3_BUCKET_NAME`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `GOOGLE_CLIENT_ID`
- `Dockerfile` 있음 (python:3.12-slim, uvicorn 8000번)
- `render.yaml`: Docker 런타임, free 플랜, `autoDeploy: true`. 옛 Render DB 블록은 2026-10-15쯤 삭제 예정
- `.github/workflows/ci.yml`: 테스트 → ghcr.io에 `sketchbook-api:latest` 빌드·푸시
  - 알려진 버그: **PR 빌드도 `:latest`를 덮어씀**, SHA 태그 없음

### mysite (프런트) — https://github.com/ddonni/mysite
- 정적 사이트(바닐라 JS ES 모듈, Three.js 로비, 스케치북, 라이브러리), GitHub Pages
- 백엔드 주소는 `js/shared/config.js`에 모여 있음 → 이사 마지막 단계에서 변경

## 진행 상황

### 1단계 — 리눅스 서버 한 대에 직접 올리기
- [ ] 저장소 정리: `ROADMAP.md`, `MEASUREMENTS.md`, `TROUBLESHOOTING.md`
- [x] **1-0 이사 전 측정** (2026-10-05 완료, 숫자는 `MEASUREMENTS.md`)
  - 백엔드에 `GET /health`(DB 안 씀) 추가해서 배포. DB 경로 측정은 운영 방 `TTHB8N` 사용
  - 콜드 스타트 3회 모두 약 22.6초 = 앱 기동 시간(배포 로그: 컨테이너 ~14초 + import ~1초 + lifespan DB/alembic ~7초)
  - 깨어 있을 때 ~0.3초, 그중 ~0.17초는 리전(Render·Neon 모두 Oregon) 왕복. DB 조회 비용은 ~5ms
  - 발견: S3 버킷이 실수로 시드니(`ap-southeast-2`), Neon은 PostgreSQL 18(1-5에서 pg_dump 버전 주의)
  - 사용자 판단: "always-on이 잠드는 무료 서버보다 빠른 건 당연" → 이사 전/후 속도 비교는 성과로 내세우지 않음. 이사 후엔 운영해서 생기는 숫자(복구 시간, 자동 재시작, 배포 시간, 비용)를 중시
- [x] **1-1 계정 안전장치** (2026-10-06 완료)
  - 루트 MFA·루트 액세스 키 없음 확인, IAM 사용자 + `admin` 그룹(`AdministratorAccess`) + MFA, 콘솔 전용(액세스 키 없음)
  - 근거는 `README.md` "선택 근거"(IAM vs Identity Center, 사람/기계 권한 분리, 예방/탐지)
  - 사용자가 헷갈렸던 개념: MFA(인증)와 권한 범위(인가)를 구분하는 것, 기계에는 액세스 키 대신 IAM 역할을 쓴다는 것
  - 트러블슈팅 #1: 사용자를 그룹에 추가하지 않아 권한이 없었음
- [x] **1-2 네트워크** (2026-10-06 완료, 학원에서 콘솔로)
  - 직접 만든 VPC + 퍼블릭 서브넷 1개 + IGW, 메인 라우팅 테이블은 `local`만 두고 퍼블릭 테이블을 따로 만들어 연결
  - 새 웹 보안그룹: 인바운드 80/443만, 22번 닫음(SSM 사용 예정), 아웃바운드 전체 허용(트레이드오프 이해함)
  - 근거는 `README.md` "선택 근거 > 네트워크", 트러블슈팅 #2(보안그룹 소스 종류 변경 불가)
  - 아직 약한 부분: 구성을 "요청이 들어오는 길"로 각 부품의 역할과 함께 설명하기, "퍼블릭 = 라우팅 테이블의 IGW 경로"(사용자가 처음엔 "서브넷 규칙"이라고 답함) → 1-3 들어가기 전에 그림으로 한 번 설명하게 해 볼 것
  - 2026-10-07 확인: "길은 라우팅, 문은 보안그룹" 퀴즈를 맞힘 (그전에 세 번 "보안그룹"이라고 답했음)
- [x] **1-3 EC2** (2026-10-07 완료, Elastic IP만 1-8 직전으로 미룸)
  - `t4g.micro` + Ubuntu 24.04 arm64, 키 페어 없음, IMDSv2만 허용, gp3 8GB(1-11에서 가득 채우고 확장 연습)
  - 역할 `ec2.amazonaws.com` 신뢰 + `AmazonSSMManagedInstanceCore`만. S3 권한은 1-6에서 같은 역할에 버킷 하나로 추가
  - SSM 접속 성공(`ssm-user`), IMDS 토큰 없으면 401 / 토큰 있으면 인스턴스 ID 직접 확인
  - 트러블슈팅 #3: SSM 기본 셸이 `sh`라 줄 편집 불가 → `bash`
  - 사용자가 헷갈렸던 개념: 기계 권한에 또 "액세스 키"를 떠올림(→ 역할), SSM은 서버가 **나가는** 연결, EBS는 켠 채로 확장 가능, wheel 파일 이름 읽기(`aarch64` = 리눅스 ARM)
  - 비용: 전환 전까지는 작업할 때만 인스턴스를 켜기로 함 → 세션 끝날 때 중지했는지 물어볼 것
- [x] **1-4 리눅스 기본 세팅** (2026-10-08 완료)
  - sshd 끔(`ssh.socket`+`ssh.service` disable, socket activation), ufw 80/443, unattended-upgrades 확인 + 자동 재부팅 04:00(`52unattended-upgrades-local`), Asia/Seoul, `/swapfile` 1GB + swappiness 10(`/etc/sysctl.d/99-swappiness.conf`)
  - SSM Session Manager 기본 설정에 `exec bash` 넣음 (한국어 콘솔: 노드 도구 → 세션 관리자 → 기본 설정)
  - 트러블슈팅 #4(설정을 주석째 복사), #5(`mkswap` 빠짐, 홈 디렉터리에 만듦)
  - 사용자가 몰랐던 기초: 스왑이 무엇인지(백업으로 오해했음), `ls -l` 읽기, chmod 숫자, nano 사용법(브라우저에서 Ctrl+X가 안 먹을 때가 있음 → 한/영, F2). **리눅스 기초 개념은 단계를 시키기 전에 먼저 짧게 설명할 것.** 명령 이름만 주면 단계를 빠뜨림
  - ufw를 `80/tcp`, `443/tcp`로 좁히라고 제안함 → 했는지 미확인
  - 나중에 확인할 것: 자동 재부팅이 실제로 일어나는지(`journalctl --list-boots`). 전환 전에는 밤에 서버를 꺼서 확인 불가 → 1-9 이후
- [ ] 1-5 PostgreSQL 직접 운영 ← 다음 (Neon은 PG 18 → 서버 PG 버전과 pg_dump 버전 주의, ufw/보안그룹으로 5432 외부 차단 확인)
- [ ] 1-6 ~ 1-12: ROADMAP.md 참고

측정 명령(PowerShell):
```powershell
curl.exe -s -o NUL -w "dns:%{time_namelookup} tcp:%{time_connect} tls:%{time_appconnect} ttfb:%{time_starttransfer} total:%{time_total} code:%{http_code}`n" https://<백엔드주소>/<경로>
```

## 지난 경과 (같은 실수 반복 방지용)

- **골드버그 파이프라인** (https://github.com/ddonni/goldberg-pipeline, 미배포): S3 → Lambda → SNS → SQS → Lambda → Render 배포 훅을 도미노처럼 잇는 CI/CD. Claude가 코드를 다 작성(테스트 23개) → "서비스를 이어 붙인 느낌, 내가 만든 느낌 없음"으로 중단.
  - 재사용 가능한 아이디어: GitHub Actions OIDC(키 없는 AWS 인증), IAM 최소 권한, 비밀 값은 SSM Parameter Store.
- "직접 만든 Render" 아이디어도 **없는 문제를 지어내는 느낌**이라 기각.
- 결론: 실제로 돌아가는 내 앱을 직접 운영하면서 생기는 진짜 문제를 풀고, 취업에 공통으로 쓰이는 역량을 쌓는다.
