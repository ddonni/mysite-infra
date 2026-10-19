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
- 서버에서 칠 명령을 줄 때: 자리표시(`<이름>`) 말고 **실제 값으로 채워서** 준다. **`journalctl`처럼 root 권한이 필요한 명령은 처음부터 `sudo`를 붙여서** 준다 (2026-10-19 사용자 요청).
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
  - 비용: 전환 전까지는 작업할 때만 인스턴스를 켜기로 했음 → **2026-10-18 전환 후로는 항상 켜 둠(중지 금지)**
- [x] **1-4 리눅스 기본 세팅** (2026-10-08 완료)
  - sshd 끔(`ssh.socket`+`ssh.service` disable, socket activation), ufw 80/443, unattended-upgrades 확인 + 자동 재부팅 04:00(`52unattended-upgrades-local`), Asia/Seoul, `/swapfile` 1GB + swappiness 10(`/etc/sysctl.d/99-swappiness.conf`)
  - SSM Session Manager 기본 설정에 `exec bash` 넣음 (한국어 콘솔: 노드 도구 → 세션 관리자 → 기본 설정)
  - 트러블슈팅 #4(설정을 주석째 복사), #5(`mkswap` 빠짐, 홈 디렉터리에 만듦)
  - 사용자가 몰랐던 기초: 스왑이 무엇인지(백업으로 오해했음), `ls -l` 읽기, chmod 숫자, nano 사용법(브라우저에서 Ctrl+X가 안 먹을 때가 있음 → 한/영, F2). **리눅스 기초 개념은 단계를 시키기 전에 먼저 짧게 설명할 것.** 명령 이름만 주면 단계를 빠뜨림
  - ufw를 `80/tcp`, `443/tcp`로 좁히라고 제안함 → 했는지 미확인
  - ~~나중에 확인할 것: 자동 재부팅이 실제로 일어나는지~~ → 2026-10-19 04:00 실제 발생 확인
- [x] **1-5 PostgreSQL** (2026-10-17 완료)
  - ④ 결과: 직접 연결(풀러 X) 주소, 비밀번호는 프롬프트, `--no-owner --no-privileges -f ~/pg_dump_result.sql`(600) → `psql -U mysite -v ON_ERROR_STOP=1 --single-transaction -f`. 행 수 덤프와 일치(rooms 26, pages 26, records 150, alembic 1), 소유자 전부 `mysite`. 검증은 awk로 덤프 파일의 COPY 줄 수와 비교(Neon 재접속 불필요)
  - 이 과정에서 Neon 비밀번호 노출 → 교체 + Render 갱신 + 예전 값 거절 확인 (트러블슈팅 #7)
  - 1-9 전환 때 같은 명령으로 최종 덤프. 리허설 덤프 파일은 전환 후 삭제
  - 아래는 진행 중 메모(참고용)
  - ① PGDG 저장소에서 PostgreSQL 18 설치 (Neon과 버전 맞춤)
  - ② 롤 `mysite`(속성 없음, `\password`로 설정) + DB `mysite`(소유자 `mysite`). 비밀번호는 한 번 잃어버려서 재설정함 → 사용자 비밀번호 관리자에 보관
  - ③ `127.0.0.1:5432`만 듣는 것 확인, pg_hba 기본값 읽기, `psql -h 127.0.0.1 -U mysite` 접속 성공. 외부 접속 실패는 학원에서 확인 → **집에서 `Test-NetConnection <IP> -Port 5432` 재확인**(학원 방화벽 때문일 수 있음)
  - 사용자가 못 맞힌 것: `-h` 없이 접속하면 peer 인증으로 거절되는 이유(설명함). "앱 롤에 최상위 권한 필요"라고 오해 → DB 소유자면 충분하다고 설명함
  - **다음 ④ (집에서)**: Neon에서 `pg_dump` → 서버에 복원 → 행 개수 비교(1-0 기준 rooms 17, pages 17, records 147. 그사이 늘었을 수 있으니 Neon에서도 다시 셀 것). 이번은 리허설이라 1-9 전환 때 다시 덤프해야 함. Neon 접속 주소에 비밀번호가 있으니 bash 기록에 남지 않게 하는 방법부터 고민시킬 것(`PGPASSWORD`를 명령 앞에 쓰는 것도 기록에 남음 → `~/.pgpass` 600 또는 프롬프트). 덤프 형식(plain vs custom `-Fc`)과 소유자 옵션(`--no-owner`, `--no-privileges`: Neon 롤 이름이 다를 것)도 질문거리
- [x] **1-6 앱을 systemd 서비스로** (2026-10-17 완료)
  - C 완료: `/etc/mysite/backend.env`(root 600, AWS 키 없음) + `/etc/systemd/system/mysite-backend.service`(User=mysite, 127.0.0.1:8000, Restart=always, NoNewPrivileges/ProtectSystem=strict/ProtectHome/PrivateTmp). 확인 5개 모두 통과(방 JSON, 실행 계정 mysite, kill -9 복구, 재부팅 후 자동 기동, 메모리 available 521Mi)
  - 트러블슈팅 #8: 서버 코드(10/08 clone)가 DB(10/15 마이그레이션 b7d41e9c0a52)보다 오래돼서 무한 재시작 → `git pull` + pip. **1-9 전환 때 서버 코드를 운영과 같은 커밋으로 맞출 것**
  - 서버 코드 업데이트 방법(지금은 수동): `sudo git -C /opt/mysite-backend pull` → `sudo .venv/bin/pip install -r requirements.txt` → `sudo systemctl restart mysite-backend`
  - 아래는 진행 중 메모(참고용)
  - 설계 결정: 앱 실행 계정 `mysite`(`--system`, nologin), 코드 `/opt/mysite-backend`(git clone, public 저장소), **코드·venv는 root 소유, 앱 실행 계정은 읽기만**(털려도 코드에 백도어를 못 심게). 앱은 디스크에 쓸 일이 없음(사진은 S3, 로그는 journald)
  - 사용자가 "앱 사용자"를 서비스 고객으로 오해했었음 → "앱 실행 계정"이라고 부르기로 함. 이해한 핵심: "인터넷 입력을 직접 처리하는 계정이 가장 먼저 털리니 가장 적은 권한"
  - 2026-10-17 집에서 확인 완료: `mysite` nologin(UID 999), `/opt/mysite-backend` 폴더·내용 root 소유 755/644, import OK. venv가 비어 있어서 재설치함(트러블슈팅 #6, 원인 미확인). 메모리·디스크는 MEASUREMENTS 2-1에 기록(디스크 65%, available 479Mi)
  - ufw는 여전히 `80`, `443`(tcp/udp 둘 다). `/tcp`로 좁힐지 사용자 결정 대기. 집에서 `Test-NetConnection <IP> -Port 5432` → TCP 실패 + ping TimedOut 확인(2026-10-17). 1-5 ③ 외부 차단 완료
  - **B 완료 (2026-10-17)**: 예전 버킷 `mysite-buckets`(시드니)은 **다른(주인 불명) AWS 계정**이라 교차 계정 대신 **이 계정 서울에 새 버킷 `mysite-photos-ddonni`** 생성. ACL 비활성화, 퍼블릭 차단은 ACL 두 개만 켬, 버킷 정책 = `records/*` 공개 GetObject만. EC2 역할 인라인 정책 = `s3:PutObject` on `mysite-photos-ddonni/records/*`. 확인: records/ OK, 맨 위 AccessDenied, PC에서 공개 GET 200
    - 예전 사진(119장, 5.4MB)은 DB에 전체 URL로 있어서 예전 버킷에서 계속 보임 → **평일에 새 버킷으로 복사 + DB `photo_url` 치환**해서 주인 불명 계정 의존을 끊을 것
    - 사고: 사용자가 Render 환경변수를 새 버킷으로 바꿨다가(Render엔 역할이 없어 업로드가 깨짐) 원래대로 되돌려 재배포. 업로드 실제 확인 여부 미확인
    - 로컬: pytest는 FakeS3라 AWS 불필요. 로컬 docker의 `.env`는 당분간 예전 버킷·키 유지
    - 1-7 메모: `_client_ip`가 X-Forwarded-For의 **첫 번째** 값을 씀 → Nginx에서 `$proxy_add_x_forwarded_for`(덧붙이기)로 하면 클라이언트가 위조 가능. `X-Forwarded-For $remote_addr`로 덮어쓸 것
  - (이전 메모) 남은 것 B: EC2 역할에 S3 권한 추가. 코드(`storage.py`)는 `put_object`만, 키는 `records/<uuid>.<ext>` → `s3:PutObject` on `arn:aws:s3:::<버킷>/records/*` 를 사용자가 코드에서 직접 찾아내게 할 것. 확인: 서버 venv의 boto3로 `records/` 업로드 성공 + 다른 경로 AccessDenied (테스트 객체는 콘솔에서 지우기). Render의 장기 키는 1-9 전환 후 삭제
  - 남은 것 C(1-5 ④ 이후): 환경변수 파일(600, DB 비밀번호), systemd 유닛, 재부팅/`kill` 테스트
  - 집에서 할 순서: 확인 → 1-5 ④ → 1-6 B → 1-6 C
- [ ] 1-7 ~ 1-12: ROADMAP.md 참고
  - 2026-10-17(토) 사용자가 "이번 주말 안에 끝내자, 속도 올리자" → 명령을 바로 주는 모드. 계획: 토 = 1-5 ④·1-6 B·C / 일 = 1-7·1-8·1-9 전환 / 평일 = 1-10~1-12
  - **1-8 도메인: 무료 서브도메인(DuckDNS 등)으로 결정** (2026-10-17). 시작할 때 Elastic IP부터 붙일 것
  - **1-7 완료 (2026-10-18)**: 아래 설정 그대로 적용. WebSocket 101 + 211초 유지(Claude가 집 PC에서 Python websockets로 테스트). 백엔드 수정 2개 push: `227fbcd` 로그 꺼짐 수정(#9), `78bf72d` `pool_pre_ping`(#10, 대조 실험으로 고치기 전 500 / 고친 후 200 확인 — 사용자가 "고치기 전에 500 나는지도 봐야 하지 않냐"고 먼저 짚음). 서버를 `checkout main`으로 되돌렸는지 결과 미확인 → 다음에 `git -C /opt/mysite-backend log --oneline -1` = 78bf72d 확인
  - **1-8 완료 (2026-10-18)**: Elastic IP + **`https://mysite-ddonni.duckdns.org`** (DuckDNS, 토큰은 비밀). certbot(apt판) `--nginx --redirect`, 만료 2027-01-16, `certbot.timer` + dry-run 성공. wss 210초 유지. 응답 시간 /health 0.057초(Render 0.329) → MEASUREMENTS 2-2a, 1-0 리전 가설 확인
    - 사고: `sed`에 `<이름>` 자리표시를 그대로 넣어 실행 → 이후 **사용자에게 줄 명령은 실제 값으로 채워서** 줄 것(모르면 먼저 물어보기)
    - 비용: 월 약 $12(+VAT 약 $13): t4g.micro ~$7.6, 퍼블릭 IPv4 $3.65(EIP는 중지해도 과금), EBS ~$0.73. MEASUREMENTS 2-2에 적을지 물어봤음(답 없음)
  - **1-9 전환 완료 (2026-10-18 21:21)** — 절차·기록은 `CUTOVER.md`. 최종 덤프 rooms 26 / pages 26 / records 151. 프런트 `53fb4ff`. 브라우저 체크리스트 통과. **병행 운영 중**: Render·Neon은 롤백용으로 유지
    - ⚠️ **이제 EC2가 운영 서버다. 인스턴스를 중지하지 말 것**(1-3의 "작업할 때만 켜기"는 끝). 새벽 자동 업데이트·04:00 재부팅이 운영에 영향 → `pool_pre_ping`으로 대비됨
    - ~~백업이 아직 없다~~ → **1-10 완료 (2026-10-18 밤)**: 매일 03:30 pg_dump → `mysite-backups-ddonni`(비공개, 14일 만료), 복구 훈련 0.823초·행 수 일치. 다음 날 `systemctl list-timers` / `sudo journalctl -u mysite-db-backup --since yesterday`로 새벽 실행 확인할 것
    - 결정 기록: 사용자가 "서버 꺼 두면 안 되나", "꺼지면 자동으로 Render로 넘기면?"을 물음 → **켜 두기로**(월 $12, 운영 경험이 목적). 자동 장애 조치는 DB가 둘로 갈라지는 스플릿 브레인(Render는 전환 시점의 Neon을 봄) 때문에 기각, 수동 롤백(CUTOVER.md) + 백업으로 대응
    - **2026-10-19 아침 점검 완료** (학원): 03:30 백업 성공 + S3 파일 확인, 04:00 자동 재부팅 실제 발생(다운타임 약 19초, MEASUREMENTS 2-2c), 서버 코드 `78bf72d`, `openssh-server` 업데이트 후에도 ssh 유닛 disabled. 1-4의 "자동 재부팅 실제 확인"도 이걸로 완료. 사용자가 `journalctl`은 sudo가 필요하다는 걸 직접 발견
    - **1-11 디스크 가득 참 실험 계획** (2026-10-19 학원에서 설계, 실행은 늦은 밤 23~01시. 03:30 백업·04:00 재부팅과 겹치지 않게)
      - 준비: `sudo systemctl start mysite-db-backup`(직전 백업) + EC2 콘솔에서 EBS 스냅샷 + `df -h /` 기준값 기록
      - 채우기: `sudo fallocate -l <크기> /var/tmp/diskfill.img` → 단계 A 80% / B 95% / C 100% / D 파일 삭제 후 회복 여부. E(EBS 확장)는 **방법만 정리**하기로 함(되돌릴 수 없어서)
      - 예약 블록 0 확인(`tune2fs`: Reserved block count 0, Ubuntu 클라우드 이미지) → root도 같이 막힘. 일단 0인 채로 실험하고 `tune2fs -m 1`은 결과 보고 결정
      - **사용자 예측**: 100%에서 ① 방 읽기 ✗ ② 그림 저장 ✗ ③ journald 로그 ✗, ④ 파일 지우면 저절로 회복 ○ → 실험 후 예측 vs 관찰을 TROUBLESHOOTING에 기록(①은 예측과 다를 수 있다고 힌트만 줬음)
      - 되돌리기: `rm` → 필요하면 서비스 재시작 → DB 꼬이면 직전 백업 `pg_restore` → 최후엔 스냅샷 복원
    - 남은 정리(병행 운영 후): Render 서비스 삭제, 예전 계정의 장기 키 삭제, Neon 정리 여부, 덤프 파일 삭제, 예전 사진 새 버킷으로 복사 + `photo_url` 치환
  - (이전) 다음: **1-9 전환** — 롤백 계획부터. 사용자에게 던진 질문: "무엇을 바꿔서 Render로 되돌리나, 그사이 내 서버에 쌓인 데이터는?"
  - (완료) 1-8 계획: Elastic IP → DuckDNS → certbot, `server_name` 도메인으로 교체
  - (완료된 계획 메모) **1-7 다음 시작점 (2026-10-18 예정)**: 10-17 밤에 Nginx 설정 안(아직 실행 안 함)을 줬음 — `map $http_upgrade`, `proxy_http_version 1.1`, Upgrade/Connection 헤더, `X-Forwarded-For $remote_addr`(덮어쓰기, 위조 방지), `client_max_body_size 11m`(기본 1MB면 사진 413), default 사이트 제거, `nginx -t` → reload → `nginx -T`로 적용 확인. 테스트: PC에서 `/health`, 8000 외부 차단, curl WebSocket 핸드셰이크 101, **Claude가 집 PC에서 Python websockets로 3분 유지 테스트**(Nginx 기본 60초 유휴 타임아웃 vs uvicorn 20초 ping)

측정 명령(PowerShell):
```powershell
curl.exe -s -o NUL -w "dns:%{time_namelookup} tcp:%{time_connect} tls:%{time_appconnect} ttfb:%{time_starttransfer} total:%{time_total} code:%{http_code}`n" https://<백엔드주소>/<경로>
```

## 지난 경과 (같은 실수 반복 방지용)

- **골드버그 파이프라인** (https://github.com/ddonni/goldberg-pipeline, 미배포): S3 → Lambda → SNS → SQS → Lambda → Render 배포 훅을 도미노처럼 잇는 CI/CD. Claude가 코드를 다 작성(테스트 23개) → "서비스를 이어 붙인 느낌, 내가 만든 느낌 없음"으로 중단.
  - 재사용 가능한 아이디어: GitHub Actions OIDC(키 없는 AWS 인증), IAM 최소 권한, 비밀 값은 SSM Parameter Store.
- "직접 만든 Render" 아이디어도 **없는 문제를 지어내는 느낌**이라 기각.
- 결론: 실제로 돌아가는 내 앱을 직접 운영하면서 생기는 진짜 문제를 풀고, 취업에 공통으로 쓰이는 역량을 쌓는다.
