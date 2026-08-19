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

## Post-install verification (2026-07-15, later the same session)

winget proved unhealthy on this machine: both a `winget list` and the triple
`winget install` ran 30+ minutes with zero output and zero installs; both
background jobs were killed. **Fallback: direct downloads to `D:\Tools\`**
(producer granted blanket install permission mid-session):

| Tool | Source | Verification (command → output) |
|---|---|---|
| Godot 4.6.2 | github.com/godotengine/godot releases, `Godot_v4.6.2-stable_win64.exe.zip` (79,831,334 bytes) | `D:\Tools\godot\godot_console.exe --version` → `4.6.2.stable.official.71f334935` |
| gh CLI 2.96.0 | github.com/cli/cli releases, `gh_2.96.0_windows_amd64.zip` | `gh --version` → `gh version 2.96.0 (2026-07-02)` |
| ffmpeg 8.1.2 | gyan.dev `ffmpeg-release-essentials.zip` | `ffmpeg -version` → `ffmpeg version 8.1.2-essentials_build-www.gyan.dev` |

- Version choice: 4.6.2-stable over latest 4.7.1-stable — matches the
  sibling-proven engine and all Phase 1 research (D1). Both GUI and console
  exes present; hardlink shims `godot.exe` / `godot_console.exe` created.
- User PATH extended (persistent): `D:\Tools\godot;D:\Tools\gh\bin;`
  `D:\Tools\ffmpeg\ffmpeg-8.1.2-essentials_build\bin`.
- `gh auth status` → "You are not logged into any GitHub hosts." → logged in
  NEEDS_YOU.md; building local until producer auths (per GOAL).

## Dev-laptop addendum (2026-08-19, D30 session)

The D:\ paths above live on GOLEM's Windows partition. This session runs
on the DEV LAPTOP; the repo is the same Syncthing share at
`C:\Users\agall\projects\soft_landing`. Producer ruling (D30): golem is
the couch box — perf numbers from this laptop are ADVISORY-ONLY.

| Tool | Path (laptop) | Verified |
|---|---|---|
| Godot 4.6.2 console | `C:\Users\agall\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64_console.exe` | `--version` → `4.6.2.stable.official.71f334935` |
| godot (GUI shim) | `C:\Users\agall\AppData\Local\Microsoft\WinGet\Links\godot.exe` | same version |
| ffmpeg | `C:\Users\agall\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe` | present |
| gh | `C:\Program Files\GitHub CLI\gh.exe` | present |

Canary: `check_placements.gd --world=bramble` →
`PLACEMENT_SUMMARY {"any_fail":false}` on this machine, this HEAD.
