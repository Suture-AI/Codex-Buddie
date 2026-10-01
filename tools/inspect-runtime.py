#!/usr/bin/env python3
"""Read-only implementation fingerprint; does not extract or change app code.

Outputs filenames, offsets and symbol presence, never credentials or source code.
This is a research tool, not a dependency of the Buddie app.
"""
import argparse
import hashlib
import json
import plistlib
import struct
from pathlib import Path


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def entries(node, prefix=""):
    for name, value in node.get("files", {}).items():
        path = prefix + name
        if "files" in value:
            yield from entries(value, path + "/")
        else:
            yield path, value


def inspect(app, helper):
    with (app / "Contents/Info.plist").open("rb") as stream:
        version = plistlib.load(stream)
    archive = app / "Contents/Resources/app.asar"
    markers = ["setRemoteHostedPIPContentComputerUseCursorLocationHandler",
               "avatar-overlay-computer-use-cursor-changed", "browser-agent-cursor-overlay",
               "data-browser-agent-cursor", "browserAgentCursorAsset"]
    findings = []
    with archive.open("rb") as stream:
        _, header_size, _, json_size = struct.unpack("<4I", stream.read(16))
        header = json.loads(stream.read(json_size))
        for path, entry in entries(header):
            if not path.endswith(".js") or entry.get("unpacked"):
                continue
            if not path.startswith((".vite/build/", "webview/assets/")):
                continue
            stream.seek(8 + header_size + int(entry["offset"]))
            data = stream.read(entry["size"])
            hits = {marker: data.find(marker.encode()) for marker in markers if marker.encode() in data}
            if hits:
                findings.append({"file": path, "sha256": hashlib.sha256(data).hexdigest(), "markerByteOffsets": hits})
    binary = helper / "Contents/MacOS/SkyComputerUseService"
    with (helper / "Contents/Info.plist").open("rb") as stream:
        helper_info = plistlib.load(stream)
    symbols = ["ComputerUseCursor", "SoftwareCursorStyle", "Computer Use Cursor",
               "computerUseCursorLocationDidChange", "cursorMotionCompletionHandler"]
    binary_data = binary.read_bytes()
    return {"appVersion": version.get("CFBundleShortVersionString"),
            "appBuild": version.get("CFBundleVersion"), "archiveSHA256": digest(archive),
            "helperVersion": helper_info.get("CFBundleShortVersionString"),
            "helperBundleID": helper_info.get("CFBundleIdentifier"),
            "helperSHA256": hashlib.sha256(binary_data).hexdigest(),
            "helperSymbolPresence": {symbol: symbol.encode() in binary_data for symbol in symbols},
            "rendererMarkers": findings}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, default=Path("/Applications/ChatGPT.app"))
    parser.add_argument("--helper", type=Path, default=Path.home() / ".codex/computer-use/Codex Computer Use.app")
    args = parser.parse_args()
    print(json.dumps(inspect(args.app, args.helper), indent=2))
