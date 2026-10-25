"""Explicitly approved APK publication to this repository's GitHub Releases.

Uses the existing Git credential helper in memory. Never prints credentials.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import urllib.error
import urllib.parse
import urllib.request

REPO = "BnymGnc/EcoVision"
API = "https://api.github.com/repos/" + REPO


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--tag", default="jury-2026-10-25")
    parser.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    if not args.publish:
        parser.error("Explicit --publish approval is required")
    origin = subprocess.check_output(["git", "remote", "get-url", "origin"], text=True).strip()
    if origin != "https://github.com/" + REPO + ".git":
        raise RuntimeError("Unexpected remote; publication refused")
    apk = args.apk.resolve(strict=True)
    if apk.suffix != ".apk":
        raise RuntimeError("Only an APK artifact may be published")
    with apk.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    if digest != args.expected_sha256.lower():
        raise RuntimeError("APK hash does not match the verified build")
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never")
    credentials = subprocess.run(["git", "credential", "fill"], input="protocol=https\nhost=github.com\n\n",
                                 text=True, capture_output=True, env=env, check=True)
    values = dict(line.split("=", 1) for line in credentials.stdout.splitlines() if "=" in line)
    token = values.get("password")
    if not token:
        raise RuntimeError("No GitHub credential available")
    headers = {"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
               "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "EcoVision-approved-jury-release"}

    def api(path, payload=None):
        body = json.dumps(payload).encode() if payload is not None else None
        request_headers = dict(headers)
        if body is not None:
            request_headers["Content-Type"] = "application/json"
        with urllib.request.urlopen(urllib.request.Request(API + path, data=body, headers=request_headers), timeout=45) as response:
            return json.load(response)

    try:
        release = api("/releases/tags/" + urllib.parse.quote(args.tag, safe=""))
    except urllib.error.HTTPError as failure:
        if failure.code != 404:
            raise RuntimeError("GitHub release lookup failed: HTTP " + str(failure.code)) from None
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
        release = api("/releases", {"tag_name": args.tag, "target_commitish": commit,
            "name": "EcoVision - Jury Preview 25 October 2026", "draft": False, "prerelease": True,
            "body": "Android ARM64 jury preview. Release-mode APK, currently signed with the project's debug key; not an App Store/Play Store production release. Requires internet and the live EcoVision backend. No guaranteed uptime or verified physical recycling claim.\n\nAPK SHA256: `" + digest + "`"})
    filename = "EcoVision-jury-arm64.apk"
    existing = next((asset for asset in release.get("assets", []) if asset["name"] == filename), None)
    if existing:
        raise RuntimeError("An APK with this release name already exists; no replacement was performed")
    url = release["upload_url"].split("{", 1)[0]
    if urllib.parse.urlsplit(url).hostname != "uploads.github.com":
        raise RuntimeError("Unexpected upload host")
    url += "?" + urllib.parse.urlencode({"name": filename})
    upload_headers = dict(headers, **{"Content-Type": "application/vnd.android.package-archive", "Content-Length": str(apk.stat().st_size)})
    with apk.open("rb") as source:
        req = urllib.request.Request(url, data=source, headers=upload_headers, method="POST")
        with urllib.request.urlopen(req, timeout=240) as response:
            asset = json.load(response)
    print(json.dumps({"release": release["html_url"], "apk": asset["browser_download_url"],
                      "sha256": digest, "bytes": apk.stat().st_size}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as failure:
        raise SystemExit("GitHub operation failed: HTTP " + str(failure.code)) from None
