#!/usr/bin/env python3
"""Prepare an isolated local copy. Never edits the source app or Codex config."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import shlex
import shutil
import subprocess
import sys
from macho import inject

ROOT = Path(__file__).resolve().parents[1]


def prepare(service, destination):
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("The native experiment currently requires an Apple Silicon Mac")
    service = service.expanduser().resolve(strict=True)
    destination = destination.expanduser().resolve()
    if destination.exists() or destination == service or service in destination.parents:
        raise ValueError("Destination must be new and outside the original app")
    executable = service / "Contents/MacOS/SkyComputerUseService"
    original = executable.read_bytes()
    digest = hashlib.sha256(original).hexdigest()
    supported = json.loads((ROOT / "compatibility/macos-arm64.json").read_text())
    if digest not in supported:
        raise ValueError(f"Unverified native build ({digest}). Source is unchanged. Inspect this build before adding compatibility.")
    library = ROOT / ".build/Codex Buddie Lab.app/Contents/Frameworks/libBuddie.dylib"
    if not library.is_file():
        raise ValueError("Run ./scripts/build.sh first")
    # Validate all binary changes before creating the destination.
    modified = inject(original)
    with (service / "Contents/Info.plist").open("rb") as f:
        info = plistlib.load(f)
    if info.get("CFBundleIdentifier") != "com.openai.sky.CUAService":
        raise ValueError("Unexpected service identity")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(service)], check=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(service, destination, symlinks=True)
    (destination / "Contents/MacOS/SkyComputerUseService").write_bytes(modified)
    info["CFBundleIdentifier"] = "ai.suture.codex-buddie.runtime"
    info["CFBundleName"] = "Codex Buddie Runtime"
    info["CFBundleDisplayName"] = "Codex Buddie Runtime"
    with (destination / "Contents/Info.plist").open("wb") as f:
        plistlib.dump(info, f)
    frameworks = destination / "Contents/Frameworks"
    frameworks.mkdir(exist_ok=True)
    shutil.copy2(library, frameworks / "libBuddie.dylib")
    # The local copy has a new ad-hoc signature, not OpenAI's identity or grants.
    subprocess.run(["codesign", "--force", "--sign", "-", "--options", "0", "--timestamp=none", str(destination)], check=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(destination)], check=True)
    if hashlib.sha256(executable.read_bytes()).hexdigest() != digest:
        raise RuntimeError("Source changed during preparation; investigate before proceeding")
    report = {"source": str(service), "source_sha256": digest, "copy": str(destination),
              "status": "prepared-not-live-verified", "compatibility": supported[digest]}
    (destination.parent / "preparation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Prepared: {destination}\nOriginal app verified unchanged. Native operation still needs testing.")


def launcher(runtime, service, output):
    runtime = runtime.expanduser().resolve(strict=True)
    service = service.expanduser().resolve(strict=True)
    with (service / "Contents/Info.plist").open("rb") as f:
        if plistlib.load(f).get("CFBundleIdentifier") != "ai.suture.codex-buddie.runtime":
            raise ValueError("Launcher requires an isolated Buddie service copy")
    modules = runtime / "lib/node_modules"
    values = {"NODE_REPL_NODE_PATH": runtime / "bin/node", "NODE_REPL_NODE_MODULE_DIRS": modules,
              "NODE_REPL_TRUSTED_CODE_PATHS": runtime, "CUA_REPL_NODE_REPL_PATH": runtime / "bin/node_repl",
              "SKY_CUA_SERVICE_PATH": service}
    entry = modules / "@oai/cua-repl/bin/cua-repl.mjs"
    for p in [runtime / "bin/node", runtime / "bin/node_repl", entry, service / "Contents/MacOS/SkyComputerUseService"]:
        if not p.is_file():
            raise ValueError(f"Missing official runtime component: {p}")
    if output.exists():
        raise ValueError("Launcher already exists; choose a new output path")
    lines = ["#!/bin/sh", "set -eu", "unset NODE_REPL_HOST_SERVICES_PIPE_PATH SKY_CUA_SERVICE_NATIVE_PIPE_PATH",
             "unset NODE_REPL_JS_BANNER NODE_REPL_TOOL_OVERRIDES NODE_REPL_TRUSTED_SERVICES"]
    lines += [f"export {k}={shlex.quote(str(v))}" for k, v in values.items()]
    lines += ["export CUA_REPL_ENABLED_SURFACES=computer", "export NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS=5000",
              'buddie_run_dir=$(mktemp -d /tmp/codex-buddie.XXXXXXXX)',
              'export SKY_CUA_SERVICE_NATIVE_PIPE_PATH="$buddie_run_dir/cua.sock"',
              'buddie_service_pid=; buddie_repl_pid=',
              'cleanup() {',
              '  trap - EXIT HUP INT TERM',
              '  [ -z "$buddie_repl_pid" ] || kill "$buddie_repl_pid" 2>/dev/null || true',
              '  [ -z "$buddie_service_pid" ] || kill "$buddie_service_pid" 2>/dev/null || true',
              '  rm -f "$buddie_run_dir/cua.sock"',
              '  rmdir "$buddie_run_dir" 2>/dev/null || true',
              '}',
              'trap cleanup EXIT', 'trap "exit 130" HUP INT TERM',
              f'{shlex.quote(str(service / "Contents/MacOS/SkyComputerUseService"))} >&2 &',
              'buddie_service_pid=$!',
              'buddie_attempt=0',
              'while [ ! -S "$SKY_CUA_SERVICE_NATIVE_PIPE_PATH" ]; do',
              '  kill -0 "$buddie_service_pid" 2>/dev/null || { echo "Buddie native service exited" >&2; exit 1; }',
              '  buddie_attempt=$((buddie_attempt + 1))',
              '  [ "$buddie_attempt" -lt 100 ] || { echo "Buddie native socket did not start" >&2; exit 1; }',
              '  sleep 0.1', 'done',
              f'{shlex.quote(str(runtime / "bin/node"))} {shlex.quote(str(entry))} <&0 &',
              'buddie_repl_pid=$!', 'wait "$buddie_repl_pid"']
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x") as f:
        f.write("\n".join(lines) + "\n")
    output.chmod(0o755)
    print(f"Launcher: {output.resolve()}\nNo Codex settings were changed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prepare")
    p.add_argument("--service", required=True, type=Path)
    p.add_argument("--destination", type=Path, default=ROOT / ".build/native/Codex Buddie Runtime.app")
    p = sub.add_parser("launcher")
    p.add_argument("--runtime", required=True, type=Path)
    p.add_argument("--service", type=Path, default=ROOT / ".build/native/Codex Buddie Runtime.app")
    p.add_argument("--output", type=Path, default=ROOT / ".build/codex-buddie-cua")
    args = parser.parse_args()
    try:
        if args.command == "prepare": prepare(args.service, args.destination)
        else: launcher(args.runtime, args.service, args.output)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print(f"Buddie: {exc}", file=sys.stderr)
        sys.exit(1)
