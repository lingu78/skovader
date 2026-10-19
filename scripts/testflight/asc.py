#!/usr/bin/env python3
"""App Store Connect API för TestFlight-flödet i GitHub Actions.

  prepare  Kontrollerar att appen finns i App Store Connect, registrerar
           bundle-id vid behov, väljer nästa byggnummer och skapar ett
           tillfälligt distributionscertifikat och en App Store-profil.
  cleanup  Tar bort certifikatet och profilen igen. Redan uppladdade byggen
           påverkas inte – Apple signerar om dem för TestFlight.

Läser ASC_KEY_ID, ASC_ISSUER_ID och ASC_KEY_PATH (sökväg till .p8-filen)
från miljön. Bara Pythons standardbibliotek och openssl behövs.
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"


class ASCError(Exception):
    pass


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(signature: bytes) -> bytes:
    """ECDSA-signatur i DER (SEQUENCE med två INTEGER) → r||s, 32 byte vardera."""
    if signature[0] != 0x30:
        raise ValueError("inte en DER-sekvens")
    index = 2 if signature[1] < 0x80 else 2 + (signature[1] & 0x7F)
    parts = []
    for _ in range(2):
        if signature[index] != 0x02:
            raise ValueError("väntade INTEGER")
        length = signature[index + 1]
        value = signature[index + 2:index + 2 + length]
        parts.append(value.lstrip(b"\x00").rjust(32, b"\x00"))
        index += 2 + length
    return b"".join(parts)


def make_token(key_id: str, issuer_id: str, key_path: str, now: int | None = None) -> str:
    """JWT (ES256) för App Store Connect, giltig i 15 minuter."""
    now = int(time.time()) if now is None else now
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = b64url(json.dumps({
        "iss": issuer_id,
        "iat": now,
        "exp": now + 15 * 60,
        "aud": "appstoreconnect-v1",
    }).encode())
    signing_input = f"{header}.{payload}".encode()
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input, capture_output=True, check=True,
    ).stdout
    return f"{header}.{payload}.{b64url(der_to_raw(der))}"


def api(method: str, path: str, body: dict | None = None, query: dict | None = None):
    url = API + path
    if query:
        url += "?" + urllib.parse.urlencode(query)
    token = make_token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"])
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        raise ASCError(f"App Store Connect svarade {error.code} på {method} {path}:\n{detail}") from None


def find_app(bundle_id: str) -> dict:
    apps = api("GET", "/apps", query={"filter[bundleId]": bundle_id, "fields[apps]": "bundleId,name"})["data"]
    for app in apps:
        if app["attributes"]["bundleId"] == bundle_id:
            return app
    raise ASCError(
        f"Hittar ingen app med bundle-id {bundle_id} i App Store Connect.\n"
        "Skapa den först: App Store Connect → Appar → + → Ny app (se docs/testflight.md)."
    )


def find_or_create_bundle_id(identifier: str, name: str) -> dict:
    found = api("GET", "/bundleIds", query={"filter[identifier]": identifier, "limit": "200"})["data"]
    for bundle in found:
        if bundle["attributes"]["identifier"] == identifier:
            return bundle
    print(f"Registrerar bundle-id {identifier}")
    return api("POST", "/bundleIds", {
        "data": {"type": "bundleIds", "attributes": {"identifier": identifier, "name": name, "platform": "IOS"}},
    })["data"]


def next_build_number(app_id: str) -> int:
    builds = api("GET", "/builds", query={
        "filter[app]": app_id,
        "fields[builds]": "version",
        "sort": "-uploadedDate",
        "limit": "200",
    })["data"]
    numbers = [int(b["attributes"]["version"]) for b in builds if b["attributes"]["version"].isdigit()]
    return max(numbers, default=0) + 1


def prepare(args) -> None:
    os.makedirs(args.out, exist_ok=True)
    state_path = os.path.join(args.out, "state.json")
    state: dict = {}

    def save_state() -> None:
        with open(state_path, "w") as file:
            json.dump(state, file, indent=2)

    app = find_app(args.bundle_id)
    bundle = find_or_create_bundle_id(args.bundle_id, args.name)
    team_id = bundle["attributes"]["seedId"]
    build_number = next_build_number(app["id"])

    key_file = os.path.join(args.out, "distribution.key")
    csr_file = os.path.join(args.out, "distribution.csr")
    subprocess.run(
        ["openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes",
         "-keyout", key_file, "-out", csr_file, "-subj", "/CN=Skovader CI"],
        check=True, capture_output=True,
    )
    with open(csr_file) as file:
        csr = file.read()

    certificate = api("POST", "/certificates", {
        "data": {"type": "certificates", "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr}},
    })["data"]
    state["certificate_id"] = certificate["id"]
    save_state()
    with open(os.path.join(args.out, "distribution.cer"), "wb") as file:
        file.write(base64.b64decode(certificate["attributes"]["certificateContent"]))

    profile_name = f"Skovader CI {args.run_id}"
    profile = api("POST", "/profiles", {
        "data": {
            "type": "profiles",
            "attributes": {"name": profile_name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
                "certificates": {"data": [{"type": "certificates", "id": certificate["id"]}]},
            },
        },
    })["data"]
    state["profile_id"] = profile["id"]
    save_state()
    with open(os.path.join(args.out, "profile.mobileprovision"), "wb") as file:
        file.write(base64.b64decode(profile["attributes"]["profileContent"]))

    outputs = {
        "app_name": app["attributes"]["name"],
        "team_id": team_id,
        "build_number": str(build_number),
        "profile_name": profile_name,
        "profile_uuid": profile["attributes"]["uuid"],
    }
    for key, value in outputs.items():
        print(f"{key}={value}")
    if "GITHUB_OUTPUT" in os.environ:
        with open(os.environ["GITHUB_OUTPUT"], "a") as file:
            for key, value in outputs.items():
                file.write(f"{key}={value}\n")


def cleanup(args) -> None:
    state_path = os.path.join(args.out, "state.json")
    if not os.path.exists(state_path):
        return
    with open(state_path) as file:
        state = json.load(file)
    for kind, key in (("profiles", "profile_id"), ("certificates", "certificate_id")):
        if key in state:
            try:
                api("DELETE", f"/{kind}/{state[key]}")
                print(f"Tog bort {kind} {state[key]}")
            except ASCError as error:
                print(f"::warning::Kunde inte ta bort {kind} {state[key]}: {error}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    prepare_parser = commands.add_parser("prepare")
    prepare_parser.add_argument("--bundle-id", required=True)
    prepare_parser.add_argument("--name", required=True, help="Namn på bundle-id om det måste registreras")
    prepare_parser.add_argument("--run-id", required=True)
    prepare_parser.add_argument("--out", required=True)

    cleanup_parser = commands.add_parser("cleanup")
    cleanup_parser.add_argument("--out", required=True)

    args = parser.parse_args()
    try:
        prepare(args) if args.command == "prepare" else cleanup(args)
    except ASCError as error:
        print(f"::error::{error}".replace("\n", "%0A"))
        sys.exit(1)


if __name__ == "__main__":
    main()
