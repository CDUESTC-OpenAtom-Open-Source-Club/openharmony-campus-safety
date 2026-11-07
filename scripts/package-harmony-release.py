"""Build and verify a HarmonyOS release using ignored, encrypted local signing settings.

Never accepts a signing password on the command line. Source signing settings are restored
after the build; delivered files contain no private signing materials.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import zipfile

from cryptography import x509
from cryptography.hazmat.primitives import hashes

ROOT = Path(__file__).resolve().parents[1]


def json5(path):
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", path.read_text(encoding="utf-8-sig")))


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_hap(path, bundle_name, version_code):
    with zipfile.ZipFile(path) as packed:
        app = json.loads(packed.read("module.json"))["app"]
        if app.get("debug") is not False or app.get("buildMode") != "release":
            raise RuntimeError("Expected a non-debug Release HAP")
        if app["bundleName"] != bundle_name or app["versionCode"] != version_code:
            raise RuntimeError("HAP metadata does not match the project")
        for name in ["libs/arm64-v8a/libxiaoan.so", "libs/arm64-v8a/libMNN.so"]:
            if name not in packed.namelist():
                raise RuntimeError("Bundled ARM64 inference runtime is missing: " + name)
        model_hashes = json5(ROOT / "entry/src/main/resources/rawfile/xiaoan/manifest.json")
        for name, expected in model_hashes.items():
            resource_name = "resources/rawfile/xiaoan/" + name
            entry = packed.getinfo(resource_name)
            if entry.file_size != expected["size"] or entry.compress_type != zipfile.ZIP_STORED:
                raise RuntimeError("Model must be complete and accessible through raw file descriptors: " + name)
            digest = hashlib.sha256()
            with packed.open(resource_name) as resource:
                for chunk in iter(lambda: resource.read(1024 * 1024), b""):
                    digest.update(chunk)
            if digest.hexdigest() != expected["sha256"]:
                raise RuntimeError("Bundled model does not match its fixed hash: " + name)
        return {"name": "Qwen3-0.6B MNN", "files": model_hashes}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, default=os.environ.get("DEVECO_SDK_HOME"))
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    sdk = args.sdk
    if sdk is None:
        match = re.search(r"^hwsdk\.dir=(.+)$", (ROOT / "local.properties").read_text(), re.M)
        if match is None:
            raise RuntimeError("Set DEVECO_SDK_HOME or provide --sdk")
        sdk = Path(re.sub(r"\\(.)", r"\1", match.group(1).strip()))
    sdk = sdk.resolve()
    ide = sdk.parent
    node = ide / "tools/node/node.exe"
    java = ide / "jbr/bin/java.exe"
    hvigor = ide / "tools/hvigor/bin/hvigorw.js"
    sign_tool = sdk / "default/openharmony/toolchains/lib/hap-sign-tool.jar"
    for tool in [node, java, hvigor, sign_tool]:
        if not tool.is_file():
            raise RuntimeError("Required build tool is missing: " + str(tool))

    active = json5(ROOT / "signing/active-harmony-release.json")
    signing_dir = (ROOT / "signing" / active["directory"]).resolve()
    if not signing_dir.is_relative_to((ROOT / "signing").resolve()):
        raise RuntimeError("Active signing directory must remain inside signing/")
    signing = json5(signing_dir / "release-signing.json")
    for field in ["storeFile", "certpath", "profile"]:
        if not Path(signing["material"][field]).is_file():
            raise RuntimeError("Signing material is missing: " + field)
    secrets = [signing["material"][field] for field in ["storePassword", "keyPassword"]]
    app = json5(ROOT / "AppScope/app.json5")["app"]
    version = app["versionName"]
    code = app["versionCode"]
    stem = f"校安通-v{version}-{code}-release-signed"
    output = (args.output_dir or ROOT / "release" / f"校安通-v{version}-{code}").resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise RuntimeError("Output directory is not empty; choose a new directory to preserve existing files")
    logs = ROOT / ".regression"
    logs.mkdir(exist_ok=True)
    env = dict(os.environ, JAVA_HOME=str(ide / "jbr"), NODE_HOME=str(node.parent), DEVECO_SDK_HOME=str(sdk))
    env["PATH"] = str(node.parent) + os.pathsep + env.get("PATH", "")
    profile = ROOT / "build-profile.json5"
    original = profile.read_bytes()
    config = json5(profile)
    config["app"]["signingConfigs"] = [signing]
    for product in config["app"]["products"]:
        product["signingConfig"] = signing["name"]
    started = time.time()
    print(f"Building 校安通 {version} ({code}) with the active AGC release identity", flush=True)
    try:
        profile.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
        result = subprocess.run([str(node), str(hvigor), "assembleApp", "--mode", "project", "-p",
                                 "product=default", "-p", "buildMode=release", "--no-daemon"],
                                cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
    finally:
        profile.write_bytes(original)
    log = result.stdout + result.stderr
    for secret in secrets:
        log = log.replace(secret, "[REDACTED]")
    (logs / "build-agc-release.log").write_text(log, encoding="utf-8")
    if result.returncode or "BUILD SUCCESSFUL" not in log:
        raise RuntimeError("Release build failed; see .regression/build-agc-release.log")
    apps = list((ROOT / "build/outputs/default").glob("*-signed.app"))
    hap = ROOT / "entry/build/default/outputs/default/entry-default-signed.hap"
    if len(apps) != 1 or not hap.is_file():
        raise RuntimeError("Expected one signed APP and the signed entry HAP")
    artifacts = {"app": apps[0], "hap": hap}
    report = {"bundleName": app["bundleName"], "versionName": version, "versionCode": code,
              "certificateSha256": active["certificateSha256"], "artifacts": {}}
    with tempfile.TemporaryDirectory(prefix="verify-release-", dir=logs) as temporary:
        verify = Path(temporary)
        for kind, source in artifacts.items():
            if source.stat().st_mtime < started - 2:
                raise RuntimeError("Refusing a stale artifact: " + source.name)
            cert = verify / (kind + ".cer")
            provision = verify / (kind + ".p7b")
            checked = subprocess.run([str(java), "-jar", str(sign_tool), "verify-app", "-inFile", str(source),
                                      "-outCertChain", str(cert), "-outProfile", str(provision)],
                                     capture_output=True, text=True, encoding="utf-8", errors="replace")
            (logs / ("verify-agc-" + kind + ".log")).write_text(checked.stdout + checked.stderr, encoding="utf-8")
            if checked.returncode or "verify-app success" not in checked.stdout:
                raise RuntimeError("Signature verification failed: " + kind)
            chain = x509.load_pem_x509_certificates(cert.read_bytes())
            if not any(c.fingerprint(hashes.SHA256()).hex() == active["certificateSha256"] for c in chain):
                raise RuntimeError("Artifact does not contain the expected release certificate")
            if sha256(provision) != sha256(Path(signing["material"]["profile"])):
                raise RuntimeError("Artifact does not contain the active AGC Profile")
        with zipfile.ZipFile(artifacts["app"]) as packed:
            info = json.loads(packed.read("pack.info"))
            metadata = info["summary"]["app"]
            if metadata["bundleName"] != app["bundleName"] or metadata["version"]["code"] != code:
                raise RuntimeError("APP metadata does not match the project")
            members = [name for name in packed.namelist() if name.endswith(".hap")]
            if len(members) != 1:
                raise RuntimeError("Expected a single embedded entry HAP")
            embedded = verify / "embedded-entry.hap"
            with packed.open(members[0]) as source, embedded.open("wb") as target:
                shutil.copyfileobj(source, target)
            check_hap(embedded, app["bundleName"], code)
            report["embeddedModelVerified"] = True
        report["model"] = check_hap(hap, app["bundleName"], code)
        report["releaseDebugFlag"] = False
        for kind, source in artifacts.items():
            destination = output / (stem + "." + kind)
            shutil.copy2(source, destination)
            report["artifacts"][destination.name] = {"bytes": destination.stat().st_size, "sha256": sha256(destination)}
        with zipfile.ZipFile(artifacts["app"]) as packed:
            (output / "pack.info").write_bytes(packed.read("pack.info"))
    report["buildProfileRestored"] = profile.read_bytes() == original
    (output / "验证报告.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (output / "SHA256校验值.txt").write_text("\n".join(
        f"{data['sha256'].upper()}  {name}" for name, data in report["artifacts"].items()) + "\n", encoding="utf-8")
    print("Release APP/HAP signatures, certificate, Profile, version and bundled model verified.", flush=True)
    print("Output: " + str(output), flush=True)


if __name__ == "__main__":
    main()
