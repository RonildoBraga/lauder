"""Lauder's internal TestFlight workflow. Keys and JWTs are never written to reports."""
import argparse
import base64
import contextlib
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = "com.ronildo.lauder"
PROJECT = "apple/Lauder.xcodeproj"
SCHEME = "Lauder"
APPLE = "https://api.appstoreconnect.apple.com"


class ReleaseError(Exception):
    """A diagnostic written deliberately without credentials or private response data."""


def require(condition, message):
    if not condition:
        raise ReleaseError(message)


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def private_file(path, mode="w"):
    require(mode in ("w", "wb"), "Unsupported private output mode.")
    require(not path.is_symlink(), "Private output must not be a symbolic link.")
    stream = os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600), mode)
    try:
        os.fchmod(stream.fileno(), 0o600)
    except OSError:
        stream.close()
        raise
    return stream


def save(folder, name, value):
    path = folder / name
    require(not path.is_symlink(), "Private report must not replace a symbolic link.")
    temporary = None
    try:
        # status and wait can run concurrently; each writer owns its own temporary file.
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=folder,
                                         prefix=f".{name}.", suffix=".tmp", delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(value, stream, indent=2)
            stream.write("\n")
        temporary.replace(path)
        path.chmod(0o600)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def read(folder, name):
    try:
        return json.loads((folder / name).read_text())
    except (OSError, ValueError):
        raise ReleaseError(f"Missing or unreadable private {name}; preserve the delivery directory.") from None


def emit(value):
    print(json.dumps(value), flush=True)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()


def identity():
    text = (ROOT / PROJECT / "project.pbxproj").read_text()
    def setting(name):
        values = set(re.findall(rf"\b{name} = ([^;]+);", text))
        require(len(values) == 1, f"Expected one committed {name} value.")
        return values.pop().strip('"')
    version, number = setting("MARKETING_VERSION"), setting("CURRENT_PROJECT_VERSION")
    require(re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", version), "Committed marketing version is invalid.")
    require(re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", number), "Committed build number is invalid.")
    return version, number


def preview_branch_name(value):
    require(type(value) is str and bool(value) and value != "main",
            "A reviewed preview requires a valid named non-main branch.")
    try:
        git("check-ref-format", "--branch", value)
    except (subprocess.CalledProcessError, ValueError):
        raise ReleaseError("A reviewed preview requires a valid named non-main branch.") from None
    return value


def source(preview_branch=None):
    branch = git("branch", "--show-current")
    if preview_branch is None:
        require(branch == "main", "Archive/upload the integrated main branch.")
    else:
        require(branch == preview_branch_name(preview_branch),
                "Preview source must remain on its original named branch.")
    require(not git("status", "--porcelain", "--untracked-files=all"), "Archive/upload requires a clean source checkout.")
    result = {"sourceCommit": git("rev-parse", "HEAD"), "sourceTree": git("rev-parse", "HEAD^{tree}")}
    if preview_branch is not None:
        result["previewBranch"] = preview_branch
    return result


def frozen(expected):
    preview = preview_branch_name(expected["previewBranch"]) if "previewBranch" in expected else None
    keys = ("sourceCommit", "sourceTree") + (("previewBranch",) if preview is not None else ())
    actual = source(preview) if preview is not None else source()
    require(actual == {key: expected[key] for key in keys},
            "Source changed after validation; preserve the archive and validate the intended source.")


def credentials():
    # Resolve only for a network/signing command, never on import or --help.
    key_path = os.environ.get("LAUDER_ASC_KEY_PATH", "")
    issuer = os.environ.get("LAUDER_ASC_ISSUER_ID", "")
    require(bool(key_path), "Set LAUDER_ASC_KEY_PATH to the identified existing upload key.")
    path = Path(key_path).expanduser()
    require(path.is_file(), "The configured upload key is not a file.")
    match = re.fullmatch(r"AuthKey_([A-Za-z0-9]+)\.p8", path.name)
    inferred = match[1] if match else None
    key_id = os.environ.get("LAUDER_ASC_KEY_ID") or inferred
    require(bool(key_id) and re.fullmatch(r"[A-Za-z0-9]+", key_id), "Set a valid LAUDER_ASC_KEY_ID.")
    require(inferred is None or key_id == inferred, "The selected key ID does not match its filename.")
    require(re.fullmatch(r"[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}", issuer),
            "Set a valid LAUDER_ASC_ISSUER_ID from the private local configuration.")
    return path, key_id, issuer


def team():
    value = os.environ.get("LAUDER_DEVELOPMENT_TEAM", "")
    require(re.fullmatch(r"[A-Z0-9]{10}", value), "Set a valid LAUDER_DEVELOPMENT_TEAM.")
    return value


def authentication():
    path, key_id, issuer = credentials()
    return ["-authenticationKeyPath", str(path), "-authenticationKeyID", key_id,
            "-authenticationKeyIssuerID", issuer, "-allowProvisioningUpdates"]


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class AppleAPI:
    def token(self):
        try:
            from cryptography.hazmat.primitives import hashes, serialization
            from cryptography.hazmat.primitives.asymmetric import ec
            from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
        except ImportError:
            raise ReleaseError("Install apple/scripts/requirements-release.txt for release commands.") from None
        path, key_id, issuer = credentials()
        key = serialization.load_pem_private_key(path.read_bytes(), password=None)
        require(isinstance(key, ec.EllipticCurvePrivateKey) and key.curve.name == "secp256r1",
                "The configured upload key must be an Apple P-256 private key.")
        def encode(value):
            return base64.urlsafe_b64encode(value).rstrip(b"=").decode()
        seconds = int(time.time())
        header = encode(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
        claims = encode(json.dumps({"iss": issuer, "iat": seconds, "exp": seconds + 600,
                                    "aud": "appstoreconnect-v1"}).encode())
        message = f"{header}.{claims}"
        r, s = decode_dss_signature(key.sign(message.encode(), ec.ECDSA(hashes.SHA256())))
        return f"{message}.{encode(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))}"

    def request(self, path, params=None):
        url = path if path.startswith("https://") else APPLE + path
        parsed = urllib.parse.urlparse(url)
        require(parsed.scheme == "https" and parsed.netloc == "api.appstoreconnect.apple.com",
                "Refusing Apple authentication to another destination.")
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
        request = urllib.request.Request(url, headers={"Authorization": "Bearer " + self.token()})
        try:
            with urllib.request.build_opener(NoRedirect()).open(request, timeout=30) as response:
                return json.loads(response.read())
        except urllib.error.HTTPError as error:
            codes = []
            try:
                codes = [item.get("code", "") for item in json.loads(error.read()).get("errors", [])]
                codes = [code for code in codes if re.fullmatch(r"[A-Z0-9_.-]+", code)]
            except (ValueError, TypeError):
                pass
            raise ReleaseError(f"Apple API HTTP {error.code}; codes: {codes}") from None


def resources(api, path, params=None):
    data, included, visited = [], {}, set()
    while path:
        require(path not in visited, "Apple pagination repeated a page.")
        visited.add(path)
        result = api.request(path, params)
        data.extend(result.get("data", []))
        for item in result.get("included", []):
            included[(item["type"], item["id"])] = item
        path, params = result.get("links", {}).get("next"), None
    return data, included


def find_app(api):
    apps, _ = resources(api, "/v1/apps", {"filter[bundleId]": BUNDLE, "limit": 200})
    require(len(apps) == 1 and apps[0].get("attributes", {}).get("bundleId") == BUNDLE,
            "Expected exactly one Lauder App Store Connect record for the bundle ID.")
    return apps[0]


def release_version(build, included):
    related = build.get("relationships", {}).get("preReleaseVersion", {}).get("data")
    return included.get(("preReleaseVersions", related["id"]), {}).get("attributes", {}).get("version") if related else None


def upload_state(upload):
    state = upload.get("attributes", {}).get("state")
    return state.get("state", "UNKNOWN") if isinstance(state, dict) else state or "UNKNOWN"


def records(api, app):
    uploads, _ = resources(api, f"/v1/apps/{app['id']}/buildUploads", {"limit": 200})
    builds, included = resources(api, "/v1/builds", {
        "filter[app]": app["id"], "include": "preReleaseVersion", "limit": 200})
    return uploads, builds, included


def reserved_numbers(version, uploads, builds, included):
    numbers = {str(item["attributes"]["cfBundleVersion"]) for item in uploads
               if item["attributes"].get("cfBundleShortVersionString") == version}
    numbers.update(str(item["attributes"]["version"]) for item in builds
                   if release_version(item, included) in (version, None))
    return numbers


def next_number(numbers):
    majors = [int(value.split(".")[0]) for value in numbers if value.split(".")[0].isdecimal()]
    candidate = max(majors, default=0) + 1
    while str(candidate) in numbers:
        candidate += 1
    return str(candidate)


def unused(api, app, version, number, folder, report):
    uploads, builds, included = records(api, app)
    require(number not in reserved_numbers(version, uploads, builds, included),
            "Apple already accepted/reserved this build number; inspect status before another upload.")
    save(folder, report, {"uploads": uploads, "builds": builds, "included": list(included.values())})


def ids(items):
    return {item["id"] for item in items}


def baseline(api, app, folder):
    groups, _ = resources(api, f"/v1/apps/{app['id']}/betaGroups", {"limit": 200})
    groups = [item for item in groups if item["attributes"].get("isInternalGroup")]
    require(groups, "Lauder has no existing internal TestFlight group.")
    testers = {}
    for group in groups:
        people, _ = resources(api, f"/v1/betaGroups/{group['id']}/betaTesters", {"limit": 200})
        testers[group["id"]] = [{"id": item["id"]} for item in people]
    require(any(testers.values()), "Lauder has no existing internal testers.")
    if (folder / "groups-before.json").exists():
        old_groups, old_testers = read(folder, "groups-before.json"), read(folder, "testers-before.json")
        require(ids(old_groups) == ids(groups) and all(ids(old_testers.get(key, [])) == ids(value)
                for key, value in testers.items()), "Existing groups/testers changed since this delivery baseline.")
    else:
        save(folder, "groups-before.json", [{"id": item["id"]} for item in groups])
        save(folder, "testers-before.json", testers)
    return groups


def discover(api, folder):
    require(not (folder / "manifest.json").exists(), "Delivery already started; preserve its baseline and run status.")
    version, _ = identity()
    app = find_app(api)
    uploads, builds, included = records(api, app)
    numbers = reserved_numbers(version, uploads, builds, included)
    groups = baseline(api, app, folder)
    save(folder, "app.json", app)
    save(folder, "discovery.json", {"bundleIdentifier": BUNDLE, "version": version, "checkedAt": now(),
         "reservedBuildNumbers": sorted(numbers), "candidateBuildNumber": next_number(numbers)})
    emit({"bundleIdentifier": BUNDLE, "version": version, "candidateBuildNumber": next_number(numbers),
          "internalGroupsAutoDistribute": all(item["attributes"].get("hasAccessToAllBuilds") is True for item in groups)})


def logged(args, path):
    with private_file(path) as stream:
        result = subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    require(result.returncode == 0, f"Command failed; inspect private {path.name} and preserve its evidence.")


def verify_receipt(folder, expected):
    receipt = read(folder, "checks.json")
    preview = "previewBranch" in expected
    require(("previewBranch" in receipt) == preview,
            "Check receipt does not match the archive preview context.")
    if preview:
        preview_branch_name(expected["previewBranch"])
        preview_branch_name(receipt["previewBranch"])
    keys = ("sourceCommit", "sourceTree") + (("previewBranch",) if preview else ())
    require(receipt.get("passed") is True and all(receipt.get(key) == expected[key]
            for key in keys), "Check receipt does not match the archive source.")
    path = folder / "check.log"
    require(path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == receipt.get("logSHA256"),
            "Check log is missing or changed since successful validation.")


def export_options(signing_team):
    return {"method": "app-store-connect", "destination": "upload", "teamID": signing_team,
            "signingStyle": "automatic", "testFlightInternalTestingOnly": True,
            "manageAppVersionAndBuildNumber": False, "uploadSymbols": True}


def archive_metadata(archive, manifest, signing_team):
    metadata = plistlib.loads((archive / "Info.plist").read_bytes())
    properties = metadata.get("ApplicationProperties", {})
    require(metadata.get("ArchiveVersion") == 2 and metadata.get("Name") == SCHEME
            and metadata.get("SchemeName") == SCHEME,
            "Archive metadata is not the expected Lauder archive format/scheme.")
    require(properties.get("ApplicationPath") == "Applications/Lauder.app"
            and properties.get("CFBundleIdentifier") == BUNDLE
            and properties.get("CFBundleShortVersionString") == manifest["version"]
            and str(properties.get("CFBundleVersion")) == manifest["build"]
            and properties.get("Team") == signing_team,
            "Archive export routing, app identity or signing team does not match Lauder.")
    products = archive / "Products"
    require({path for path in products.rglob("*.app")} == {products / "Applications/Lauder.app"},
            "Archive contains an unexpected application product.")
    # Xcode appends Distributions upload history; retain only immutable export-routing metadata.
    return {key: metadata[key] for key in ("ArchiveVersion", "Name", "SchemeName", "ApplicationProperties")}


def archive_digest(app, symbols, metadata):
    digest = hashlib.sha256(plistlib.dumps(metadata, fmt=plistlib.FMT_BINARY, sort_keys=True))
    for index, base in enumerate((app, symbols)):
        digest.update(str(index).encode() + b"\0")
        files = sorted(path for path in base.rglob("*") if path.is_file()) if base.is_dir() else [base]
        for path in files:
            digest.update(str(path.relative_to(base.parent)).encode() + b"\0")
            digest.update(str(path.stat().st_size).encode() + b"\0")
            with path.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
    return digest.hexdigest()


def verify_archive(folder, manifest, signing_team, record=False):
    archive = Path(manifest["archivePath"])
    require(archive == folder / f"Lauder-build{manifest['build']}.xcarchive",
            "Archive path does not belong to this delivery manifest.")
    metadata = archive_metadata(archive, manifest, signing_team)
    app = archive / "Products/Applications/Lauder.app"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    require((info.get("CFBundleIdentifier"), info.get("CFBundleShortVersionString"), str(info.get("CFBundleVersion")))
            == (BUNDLE, manifest["version"], manifest["build"]), "Archive app identity/version/build does not match.")
    logged(["codesign", "--verify", "--deep", "--strict", str(app)], folder / "signature-check.log")
    logged(["codesign", "-d", "--verbose=4", str(app)], folder / "signature-details.log")
    signature = (folder / "signature-details.log").read_text(errors="replace")
    require("TeamIdentifier=" + signing_team + "\n" in signature, "Archive signing team does not match configuration.")
    binary = app / info["CFBundleExecutable"]
    symbols = archive / "dSYMs/Lauder.app.dSYM/Contents/Resources/DWARF/Lauder"
    def uuids(path, name):
        logged(["dwarfdump", "--uuid", str(path)], folder / name)
        value = (folder / name).read_text(errors="replace")
        return sorted(re.findall(r"UUID: ([A-Fa-f0-9-]+)", value))
    binary_uuids = uuids(binary, "binary-symbols.log")
    require(symbols.is_file() and binary_uuids and uuids(symbols, "debug-symbols.log") == binary_uuids,
            "Archive and dSYM UUIDs do not match.")
    fingerprint = archive_digest(app, symbols, metadata)
    if record:
        manifest.update({"archiveVerified": True, "signatureVerified": True, "dSYMVerified": True,
                         "binaryUUIDs": binary_uuids, "archiveSHA256": fingerprint})
        save(folder, "manifest.json", manifest)
    else:
        require(manifest.get("archiveVerified") and manifest.get("signatureVerified") and manifest.get("dSYMVerified")
                and manifest.get("binaryUUIDs") == binary_uuids and manifest.get("archiveSHA256") == fingerprint,
                "Archive changed since its signed-source verification.")


@contextlib.contextmanager
def exclusive(folder, name):
    lock = folder / name
    try:
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    except FileExistsError:
        raise ReleaseError("A release operation lock exists; preserve its receipt and inspect status.") from None
    os.close(descriptor)
    try:
        yield
    finally:
        lock.unlink(missing_ok=True)


def archive(api, folder, reviewed, reviewed_preview=False):
    require(type(reviewed_preview) is bool, "Reviewed-preview selection must be a boolean.")
    with exclusive(folder, "archive-in-progress"):
        return _archive(api, folder, reviewed, reviewed_preview)


def _archive(api, folder, reviewed, reviewed_preview=False):
    require(type(reviewed_preview) is bool, "Reviewed-preview selection must be a boolean.")
    require(re.fullmatch(r"[a-fA-F0-9]{7,40}", reviewed or ""), "Supply --reviewed-commit from the completed review.")
    initial = source(git("branch", "--show-current")) if reviewed_preview else source()
    reviewed_commit = git("rev-parse", "--verify", reviewed + "^{commit}")
    require(git("rev-parse", reviewed_commit + "^{tree}") == initial["sourceTree"],
            "Archive source must match the reviewed source tree.")
    require(not (folder / "manifest.json").exists(), "A manifest already exists; preserve this delivery and run status.")
    discovery = read(folder, "discovery.json")
    version, number = identity()
    require(discovery["bundleIdentifier"] == BUNDLE and discovery["version"] == version,
            "Run discovery for this Lauder version before archiving.")
    require((folder / "groups-before.json").is_file() and (folder / "testers-before.json").is_file(),
            "The existing-tester baseline is required before archiving.")
    app = find_app(api)
    require(app["id"] == read(folder, "app.json")["id"], "Lauder app record changed since discovery.")
    signing_team = team()
    auth = authentication()
    unused(api, app, version, number, folder, "before-archive.json")
    logged([str(ROOT / "scripts/check")], folder / "check.log")
    frozen(initial)
    save(folder, "checks.json", {**initial, "passed": True, "completedAt": now(),
         "logSHA256": hashlib.sha256((folder / "check.log").read_bytes()).hexdigest()})
    unused(api, app, version, number, folder, "before-archive.json")
    frozen(initial)
    output = folder / f"Lauder-build{number}.xcarchive"
    require(not output.exists(), "Archive path already exists; preserve the existing archive.")
    manifest = {**initial, "reviewedCommit": reviewed_commit, "bundleIdentifier": BUNDLE,
                "version": version, "build": number, "appStoreConnectAppID": app["id"],
                "archivePath": str(output), "createdAt": now()}
    save(folder, "manifest.json", manifest)
    options = folder / "ExportOptions.plist"
    with private_file(options, mode="wb") as stream:
        stream.write(plistlib.dumps(export_options(signing_team)))
    logged(["xcodebuild", "-quiet", "-project", PROJECT, "-scheme", SCHEME,
            "-configuration", "Release", "-destination", "generic/platform=iOS", "-archivePath", str(output),
            "-derivedDataPath", str(folder / "DerivedData"), "DEVELOPMENT_TEAM=" + signing_team,
            *auth, "archive"], folder / "archive.log")
    frozen(initial)
    verify_archive(folder, manifest, signing_team, record=True)
    emit({"archiveVerified": True, "sourceCommit": initial["sourceCommit"], "version": version, "build": number})


def upload(api, folder):
    # The receipt is read under the lock, so a stale caller cannot overwrite a completed attempt.
    with exclusive(folder, "upload-in-progress"):
        return _upload(api, folder)


def _upload(api, folder):
    manifest = read(folder, "manifest.json")
    require(manifest.get("bundleIdentifier") == BUNDLE, "Manifest is not Lauder.")
    require(not manifest.get("uploadStartedAt"), "An upload was attempted; inspect status before any retry.")
    frozen(manifest)
    verify_receipt(folder, manifest)
    signing_team = team()
    auth = authentication()
    options = plistlib.loads((folder / "ExportOptions.plist").read_bytes())
    require(options == export_options(signing_team), "Export policy/configuration changed after archiving.")
    verify_archive(folder, manifest, signing_team)
    app = find_app(api)
    require(app["id"] == manifest["appStoreConnectAppID"], "Manifest App Store Connect record is not Lauder.")
    unused(api, app, manifest["version"], manifest["build"], folder, "before-upload.json")
    require((folder / "groups-before.json").is_file() and (folder / "testers-before.json").is_file(),
            "Existing-tester discovery baseline is missing; preserve this delivery.")
    baseline(api, app, folder)
    frozen(manifest)
    manifest["uploadStartedAt"] = now()
    save(folder, "manifest.json", manifest)
    args = ["xcodebuild", "-exportArchive", "-archivePath", manifest["archivePath"],
            "-exportPath", str(folder / "export"), "-exportOptionsPlist", str(folder / "ExportOptions.plist"), *auth]
    with private_file(folder / "upload.log") as stream:
        result = subprocess.run(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    manifest.update({"uploadExitCode": result.returncode, "uploadCommandSucceeded": result.returncode == 0,
                     "uploadFinishedAt": now()})
    save(folder, "manifest.json", manifest)
    require(result.returncode == 0, "Upload command failed; inspect private logs and Apple status before retrying.")
    emit({"uploadCommandSucceeded": True, "version": manifest["version"], "build": manifest["build"],
          "availabilityVerified": False})


def collect_status(api, folder):
    manifest = read(folder, "manifest.json")
    require(manifest.get("bundleIdentifier") == BUNDLE, "Manifest is not Lauder.")
    groups, before = read(folder, "groups-before.json"), read(folder, "testers-before.json")
    require(groups and any(before.values()), "Existing internal testers must have a discovery baseline.")
    app = find_app(api)
    require(app["id"] == manifest["appStoreConnectAppID"], "Manifest App Store Connect record is not Lauder.")
    version, number = manifest["version"], manifest["build"]
    uploads, builds, included = records(api, app)
    ours = [item for item in uploads if str(item["attributes"].get("cfBundleVersion")) == number
            and item["attributes"].get("cfBundleShortVersionString") == version]
    matches = [item for item in builds if str(item["attributes"].get("version")) == number
               and release_version(item, included) == version]
    require(len(ours) <= 1 and len(matches) <= 1, "Multiple Apple records match this version/build.")
    result = {"checkedAt": now(), "bundleIdentifier": BUNDLE, "version": version, "build": number,
              "uploadState": upload_state(ours[0]) if ours else None, "processingState": None,
              "availableToExistingInternalTesters": False}
    if ours:
        state = ours[0]["attributes"].get("state", {})
        errors = state.get("errors", []) if isinstance(state, dict) else []
        result["uploadErrorCount"] = len(errors)
        save(folder, "upload-state.json", ours[0])
        require(not errors and result["uploadState"] not in ("FAILED", "INVALID"),
                "Apple reports an upload failure; inspect the private upload state.")
    if matches:
        build = matches[0]
        proof = api.request(f"/v1/builds/{build['id']}", {"include": "app,preReleaseVersion,buildBetaDetail"})
        save(folder, "build-proof.json", proof)
        actual, related = proof["data"], proof.get("included", [])
        apps = [item for item in related if item["type"] == "apps"]
        versions = [item for item in related if item["type"] == "preReleaseVersions"]
        details = [item for item in related if item["type"] == "buildBetaDetails"]
        require(len(apps) == 1 and apps[0]["id"] == app["id"] and apps[0]["attributes"].get("bundleId") == BUNDLE
                and len(versions) == 1 and versions[0]["attributes"].get("version") == version
                and str(actual["attributes"].get("version")) == number, "Apple build identity does not match Lauder.")
        attributes = actual["attributes"]
        result.update({"identityConfirmed": True, "processingState": attributes.get("processingState"),
                       "expired": attributes.get("expired"), "buildAudienceType": attributes.get("buildAudienceType"),
                       "internalBuildState": details[0]["attributes"].get("internalBuildState") if len(details) == 1 else None})
        require(result["processingState"] not in ("FAILED", "INVALID") and result["expired"] is not True,
                "Apple build is invalid or expired; inspect private build proof.")
        require(result["buildAudienceType"] in (None, "INTERNAL_ONLY"), "Apple build is not internal-only.")
        current_groups, _ = resources(api, f"/v1/apps/{app['id']}/betaGroups", {"limit": 200})
        require(ids([item for item in current_groups if item["attributes"].get("isInternalGroup")]) == ids(groups),
                "The internal group set changed since discovery.")
        snapshots, memberships = {}, {}
        available = []
        for group in groups:
            key = group["id"]
            group_builds, _ = resources(api, f"/v1/betaGroups/{key}/builds", {"limit": 200})
            testers, _ = resources(api, f"/v1/betaGroups/{key}/betaTesters", {"limit": 200})
            require(ids(testers) == ids(before.get(key, [])), "Tester membership changed since discovery.")
            available.append(any(item["id"] == actual["id"] for item in group_builds))
            snapshots[key], memberships[key] = group_builds, [{"id": item["id"]} for item in testers]
        save(folder, "group-builds-after.json", snapshots)
        save(folder, "testers-after.json", memberships)
        result.update({"internalGroupSetUnchanged": True, "testersUnchanged": True,
                       "existingGroupsContainBuild": all(available)})
        result["availableToExistingInternalTesters"] = (
            result["uploadState"] == "COMPLETE" and result.get("uploadErrorCount") == 0
            and result["processingState"] == "VALID" and result["expired"] is False
            and result["internalBuildState"] == "IN_BETA_TESTING" and result["buildAudienceType"] == "INTERNAL_ONLY"
            and all(available))
    save(folder, "availability.json", result)
    return result


def status(api, folder, timeout=0, interval=15):
    deadline = time.monotonic() + timeout
    while True:
        result = collect_status(api, folder)
        emit(result)
        if result["availableToExistingInternalTesters"]:
            return 0
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return 2
        time.sleep(min(interval, remaining))


def delivery_directory(value, command):
    # Keep account snapshots and logs out of source, including symlinked paths into source.
    base = ROOT / ".local"
    lexical = Path(os.path.abspath(value.expanduser()))
    require(lexical.is_relative_to(base) and lexical != base,
            "Use a private delivery directory beneath .local/.")
    cursor = lexical
    while cursor != ROOT:
        require(not cursor.is_symlink(), "Private delivery directories must not traverse symbolic links.")
        cursor = cursor.parent
    folder = lexical.resolve()
    require(folder.is_relative_to(base.resolve()), "Private output escaped .local/.")
    marker = folder / "delivery-owner.json"
    owner = {"tool": "lauder-testflight", "formatVersion": 1, "bundleIdentifier": BUNDLE}
    if command == "discover" and not marker.exists():
        require(not folder.exists() or not any(folder.iterdir()),
                "Use a fresh delivery directory; existing files have no Lauder release ownership receipt.")
        folder.mkdir(mode=0o700, parents=True, exist_ok=True)
        save(folder, "delivery-owner.json", owner)
    require(not marker.is_symlink() and read(folder, "delivery-owner.json") == owner,
            "The output directory does not belong to this Lauder release workflow.")
    folder.chmod(0o700)
    return folder


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("discover", "archive", "upload", "status", "wait"))
    parser.add_argument("--output", type=Path, required=True, help="private delivery directory under .local/")
    parser.add_argument("--reviewed-commit",
                        help="completed-review commit; exact tree on clean main or an explicit reviewed-preview branch")
    parser.add_argument("--reviewed-preview", action="store_true",
                        help="archive an explicitly authorised reviewed preview from a clean named non-main branch")
    parser.add_argument("--timeout", type=int, default=600, help="wait seconds (1–3600; default 600)")
    args = parser.parse_args(argv)
    os.umask(0o077)
    folder = None
    try:
        require(not args.reviewed_preview or args.command == "archive",
                "--reviewed-preview is supported only for archive; upload uses its recorded manifest.")
        require(1 <= args.timeout <= 3600, "Wait timeout must be between 1 and 3600 seconds.")
        folder = delivery_directory(args.output, args.command)
        api = AppleAPI()
        if args.command == "discover":
            discover(api, folder)
        elif args.command == "archive":
            archive(api, folder, args.reviewed_commit, args.reviewed_preview)
        elif args.command == "upload":
            upload(api, folder)
        else:
            return status(api, folder, timeout=args.timeout if args.command == "wait" else 0)
        return 0
    except Exception as error:
        # Unknown messages can contain accounts, paths, key text or HTTP response bodies.
        result = {"ok": False, "error": str(error) if isinstance(error, ReleaseError) else type(error).__name__}
        if folder is not None and args.command in ("status", "wait"):
            try:
                save(folder, "status-error.json", {**result, "checkedAt": now(),
                     "availableToExistingInternalTesters": False})
            except (OSError, ReleaseError):
                pass
        emit(result)
    return 1
