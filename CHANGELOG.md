# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-09-03

Setup notes and Check again on the select screen. Open prompt now reads the kit skill first.

## [1.1.2] - 2026-09-01

Codex is now labeled ChatGPT in the installer.

## [1.1.1] - 2026-09-01

The done screen now offers Open for Codex when the ChatGPT desktop app is installed: it opens a new chat with the first-run prompt prefilled.

## [1.1.0] - 2026-09-01

Claude Desktop chat now gets the IronWallet MCP: when the desktop app is installed, the `ironwallet` entry is merged into `claude_desktop_config.json` (classic and Microsoft Store installs on Windows, `Claude.app` on macOS) with an absolute `npx` path; the chat picks it up after a full restart of Claude. Claude is reported installed when either the CLI plugin or the chat config succeeded, and Open starts a chat when only the chat was configured.

Codex install no longer requires `codex` on PATH: the installer falls back to the CLI bundled with the ChatGPT desktop app (the user-cache copy on Windows, the app bundle or `~/.local/bin/codex` on macOS), so the plugin now really lands in `~/.codex` for desktop-only installs that previously showed success without installing anything.

A UTF-8 BOM in an existing `mcp.json` / `claude_desktop_config.json` (Notepad and older PowerShell write one) no longer fails the config merge; the file is saved back without the BOM.

## [1.0.2] - 2026-09-01

Build macOS binaries with `MACOSX_DEPLOYMENT_TARGET=12.0` so Sonoma can launch them. Claude and Codex download buttons open the current product pages.

## [1.0.1] - 2026-09-01

Install the Claude Code CLI into `~/.local` when the npm global prefix is not writable.

## [1.0.0] - 2026-08-27

Initial release.

[Unreleased]: https://github.com/ironwallet/mcp-installer/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/ironwallet/mcp-installer/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/ironwallet/mcp-installer/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/ironwallet/mcp-installer/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/ironwallet/mcp-installer/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/ironwallet/mcp-installer/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/ironwallet/mcp-installer/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/ironwallet/mcp-installer/releases/tag/v1.0.0
