#!/usr/bin/env python3
"""App Store Connect API för TestFlight-flödet i GitHub Actions.

  prepare  Kontrollerar att appen finns i App Store Connect, registrerar
           bundle-id vid behov, väljer nästa byggnummer och skapar ett
           tillfälligt distributionscertifikat och en App Store-profil.
  cleanup  Tar bort certifikatet och profilen igen. Redan uppladdade byggen
           påverkas inte – Apple signerar om dem för TestFlight.
  fix-key  Bygger om en inklistrad .p8-nyckel till korrekt PEM (tappade
           bindestreck, Windows-radbrytningar, allt på en rad) och kontrollerar
           att openssl kan läsa den.

Läser ASC_KEY_ID, ASC_ISSUER_ID och ASC_KEY_PATH (sökväg till .p8-filen)
från miljön. Bara Pythons standardbibliotek och openssl behövs.
"""

import argparse
import base64
import json
import os
import re
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


# Alla .p8-nycklar från App Store Connect är P-256-nycklar i PKCS#8, som
# base64-kodade alltid börjar så här och är 200 tecken långa.
APPLE_KEY_PREFIX = "MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkw"
APPLE_KEY_LENGTH = 200


def normalize_pem(text: str) -> str:
    """Den base64-kodade nyckeln, omradbruten med rätta rubriker. Text före
    BEGIN och efter END (t.ex. ett filnamn som följt med) ignoreras."""
    marked = re.search(r"BEGIN\s+[A-Z ]*KEY-*(.*?)-*\s*END\s+[A-Z ]*KEY", text, re.DOTALL)
    body = marked.group(1) if marked else text
    body = re.sub(r"[^A-Za-z0-9+/=]", "", body)
    start = body.find(APPLE_KEY_PREFIX)
    if start >= 0 and len(body) - start >= APPLE_KEY_LENGTH:
        body = body[start:start + APPLE_KEY_LENGTH]
    lines = [body[i:i + 64] for i in range(0, len(body), 64)]
    return "-----BEGIN PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END PRIVATE KEY-----\n"


def fix_key(args) -> None:
    with open(args.path) as file:
        pem = normalize_pem(file.read())
    with open(args.path, "w") as file:
        file.write(pem)
    check = subprocess.run(["openssl", "pkey", "-in", args.path, "-noout"], capture_output=True, text=True)
    if check.returncode != 0:
        length = len(re.sub(r"-----[A-Z ]+-----|\s", "", pem))
        raise ASCError(
            "ASC_KEY_P8 går inte att läsa som en privat nyckel "
            f"({length} tecken mellan BEGIN och END; en nyckel från App Store Connect har {APPLE_KEY_LENGTH}).\n"
            "Öppna .p8-filen i en textredigerare, kopiera allt från -----BEGIN till och med -----END "
            "(inget filnamn eller annan text) och lägg in det på nytt som hemligheten ASC_KEY_P8."
        )
    print("Nyckeln kan läsas.")

    key_id, issuer_id, _ = credentials()
    problems = []
    if not re.fullmatch(r"[A-Z0-9]{10}", key_id):
        problems.append(f"ASC_KEY_ID ska vara 10 tecken (A–Z, 0–9) men har {len(key_id)}.")
    if not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", issuer_id):
        problems.append(f"ASC_ISSUER_ID ska vara ett id med bindestreck (36 tecken) men har {len(issuer_id)}.")
    if problems:
        raise ASCError("\n".join(problems))
    print("Key ID och Issuer ID har rätt format.")


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
    result = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input, capture_output=True)
    if result.returncode != 0:
        raise ASCError("Kunde inte signera med API-nyckeln: " + result.stderr.decode(errors="replace").strip())
    der = result.stdout
    return f"{header}.{payload}.{b64url(der_to_raw(der))}"


def clean_key_id(value: str) -> str:
    """Key ID är 10 tecken. Tål mellanslag och hela filnamnet AuthKey_XXXXXXXXXX.p8."""
    match = re.search(r"(?:AuthKey_)?([A-Z0-9]{10})(?:\.p8)?", value.strip().upper())
    return match.group(1) if match else value.strip()


def clean_issuer_id(value: str) -> str:
    """Issuer ID är ett UUID. Tål mellanslag och radbrytningar runt om."""
    match = re.search(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", value)
    return match.group(0).lower() if match else value.strip()


def credentials() -> tuple[str, str, str]:
    return (
        clean_key_id(os.environ["ASC_KEY_ID"]),
        clean_issuer_id(os.environ["ASC_ISSUER_ID"]),
        os.environ["ASC_KEY_PATH"],
    )


def api(method: str, path: str, body: dict | None = None, query: dict | None = None):
    url = API + path
    if query:
        url += "?" + urllib.parse.urlencode(query)
    token = make_token(*credentials())
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
        hint = ""
        if error.code == 401:
            hint = (
                "\nApple godtar inte nyckeln. Kontrollera att\n"
                "- ASC_KEY_ID är Key ID för just den nyckel som ligger i ASC_KEY_P8 (står i filnamnet AuthKey_XXXXXXXXXX.p8),\n"
                "- ASC_ISSUER_ID är Issuer ID överst på sidan Team Keys,\n"
                "- nyckeln är en Team Key (inte Individual Key) och inte återkallad."
            )
        elif error.code == 403:
            hint = "\nNyckeln saknar behörighet. Den behöver rollen Admin."
        raise ASCError(f"App Store Connect svarade {error.code} på {method} {path}:\n{detail}{hint}") from None


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

    fix_key_parser = commands.add_parser("fix-key")
    fix_key_parser.add_argument("path")

    args = parser.parse_args()
    handlers = {"prepare": prepare, "cleanup": cleanup, "fix-key": fix_key}
    try:
        handlers[args.command](args)
    except ASCError as error:
        print(f"::error::{error}".replace("\n", "%0A"))
        sys.exit(1)


if __name__ == "__main__":
    main()
