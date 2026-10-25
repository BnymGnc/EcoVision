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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=int, default=3, choices=range(1, 7))
    args = parser.parse_args()
    result = {"checkedAtUtc": datetime.now(timezone.utc).isoformat(), "url": URL,
              "credentialsSent": False, "samples": []}
    for method in ["GET"] * args.samples + ["HEAD"]:
        started = time.monotonic()
        row = {"method": method}
        try:
            req = urllib.request.Request(URL, method=method, headers={"User-Agent": "EcoVision-Liveness-Verification/1.0"})
            with urllib.request.urlopen(req, timeout=30) as response:
                body = response.read(1024)
                row.update(status=response.status, expectedBody=(body == EXPECTED if method == "GET" else body == b""))
        except urllib.error.HTTPError as failure:
            row.update(status=failure.code, expectedBody=False)
        except (OSError, TimeoutError):
            row.update(status=None, expectedBody=False, error="timeout-or-network-error")
        row["durationMs"] = round((time.monotonic() - started) * 1000)
        result["samples"].append(row)
        if len(result["samples"]) < args.samples + 1:
            time.sleep(2)
    result["allPassed"] = all(row.get("status") == 200 and row["expectedBody"] for row in result["samples"])
    result["caveat"] = "Short observation only; not proof of uptime or cron-job.org task activation. Errors are not masked."
    output = Path(__file__).resolve().parents[1] / "docs/keepalive-verification.json"
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["allPassed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
