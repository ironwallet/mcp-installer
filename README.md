# IronWallet Setup

Desktop installer for the local [IronWallet](https://ironwallet.io/ai) MCP server.
It adds the wallet to Cursor, Claude Code, VS Code, Codex, and Grok so agents
can use a non-custodial hot wallet on this machine.

Download the signed binary for your OS from
[ironwallet.io/ai](https://ironwallet.io/ai) or GitHub Releases.
**Source is not published** — only those binaries.

- https://cdn.ironwallet.io/mcp/download/latest/windows/ironwallet-mcp-installer-1.0.0-amd64.exe
- https://cdn.ironwallet.io/mcp/download/latest/windows/ironwallet-mcp-installer-1.0.0-arm64.exe
- https://cdn.ironwallet.io/mcp/download/latest/mac/ironwallet-mcp-installer-1.0.0-amd64.dmg
- https://cdn.ironwallet.io/mcp/download/latest/mac/ironwallet-mcp-installer-1.0.0-arm64.dmg
- https://cdn.ironwallet.io/mcp/download/latest/linux/ironwallet-mcp-installer-1.0.0-amd64
- https://cdn.ironwallet.io/mcp/download/latest/linux/ironwallet-mcp-installer-1.0.0-arm64
- https://cdn.ironwallet.io/mcp/download/latest/checksums.txt
- https://cdn.ironwallet.io/mcp/download/latest/checksums.txt.sig

The installer is a one-shot GUI. It does not copy itself onto the system, does
not stay resident, and does not phone home. What it may write is listed in
[SECURITY.md](SECURITY.md).

Version: see [`VERSION`](VERSION). Changes: [`CHANGELOG.md`](CHANGELOG.md).

The MCP server is not inside this installer. Cursor and VS Code get
`npx -y @ironwallet/mcp-server`. The wizard prefetches that package into the
npx cache (install only, the wallet server is not started) so Claude’s first
MCP handshake does not stall on a download. Claude, Codex, and Grok
also install the marketplace plugin from
[github.com/ironwallet/ironwallet-agent-kit](https://github.com/ironwallet/ironwallet-agent-kit).

## What it does

1. After you pick environments, checks for Node.js 20+. If it is missing, installs
   it via `winget` / Homebrew / the distro package manager (no `curl | sh`). If
   that fails, opens the official Node.js download page; Retry re-checks PATH.
2. Detects Cursor, Claude Code, VS Code, Codex, and Grok. Found apps are
   pre-checked. Missing ones show a Download link instead of a checkbox.
3. Install MCP stays disabled until at least one found app is selected.
4. Asks selected GUI apps to quit, prefetches `@ironwallet/mcp-server` into
   the npx cache, then writes configs. One agent failure does not abort the
   others. A failed prefetch is a hint, not a hard stop.
5. Cursor and VS Code: merge MCP JSON (does not wipe other servers).
6. Claude Code: Git + `claude` CLI if needed, then
   `claude plugin marketplace add ironwallet/ironwallet-agent-kit` and
   `claude plugin install ironwallet-mcp@ironwallet --scope user`.
7. Codex (if the CLI is present):
   `codex plugin marketplace add ironwallet/ironwallet-agent-kit` and
   `codex plugin add ironwallet-mcp@ironwallet`.
8. Grok (if `grok` is on PATH):
   `grok plugin marketplace add ironwallet/ironwallet-agent-kit` and
   `grok plugin install ironwallet-mcp --trust`.

Chat is never used as an install channel. Missing CLIs get a Download button.

## Supported platforms

Releases include **amd64 and arm64** for Windows, Linux, and macOS.

| File | Arch |
|------|------|
| `ironwallet-setup-windows-amd64.exe` / `windows-arm64.exe` | both |
| `ironwallet-setup-linux-amd64` / `linux-arm64` | both |
| `ironwallet-setup-macos-amd64.dmg` / `arm64.dmg` | both |

The installer does not declare a minimum OS version. Practical floor:

| OS | Auto Node.js | Notes |
|----|----------------|--------|
| Windows | `winget` (`OpenJS.NodeJS.LTS`) — typically Windows 10 1709+ / Windows 11 | No console window |
| macOS | Homebrew `node` | Signed/notarized `.app` in a dmg |
| Linux | `apt-get` or `dnf` (`nodejs`, `npm`), via `pkexec` when present | X11 or Wayland |

No zypper/pacman path: install Node.js 20+ yourself, then Retry.

### Environments

| Environment | What the installer configures | First-run Open |
|-------------|-------------------------------|----------------|
| Cursor | Merge `~/.cursor/mcp.json` | Deeplink with the starter prompt |
| Visual Studio Code | Merge user `mcp.json` | Copilot Chat URI with the starter prompt |
| Claude Code | `claude` CLI plugins, `--scope user` | `claude://` new-chat URI |
| Codex | `codex` CLI plugins | none (CLI) |
| Grok | `grok` CLI plugins, `--trust` | none (CLI) |

Detection looks at PATH, well-known app paths, and `~/.cursor` / `~/.claude` /
`~/.codex` / `~/.grok`. Claude Desktop may be detected as present, but the
installer never writes `claude_desktop_config.json` — only the Claude Code CLI
plugin flow.

If the environment is already configured: Cursor/VS Code **overwrite only** the
`ironwallet` key; other MCP servers stay. Claude/Codex/Grok treat
already/exists/duplicate from the CLI as success. Node.js 20+ already on PATH
is left as-is (no pin, no upgrade). The `npx` entry does not pin a package
version — the next agent start may pull latest `@ironwallet/mcp-server`.

## Config paths

Parent directories are created with mode `0755` only when a file is written.

| OS | Cursor | VS Code |
|----|--------|---------|
| Windows | `%USERPROFILE%\.cursor\mcp.json` | `%APPDATA%\Code\User\mcp.json` |
| macOS | `~/.cursor/mcp.json` | `~/Library/Application Support/Code/User/mcp.json` |
| Linux | `~/.cursor/mcp.json` | `$XDG_CONFIG_HOME/Code/User/mcp.json` or `~/.config/Code/User/mcp.json` |

On Windows, if `APPDATA` is empty, VS Code uses
`%USERPROFILE%\AppData\Roaming\Code\User\mcp.json`.

Entry written (Cursor, and VS Code when the file already uses `mcpServers`):

```json
{
  "mcpServers": {
    "ironwallet": {
      "command": "npx",
      "args": ["-y", "@ironwallet/mcp-server"]
    }
  }
}
```

New VS Code files use `servers` plus `"type": "stdio"` on that entry. If a VS
Code file already has `mcpServers` and no `servers`, the installer keeps
`mcpServers` and does not invent a `servers` object.

Invalid JSON is an error; the file is not replaced with an empty document.

Claude / Codex / Grok configs are written by those CLIs (typically under
`~/.claude`, `~/.codex`, `~/.grok`). This installer does not edit those files
directly.

## First-run prompt

On the done screen, **Open** (and **Finish**, which opens every successfully
installed GUI) prefills this text. It is not written into MCP JSON or plugin
files.

```
Using the IronWallet MCP tools, show what you can do: list my wallets and balances, and briefly explain how transfers, swaps, and deposit QR codes work from this chat.
```

The prompt names wallets, balances, transfers, swaps, and deposit QR codes. It
does not mention a seed, recovery phrase, private key, or mnemonic, and it does
not ask the agent to sign or export secrets.

## Uninstall

There is **no** uninstaller, silent flag, or reverse wizard. Close the
installer and delete the binary (or the macOS `.app`) if you still have it.

The installer never removes other people’s MCP servers. To undo IronWallet
only:

1. **Cursor** — in `mcp.json` (path above), delete the `ironwallet` key from
   `mcpServers`. Delete the file if it is otherwise empty.
2. **VS Code** — same key in `servers` or `mcpServers` in the user `mcp.json`.
3. **Claude Code** — uninstall `ironwallet-mcp@ironwallet` with the current
   `claude plugin` command (the installer does not invoke uninstall). Remove the
   marketplace `ironwallet/ironwallet-agent-kit` if you want a full rollback.
4. **Codex** — remove `ironwallet-mcp@ironwallet` with the current
   `codex plugin` command.
5. **Grok** — remove `ironwallet-mcp` with the current `grok plugin` command.

Left on purpose, because the installer does not record whether it installed
them: Node.js, Git, global `@anthropic-ai/claude-code`, other MCP servers, and
any `~/.cursor` / `~/.claude` / `~/.codex` / `~/.grok` directory that already
existed or that a CLI created.

## Known limitations

- **Interrupted install.** No checkpoint. Re-run the installer: Node.js 20+ is
  skipped, JSON upsert is idempotent for the `ironwallet` key, plugin add
  treats “already present” as success. A kill while `mcp.json` is being written
  can leave a truncated file. A kill during winget/brew/apt leaves whatever
  that tool already committed. The only in-UI resume is **Retry** on the failed
  Node.js step in the same window (the environment selection is kept in
  memory).
- **Running clients.** Config is not pushed into a live process. The installer
  asks selected GUIs to quit (`WM_CLOSE` / `osascript quit` / `pkill -TERM -x`)
  and waits 800 ms. The done screen says to open a new chat and reload the app
  if it was still open. That reload is not guaranteed.
- **Restricted machines.** No proxy settings. winget, Homebrew, apt/dnf, and
  npm use the ambient environment. Writing `mcp.json` in the user profile
  usually works without admin; auto Node.js/Git often does not. No winget on
  Windows → Node.js step fails and opens [nodejs.org/en/download](https://nodejs.org/en/download).
  GitHub/npm must be reachable for plugins and for later `npx`. UAC / `pkexec`
  are the only elevation prompts; there is no silent enterprise install.

## Docs shipped with the binaries

| File | Audience |
|------|----------|
| [SECURITY.md](SECURITY.md) | System impact, network, privileges, leftovers |
| [CHANGELOG.md](CHANGELOG.md) | User-facing changes per release |

## License

Apache License 2.0. Copyright 2026 INWAY AG. See [LICENSE](LICENSE) and
[NOTICE](NOTICE).

The installer embeds Manrope fonts under the SIL Open Font License. That
license applies to the fonts only, not to the installer.
