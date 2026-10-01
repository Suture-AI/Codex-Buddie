#!/usr/bin/env python3
"""Enable/restore Buddie for existing Codex CLI and Orca CUA registrations."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import subprocess
import sys
import tempfile
import time


def location(home):
    return home / '.local/share/codex-buddie'


def atomic(path, content, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.buddie-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def section(text):
    matches = list(re.finditer(r'^\[mcp_servers\.cua\][ \t]*\r?\n.*?(?=^\[|\Z)', text, re.M | re.S))
    if len(matches) != 1:
        raise ValueError('Expected one existing [mcp_servers.cua] registration')
    return matches[0]


def changed_section(before, entry):
    # Preserve timeouts, enabled tools, comments and every unrelated section.
    # Refuse multiline values instead of risking a partial TOML rewrite.
    command = re.findall(r'^command[ \t]*=.*$', before, re.M)
    args = re.findall(r'^args[ \t]*=.*$', before, re.M)
    if len(command) != 1 or len(args) != 1 or not re.fullmatch(r'args\s*=\s*\[.*\]\s*(?:#.*)?', args[0]):
        raise ValueError('CUA command/args must use single-line TOML values')
    after = re.sub(r'^command[ \t]*=.*$', lambda _: 'command = "/usr/bin/python3"', before, flags=re.M)
    return re.sub(r'^args[ \t]*=.*$', lambda _: 'args = ' + json.dumps([str(entry), 'launch']), after, flags=re.M)


def configs(home):
    return [p for p in [home / '.codex/config.toml',
            *sorted((home / 'Library/Application Support/orca/codex-accounts').glob('*/home/config.toml')),
            home / 'Library/Application Support/orca/codex-runtime-home/home/config.toml'] if p.is_file()]


def official_runtime(home):
    root = home / '.codex/plugins/cache/openai-bundled/unified-computer-use'
    candidates = sorted(root.glob('*/.mcp.json'), key=lambda p: tuple(int(v) for v in p.parent.name.split('.')), reverse=True)
    for path in candidates:
        server = json.loads(path.read_text()).get('mcpServers', {}).get('cua_repl', {})
        if server.get('enabled') and Path(server.get('command', '')).is_file() and server.get('args') and Path(server['args'][0]).is_file():
            return path, server
    raise ValueError('No enabled official Computer Use runtime is installed')


def validate_service(service):
    info = plistlib.loads((service / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != 'ai.suture.codex-buddie.runtime':
        raise ValueError('Use an isolated, prepared Buddie service')
    if not (service / 'Contents/Frameworks/libBuddie.dylib').is_file():
        raise ValueError('Buddie renderer is missing')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(service)], check=True)


def enable(home, service):
    root = location(home); state_path = root / 'terminal-state.json'
    if state_path.exists() and json.loads(state_path.read_text()).get('active'):
        raise ValueError('Already enabled; disable before changing the service')
    service = service.expanduser().resolve(strict=True)
    validate_service(service)
    official_runtime(home)
    entry = root / 'terminal.py'
    plans = []
    for path in configs(home):
        text = path.read_text(); match = section(text)
        plans.append({'path': str(path), 'before': match[0], 'after': changed_section(match[0], entry), 'text': text, 'mode': path.stat().st_mode & 0o777})
    if not plans:
        raise ValueError('No existing Codex CUA configurations found')
    atomic(entry, Path(__file__).read_text(), 0o700)
    # Save the rollback data before changing any config. It contains only CUA's
    # own stanza, never the rest of a profile (which may contain credentials).
    state = {'active': True, 'service': str(service), 'configs': [{k:v for k,v in p.items() if k != 'text'} for p in plans]}
    atomic(state_path, json.dumps(state, indent=2) + '\n')
    applied = []
    try:
        for plan in plans:
            path = Path(plan['path'])
            if path.read_text() != plan['text']:
                raise ValueError('Config changed concurrently: ' + str(path))
            atomic(path, plan['text'].replace(plan['before'], plan['after'], 1), plan['mode'])
            applied.append(plan)
    except BaseException:
        for plan in reversed(applied):
            path = Path(plan['path']); current = path.read_text()
            if section(current)[0] == plan['after']:
                atomic(path, current.replace(plan['after'], plan['before'], 1), plan['mode'])
        state['active'] = False
        atomic(state_path, json.dumps(state, indent=2) + '\n')
        raise
    return {'active': True, 'profiles': len(plans), 'service': str(service), 'restart_required': True}


def disable(home):
    path = location(home) / 'terminal-state.json'
    state = json.loads(path.read_text())
    if not state['active']:
        return {'active': False, 'profiles_restored': 0}
    # Validate all stanzas before restoring any. Preserve unrelated later edits.
    plans = []
    for plan in state['configs']:
        target = Path(plan['path']); current = target.read_text()
        current_section = section(current)[0]
        if current_section == plan['before']:
            continue # Resume safely if an earlier restore hit an I/O failure.
        if current_section != plan['after']:
            raise ValueError('CUA config changed since activation; review before restoring: ' + str(target))
        plans.append((target, current.replace(plan['after'], plan['before'], 1), plan['mode']))
    for target, content, mode in plans:
        atomic(target, content, mode)
    state['active'] = False
    atomic(path, json.dumps(state, indent=2) + '\n')
    return {'active': False, 'profiles_restored': len(plans)}


def launch(home):
    state = json.loads((location(home) / 'terminal-state.json').read_text())
    if not state['active']:
        raise ValueError('Buddie is disabled; restart the terminal session')
    service = Path(state['service'])
    validate_service(service)
    _, server = official_runtime(home)
    env = os.environ.copy(); env.update(server.get('env', {}))
    # Keep official browser providers, trusted services and permission metadata.
    # Only the native process/socket is replaced with the prepared service.
    env.pop('NODE_REPL_HOST_SERVICES_PIPE_PATH', None)
    env.pop('BUDDIE_CAPTURE_DIRECTORY', None)
    env['SKY_CUA_SERVICE_PATH'] = str(service)
    children = []
    def stop(signum, frame):
        raise SystemExit(128 + signum)
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, stop)
    with tempfile.TemporaryDirectory(prefix='codex-buddie-', dir='/tmp') as directory:
        socket = Path(directory) / 'cua.sock'
        env['SKY_CUA_SERVICE_NATIVE_PIPE_PATH'] = str(socket)
        try:
            native = subprocess.Popen([str(service / 'Contents/MacOS/SkyComputerUseService')], env=env, stdout=sys.stderr, start_new_session=True)
            children.append(native)
            deadline = time.monotonic() + 10
            while not socket.exists():
                if native.poll() is not None:
                    raise RuntimeError('Buddie native service exited')
                if time.monotonic() >= deadline:
                    raise TimeoutError('Buddie native socket did not start')
                time.sleep(.05)
            client = subprocess.Popen([server['command'], *server['args']], env=env, start_new_session=True)
            children.append(client)
            return client.wait()
        finally:
            for child in reversed(children):
                try:
                    os.killpg(child.pid, signal.SIGTERM)
                except ProcessLookupError:
                    continue
                try:
                    child.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL); child.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['enable', 'disable', 'status', 'launch'])
    parser.add_argument('--service', type=Path)
    args = parser.parse_args(); home = Path.home()
    if args.action == 'enable':
        if args.service is None: parser.error('enable requires --service')
        result = enable(home, args.service)
    elif args.action == 'disable': result = disable(home)
    elif args.action == 'launch': return launch(home)
    else:
        path = location(home) / 'terminal-state.json'
        state = json.loads(path.read_text()) if path.exists() else {}
        result = {k:state.get(k) for k in ['active', 'service']}
        result['profiles'] = len(state.get('configs', []))
    print(json.dumps(result, indent=2))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print('Buddie: ' + str(error), file=sys.stderr)
        sys.exit(1)
