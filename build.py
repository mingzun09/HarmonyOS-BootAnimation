#!/usr/bin/env python3
"""Build the HarmonyOS-style boot animation module.

Two artwork modes:

* "generated" - render the original wordmark animation.
* "custom"    - package your own image sequence from artwork/custom.

The inner bootanimation.zip is always ZIP_STORED, contains RGB PNG frames and
matches the dimensions in desc.txt. The outer module ZIP is normal DEFLATE.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import zipfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
import numpy as np

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / ".build"
ASSETS = BUILD / "assets"
ARTIFACTS = ROOT / "artifacts"
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}
STAMP = (2026, 1, 1, 0, 0, 0)
REFERENCE = 1080
CROP_BOX = (180, 412, 900, 668)


def zip_entry(name: str, content: bytes, *, stored: bool = False, executable: bool = False) -> tuple[zipfile.ZipInfo, bytes]:
    entry = zipfile.ZipInfo(name, STAMP)
    entry.create_system = 3
    entry.external_attr = (0o100755 if executable else 0o100644) << 16
    entry.compress_type = zipfile.ZIP_STORED if stored else zipfile.ZIP_DEFLATED
    return entry, content


def put(z: zipfile.ZipFile, name: str, content: bytes, **kwargs) -> None:
    entry, data = zip_entry(name, content, **kwargs)
    z.writestr(entry, data)


def read_config(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    for key in ("width", "height", "fps", "background", "mode"):
        if key not in data:
            raise ValueError(f"config.json: missing {key}")
    if data["mode"] not in {"generated", "custom"}:
        raise ValueError("config.json: mode must be 'generated' or 'custom'")
    if not (16 <= data["width"] <= 4096 and 16 <= data["height"] <= 4096):
        raise ValueError("config.json: width/height out of range")
    if not (1 <= data["fps"] <= 120):
        raise ValueError("config.json: fps out of range")
    if not re.fullmatch(r"#[0-9A-Fa-f]{6}", data["background"]):
        raise ValueError("config.json: background must be #RRGGBB")
    return data


def module_version() -> str:
    text = (ROOT / "module" / "module.prop").read_text(encoding="utf-8")
    match = re.search(r"^version=(.+)$", text, re.MULTILINE)
    if not match:
        raise ValueError("module.prop: missing version")
    return match.group(1).strip()


def font_path(requested: str | None) -> Path:
    if requested:
        path = Path(requested)
        if not path.is_file():
            raise FileNotFoundError(path)
        return path
    candidates = [
        Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts" / "segoeui.ttf",
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
        Path("/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf"),
    ]
    for path in candidates:
        if path.is_file():
            return path
    raise RuntimeError("No sans-serif font found. Pass --font /path/to/font.ttf.")


def smoothstep(x: float) -> float:
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


class GeneratedArtwork:
    """Original white wordmark with a restrained highlight and blue underline."""

    def __init__(self, font: Path, config: dict):
        self.width = int(config["width"])
        self.height = int(config["height"])
        self.fps = int(config["fps"])
        self.intro_frames = int(config["generated"]["intro_frames"])
        self.loop_frames = int(config["generated"]["loop_frames"])
        if self.intro_frames < 1 or self.loop_frames < 1:
            raise ValueError("generated frame counts must be positive")

        scale = 2
        size = 130
        while True:
            font_object = ImageFont.truetype(str(font), size * scale)
            measure = ImageDraw.Draw(Image.new("L", (1, 1)))
            text_width = measure.textlength("HarmonyOS", font=font_object) / scale
            if text_width <= 646:
                break
            size -= 1
        bounds = measure.textbbox((0, 0), "HarmonyOS", font=font_object)
        x = (REFERENCE - text_width) / 2
        y = 518 - (bounds[1] + bounds[3]) / (2 * scale)
        mask = Image.new("L", (REFERENCE * scale, REFERENCE * scale))
        ImageDraw.Draw(mask).text(
            (round(x * scale), round(y * scale)),
            "HarmonyOS",
            font=font_object,
            fill=255,
        )
        self.text = mask.resize((REFERENCE, REFERENCE), Image.Resampling.LANCZOS)
        self.text_array = np.asarray(self.text, dtype=np.float32) / 255.0
        self.glow = self.text.filter(ImageFilter.GaussianBlur(3.2))
        self.x0, self.x1 = x, x + text_width
        self.bar_x0 = x + measure.textlength("Harmony", font=font_object) / scale + 4
        self.bar_x1 = x + text_width - 3
        self.bar_y = y + bounds[3] / scale + 24
        self.xgrid = np.arange(REFERENCE, dtype=np.float32)[None, :]
        self.meta = {
            "mode": "generated",
            "canvas": [self.width, self.height],
            "reference_canvas": [REFERENCE, REFERENCE],
            "fps": self.fps,
            "part0_frames": self.intro_frames,
            "part1_frames": self.loop_frames,
            "wordmark": "HarmonyOS",
            "font_input": font.name,
            "crop_method": "actual center crop of black borders; no scaling and no trim.txt",
            "copyright_note": (
                "Original rendered artwork; not an official Huawei asset. "
                "HarmonyOS is a Huawei trademark."
            ),
        }

    def frame(self, part: int, index: int) -> Image.Image:
        if part == 0:
            t = index / self.fps
            alpha = smoothstep((t - 0.10) / 0.83)
            bar_length = smoothstep((t - 0.43) / 0.78)
            phase = max(0.0, t - 1.15) / 2.0
            sheen = math.sin(math.pi * max(0.0, min(1.0, (t - 0.37) / 1.04))) ** 2
            sheen_x = self.x0 - 70 + (self.x1 - self.x0 + 140) * max(
                0.0, min(1.0, (t - 0.37) / 1.04)
            )
        else:
            alpha = bar_length = 1.0
            phase = index / self.loop_frames
            sheen = 0.0
            sheen_x = 0.0

        band = np.exp(-((self.xgrid - sheen_x) / 39.0) ** 2) * sheen * 18
        luminance = np.clip(
            self.text_array * (237.0 + band) * alpha, 0, 255
        ).astype(np.uint8)
        img = Image.fromarray(luminance).convert("RGB")
        text_glow = Image.composite(
            Image.new("RGB", (REFERENCE, REFERENCE), (11, 16, 23)),
            Image.new("RGB", (REFERENCE, REFERENCE)),
            self.glow.point(lambda p: round(p * alpha)),
        )
        img = ImageChops.add(img, text_glow)

        if bar_length > 0:
            bar = Image.new("L", (REFERENCE, REFERENCE))
            right = self.bar_x0 + (self.bar_x1 - self.bar_x0) * bar_length
            breath = 0.76 + 0.24 * math.cos(2 * math.pi * phase)
            ImageDraw.Draw(bar).rounded_rectangle(
                (
                    round(self.bar_x0),
                    round(self.bar_y),
                    max(round(self.bar_x0 + 1), round(right)),
                    round(self.bar_y + 4),
                ),
                radius=2,
                fill=round(255 * breath * alpha),
            )
            halo = bar.filter(ImageFilter.GaussianBlur(10))
            haze = Image.composite(
                Image.new("RGB", (REFERENCE, REFERENCE), (31, 117, 210)),
                Image.new("RGB", (REFERENCE, REFERENCE)),
                halo.point(lambda p: min(255, p * 3)),
            )
            ink = Image.composite(
                Image.new("RGB", (REFERENCE, REFERENCE), (78, 184, 255)),
                Image.new("RGB", (REFERENCE, REFERENCE)),
                bar,
            )
            img = ImageChops.add(ImageChops.add(img, haze), ink)

        bounds = img.getbbox()
        if bounds and not (
            CROP_BOX[0] <= bounds[0]
            and CROP_BOX[1] <= bounds[1]
            and bounds[2] <= CROP_BOX[2]
            and bounds[3] <= CROP_BOX[3]
        ):
            raise ValueError(f"Crop would cut visible pixels: {bounds}")
        cropped = img.crop(CROP_BOX)
        return cropped.resize((self.width, self.height), Image.Resampling.LANCZOS)


def natural_key(path: Path) -> list:
    return [int(p) if p.isdigit() else p.lower() for p in re.split(r"(\d+)", path.name)]


def load_custom_frames(directory: Path) -> list[Path]:
    if not directory.is_dir():
        return []
    return sorted(
        (p for p in directory.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_SUFFIXES),
        key=natural_key,
    )


def prepare_custom_image(path: Path, config: dict) -> Image.Image:
    width, height = int(config["width"]), int(config["height"])
    background = tuple(int(config["background"][i : i + 2], 16) for i in (1, 3, 5))
    with Image.open(path) as source:
        source.load()
        image = source.convert("RGBA")
        scale = min(width / image.width, height / image.height)
        resized = image.resize(
            (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
            Image.Resampling.LANCZOS,
        )
        canvas = Image.new("RGB", (width, height), background)
        canvas.paste(
            resized.convert("RGB"),
            ((width - resized.width) // 2, (height - resized.height) // 2),
        )
    return canvas


class CustomArtwork:
    def __init__(self, config: dict):
        custom = config.get("custom", {})
        intro_dir = (ROOT / custom.get("intro_dir", "artwork/custom/intro")).resolve()
        loop_dir = (ROOT / custom.get("loop_dir", "artwork/custom/loop")).resolve()
        intro = load_custom_frames(intro_dir)
        loop = load_custom_frames(loop_dir)
        if not intro:
            raise ValueError(
                f"No custom intro images in {intro_dir}. "
                "Add PNG/JPG/WebP files, or set mode to 'generated'."
            )
        if not loop:
            loop = [intro[-1]]
        self.width = int(config["width"])
        self.height = int(config["height"])
        self.fps = int(config["fps"])
        self.intro = intro
        self.loop = loop
        self.images = {p: prepare_custom_image(p, config) for p in {*intro, *loop}}
        self.meta = {
            "mode": "custom",
            "canvas": [self.width, self.height],
            "fps": self.fps,
            "part0_frames": len(intro),
            "part1_frames": len(loop),
            "intro_images": [p.name for p in intro],
            "loop_images": [p.name for p in loop],
            "fit": "contain (aspect preserved, centered, background filled)",
            "copyright_note": "User-supplied custom artwork. Verify you have redistribution rights.",
        }

    def frame(self, part: int, index: int) -> Image.Image:
        files = self.intro if part == 0 else self.loop
        return self.images[files[index % len(files)]]


def write_animation(artwork, config: dict, output: Path) -> dict:
    width, height, fps = int(config["width"]), int(config["height"]), int(config["fps"])
    desc = (
        f"{width} {height} {fps}\n"
        f"p 1 0 part0 {config['background']}\n"
        f"p 0 0 part1 {config['background']}\n"
    ).encode("ascii")
    counts = [
        int(artwork.meta["part0_frames"]),
        int(artwork.meta["part1_frames"]),
    ]
    with zipfile.ZipFile(output, "w") as archive:
        put(archive, "desc.txt", desc, stored=True)
        for part, count in enumerate(counts):
            for index in range(count):
                data = io.BytesIO()
                artwork.frame(part, index).save(data, format="PNG", compress_level=8)
                put(archive, f"part{part}/{index:05d}.png", data.getvalue(), stored=True)
    result = dict(artwork.meta)
    result["animation_sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
    result["animation_bytes"] = output.stat().st_size
    result["desc"] = desc.decode("ascii")
    return result


def write_preview(artwork, config: dict, metadata: dict, version: str) -> None:
    width, height = int(config["width"]), int(config["height"])
    display = (1080, 2400)
    preview_size = (270, 600)
    intro_count = int(metadata["part0_frames"])
    loop_count = int(metadata["part1_frames"])
    indices = [(0, i) for i in range(0, intro_count, max(1, intro_count // 30))]
    indices += [(1, i) for _ in range(2) for i in range(0, loop_count, max(1, loop_count // 30))]
    frames = []
    for part, index in indices:
        phone = Image.new("RGB", display)
        phone.paste(artwork.frame(part, index), ((display[0] - width) // 2, (display[1] - height) // 2))
        frames.append(phone.resize(preview_size, Image.Resampling.LANCZOS))
    gif = ARTIFACTS / f"HarmonyOS-BootAnimation-v{version}-preview.gif"
    durations = [60 if i % 3 == 0 else 70 for i in range(len(frames))]
    frames[0].save(
        gif,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=False,
    )
    phone = Image.new("RGB", display)
    phone.paste(artwork.frame(1, 0), ((display[0] - width) // 2, (display[1] - height) // 2))
    phone.resize((360, 800), Image.Resampling.LANCZOS).save(
        ARTIFACTS / f"HarmonyOS-BootAnimation-v{version}-poster.png"
    )


def assemble(metadata: dict, version: str) -> Path:
    module = ROOT / "module"
    required = [
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
    for name in required:
        if not (module / name).is_file():
            raise FileNotFoundError(module / name)
    output = ARTIFACTS / f"HarmonyOS-BootAnimation-v{version}.zip"
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in required:
            raw = (module / name).read_bytes()
            if raw.startswith(b"\xef\xbb\xbf") or b"\r" in raw:
                raise ValueError(f"{name}: requires UTF-8 without BOM and LF line endings")
            put(
                archive,
                name,
                raw,
                executable=name.endswith(".sh") or name.endswith("/update-binary"),
            )
        put(archive, "payload/bootanimation.zip", (ASSETS / "bootanimation.zip").read_bytes())
        put(archive, "common/payload.sha256", (metadata["animation_sha256"] + "\n").encode("ascii"))
        put(archive, "common/artwork.json", (ASSETS / "artwork.json").read_bytes())
        put(archive, "README.md", (ROOT / "README.md").read_bytes())
        put(archive, "LICENSE", (ROOT / "LICENSE").read_bytes())
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=str(ROOT / "config.json"))
    parser.add_argument("--mode", choices=("generated", "custom"))
    parser.add_argument("--font", help="TTF/OTF used only by generated mode")
    args = parser.parse_args()

    config = read_config(Path(args.config))
    if args.mode:
        config["mode"] = args.mode
    version = module_version()
    BUILD.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    ARTIFACTS.mkdir(parents=True, exist_ok=True)

    artwork = (
        CustomArtwork(config)
        if config["mode"] == "custom"
        else GeneratedArtwork(font_path(args.font), config)
    )
    metadata = write_animation(artwork, config, ASSETS / "bootanimation.zip")
    write_preview(artwork, config, metadata, version)
    (ASSETS / "artwork.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    output = assemble(metadata, version)
    print(json.dumps(metadata, ensure_ascii=False, indent=2))
    print(f"MODULE={output}")
    print(f"MODULE_SHA256={hashlib.sha256(output.read_bytes()).hexdigest()}")
    print(f"MODULE_BYTES={output.stat().st_size}")


if __name__ == "__main__":
    main()
