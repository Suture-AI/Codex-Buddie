# Matching-team native IPC experiment

The ad-hoc service copy had reported `SkyIPCRequirement.Error.teamNotFound`.
Read-only inspection found `SkyIPCRequirement.isFromSameTeam`, and this Mac had
an existing Apple Development identity. This justified testing properly signed
isolated copies without changing authentication code or macOS permissions.

## Result

**Still blocked.** The copied service boots and loads the Buddie dylib. MCP
initialization succeeds. Service, Node and node_repl signatures have the same
nonempty team identifier. The official CUA native app inventory nevertheless
returns zero apps with `Sky Computer Use native pipe startup failed`.

Repeating with eight seconds of startup grace did not resolve it. The captured
stderr no longer contains `teamNotFound`, but that absence does not prove an
authentication check passed. The precise connection rejection remains unknown.
No native cursor replacement, permissions, app observations or clicks were reached.
See [the redacted evidence](evidence/development-signing.json).

The service was version `26.924.1001281`, SHA-256
`d4b1775138342c0df8e9451df3c23dda3fdef44c4ade50a2de382c188cf61b54`.
Its original deep/strict signature passed. Known cursor class/style markers are
present. The dylib load command fits zero-filled header padding, changes 53 bytes
ending at offset 9997, and leaves executable code beginning at 10176 in place.
This is an inspected research entry, not a compatibility certification or a
verification of this version's cursor geometry.

## Reproduce locally

Use an existing local Apple development signing identity. Nothing here creates
or exports a key. Vendor runtime copies stay local and are not repository assets.

```sh
./scripts/build.sh
python3 scripts/development-runtime.py \
  --runtime '/path/to/official/cua_node' \
  --destination '.build/native-development/runtime' \
  --signing-identity "$BUDDIE_SIGNING_IDENTITY"
python3 scripts/prepare.py prepare \
  --service '/path/to/Codex Computer Use.app' \
  --destination '.build/native-development/Codex Buddie Runtime.app' \
  --signing-identity "$BUDDIE_SIGNING_IDENTITY"
python3 scripts/prepare.py launcher \
  --runtime '.build/native-development/runtime' \
  --service '.build/native-development/Codex Buddie Runtime.app' \
  --output '.build/native-development/codex-buddie-cua'
python3 scripts/probe-native.py \
  --launcher '.build/native-development/codex-buddie-cua' \
  --report '.build/native-development/probe.json' --startup-grace 8
```

Destinations must be new. The runtime uses an APFS copy-on-write clone, then signs
its local Node/node_repl and Darwin native libraries with hardened runtime.
OpenAI-specific team, app-group and keychain entitlements are omitted from these
new identities. Original executable hashes are checked after preparation.
The service copy includes our character assets; its replacement factory loads
bundled Pip before any studio selection override. The IPC evidence above used
the earlier renderer built at the start of the experiment, before that packaging
follow-up; the probe records its dylib digest.

The probe uses the official initialized CUA REPL, saves only counts/errors rather
than an application inventory, refuses interactive permission requests, and stops
the isolated process group. No installed OpenAI files, authentication instructions,
MCP configuration, TCC database or system security settings are edited.
