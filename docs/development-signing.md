# Native IPC signing experiments

**The unmodified official client connected to the development-signed service copy.**
It listed 33 native apps with the Buddie renderer loaded. The earlier experiment
that re-signed both client and service failed: scoped macOS logs now identify
`Sender process is not authenticated` as its rejection.

This clears the connection blocker for the tested combination. It does not yet
prove cursor replacement during a real task. A fresh copy containing the current
Bit renderer reached the official app-access prompt for Codex Buddie Lab; native
observation and clicks remain pending that prompt. See
[the new evidence](evidence/native-ipc.json).

A follow-up at `2026-10-01T05:59:43Z` also passed the 33-app probe with the
Studio-library subscription included. Its log confirms the saved appearance was
prepared in the service process. [That evidence](evidence/cursor-library.json)
covers startup and preference loading, not native cursor rendering or clicks.

## What changed

Both inventory probes used the same isolated service copy, development signature,
renderer and two-second startup grace. Only the client runtime changed:

| Client | Native inventory | Authentication diagnostics |
| --- | --- | --- |
| Copied and re-signed Node/node_repl | Failed, zero apps | 42 sender-authentication rejection events |
| Unmodified official Node/node_repl | Passed, 33 apps | No sender-authentication rejection in the scoped log |

The successful inventory is the positive connection evidence; absence of a log
message alone would not establish success. This does not establish the complete
private authentication rule or compatibility with other runtime versions.

The earlier ad-hoc service reported `SkyIPCRequirement.Error.teamNotFound`.
Giving both sides matching development-team metadata removed that stderr string,
but did not establish successful authentication. Historical results remain in
[the original evidence](evidence/development-signing.json).

The service was version `26.924.1001281`, SHA-256
`d4b1775138342c0df8e9451df3c23dda3fdef44c4ade50a2de382c188cf61b54`.
Its original deep/strict signature passed. The dylib load command fits verified
header padding without moving executable code. This remains an inspected
research build, not a compatibility certification or native geometry validation.

## Reproduce the successful inventory probe

Use an existing local Apple development signing identity and the **unmodified**
official runtime. Nothing here creates or exports a key. Vendor code stays local.

```sh
./scripts/build.sh
python3 scripts/prepare.py prepare \
  --service '/path/to/Codex Computer Use.app' \
  --destination '.build/native-current/Codex Buddie Runtime.app' \
  --signing-identity "$BUDDIE_SIGNING_IDENTITY"
python3 scripts/prepare.py launcher \
  --runtime '/path/to/official/cua_node' \
  --service '.build/native-current/Codex Buddie Runtime.app' \
  --output '.build/native-current/codex-buddie-cua'
python3 scripts/probe-native.py \
  --launcher '.build/native-current/codex-buddie-cua' \
  --report '.build/native-current/probe.json' --startup-grace 2
```

Destinations must be new. Only the service copy and our embedded library are
signed. The copy uses its own bundle identifier, without claiming vendor
app-group/keychain grants. The factory now loads bundled Bit, matching the
Studio's initial choice. The 33-app result used the older renderer retained in
`.build/native-development`; the separate current-Bit attempt reached the app
access prompt. These are distinct evidence scopes.

The probe uses the official initialized CUA REPL, saves counts/errors rather than
an application inventory, refuses interactive permission requests, and stops its
isolated process group. To continue into UI testing, use an MCP client that
supports form elicitation and presents the runtime's ordinary app-access prompt.
Do not synthesize approval or infer an app permission from inventory success.

No installed OpenAI files, authentication checks, MCP configuration, TCC database
or system security settings are edited. Normal macOS permissions may still be
needed for the isolated service; this experiment has not tested that stage.
