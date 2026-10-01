# Buddie in regular Codex and Orca sessions

The local installation now routes `cua` through Buddie in nine existing profiles:
the main Codex home, seven Orca account homes and the shared Orca home. New
sessions load the replacement without a special command or an open Lab window.
An already connected session needs to be restarted or resumed in a new process.

The switch changes only `command` and `args` in each existing `[mcp_servers.cua]`
stanza. It stores the previous stanzas under
`~/.local/share/codex-buddie/terminal-state.json`; the local launcher is
`~/.local/share/codex-buddie/terminal.py`. Both are private to the user.
No app-access grants, authentication rules, sandbox settings or vendor files
are changed. The desktop-owned `cua_repl` key remains untouched.

The launcher reads the installed official manifest to retain its browser and
computer providers, trusted services, instructions and permission handling. It
starts the prepared Buddie service on a private socket, then the unmodified
official CUA runtime. On exit it stops only its own subprocess groups and removes
its temporary socket directory. Diagnostic frame capture is disabled.

Use native computer input to see the character. DOM-based browser actions can draw a separate in-page cursor, but do not move
the native cursor window. See [the browser companion](../browser-extension/README.md). This activation does not resolve the renderer's
remaining [smooth travel, click animation and compatibility gaps](native-layout.md).

## Verification

- Main Codex and active Orca app-server connections exposed `js`, `js_reset` and `turn_ended`; both returned 33 native apps.
- A direct launch of the installed helper confirmed `Native cursor renderer shim loaded` and `Saved cursor appearance prepared`, then returned 33 apps.
- All nine resulting TOML files parsed with their existing enabled tools preserved.
- Six isolated tests passed: preservation of unrelated settings and later edits, refusal to overwrite changed CUA settings, preflight rejection of malformed profiles, rollback on activation failure, prevention of double activation, and recovery from a partial restore failure.

The inventory probes have no model turn and therefore returned the expected
browser error about missing `session_id`/`turn_id`. They verify native startup,
not browser interaction. No app was clicked or granted access in these checks.
Actual native rendering remains covered by the earlier live Lab test.

The prepared service currently remains at its existing local test path. Keep
that copy until disabling the registration; the installer does not redistribute
or download vendor binaries. A clean-machine installer and update compatibility
remain separate work. See the [activation and rollback commands](../README.md#use-buddie-from-your-regular-terminals)
and [verification record](evidence/terminal-activation.json).
