"""Small, bounded public liveness check. No credentials or database/API actions."""
import argparse
import json
from pathlib import Path
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

URL = "https://ecovision-backend-wdr0.onrender.com/api/health/live"
EXPECTED = b"EcoVision Backend is awake!"
SAFE_HEADERS = ("Content-Type", "Server", "Date", "Retry-After", "X-Render-Origin-Server")


def probe(url, method="GET", timeout=30):
    started = time.monotonic()
    row = {"method": method, "url": url}
    request = urllib.request.Request(url, method=method, headers={"User-Agent": "EcoVision-Liveness-Verification/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read(1024)
            row.update(status=response.status, expectedBody=(body == EXPECTED if method == "GET" else body == b""),
                       headers={key: response.headers[key] for key in SAFE_HEADERS if key in response.headers})
    except urllib.error.HTTPError as failure:
        row.update(status=failure.code, expectedBody=False,
                   headers={key: failure.headers[key] for key in SAFE_HEADERS if key in failure.headers},
                   responsePreview=failure.read(256).decode("utf-8", errors="replace"))
    except (OSError, TimeoutError) as failure:
        row.update(status=None, expectedBody=False, error=type(failure).__name__)
    row["durationMs"] = round((time.monotonic() - started) * 1000)
    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=int, default=3, choices=range(1, 7))
    parser.add_argument("--interval", type=int, default=2, choices=range(1, 61))
    parser.add_argument("--timeout", type=int, default=30, choices=range(1, 61))
    parser.add_argument("--output", type=Path,
                        default=Path(__file__).resolve().parents[1] / "docs/keepalive-verification.json")
    args = parser.parse_args()
    result = {"checkedAtUtc": datetime.now(timezone.utc).isoformat(), "url": URL,
              "credentialsSent": False, "samples": []}
    for method in ["GET"] * args.samples + ["HEAD"]:
        row = probe(URL, method, args.timeout)
        result["samples"].append(row)
        print(json.dumps(row), flush=True)
        if len(result["samples"]) < args.samples + 1:
            time.sleep(args.interval)
    result["allPassed"] = all(row.get("status") == 200 and row["expectedBody"] for row in result["samples"])
    result["caveat"] = "Short observation only; not proof of uptime or cron-job.org task activation. Errors are not masked."
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["allPassed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
