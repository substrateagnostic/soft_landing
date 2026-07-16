# Toolchain Audit — Phase 0 (2026-07-15)

Machine: golem, Windows 11 Pro 10.0.26200 partition (D:\Projects is a
Syncthing share with the Pop!_OS side — `.stfolder` marker present).

## Findings

| Tool | Status | Evidence |
|---|---|---|
| git | ✅ 2.52.0.windows.1 | `git --version` → `git version 2.52.0.windows.1` |
| python | ✅ 3.14.0 (`C:\Python314\python.exe`) | `python --version` → `Python 3.14.0` |
| winget | ✅ present | `Get-Command winget` → `...\WindowsApps\winget.exe` |
| godot | ❌→⏳ installing | `godot`/`Get-Command godot` → NOT FOUND anywhere on C:/D:; no `%APPDATA%\Godot` (editor never ran on this partition). WinGet Links dir on PATH but contains only OCCT.exe. `winget install GodotEngine.GodotEngine` issued. |
| gh | ❌→⏳ installing | `gh` → NOT FOUND. `winget install GitHub.cli` issued. Auth will need producer (browser login) — logged in NEEDS_YOU.md. |
| ffmpeg | ❌→⏳ installing | `ffmpeg` → NOT FOUND. `winget install Gyan.FFmpeg` issued. Needed to transcode Movie Maker MJPEG AVI → mp4 receipts. |
| Meshy key | ❌ unreachable | `D:\Projects\Dead_Attestation\.env` does not exist. un_party_game's `tools/meshy_forge.ps1` defaults to `C:\Users\agall\projects\Dead_Attestation\.env` (a Linux-home-style path) — the key lives on the Pop!_OS side. Producer asked to drop key into `soft_landing\.env` (gitignored). Not needed until Phase 4. |
| Godot MCP | ❌ not configured | ToolSearch for godot tools → none in this session. `D:\Projects\godot-mcp-pro-v1.13.2` exists on disk but is not wired into this session. **Fallback per GOAL: drive godot headless via CLI.** |

## Notes
- Sibling projects (un_party_game, Garden_Train) built against **Godot 4.6.2
  stable** on the Pop!_OS side; their docs warn: `godot.exe` is GUI-subsystem —
  use `Godot_v4.x_win64_console.exe` when stdout is a receipt.
- This partition's Godot install status will be re-verified below once winget
  completes (version output captured verbatim).

## Post-install verification
(to be appended when installs complete)
