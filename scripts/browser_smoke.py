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
from urllib.parse import urlsplit, parse_qs

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
API = "http://127.0.0.1:18081"
OUTPUT = ROOT / "docs/screenshots"
DIAGNOSTICS = ROOT / "frontend/build/browser-diagnostics"


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
    parser.add_argument("--profile-only", action="store_true")
    parser.add_argument("--academy-only", action="store_true")
    parser.add_argument("--core-only", action="store_true")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    DIAGNOSTICS.mkdir(parents=True, exist_ok=True)
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
    if args.core_only:
        request("/api/auth/me/profile-picture", upload, token,
            content_type="multipart/form-data; boundary=" + boundary)
        request("/api/users/privacy", {"visibility":"FRIENDS_ONLY"}, token, method="PUT")
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
            navigation_requests = []
            context.on("request", lambda req: navigation_requests.append(req.url)
                if "google.com/maps/dir/" in req.url else None)
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
                page.screenshot(path=str(DIAGNOSTICS / "startup-diagnostic.png"))
                print("Browser startup diagnosis:", page.locator("body").inner_text()[:1500], errors[:3], flush=True)
                raise
            page.screenshot(path=str(OUTPUT / "login-390.png"))
            # CanvasKit's accessibility nodes can report zero-size boxes;
            # use the actual visible mobile input controls for the login.
            page.mouse.click(155, 430)
            page.wait_for_timeout(150)
            page.keyboard.type(email, delay=50)
            page.mouse.click(155, 490)
            page.wait_for_timeout(150)
            page.keyboard.type(password, delay=50)
            page.mouse.click(190, 592)
            try:
                page.wait_for_function("document.body.innerText.includes('Atla')", polling=100, timeout=45000)
            except Exception:
                page.screenshot(path=str(DIAGNOSTICS / "login-diagnostic.png"))
                print("Login diagnosis:", page.locator("body").inner_text()[:1500], network[-8:], errors[:3], flush=True)
                raise
            page.screenshot(path=str(OUTPUT / "onboarding-390.png"))
            page.get_by_role("button", name="Atla", exact=True, include_hidden=True).evaluate("el => el.click()")
            try:
                page.wait_for_function("document.body.innerText.includes('Galeriden Seç')", polling=100, timeout=20000)
            except Exception:
                page.screenshot(path=str(DIAGNOSTICS / "route-diagnostic.png"))
                print("Route diagnosis:", page.locator("body").inner_text()[:1800], errors[:3], flush=True)
                raise
            page.screenshot(path=str(OUTPUT / "home-390.png"))
            if args.core_only:
                with page.expect_response(lambda response: response.request.method == "GET"
                        and "/api/media/" in response.url, timeout=30000) as loaded:
                    page.mouse.click(330,795)
                assert loaded.value.status == 200
                assert loaded.value.request.headers.get("authorization", "").startswith("Bearer ")
                assert "token=" not in loaded.value.url
                page.wait_for_timeout(600)
                page.screenshot(path=str(OUTPUT / "secure-profile-390.png"))
                page.mouse.click(55,795)
                gallery=page.get_by_role("button", name="Galeriden Seç", exact=True, include_hidden=True)
                gallery.wait_for(state="attached",timeout=20000)
                with page.expect_file_chooser(timeout=15000) as chooser:
                    gallery.evaluate("el => el.click()")
                chooser.value.set_files(str(photo))
                try:
                    page.wait_for_function("document.body.innerText.includes('Tarama Sonucu') || document.body.innerText.includes('Harika tarama!') || document.body.innerText.includes('Tebrikler!')",timeout=45000)
                except Exception:
                    page.screenshot(path=str(DIAGNOSTICS / "core-upload.png"))
                    print("Core upload diagnosis:", page.locator("body").inner_text()[:2400], network[-12:], errors[:3], flush=True)
                    raise
                page.wait_for_timeout(700)
                proceed=page.get_by_role("button",name="Devam Et",exact=True,include_hidden=True)
                if proceed.count():
                    proceed.evaluate("el => el.click()")
                page.wait_for_function("document.body.innerText.includes('Tarama Sonucu')",timeout=15000)
                page.get_by_text(re.compile("Yapay zeka analizi")).first.evaluate(
                    "el => (el.closest('[flt-tappable]') || el).click()")
                page.wait_for_timeout(500)
                page.screenshot(path=str(OUTPUT / "secure-scan-result-390.png"))
                page.mouse.move(200,500)
                page.mouse.wheel(0,650)
                page.wait_for_timeout(500)
                guide=page.get_by_role("button",name="Bu Atığın Ayırma Rehberi",exact=True,include_hidden=True)
                guide.evaluate("el => el.click()")
                page.get_by_text(re.compile("Cam Atıklar: Şişe ile Seramiği Ayır")).wait_for(state="attached")
                page.get_by_role("button",name="Geri",exact=True,include_hidden=True).evaluate("el => el.click()")
                page.wait_for_timeout(400)
                with page.expect_response(lambda response: response.request.method=="GET"
                        and "/api/map-pins/nearby" in response.url
                        and parse_qs(urlsplit(response.url).query).get("lat")==["38.72"],timeout=30000) as fetched:
                    page.get_by_role("button",name="DOA Makinelerini Haritada Göster",exact=True,include_hidden=True).evaluate("el => el.click()")
                assert fetched.value.status==200
                parsed=urlsplit(fetched.value.url)
                nearby=request(parsed.path+"?"+parsed.query,token=token)
                assert nearby and all(p["pointType"]=="DIM" for p in nearby)
                assert parse_qs(parsed.query).get("materials")==["glass"]
                name=nearby[0]["title"]
                page.get_by_text(re.compile(re.escape(name))).first.wait_for(state="attached",timeout=20000)
                page.get_by_text(re.compile(re.escape(name))).first.evaluate(
                    "el => (el.closest('[flt-tappable]') || el).click()")
                page.wait_for_function("document.body.innerText.includes('Bu malzemeyi destekler')",timeout=20000)
                page.screenshot(path=str(OUTPUT / "secure-map-detail-390.png"))
                page.mouse.move(200,600)
                page.mouse.wheel(0,650)
                page.wait_for_timeout(500)
                page.get_by_role("button",name="Yol Tarifi Al",exact=True,include_hidden=True).evaluate("el => el.click()")
                with context.expect_page(timeout=15000) as opened:
                    page.get_by_text("Google Maps",exact=True).evaluate("el => (el.closest('[flt-tappable]') || el).click()")
                popup=opened.value
                popup.wait_for_url(re.compile(r"https://.*google.*maps.*"),timeout=15000)
                expected_destination = f"{nearby[0]['latitude']},{nearby[0]['longitude']}"
                assert any(parse_qs(urlsplit(url).query).get("destination")==[expected_destination]
                    for url in navigation_requests), "Directions must request the selected real coordinates before provider redirects"
                popup.close()
            elif args.academy_only:
                page.get_by_text("Atık Rehberi", exact=True).evaluate("el => (el.closest('[flt-tappable]') || el).click()")
                search = page.get_by_role("textbox", name="Atık veya malzeme ara", include_hidden=True)
                search.wait_for(state="attached", timeout=20000)
                # Real Chrome search interaction on Flutter's semantics input.
                page.wait_for_timeout(400)
                page.mouse.click(155, 265)
                page.keyboard.type("YAG", delay=100)
                try:
                    page.wait_for_function("document.body.innerText.includes('Bitkisel Atık Yağ')", timeout=15000)
                except Exception:
                    page.screenshot(path=str(DIAGNOSTICS / "academy-search.png"))
                    print("Academy search diagnosis:", page.locator("body").inner_text()[:2500], flush=True)
                    raise
                page.screenshot(path=str(OUTPUT / "academy-search-390.png"))
                page.mouse.click(155, 265)
                page.keyboard.press("Control+A")
                page.keyboard.type("PET", delay=100)
                page.get_by_text(re.compile(r"Plastik Atıklar: Her Plastik PET Değildir")).evaluate(
                    "el => (el.closest('[flt-tappable]') || el).click()")
                page.get_by_role("button", name="Sınavı Başlat", exact=True, include_hidden=True).wait_for(state="attached")
                for width in [320, 390, 768]:
                    page.set_viewport_size({"width": width, "height": 844})
                    page.wait_for_timeout(400)
                    page.screenshot(path=str(OUTPUT / f"academy-lesson-{width}.png"))
                page.set_viewport_size({"width": 390, "height": 844})
                points_before_quiz = request("/api/auth/me", token=token)["totalPoints"]
                page.get_by_role("button", name="Sınavı Başlat", exact=True, include_hidden=True).evaluate("el => el.click()")
                curriculum = json.loads((ROOT / "frontend/assets/data/academy_guide.json").read_text(encoding="utf-8"))
                module = curriculum[0]
                for index, question in enumerate(module["questions"]):
                    answer = question["options"][question["correctOptionIndex"]]
                    page.get_by_text(answer, exact=True).wait_for(state="attached", timeout=15000)
                    page.get_by_text(answer, exact=True).evaluate("el => (el.closest('[flt-tappable]') || el).click()")
                    page.wait_for_timeout(250)
                    page.get_by_role("button", name="Cevabı Onayla", exact=True, include_hidden=True).evaluate("el => el.click()")
                    page.wait_for_timeout(250)
                    label = "Sonucu Gör" if index == 2 else "Sonraki Soru"
                    if index == 0:
                        page.screenshot(path=str(DIAGNOSTICS / "academy-answer.png"))
                    page.get_by_role("button", name=label, exact=True, include_hidden=True).evaluate("el => el.click()")
                    page.wait_for_timeout(600)
                page.get_by_text("Modülü Tamamladın!", exact=True).wait_for(state="attached", timeout=20000)
                page.screenshot(path=str(OUTPUT / "academy-quiz-complete-390.png"))
                assert "modul-1" in request("/api/education/progress", token=token)
                points_after_quiz = request("/api/auth/me", token=token)["totalPoints"]
                assert points_after_quiz > points_before_quiz
                retry = request("/api/education/complete/modul-1", {
                    "quizVersion": "2026-10-24-v1",
                    "answers": [q["correctOptionIndex"] for q in module["questions"]],
                }, token)
                assert retry["pointsAwarded"] == 0 and not retry["newlyCompleted"]
                assert request("/api/auth/me", token=token)["totalPoints"] == points_after_quiz
                page.get_by_role("button", name="Akademiye Dön", exact=True, include_hidden=True).evaluate("el => el.click()")
                page.wait_for_function("document.body.innerText.includes('Tamamlandı')", timeout=15000)
                page.screenshot(path=str(OUTPUT / "academy-completed-list-390.png"))
            elif args.profile_only:
                # CanvasKit omits the glass navigation bar's label nodes.
                page.mouse.click(330, 795)
                edit = page.get_by_role("button", name="Avatarı Düzenle", exact=True, include_hidden=True)
                edit.wait_for(state="attached", timeout=20000)
                streak = page.get_by_role("button", name=re.compile(r"\d+ gün giriş serisi"), include_hidden=True)
                streak.wait_for(state="attached", timeout=20000)
                page.mouse.move(10, 60)
                for width in [320, 390, 430]:
                    page.set_viewport_size({"width": width, "height": 844})
                    page.wait_for_timeout(400)
                    page.screenshot(path=str(OUTPUT / f"profile-{width}.png"))
                page.set_viewport_size({"width": 390, "height": 844})
                with page.expect_response(lambda response: response.request.method == "GET" and "/api/users/login-history" in response.url, timeout=20000) as fetched:
                    streak.evaluate("el => el.click()")
                history = fetched.value
                assert history.status == 200
                # Chrome's Fetch/CDP adapter can discard response bodies after
                # Flutter consumes them; read the same own-user calendar via HTTP.
                calendar_url = urlsplit(history.url)
                calendar = request(calendar_url.path + "?" + calendar_url.query, token=token)
                assert calendar["today"] in calendar["loginDates"]
                page.get_by_role("button", name="Önceki ay", exact=True, include_hidden=True).wait_for(state="attached")
                page.screenshot(path=str(OUTPUT / "profile-login-calendar-390.png"))
                with page.expect_response(lambda response: response.request.method == "GET" and "/api/users/login-history" in response.url, timeout=20000) as fetched:
                    page.get_by_role("button", name="Önceki ay", exact=True, include_hidden=True).evaluate("el => el.click()")
                assert fetched.value.status == 200
                assert parse_qs(urlsplit(fetched.value.url).query)["month"][0] != calendar["month"]
                page.wait_for_timeout(500)
                page.screenshot(path=str(OUTPUT / "profile-login-previous-390.png"))
                page.get_by_role("button", name="Kapat", exact=True, include_hidden=True).evaluate("el => el.click()")
                edit.wait_for(state="attached", timeout=20000)
            else:
                page.get_by_text(re.compile("Karbon Ayak")).evaluate("el => (el.closest('[flt-tappable]') || el).click()")
                for question in range(20):
                    option = page.get_by_role("button", name=re.compile(r"^Yanıt 1:"), include_hidden=True)
                    option.wait_for(state="attached", timeout=20000)
                    if question == 0:
                        page.screenshot(path=str(OUTPUT / "carbon-survey-390.png"))
                    option.evaluate("el => el.click()")
                    next_label = "Karbonumu Hesapla" if question == 19 else "Devam Et"
                    page.get_by_role("button", name=next_label, exact=True, include_hidden=True).evaluate("el => el.click()")
                    page.wait_for_timeout(650)
                try:
                    page.get_by_role("button", name="Karbonunu Sıfırlamaya Başla!", exact=True, include_hidden=True).wait_for(state="attached", timeout=30000)
                    page.screenshot(path=str(OUTPUT / "carbon-result-390.png"))
                except Exception:
                    page.screenshot(path=str(DIAGNOSTICS / "carbon-diagnostic.png"))
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
    report = {"backend": "isolated local PostgreSQL test environment", "viewports": [390] if args.core_only else [320, 390, 768] if args.academy_only else [320, 390, 430] if args.profile_only else [390, 768, 1440],
              "api_checks": ["register", "quests_200", "map_DIM_OR_material", "eligibility", "local_photo_inference"],
              "local_photo_endpoint_ms": analysis_ms, "provider": analysis["provider"],
              "ui_flow": "private profile image, real photo upload, AI, guide, filtered map and directions intent" if args.core_only else "academy search, lesson, quiz, completion and one-time reward" if args.academy_only else "profile header and own monthly login calendar" if args.profile_only else "20-question survey",
              "browser_errors": errors}
    if args.academy_only:
        report["api_checks"].extend(["education_progress", "quiz_reward_balance_updated", "repeat_completion_no_points"])
    if args.core_only:
        report["api_checks"].extend(["private_media_authorization_header", "browser_photo_upload",
            "guide_for_glass", "glass_map_filter", "directions_real_coordinates"])
    (ROOT / ("docs/security-core-browser-verification.json" if args.core_only else "docs/academy-browser-verification.json" if args.academy_only else "docs/profile-browser-verification.json" if args.profile_only else "docs/browser-verification.json")).write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("Real Chrome checks passed; screenshots saved in docs/screenshots", flush=True)


if __name__ == "__main__":
    main()
