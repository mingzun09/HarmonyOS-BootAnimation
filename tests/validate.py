#!/usr/bin/env python3
"""Portable checks for the built module ZIP and boot animation payload."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "module.prop",
    "customize.sh",
    "post-fs-data.sh",
    "post-mount.sh",
    "service.sh",
    "uninstall.sh",
    "action.sh",
    "common/lib.sh",
    "META-INF/com/google/android/update-binary",
    "META-INF/com/google/android/updater-script",
]
FORBIDDEN = {"skip_mount", ".replace", "system.prop", "sepolicy.rule"}
TEXT_SUFFIXES = {".sh", ".prop", ".txt", ".json", ".md", "/update-binary", "/updater-script"}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--config", type=Path, default=ROOT / "config.json")
    parser.add_argument("--expect-mode", choices=("generated", "custom"))
    args = parser.parse_args()

    config = json.loads(args.config.read_text(encoding="utf-8"))
    prop = (ROOT / "module" / "module.prop").read_text(encoding="utf-8")
    version = next(line.split("=", 1)[1] for line in prop.splitlines() if line.startswith("version="))
    package = args.package or ROOT / "artifacts" / f"HarmonyOS-BootAnimation-v{version}.zip"
    if not package.is_file():
        fail(f"package missing: {package}")

    with zipfile.ZipFile(package) as outer:
        if outer.testzip() is not None:
            fail("outer ZIP CRC error")
        names = outer.namelist()
        if len(names) != len(set(names)):
            fail("duplicate outer ZIP entries")
        for name in names:
            if name.startswith("/") or ".." in Path(name).parts:
                fail(f"unsafe archive path: {name}")
            if FORBIDDEN & set(Path(name).parts):
                fail(f"forbidden module entry: {name}")
        for required in REQUIRED:
            if required not in names:
                fail(f"missing module file: {required}")
        for name in names:
            if any(name.endswith(suffix) for suffix in TEXT_SUFFIXES):
                data = outer.read(name)
                if data.startswith(b"\xef\xbb\xbf") or b"\r" in data:
                    fail(f"requires UTF-8 without BOM and LF: {name}")
        if b"version=" not in outer.read("module.prop"):
            fail("module.prop missing version")
        payload = outer.read("payload/bootanimation.zip")
        expected = outer.read("common/payload.sha256").decode("ascii").strip()
        if sha256(payload) != expected:
            fail("payload SHA-256 mismatch")
        metadata = json.loads(outer.read("common/artwork.json").decode("utf-8"))
        if args.expect_mode and metadata.get("mode") != args.expect_mode:
            fail(f"expected mode {args.expect_mode}, got {metadata.get('mode')}")

        with zipfile.ZipFile(io.BytesIO(payload)) as animation:
            if animation.testzip() is not None:
                fail("inner ZIP CRC error")
            infos = animation.infolist()
            if any(info.compress_type != zipfile.ZIP_STORED for info in infos):
                fail("inner ZIP must be stored, not compressed")
            desc = animation.read("desc.txt")
            if b"\r" in desc or not desc.endswith(b"\n"):
                fail("desc.txt must be LF terminated")
            header = desc.decode("ascii").splitlines()[0].split()
            if header != [str(config["width"]), str(config["height"]), str(config["fps"])]:
                fail(f"desc header mismatch: {header}")
            expected_names = ["desc.txt"]
            for part, count in enumerate((metadata["part0_frames"], metadata["part1_frames"])):
                expected_names += [f"part{part}/{i:05d}.png" for i in range(count)]
            if animation.namelist() != expected_names:
                fail("frame names/counts do not match artwork.json")
            for name in expected_names[1:]:
                with Image.open(io.BytesIO(animation.read(name))) as image:
                    image.load()
                    if image.size != (config["width"], config["height"]):
                        fail(f"{name}: {image.size} != configured canvas")
                    if image.mode != "RGB":
                        fail(f"{name}: expected RGB, got {image.mode}")

    bash = shutil.which("bash")
    if bash:
        # A confined Windows sandbox may expose bash but forbid its signal pipe.
        probe = subprocess.run(
            [bash, "-c", "true"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if probe.returncode == 0:
            scripts = sorted((ROOT / "module").glob("*.sh")) + [ROOT / "module" / "common" / "lib.sh"]
            for script in scripts:
                result = subprocess.run(
                    [bash, "-n", str(script)],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                )
                if result.returncode != 0:
                    fail(f"bash -n failed for {script.name}: {result.stderr.strip()}")
            print(f"OK: shell syntax checked ({len(scripts)} scripts)")
        else:
            print("WARN: bash cannot start in this environment; skipped bash -n")

    print(f"OK: {package.name} ({package.stat().st_size} bytes)")
    print(f"OK: mode={metadata.get('mode')} canvas={config['width']}x{config['height']} frames={metadata['part0_frames']}+{metadata['part1_frames']}")
    print(f"OK: payload sha256={sha256(payload)}")


if __name__ == "__main__":
    main()
