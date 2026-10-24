"""Local-only browser/API check against the isolated ecovision_test backend.

Requires Playwright and an installed Chrome. Never accepts a remote backend URL.
"""
import argparse
import functools
import http.server
import json
from pathlib import Path
import re
import secrets
import threading
import time
import urllib.error
import urllib.request
from urllib.parse import urlsplit

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
API = "http://127.0.0.1:18081"
OUTPUT = ROOT / "docs/screenshots"


def request(path, body=None, token=None, method=None, content_type="application/json"):
    headers = {"Content-Type": content_type}
    if token:
        headers["Authorization"] = "Bearer " + token
    data = body if isinstance(body, bytes) else json.dumps(body).encode() if body is not None else None
    operation = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(operation, timeout=45) as response:
            result = response.read()
            return json.loads(result) if result else {}
    except urllib.error.HTTPError as failure:
        raise RuntimeError(f"Local API failed: {path} HTTP {failure.code}") from None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--web-dir", required=True)
    parser.add_argument("--api-only", action="store_true")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    unique = secrets.token_hex(5)
    email = "browser_" + unique + "@ecovision.invalid"
    password = "Local-" + secrets.token_urlsafe(12) + "!8aA"
    identity = request("/api/auth/register", {
        "name": "Tarayıcı", "surname": "Test", "email": email, "password": password,
        "dateOfBirth": "2000-01-01", "city": "Kayseri", "district": "Talas",
        "username": "browser_" + unique, "termsAccepted": True, "privacyAccepted": True,
    })
    token = identity["accessToken"]
    quests = request("/api/quests?limit=200", token=token)
    assert len(quests) == 200
    points = request("/api/map-pins/nearby?lat=38.72&lng=35.48&materials=pet,glass,aluminum&limit=500", token=token)
    assert points and all(point["pointType"] == "DIM" for point in points)
    eligibility = request("/api/scans/eligibility", {
        "material": "glass", "singleUseNonDairyBeverage": True, "doaMark": True,
        "emptyAndIntact": True, "volumeLitres": 0.5,
    }, token)
    assert eligibility["eligibilityStatus"] == "ELIGIBLE"
    assert eligibility["eligibilityEvidence"] == "USER_DECLARED"
    boundary = "ecovision-local-boundary-" + unique
    photo = ROOT / "backend/src/test/resources/ml/glass.png"
    upload = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"glass.png\"\r\n"
              f"Content-Type: image/png\r\n\r\n").encode() + photo.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    started = time.perf_counter()
    analysis = request("/api/scans/analyze", upload, token, content_type="multipart/form-data; boundary=" + boundary)
    analysis_ms = (time.perf_counter() - started) * 1000
    assert analysis["provider"] == "ONNX_CPU"
    assert analysis["detections"]
    print("Local API checks passed: registration, 200 quests, filtered map, eligibility, real multipart inference", flush=True)
    if args.api_only:
        durations = []
        map_durations = []
        for _ in range(12):
            started = time.perf_counter()
            request("/api/scans/analyze", upload, token, content_type="multipart/form-data; boundary=" + boundary)
            durations.append((time.perf_counter() - started) * 1000)
            started = time.perf_counter()
            request("/api/map-pins/nearby?lat=38.72&lng=35.48&materials=pet,glass,aluminum&limit=500", token=token)
            map_durations.append((time.perf_counter() - started) * 1000)
        report = {"environment": "isolated local PostgreSQL + 512 MB Java 17 container; not Render",
                  "samples": 12, "concurrency": 1, "provider": analysis["provider"],
                  "photo_first_ms": analysis_ms, "photo_warm_p95_ms": sorted(durations)[-1],
                  "map_p95_ms": sorted(map_durations)[-1],
                  "note": "Nearest-rank p95, one known glass image repeated. Not a field accuracy or throughput test."}
        (ROOT / "docs/api-verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report), flush=True)
        return

    class QuietHandler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *_):
            pass
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 18743), functools.partial(QuietHandler, directory=args.web_dir))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    errors = []
    network = []
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe", headless=True,
                args=["--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows", "--enable-unsafe-swiftshader", "--use-angle=swiftshader"])
            context = browser.new_context(viewport={"width": 390, "height": 844},
                geolocation={"latitude": 38.72, "longitude": 35.48}, permissions=["geolocation"])
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("console", lambda message: errors.append(message.text) if "overflowed by" in message.text else None)
            page.on("requestfinished", lambda req: network.append([req.method, urlsplit(req.url).path, req.response().status]) if req.url.startswith(API) else None)
            page.goto("http://127.0.0.1:18743", wait_until="networkidle")
            page.locator("flt-semantics-placeholder").wait_for(state="attached", timeout=30000)
            page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
            page.screenshot(path=str(OUTPUT / "login-390.png"))
            try:
                page.wait_for_function("document.body.innerText.includes('Giri')", polling=100, timeout=20000)
            except Exception:
                page.screenshot(path=str(OUTPUT / "startup-diagnostic.png"))
                print("Browser startup diagnosis:", page.locator("body").inner_text()[:1500], errors[:3], flush=True)
                raise
            page.screenshot(path=str(OUTPUT / "login-390.png"))
            # CanvasKit's accessibility nodes can report zero-size boxes;
            # use the actual visible mobile input controls for the login.
            page.mouse.click(155, 430)
            page.keyboard.type(email)
            page.mouse.click(155, 490)
            page.keyboard.type(password)
            page.mouse.click(190, 592)
            page.wait_for_function("document.body.innerText.includes('Atla')", polling=100, timeout=30000)
            page.screenshot(path=str(OUTPUT / "onboarding-390.png"))
            page.get_by_role("button", name="Atla", exact=True, include_hidden=True).evaluate("el => el.click()")
            try:
                page.wait_for_function("document.body.innerText.includes('Galeriden Seç')", polling=100, timeout=20000)
            except Exception:
                page.screenshot(path=str(OUTPUT / "route-diagnostic.png"))
                print("Route diagnosis:", page.locator("body").inner_text()[:1800], errors[:3], flush=True)
                raise
            page.screenshot(path=str(OUTPUT / "home-390.png"))
            page.get_by_text(re.compile("Karbon Ayak")).evaluate("el => (el.closest('[flt-tappable]') || el).click()")
            field = page.get_by_role("textbox", name="Hane elektrik tüketimi (kWh)", exact=True, include_hidden=True)
            field.wait_for(state="attached")
            page.wait_for_timeout(700)
            page.mouse.click(160, 264)
            page.keyboard.type("200")
            page.wait_for_timeout(500)
            page.screenshot(path=str(OUTPUT / "carbon-form-390.png"))
            page.mouse.click(190, 455)
            try:
                page.wait_for_function("document.body.innerText.includes('1125.6')", polling=100, timeout=30000)
            except Exception:
                page.screenshot(path=str(OUTPUT / "carbon-diagnostic.png"))
                print("Carbon diagnosis:", page.locator("body").inner_text()[:1800], errors[:3], network[-15:], flush=True)
                raise
            for width in [390, 768, 1440]:
                page.set_viewport_size({"width": width, "height": 1000})
                page.wait_for_timeout(400)
                page.screenshot(path=str(OUTPUT / f"carbon-{width}.png"), full_page=True)
            if errors:
                raise AssertionError("Browser errors: " + " | ".join(errors[:3]))
            browser.close()
    finally:
        server.shutdown()
        server.server_close()
    report = {"backend": "isolated local PostgreSQL test environment", "viewports": [390, 768, 1440],
              "api_checks": ["register", "quests_200", "map_DIM_OR_material", "eligibility", "local_photo_inference"],
              "local_photo_endpoint_ms": analysis_ms, "provider": analysis["provider"], "browser_errors": errors}
    (ROOT / "docs/browser-verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("Real Chrome checks passed; screenshots saved in docs/screenshots", flush=True)


if __name__ == "__main__":
    main()
