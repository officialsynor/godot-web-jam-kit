# REFERENCE GAME — Hack Club Haven Panipat web jam

A Godot 4.7.2 game that exports to a single-page HTML5 build and plays in the
browser. Source is here so the project can be submitted open source, as the
event requires.

Event: **Sunday 22 November 2026**, Hotel Surya Inn, Panipat. Build window
10:00 → 17:30. Theme drops at the opening ceremony.

The theme-agnostic setup (tooling, export pipeline, deployment) is done in
advance so that on theme-reveal day the only work left is game content. See
[JAM_PLAN.md](JAM_PLAN.md) for the full runbook, schedule and cut list.

## Requirements

| Thing | Version used |
| --- | --- |
| Godot | 4.7.2 stable (with web export templates installed) |
| Python | 3.x — only for the local test server |
| butler | 15.32.0 — only for uploading to itch.io |

## Build and run

```powershell
cd "d:\Hack club\GAME]"
.\build.ps1              # import -> error check -> export -> serve on :8080
.\build.ps1 -NoServe     # build only, for the final ship
```

Then open <http://127.0.0.1:8080/>.

`build.ps1` refuses to export if the game does not load cleanly, because a
headless Godot export happily ships a build containing a broken script.

By hand:

```powershell
$GODOT = "D:\Hack club\Godot_v4.7.2-stable_win64_console.exe"
$PROJ  = "d:\Hack club\GAME]"

& $GODOT --headless --path $PROJ --import
& $GODOT --headless --path $PROJ --quit-after 60
& $GODOT --headless --path $PROJ --export-release "Web" "build/web/index.html"
python tools/serve.py "d:\Hack club\GAME]\build\web" 8080
```

**Never test by opening `build/web/index.html` directly.** `file://` cannot
load the `.wasm` or `.pck`. Always serve.

> **Windows trap:** this folder is named `GAME]`, and `]` is a PowerShell
> wildcard. Plain `Test-Path` / `Get-Item` report that existing files do not
> exist. Always pass `-LiteralPath`.

## Controls

| Input | Action |
| --- | --- |
| W A S D / arrow keys | Move |
| Touch or drag | Move (mobile) |
| Any key / click / tap | Start |
| R | Restart after win or death |

The first click or key press is also what unlocks browser audio — browsers
block AudioContext creation before a user gesture, so music cannot start
before then.

## Theme slot

Everything theme-specific lives in one block at the top of
[scripts/game.gd](scripts/game.gd):

```gdscript
const GAME_TITLE := "REFERENCE GAME"
const FONT_PATH := "res://fonts/PressStart2P-Regular.ttf"
const SFX_DIR := "res://audio/kenney_interface_sounds/"
```

Change the title, swap the palette in `scripts/player.gd`,
`scripts/collectible.gd` and `scripts/hazard.gd`, then theme the **title
card, the colours and the death screen first** — those are the three frames
every voter sees.

## Layout

```
project.godot          web-safe settings: gl_compatibility, canvas_items stretch
export_presets.cfg     "Web" preset, single-threaded, committed so CI matches local
autoload/game_state.gd     score + all input bindings, registered in code
autoload/audio_director.gd music/SFX + browser audio unlock + make_tone()
autoload/scene_router.gd   fade-to-black scene switching on its own CanvasLayer
scripts/game.gd        the reference loop: start, score, win, death, restart
scripts/player.gd      CharacterBody2D: acceleration/friction + squash & stretch
scripts/collectible.gd Area2D pickup, picked_up(at) signal, bobbing/spinning
scripts/hazard.gd      Area2D chaser that grows over time, caught_player signal
scenes/game.tscn       main scene
scenes/preflight.tscn  smoke test: rendering, input, audio, isolation
tools/serve.py         local server with COOP/COEP + wasm MIME type
build.ps1              one command: import -> error check -> export -> serve
fonts/                 PressStart2P pixel font (OFL)
audio/                 100 CC0 interface sounds (Kenney)
.github/workflows/     tag push -> web export -> butler push to itch.io
```

## Deploy to itch.io

First time only:

```powershell
& "D:\Hack club\tools\butler\windows-amd64\butler.exe" login
```

Then per upload:

```powershell
& "D:\Hack club\tools\butler\windows-amd64\butler.exe" push `
  "d:\Hack club\GAME]\build\web" "YOURUSER/YOURGAME:web"
```

The channel name must be exactly `web` — that is what makes itch.io treat the
upload as an HTML5 playable rather than a download.

For CI, add repo secrets `BUTLER_API_KEY`, `ITCH_USER`, `ITCH_GAME`, then push
a `v*` tag.

## Assets and licensing

- **Font** — PressStart2P, SIL Open Font License. See
  [fonts/OFL-PressStart2P.txt](fonts/OFL-PressStart2P.txt).
- **Sounds** — Kenney "Interface Sounds", CC0. See
  [audio/kenney_interface_sounds/LICENSE.txt](audio/kenney_interface_sounds/LICENSE.txt).
- **Everything else** — all visuals are `Polygon2D` shapes built in code. The
  music is a short arpeggio synthesised at runtime by `Game._build_music()`;
  `AudioDirector.make_tone()` also exists for placeholder tones and is what the
  preflight smoke scene plays.

Both asset packs are hand-made, not AI-generated, so they carry no risk under
jam rules that restrict generated assets. The project also avoids AI-generated
art entirely for the same reason.
