#!/usr/bin/env python3
"""Small App Store Connect API helper. Reads .secrets/apple.env.
Usage: python3 scripts/asc.py <subcommand> [args]
"""
import os
import sys
import time
import json
from pathlib import Path

# Load .secrets/apple.env into env
env_file = Path(__file__).resolve().parent.parent / ".secrets" / "apple.env"
if env_file.exists():
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[len("export "):]
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

KEY_ID = os.environ["APP_STORE_CONNECT_KEY_ID"]
ISSUER_ID = os.environ["APP_STORE_CONNECT_ISSUER_ID"]
KEY_PATH = os.path.expandvars(os.path.expanduser(os.environ["APP_STORE_CONNECT_KEY_PATH"]))
APP_ID = os.environ.get("BIDE_APP_STORE_CONNECT_ID")
BUNDLE_ID = os.environ.get("BIDE_BUNDLE_ID")

import jwt  # PyJWT
import urllib.request
import urllib.error

def make_jwt():
    payload = {
        "iss": ISSUER_ID,
        "iat": int(time.time()),
        "exp": int(time.time()) + 1200,
        "aud": "appstoreconnect-v1",
    }
    headers = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    with open(KEY_PATH, "rb") as f:
        return jwt.encode(payload, f.read(), algorithm="ES256", headers=headers)

def api(method, path, body=None):
    url = "https://api.appstoreconnect.apple.com" + path
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + make_jwt())
    req.add_header("Accept", "application/json")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            body = json.loads(body)
        except Exception:
            pass
        return e.code, body

def cmd_whoami():
    code, data = api("GET", "/v1/users?limit=1")
    print("status:", code)
    print(json.dumps(data, indent=2)[:600])

def cmd_app():
    if not APP_ID:
        print("BIDE_APP_STORE_CONNECT_ID not set"); return
    code, data = api("GET", f"/v1/apps/{APP_ID}")
    print("status:", code)
    print(json.dumps(data, indent=2)[:1500])

def cmd_versions():
    code, data = api("GET", f"/v1/apps/{APP_ID}/appStoreVersions")
    print("status:", code)
    print(json.dumps(data, indent=2)[:2000])

def cmd_profile():
    """Try to create an App Store distribution profile for our bundle ID."""
    code, data = api("POST", "/v1/profiles", {
        "data": {
            "type": "profiles",
            "attributes": {
                "name": "Bide App Store",
                "profileType": "IOS_APP_STORE",
            },
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": "$BUNDLE_ID_REF"}},
            },
        }
    })
    print("status:", code)
    print(json.dumps(data, indent=2)[:1500])

def cmd_bundleids():
    code, data = api("GET", "/v1/bundleIds?filter[identifier]=" + BUNDLE_ID)
    print("status:", code)
    if isinstance(data, dict) and data.get("data"):
        for b in data["data"]:
            print(f'  - id: {b["id"]}  identifier: {b["attributes"]["identifier"]}  name: {b["attributes"]["name"]}')

if __name__ == "__main__":
    sub = sys.argv[1] if len(sys.argv) > 1 else "whoami"
    fn = globals().get("cmd_" + sub)
    if not fn:
        print("Unknown:", sub); sys.exit(1)
    fn()
