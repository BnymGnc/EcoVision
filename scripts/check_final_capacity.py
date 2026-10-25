"""Exercise a real local production container; never accepts a remote API URL.

Run after starting the production image on 127.0.0.1:18081 with the isolated
ecovision_test database and AI_PROVIDER=local. No credentials are printed.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import json
import secrets
import subprocess
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CONTAINER = "ecovision-final-capacity"
API = "http://127.0.0.1:18081"


def request(path, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(urllib.request.Request(API + path, data=data, headers=headers), timeout=60) as response:
        return json.loads(response.read())


def account():
    suffix = secrets.token_hex(6)
    return request("/api/auth/register", {
        "name": "Capacity", "surname": "Local", "email": suffix + "@ecovision.invalid",
        "password": "Local!8aA-" + suffix, "username": "capacity_" + suffix,
        "dateOfBirth": "2000-01-01", "city": "Kayseri", "district": "Talas",
        "termsAccepted": True, "privacyAccepted": True,
    })


def memory():
    values = {}
    for name in ("memory.current", "memory.peak", "memory.events"):
        result = subprocess.run(
            ["docker", "exec", CONTAINER, "cat", "/sys/fs/cgroup/" + name],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        values[name] = result if name == "memory.events" else int(result)
    return values


def wait_ready():
    for _ in range(180):
        try:
            with urllib.request.urlopen(API + "/actuator/health/readiness", timeout=2) as response:
                if json.loads(response.read()).get("status") == "UP":
                    break
        except (OSError, ValueError):
            pass
        time.sleep(1)
    else:
        raise RuntimeError("Local container did not become ready")


def cloud_startup():
    wait_ready()
    result = {"environment": "same local production image, 512MiB/1CPU, ML_ENABLED=false",
              "startup": memory(), "liveAiVerified": False,
              "caveat": "No real Gemini key supplied; external AI access/quota and image-analysis peak were NOT tested."}
    identity = account()
    token = identity["accessToken"]
    for _ in range(10):
        points = request("/api/map-pins/search?lat=38.72&lng=35.48&limit=100", token=token)
        assert points["items"]
    result["afterLoginAndMaps"] = memory()
    output = ROOT / "docs/final-cloud-verification.json"
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


def main():
    wait_ready()
    result = {"environment": "local Java17 production image, 512MiB cgroup, isolated PostgreSQL",
              "startup": memory()}
    identity = account()
    token = identity["accessToken"]

    def analyze(name):
        data = (ROOT / "backend/src/test/resources/ml" / (name + ".png")).read_bytes()
        boundary = "ecovision-final-capacity-boundary"
        payload = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{name}.png\"\r\n"
                   "Content-Type: image/png\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
        req = urllib.request.Request(API + "/api/scans/analyze", data=payload, headers={
            "Authorization": "Bearer " + token,
            "Content-Type": "multipart/form-data; boundary=" + boundary,
        })
        started = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=90) as response:
                body = json.loads(response.read())
                return {"status": response.status, "provider": body.get("provider"),
                        "elapsedMs": round((time.perf_counter() - started) * 1000)}
        except urllib.error.HTTPError as failure:
            return {"status": failure.code}

    result["firstPhoto"] = analyze("glass")
    assert result["firstPhoto"]["status"] == 200, result["firstPhoto"]
    result["afterFirstPhoto"] = memory()
    result["sequential"] = [analyze(name) for name in ("plastic", "metal", "paper", "glass") * 3]
    assert all(item["status"] == 200 for item in result["sequential"])
    result["afterSequential"] = memory()
    for _ in range(5):
        points = request("/api/map-pins/search?lat=38.72&lng=35.48&limit=100", token=token)
        assert len(points["items"]) > 0
    with ThreadPoolExecutor(max_workers=3) as pool:
        result["concurrent3"] = list(pool.map(analyze, ["glass", "plastic", "metal"]))
    assert all(item["status"] in (200, 503) for item in result["concurrent3"])
    assert any(item["status"] == 200 for item in result["concurrent3"])
    result["final"] = memory()
    result["caveat"] = "Short local run; 503 is bounded inference backpressure, not a successful analysis. Not Render evidence."
    output = ROOT / "docs/final-capacity-verification.json"
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cloud", action="store_true", help="Startup/map-only check; never calls paid AI")
    if parser.parse_args().cloud:
        API = "http://127.0.0.1:18082"
        CONTAINER = "ecovision-final-cloud"
        cloud_startup()
    else:
        main()
