# mysite 이사 프로젝트 — Render에서 내가 운영하는 서버로

> 목표: mysite-backend(FastAPI + PostgreSQL + WebSocket)를 Render 무료 플랜에서 AWS의 내 리눅스 서버로 옮기고, **직접 운영**한다.
> 1단계는 지금 지원 가능한 SE 공고(리눅스·WEB/WAS·DB·네트워크·장애 처리)를, 2~3단계는 데브옵스 공고(IaC·CI/CD·관측성·쿠버네티스)를 겨냥한다.

## 진행 규칙

- 코드와 설정은 **내가 직접** 짠다. Claude는 힌트·개념 설명·리뷰 담당. 막히면 에러 원문을 들고 물어본다.
- 각 단계는 **완료 확인** 항목을 내 눈으로 확인해야 체크한다.
- 문제가 생기면 `TROUBLESHOOTING.md`에 바로 적는다: **증상 → 원인 추측 → 확인한 것 → 진짜 원인 → 해결 → 배운 점.** 이게 면접에서 제일 강한 무기다.
- 단계 하나 끝날 때마다 커밋.

공고 표시: 🅢 = 위즈코리아 SE(지금 지원 가능) · 🅓 = 데이터유니버스 클라우드 인프라(목표)

---

## 1단계 — 리눅스 서버 한 대에 직접 올리기

### 1-0. 이사 전 측정 (학원에서도 가능)
- [x] Render 백엔드가 **잠든 상태**(15분 이상 요청 없음)에서 첫 응답 시간 측정 — 3번
- [x] 깨어 있는 상태의 응답 시간 측정 — 10번 평균
- [x] 현재 DB 크기, 테이블 목록, 환경변수 목록(값 말고 이름만) 정리
- 힌트: PowerShell에서 `curl.exe -s -o NUL -w "%{time_total}\n" <백엔드 주소>`
- 완료 확인: 숫자가 `MEASUREMENTS.md`에 적혀 있다 → 마지막에 이사 후 숫자와 비교
- 공고: 🅓 성능 지표 분석

### 1-1. 계정 안전장치
- [x] 루트 계정 MFA, 작업용 IAM 사용자(+MFA) 만들고 앞으로 콘솔은 IAM 사용자로만
- [x] 예산 알림 확인 (이미 생성함 ✅)
- [x] 학원 PC에는 액세스 키 저장 금지 — 콘솔 로그인만 하고 끝나면 로그아웃
- 권한 선택 근거는 `README.md` "선택 근거"에 기록
- 공고: 🅢 보안 / 🅓 운영

### 1-2. 네트워크를 손으로 만들기 (콘솔)
- [x] VPC, 퍼블릭 서브넷, 인터넷 게이트웨이, 라우팅 테이블을 **기본 VPC 말고 직접** 만든다
- [x] 보안그룹: 80/443은 전체, 22(SSH)는 **내 IP만** — 또는 SSM Session Manager로 22번 자체를 닫기 → **SSM 선택, 22번 닫음** (1-3에서 EC2에 SSM용 IAM 역할 필요)
- 선택 근거는 `README.md` "선택 근거 > 네트워크"에 기록
- 생각할 것: 서브넷의 "퍼블릭"은 무엇으로 결정되나? (라우팅 테이블 한 줄)
- 비용 주의: NAT 게이트웨이는 만들지 않는다 (켜두기만 해도 월 수만 원)
- 완료 확인: 내가 만든 VPC 구성을 종이에 그려서 설명할 수 있다
- 공고: 🅢 NW · 네트워크관리사 / 🅓 네트워크

### 1-3. 서버(EC2) 띄우기
- [x] Ubuntu 24.04 LTS, t4g.small 정도 (작은 서버 + 스왑으로 버틸지 직접 판단) → **`t4g.micro` + 스왑**, 키 페어 없이 SSM, IMDSv2만 허용, 디스크 8GB
- [ ] 고정 IP(Elastic IP) 연결 → **1-8(도메인) 직전으로 미룸** (그전까지는 작업할 때만 켜서 비용 절감)
- 완료 확인: 내 PC에서 서버에 접속된다
- 비용 메모: 서버 + 고정 IP + 디스크 대략 월 2만 원 안팎 — 실제 청구액을 `MEASUREMENTS.md`에 기록

### 1-4. 리눅스 기본 보안·운영 세팅
- [x] 작업용 사용자 + sudo, SSH 비밀번호 로그인·root 로그인 끄기 → SSM의 `ssm-user`가 작업용 사용자 역할, **sshd 자체를 끔**(`ssh.socket`·`ssh.service` disable)
- [x] 방화벽(ufw) — 보안그룹과 이중으로 두는 이유를 설명할 수 있게
- [x] 자동 보안 업데이트(unattended-upgrades), 시간대 Asia/Seoul → 자동 재부팅 04:00 KST 추가
- [x] 메모리가 작으면 스왑 파일 → `/swapfile` 1GB, swappiness 10
- 완료 확인: ~~비밀번호로 SSH 시도 → 거절되는 걸 직접 본다~~ → SSH를 안 쓰므로 **재부팅 후에도 22번을 듣는 프로세스가 없다**(`ss -tlnp`)로 변경. 2026-10-08 확인
- 공고: 🅢 리눅스·OS, 취약점 조치 · 리눅스마스터

### 1-5. PostgreSQL 직접 운영 (DB)
- [x] 설치, 앱 전용 DB 사용자/DB 생성 (슈퍼유저로 앱 돌리지 않기) → PGDG 저장소에서 **PostgreSQL 18**, 롤 `mysite`(속성 없음) + DB `mysite`(소유자 `mysite`)
- [x] 외부 접속 차단 — 서버 안에서만 접속되게 (`listen_addresses`, `pg_hba.conf`) → 기본값 `localhost`·`127.0.0.1:5432` 확인. 학원에서 외부 접속 실패 확인(학원 방화벽일 수도 있어서 집에서 재확인)
- [x] Neon에서 `pg_dump` → 내 서버에 복원, 행 개수 비교로 데이터 이전 검증 → 2026-10-17 리허설 완료: rooms 26 / pages 26 / records 150 / alembic_version 1, 덤프와 일치, 소유자 전부 `mysite`. 1-9 전환 때 같은 절차로 다시 덤프
- 생각할 것: Neon(관리형)을 버리고 직접 운영하면 무엇을 얻고 무엇을 책임지게 되나?
- 완료 확인: 서버 밖에서 5432 접속 시도 → 실패, 안에서는 성공
- 공고: 🅢 DB / 🅓 RDB

### 1-6. 앱을 리눅스 서비스로 실행 (WAS)
- [x] 코드 배치, Python 가상환경, 의존성 설치, Alembic 마이그레이션 → `/opt/mysite-backend`(root 소유), 앱 실행 계정 `mysite`(nologin). 마이그레이션은 앱 시작 시 자동 (코드가 DB보다 오래돼서 실패 → 트러블슈팅 #8)
- [x] **systemd 서비스**로 uvicorn 실행 — `mysite-backend.service`, `127.0.0.1:8000`, `Restart=always`, `ProtectSystem=strict` 등. 2026-10-17 확인: 재부팅 후 자동 기동, `kill -9` 후 새 PID로 복구, 실행 계정 `mysite`
- [x] 환경변수는 권한 600 파일로 (깃에 절대 안 올림) → `/etc/mysite/backend.env`(root 600, systemd가 읽어서 주입). AWS 키 없음(EC2 역할)
- [x] (추가) S3: 예전 버킷이 다른 계정·시드니라 이 계정 서울에 `mysite-photos-ddonni` 새로 만듦. 역할에 `records/*` PutObject만
- 완료 확인: `sudo reboot` 후 아무것도 안 해도 앱이 떠 있다 / 프로세스를 `kill` 하면 다시 살아난다
- 공고: 🅢 WAS, 리눅스 / 🅓 시스템

### 1-7. Nginx 리버스 프록시 (WEB)
- [x] Nginx가 80/443을 받고 uvicorn으로 넘긴다 (uvicorn은 외부에 직접 안 열기) → 2026-10-18: 80 → `127.0.0.1:8000`, 8000 외부 차단 확인. `X-Forwarded-For $remote_addr`(덮어쓰기), `client_max_body_size 11m`
- [x] **WebSocket 프록시 설정** — `proxy_http_version 1.1` + Upgrade/Connection 헤더(`map`). 핸드셰이크 101, **211초 유지 후 정상 종료**(양쪽 20초 ping으로 Nginx 60초 유휴 타임아웃에 안 걸림). 조사하다 앱 쪽 문제 둘 발견·수정: 로그가 꺼져 있음(트러블슈팅 #9), PostgreSQL 재시작 후 첫 요청 500(#10)
- 완료 확인: 브라우저 개발자도구에서 WebSocket 연결이 101로 열리고 몇 분 놔둬도 유지된다
- 공고: 🅢 WEB/WAS

### 1-8. 도메인과 HTTPS
- [x] 도메인 결정 (구매 vs 무료 서브도메인) → DNS A 레코드 → 2026-10-18: Elastic IP 할당·연결 + DuckDNS `mysite-ddonni.duckdns.org`
- [x] Let's Encrypt 인증서 + **자동 갱신이 실제로 예약돼 있는지** 확인 → `certbot --nginx --redirect`, ECDSA, 만료 2027-01-16. `certbot.timer` 예약 + `renew --dry-run` 성공. HTTP→HTTPS 301, `https://.../health` 200, `wss://` 210초 유지
- 생각할 것: 프런트(GitHub Pages)가 HTTPS인데 백엔드가 HTTP면 브라우저는 왜 막나?
- 완료 확인: `https://내도메인`으로 API 응답, 인증서 만료일 확인
- 공고: 🅢 NW / 🅓 네트워크

### 1-9. 프런트 연결과 전환 (롤백 계획 먼저)
- [x] **롤백 계획을 먼저 적는다**: 문제가 생기면 무엇을 바꿔서 Render로 되돌리나 → `CUTOVER.md` (롤백 스위치 = `config.js` 한 줄을 revert, 롤백 B = EC2 → Neon 역방향 덤프)
- [x] `js/shared/config.js`의 API 주소 변경, CORS 확인 → 2026-10-18 21:21 전환 (`mysite` `53fb4ff`), 브라우저 체크리스트 통과
- [ ] 며칠 병행 운영 → 문제 없으면 Render 정리
- [ ] (후보) S3 버킷을 시드니 → 서울로 옮기기 — 버킷은 리전 변경 불가라 새 버킷 + 사진 복사 + DB의 `photo_url` 갱신이 필요. 전환과 같이 할지 따로 할지 결정
- 완료 확인: 실제 사이트에서 그림 저장·동기화·라이브러리 사진 업로드가 다 된다
- 공고: 🅢 구축·운영 / 🅓 서비스 안정성

### 1-10. 백업과 복구 훈련
- [x] 매일 `pg_dump` → S3 업로드 (systemd timer 또는 cron), 오래된 백업 자동 삭제 → 2026-10-18: `mysite-db-backup.timer`(03:30) + `.service`(User=postgres, peer 인증이라 비밀번호 파일 없음) + `/usr/local/bin/mysite-db-backup`. 비공개 버킷 `mysite-backups-ddonni`, 수명 주기 14일. 역할은 `db/*` Put/Get만(삭제 권한 없음)
- [x] **복구 훈련**: 새 DB에 백업을 복원해서 데이터 확인, 걸린 시간 측정 → 0.823초, 행 수 일치. RPO 24시간 / RTO는 MEASUREMENTS 2-2b
- [ ] (남은 것) 타이머가 실제로 새벽에 돌았는지 다음 날 확인. 백업 실패 알림은 2단계(관측성)에서
- 완료 확인: "어제 백업에서 몇 분 안에 복구 가능"을 숫자로 말할 수 있다
- 공고: 🅢 DB, 장애 처리

### 1-11. 일부러 고장 내기 (장애 대응 연습)
- [x] 앱 프로세스 강제 종료 → 자동 복구되는지 → 1-6에서 확인(`kill -9` 후 3초 안에 새 PID, 2026-10-17)
- [x] PostgreSQL 중지 → 사이트는 어떻게 보이고, 로그(`journalctl`, Nginx error log)엔 뭐가 남나 → 2026-10-19 트러블슈팅 #11: 예측 4개 적중, `/health`는 거짓 healthy(readiness 체크 필요), ProtectHome 때문에 SSL 시도가 매번 실패하던 문제 발견 → `sslmode=disable`
- [x] 디스크·메모리 부족 상황 확인 방법 익히기 (`df`, `free`, `top`) → `df -h`, `free -h`(available을 볼 것), `ps -eo rss,... --sort=-rss`로 범인 찾기(10/17 unattended-upgrades 119MB)
- [x] 8GB 디스크를 일부러 가득 채워 보고 → 서버를 켠 채로 EBS 볼륨 확장 (1-3에서 일부러 8GB로 둠) → 2026-10-19 트러블슈팅 #12: 100%에서 읽기 ○, 그림 저장 500(**Nginx** 본문 임시 파일 실패), 파일 삭제로 저절로 회복. 볼륨 확장은 되돌릴 수 없어서 **방법만 정리**(#12 아래)
- [x] 로그가 디스크를 채우지 않게 로그 로테이션 확인 → 2026-10-19: Nginx는 logrotate 매일 00:00·14개·압축(실제로 돈 것 확인). journald는 기본 상한이 디스크의 10%(≈680MB)라 `/etc/systemd/journald.conf.d/size.conf`로 **SystemMaxUse=200M**(현재 94MB, 하루 약 8MB → 약 25일 보관)
- 완료 확인: 각 실험이 `TROUBLESHOOTING.md`에 기록돼 있다
- 공고: 🅢 장애 처리·트러블슈팅 / 🅓 서비스 안정성

### 1-12. 마무리 문서화
- [ ] 이사 후 응답 시간 재측정 → 1-0 숫자와 비교
- [ ] README: 구성도, 선택 근거, 월 비용, 롤백·복구 방법
- 완료 확인: 처음 보는 사람이 README만 보고 구조를 이해한다

---

## 2단계 — 자동화와 관측성 (요약)
- 1단계에서 **손으로 만든 걸 Terraform으로 코드화** (VPC, 보안그룹, EC2) — 손으로 해봤기 때문에 코드가 읽힌다
- GitHub Actions로 배포 자동화 (골드버그 때 만든 GitHub OIDC·최소 권한 IAM 재사용)
- Prometheus + node_exporter + Grafana, 장애 알림
- 공고: 🅓 IaC, CI/CD, Observability

## 3단계 — 쿠버네티스 (요약)
- k3s + ArgoCD로 이전, 무중단 배포 중 WebSocket 연결 처리, graceful shutdown
- CKA 공부와 같이
- 공고: 🅓 Kubernetes, CI/CD, MSA
