"""서버 바깥 감시자 — AWS Lambda(도쿄 ap-northeast-1)에서 5분마다 실행.

서버 안의 알림(systemd OnFailure=)은 서버가 통째로 죽으면 보낼 주체가 없다.
그래서 다른 리전에서 /health/db를 찔러 보고, 실패하면 디스코드로 알린다.

- 한 번 실행할 때 ATTEMPTS번(기본 3) INTERVAL초(기본 20) 간격으로 찔러서,
  전부 실패해야 알림. 새벽 자동 재부팅(약 19초)이나 배포 중 502(#14)에는
  울리지 않게 하려는 것. 실행마다 기억이 없어도 되니 실패 횟수를 저장하지 않음.
- 실패 = 200이 아닌 응답, 또는 응답 없음(타임아웃·연결 거부·DNS 실패).
- 복구 알림은 없음. 장애가 이어지는 동안은 실행마다(5분) 알림이 온다.
- 표준 라이브러리만 씀(Lambda Python 런타임에 requests가 없음).

환경 변수: HEALTH_URL, DISCORD_WEBHOOK_URL(비밀), 선택: ATTEMPTS, INTERVAL, REQUEST_TIMEOUT
Lambda 제한 시간: 최악 = REQUEST_TIMEOUT×3 + INTERVAL×2 = 100초 → 120초로 설정.
"""
import json
import os
import time
import urllib.error
import urllib.request

# 디스코드(Cloudflare)는 urllib 기본 User-Agent("Python-urllib/3.x")를 403으로 막는다.
USER_AGENT = "mysite-monitor/1.0"


def check_once(url, timeout):
    """(성공 여부, 결과 설명) — 설명은 알림 메시지에 들어감."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status == 200, f"HTTP {resp.status}"
    except urllib.error.HTTPError as e:  # 4xx·5xx (502, 503 등)
        return False, f"HTTP {e.code}"
    except Exception as e:  # 응답 없음: 타임아웃, 연결 거부, DNS 실패 등
        # URLError는 진짜 원인을 .reason에 감싸 둠 → TimeoutError / ConnectionRefusedError 등으로 구분
        reason = getattr(e, "reason", e)
        return False, f"응답 없음 ({type(reason).__name__})"


def send_alert(webhook_url, message):
    body = json.dumps({"content": message}).encode()  # json.dumps라 따옴표가 있어도 안 깨짐
    req = urllib.request.Request(
        webhook_url,
        data=body,
        headers={"Content-Type": "application/json", "User-Agent": USER_AGENT},
        method="POST",
    )
    # 실패하면 예외가 그대로 올라가서 Lambda 실행이 "에러"로 기록됨(CloudWatch에서 보임).
    with urllib.request.urlopen(req, timeout=20):
        pass


def lambda_handler(event, context):
    url = os.environ["HEALTH_URL"]
    attempts = int(os.environ.get("ATTEMPTS", "3"))
    interval = float(os.environ.get("INTERVAL", "20"))
    timeout = float(os.environ.get("REQUEST_TIMEOUT", "20"))

    results = []
    for i in range(attempts):
        ok, detail = check_once(url, timeout)
        results.append(detail)
        if ok:
            print(f"ok: {url} ({detail}, {i + 1}번째 시도)")
            return {"healthy": True, "results": results}
        if i < attempts - 1:
            time.sleep(interval)

    message = (
        f"[바깥 감시] {url} {attempts}번 연속 실패 ({interval:g}초 간격): "
        + " / ".join(results)
        + "\n확인: sudo systemctl status mysite-backend postgresql, sudo tail /var/log/nginx/error.log"
    )
    print(message)
    send_alert(os.environ["DISCORD_WEBHOOK_URL"], message)
    return {"healthy": False, "results": results}
