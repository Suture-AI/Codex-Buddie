#!/usr/bin/env python3
"""Clone an installed official CUA runtime for a same-team signing experiment.

Local research only. Never modifies the source, registers a service, grants
permissions, or redistributes vendor code. Requires an existing Apple signing
identity. Authentication and native permission checks remain intact.
"""
import argparse
import hashlib
from pathlib import Path
import plistlib
import subprocess
import tempfile
import json


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clone_runtime(source, destination, identity):
    source = source.expanduser().resolve(strict=True)
    destination = destination.expanduser().resolve()
    if destination.exists() or source == destination or source in destination.parents:
        raise ValueError('Destination must be new and outside the original runtime.')
    executables = [Path('bin/node'), Path('bin/node_repl')]
    for rel in executables:
        subprocess.run(['codesign', '--verify', '--strict', str(source / rel)], check=True)
    original = {str(p): digest(source / p) for p in executables}
    destination.parent.mkdir(parents=True, exist_ok=True)
    # APFS copy-on-write, including existing node_modules. No fresh install.
    subprocess.run(['cp', '-cR', str(source), str(destination)], check=True)
    candidates = [destination / rel for rel in executables]
    candidates += sorted(destination.rglob('*.node')) + sorted(destination.rglob('*.dylib'))
    magic = {b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'}
    signed = []
    with tempfile.TemporaryDirectory(prefix='buddie-signing-') as temporary:
        for path in candidates:
            resolved = path.resolve()
            if destination not in resolved.parents:
                raise ValueError('Refusing to sign a symlink outside the copied runtime.')
            with path.open('rb') as stream:
                if stream.read(4) not in magic:
                    continue
            rel = path.relative_to(destination)
            original.setdefault(str(rel), digest(source / rel))
            output = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(path)], capture_output=True, check=True)
            entitlements = plistlib.loads(output.stdout) if output.stdout.strip() else {}
            # Team-bound OpenAI entitlements are not ours to retain.
            for key in ['com.apple.application-identifier', 'com.apple.developer.team-identifier',
                        'com.apple.security.application-groups', 'keychain-access-groups']:
                entitlements.pop(key, None)
            plist = Path(temporary) / 'entitlements.plist'
            plist.write_bytes(plistlib.dumps(entitlements))
            subprocess.run(['codesign', '--force', '--sign', identity, '--options', 'runtime',
                            '--timestamp=none', '--entitlements', str(plist), str(path)], check=True)
            subprocess.run(['codesign', '--verify', '--strict', str(path)], check=True)
            signed.append(str(rel))
    if any(digest(source / rel) != sha for rel, sha in original.items()):
        raise RuntimeError('An original runtime file changed during preparation.')
    report = {'status': 'signed-not-live-verified', 'source': str(source), 'copy': str(destination),
              'original_sha256': original, 'signed_paths': signed, 'originals_unchanged': True,
              'permission_changes': False, 'authentication_changes': False}
    (destination.parent / 'development-runtime.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Prepared {len(signed)} local signed executables/libraries; originals verified unchanged.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--signing-identity', required=True)
    args = parser.parse_args()
    clone_runtime(args.runtime, args.destination, args.signing_identity)
