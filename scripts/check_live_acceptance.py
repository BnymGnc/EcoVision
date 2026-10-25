"""Opt-in, single-account/single-photo production acceptance check.

Creates one normal test account. Never edits existing accounts, resets data,
changes roles, stress-tests production, or prints credentials/tokens.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import secrets
import urllib.error
import urllib.request

API = "https://ecovision-backend-wdr0.onrender.com"
ROOT = Path(__file__).resolve().parents[1]


def request(path, body=None, token=None, content_type="application/json"):
    headers = {"Content-Type": content_type}
    if token:
        headers["Authorization"] = "Bearer " + token
    payload = body if isinstance(body, bytes) else json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=payload, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            raw = response.read()
            try:
                return response.status, json.loads(raw)
            except ValueError:
                return response.status, {}
    except urllib.error.HTTPError as failure:
        try:
            message = json.loads(failure.read()).get("message", "")
        except ValueError:
            message = "Non-JSON provider/platform error"
        return failure.code, {"message": str(message)[:240]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-create-test-account", action="store_true")
    if not parser.parse_args().allow_create_test_account:
        parser.error("Explicit opt-in required: creates one real production test account")
    result = {"scope": "Production: one normal test account, one real photo; no existing-user changes",
              "checkedAtUtc": datetime.now(timezone.utc).isoformat()}
    result["livenessStatus"], _ = request("/api/health/live")
    result["readinessStatus"], _ = request("/actuator/health/readiness")
    assert result["livenessStatus"] == result["readinessStatus"] == 200
    suffix = secrets.token_hex(7)
    password = "Final!8aA-" + secrets.token_urlsafe(24)
    email = "final_" + suffix + "@ecovision.invalid"
    status, identity = request("/api/auth/register", {
        "name": "Final", "surname": "Verification", "email": email,
        "password": password, "username": "final_" + suffix,
        "dateOfBirth": "2000-01-01", "city": "Kayseri", "district": "Talas",
        "termsAccepted": True, "privacyAccepted": True,
    })
    result["registrationStatus"] = status
    assert status in (200, 201), {"registrationStatus": status}
    assert identity["user"]["role"] == "USER"
    token = identity["accessToken"]
    status, inventory = request("/api/map-pins/locations", token=token)
    result["inventory"] = {"status": status, "total": inventory.get("total"),
                           "provinces": len(inventory.get("cities", [])), "counts": inventory.get("counts")}
    status, page = request("/api/map-pins/search?lat=38.72&lng=35.48&pointTypes=DIM&limit=100", token=token)
    result["mapPage"] = {"status": status, "items": len(page.get("items", [])),
                         "total": page.get("total"), "hasMore": page.get("hasMore")}
    boundary = "ecovision-final-live-check"
    image = (ROOT / "backend/src/test/resources/ml/glass.png").read_bytes()
    payload = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"glass.png\"\r\n"
               "Content-Type: image/png\r\n\r\n").encode() + image + f"\r\n--{boundary}--\r\n".encode()
    status, analysis = request("/api/scans/analyze", payload, token, "multipart/form-data; boundary=" + boundary)
    result["realPhoto"] = {"status": status, "provider": analysis.get("provider"),
                           "modelVersion": analysis.get("modelVersion"),
                           "inferenceMode": analysis.get("inferenceMode"),
                           "detectedTypes": [d.get("type") for d in analysis.get("detections", [])],
                           "error": analysis.get("message")}
    status, again = request("/api/auth/login", {"email": email, "password": password})
    result["loginStatus"] = status
    result["sameAccountAfterLogin"] = status == 200 and again.get("user", {}).get("id") == identity["user"]["id"]
    result["limits"] = "API acceptance only, not a browser/phone walkthrough, no GPS/navigation or Render dashboard access. AI failure is not replaced by a sample result."
    result["allPassed"] = (
        result["inventory"]["status"] == 200
        and result["inventory"]["provinces"] == 81
        and result["mapPage"]["status"] == 200
        and result["mapPage"]["items"] > 0
        and result["realPhoto"]["status"] == 200
        and bool(result["realPhoto"]["detectedTypes"])
        and result["sameAccountAfterLogin"]
    )
    (ROOT / "docs/final-live-verification.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["allPassed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
