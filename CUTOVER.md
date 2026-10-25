# CUTOVER — Render → EC2 전환 절차서 (1-9)

> 전환하는 날 위에서부터 그대로 따라간다. 각 단계는 **확인**이 통과해야 다음으로 간다.
> 처음 실행: 2026-10-18(일) 저녁

## 구성 요약

| | 전환 전 | 전환 후 |
|---|---|---|
| 프런트 | GitHub Pages `https://ddonni.github.io` | 그대로 |
| 백엔드 주소 (`mysite/js/shared/config.js`의 `API_BASE`) | `https://sketchbook-api.onrender.com` | `https://mysite-ddonni.duckdns.org` |
| DB | Neon (Oregon) | EC2 안의 PostgreSQL 18 |
| 사진 업로드 | 버킷 `mysite-buckets` (시드니, 다른 계정, 장기 키) | 버킷 `mysite-photos-ddonni` (서울, EC2 역할) |

**전환 스위치는 `API_BASE` 한 줄이다.** WebSocket 주소도 여기서 만든다(`store.js`의 `API_BASE.replace(/^http/, 'ws')`).
롤백 스위치가 GitHub에 있으니, EC2가 통째로 죽어도 되돌릴 수 있다. 롤백 스위치는 문제가 생긴 시스템 바깥에 있어야 한다.

## 데이터 손실이 생길 수 있는 구간

1. **최종 덤프부터 프런트 배포까지** (몇 분): 그사이 Render/Neon에 쓰인 데이터는 내 서버로 오지 않는다. → 사람이 적은 시간에, 쉬지 않고 진행한다.
2. **이미 열려 있던 탭**: 예전 `config.js`를 들고 있어서, 새로고침하기 전까지 Render로 쓴다. → 잃는 양이 적다고 보고 받아들인다.
3. **롤백할 때**: 전환 이후 EC2에 쌓인 데이터. → 아래 "롤백 B"의 역방향 덤프로 Neon에 옮긴 뒤 되돌린다.

사진은 손실 걱정이 없다. 어느 버킷에 올라갔든 공개 URL이라, 어느 백엔드를 쓰든 그대로 보인다.

---

## 0. 사전 점검 (서버)

```bash
git -C /opt/mysite-backend log --oneline -1          # 백엔드 main 최신 커밋과 같아야 함
systemctl is-active mysite-backend nginx postgresql  # 셋 다 active
curl -s https://mysite-ddonni.duckdns.org/health; echo
df -h / ; free -h
```

- 서버 코드가 GitHub `main`과 같은지 확인한다(#8 재발 방지).
- 새 마이그레이션이 있으면, 앱이 시작할 때 서버 DB에도 적용된다. Neon에 이미 적용됐는지는 Render 배포 상태로 확인한다.

## 1. 최종 덤프 (서버)

```bash
pg_dump "postgresql://neondb_owner@<Neon 직접 연결 호스트>/neondb?sslmode=require&channel_binding=require" \
  --no-owner --no-privileges -f ~/pg_dump_final.sql      # 비밀번호는 프롬프트가 뜬 뒤 붙여넣기
chmod 600 ~/pg_dump_final.sql
grep -c neondb_owner ~/pg_dump_final.sql                 # 0
```

## 2. 서버 DB 교체 (서버)

```bash
sudo systemctl stop mysite-backend                       # DB 연결을 끊어야 DB를 지울 수 있음
sudo -u postgres dropdb mysite                           # 리허설 데이터 삭제
sudo -u postgres createdb -O mysite mysite               # 빈 DB, 소유자 mysite
psql -h 127.0.0.1 -U mysite -d mysite -v ON_ERROR_STOP=1 --single-transaction -f ~/pg_dump_final.sql
```

**확인**: 덤프 파일의 행 수 = DB 행 수, 소유자는 전부 `mysite`

```bash
awk '/^COPY /{t=$2;n=0;next} /^\\\.$/{if(t)print t, n; t=""} t{n++}' ~/pg_dump_final.sql
psql -h 127.0.0.1 -U mysite -d mysite -c "select 'rooms' t, count(*) from rooms union all select 'pages', count(*) from pages union all select 'records', count(*) from records union all select 'alembic_version', count(*) from alembic_version;"
psql -h 127.0.0.1 -U mysite -d mysite -c '\dt'
```

```bash
sudo systemctl start mysite-backend
sudo journalctl -u mysite-backend -n 8 --no-pager        # Application startup complete
curl -s https://mysite-ddonni.duckdns.org/api/rooms/TTHB8N; echo
```

## 3. 프런트 전환 (집 PC, `mysite` 저장소)

`js/shared/config.js`: `'https://sketchbook-api.onrender.com'` → `'https://mysite-ddonni.duckdns.org'`
→ 커밋 → push → GitHub Pages 배포 완료를 기다린다(Actions 탭 또는 아래 명령).

```powershell
curl.exe -s https://ddonni.github.io/mysite/js/shared/config.js | Select-String API_BASE   # 새 주소가 보이면 배포 완료
```

## 4. 전환 확인 (브라우저, 강력 새로고침 Ctrl+F5)

- [ ] 개발자도구 Network: API 요청이 `mysite-ddonni.duckdns.org`로 가고 200
- [ ] 스케치북: WebSocket이 `wss://mysite-ddonni.duckdns.org/ws/...`로 **101**
- [ ] 그림을 그려 저장 → 새로고침해도 남아 있음
- [ ] **다른 브라우저(또는 시크릿 창)** 에서 같은 페이지를 열어 두고 그림 → 실시간으로 반영(브로드캐스트)
- [ ] 라이브러리: 기록 목록 보임, **사진 업로드** → 새 버킷 URL(`mysite-photos-ddonni.s3.ap-northeast-2...`)로 보임
- [ ] 예전 사진(시드니 버킷)도 그대로 보임
- [ ] 서버 로그에 실제 브라우저 요청이 찍힘: `sudo tail -f /var/log/nginx/access.log`

## 5. 병행 운영 (며칠)

- Render 서비스와 Neon은 **지우지 않는다**(롤백용). Render는 계속 Neon을 바라본다.
- 매일 한 번: `sudo journalctl -u mysite-backend --since yesterday | grep -iE "error|exception" | head`, `free -h`, `df -h /`
- 며칠 동안 문제가 없으면 정리: Render 서비스 삭제, Render의 장기 AWS 키 삭제(그 키의 계정 쪽에서), Neon 정리 여부 결정, 리허설·최종 덤프 파일 삭제

---

## 롤백

> **2026-10-25 병행 운영 종료로 Render·Neon을 삭제해서, 아래 롤백 A/B는 더 이상 쓸 수 없다.** 전환 기간에 쓰려고 세운 계획으로 기록만 남긴다. 지금 EC2에 큰 문제가 생기면 서버를 다시 만들고 S3 백업으로 복원한다(README "롤백·복구 방법").

### 언제 롤백하나

- 사이트의 핵심 기능(그림 저장·동기화, 기록 보기·저장)이 **10분 넘게** 안 되고, 원인을 바로 못 고칠 때
- EC2에 접속할 수 없을 때(SSM 불가, 인스턴스 이상)

### 롤백 A — 전환 직후, 새 데이터가 거의 없을 때

1. `mysite`에서 전환 커밋을 `git revert` → push → Pages 배포 확인(3번의 curl로 `onrender.com`이 보이는지)
2. Render가 잠들어 있으면 첫 요청에 약 22초가 걸린다(1-0 측정). 미리 `/health`를 한 번 호출해서 깨워 둔다.
3. 그사이 EC2에 쓰인 데이터는 버린다.

### 롤백 B — 전환 후 시간이 지나서 EC2에 데이터가 쌓였을 때

1. 롤백 A의 1번을 먼저 한다(새 쓰기가 EC2로 가지 않게).
2. EC2 DB를 덤프: `pg_dump -h 127.0.0.1 -U mysite -d mysite --no-owner --no-privileges -f ~/pg_dump_rollback.sql`
3. Neon을 비우고 복원한다(Neon 콘솔에서 브랜치를 만들어 백업해 둔 뒤 진행). Render 앱을 잠깐 중지한 상태에서 한다.
4. 행 수를 비교하고 Render를 재시작한다.

## 실행 기록

| 날짜 | 단계 | 결과 / 메모 |
|---|---|---|
| 2026-10-18 | 1 최종 덤프 | Neon 직접 연결, `neondb_owner` 0줄 |
| 2026-10-18 21:19 | 2 DB 교체 | dropdb → createdb → 복원. rooms 26 / pages 26 / records 151 / alembic 1, 덤프와 일치. 앱 21:19:58 시작 |
| 2026-10-18 21:20:30 | 3 프런트 push | `mysite` `53fb4ff`. **Pages 배포 확인 21:21:08** (push 후 약 40초). 최종 덤프 ~ 배포 사이가 데이터 손실 가능 구간 |
| 2026-10-18 저녁 | 4 브라우저 확인 | 사용자가 체크리스트 확인 완료 (API·WebSocket이 새 도메인으로, 저장·실시간 반영, 기록·사진). **전환 완료, 병행 운영 시작** |
| 2026-10-25 | 5 병행 운영 종료 | 예전 사진 149장을 새 버킷으로 옮김(트러블슈팅 #13). **Render 서비스·Neon 프로젝트 삭제**(예전 계정 장기 키가 든 Render 환경변수도 함께), 서버의 덤프 파일 삭제, GitHub의 Render 앱 연결 해제, 백엔드 `render.yaml` 삭제. **이 시점부터 아래 롤백 A/B는 쓸 수 없다** |
