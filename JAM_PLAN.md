# Hack Club Haven Panipat — Godot Web Jam Setup and Plan

Event: **Sunday 22 November 2026**, Hotel Surya Inn, Panipat. Free. Teens 13–18.
Theme drops at the opening ceremony; **build window is 10:00 → 17:30 (7.5 hours)**.

Theme is unknown, so everything below is theme-agnostic infrastructure. The
goal is that when the theme drops, **zero time is spent on tooling**.

> **Unresolved:** Hack Club's Ember jam rules state that AI-generated *assets*
> are not allowed and that no more than 1/3 of the project may be AI-written.
> Panipat's own rules page has not been checked yet. Until it is, treat this repo
> as a **skeleton and reference**, not as a finished entry — and write the final
> game yourselves. See section 6.

---

## 1. Environment status (verified, not assumed)

| Thing | State |
| --- | --- |
| Godot | 4.7.2 stable official, `ed1daf0bf` |
| Godot binary | `D:\Hack club\Godot_v4.7.2-stable_win64.exe` |
| Godot CLI binary | `D:\Hack club\Godot_v4.7.2-stable_win64_console.exe` (use this in a terminal — the plain `.exe` detaches from the console and swallows stdout) |
| Web export templates | Installed at `%APPDATA%\Godot\export_templates\4.7.2.stable` |
| butler | v15.32.0 at `D:\Hack club\tools\butler\windows-amd64\butler.exe` |
| git | 2.53.0, repo initialised, identity `SYNØR <officialsynor@gmail.com>` |
| GitHub CLI | 2.105.0 — available if you want to create the remote repo |
| Python | 3.14.3 (used by `tools/serve.py`) |

**Verified end to end:** a headless web export produces `index.wasm` (39,514,754
bytes — 39.5 MB decimal, 37.7 MiB), `index.js` (273 KB), `index.pck` (823 KB)
and `index.html`, and `tools/serve.py` serves all four with the correct MIME
types (`application/wasm`, `application/octet-stream`) and COOP/COEP headers.
Re-checked with `build.ps1 -NoServe` plus an HTTP probe.

### One deliberate trade-off

Only the **web** templates were installed (~85 MB). The full template archive is
1.19 GB and `C:` had 6.4 GB free, so the other platforms were dropped rather
than extracted. If you ever want a Windows build, re-download:

```
curl.exe -L -o "$env:TEMP\t.tpz" "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
```

---

## 2. The build is single-threaded, and that is deliberate

`export_presets.cfg` sets `variant/thread_support=false`, which selects
`web_nothreads_release.zip`. Consequences worth knowing before you panic:

- The build **does not need SharedArrayBuffer**, so it does **not** need the
  COOP/COEP cross-origin-isolation headers.
- itch.io therefore hosts it correctly with no special configuration.
- The preflight page reports `crossOriginIsolated: false` when served from
  itch.io. **That is expected and harmless** for this build.
- `tools/serve.py` still sends the headers. Harmless, and it means the same
  build can be switched to a threaded template later without re-testing.

If you ever flip `thread_support` to `true`, the isolation headers become
mandatory and itch.io's default hosting stops being enough.

---

## 3. What is already built

```
project.godot            web-safe settings: gl_compatibility renderer, canvas_items stretch
export_presets.cfg       "Web" preset, nothreads, committed so CI matches local
icon.svg                 placeholder icon
autoload/game_state.gd   score + all input bindings, registered in code
autoload/audio_director.gd  music/SFX + browser audio unlock + make_tone()
autoload/scene_router.gd    fade-to-black scene switching on its own CanvasLayer
scripts/player.gd        CharacterBody2D: acceleration/friction, squash & stretch,
                         keyboard + touch/drag steering
scripts/collectible.gd   Area2D pickup, picked_up(at) signal, bobbing/spinning
scripts/hazard.gd        Area2D chaser that grows over time, caught_player signal
scenes/game.tscn/gd      reference game: start card, score, win, death, restart,
                         screen shake + hit-pause on impact
scenes/preflight.tscn/gd    smoke test: rendering, input, audio, isolation
tools/serve.py           local server with COOP/COEP + wasm MIME type
build.ps1                one command: import -> error check -> export -> serve
fonts/PressStart2P-Regular.ttf  pixel font (OFL), wired into every UI element
audio/kenney_interface_sounds/  100 CC0 .wav UI sounds, 4 of them wired in
README.md                build, controls, layout, deployment, licensing
LICENSE                  MIT — required for the open-source submission
.github/workflows/       tag push -> web export -> butler push to itch.io
build/.gdignore          stops Godot re-importing its own export output
```

### The `]` trap — read this before running any shell command

The project folder is named `GAME]`, and **`]` is a PowerShell wildcard
character**. Plain `Test-Path`, `Get-Item`, `Get-ChildItem` and `Copy-Item`
silently report that existing files **do not exist**:

```
Test-Path  "D:\Hack club\GAME]\build\web\index.html"              -> False
Test-Path -LiteralPath "D:\Hack club\GAME]\build\web\index.html"  -> True
```

This already cost time once — an export looked "empty" when it was fine. If a
script of your own needs to check a path in this repo, **always use
`-LiteralPath`**.


### The reference game (`scenes/game.tscn`)

A complete working loop you can reskin instead of starting from an empty scene:
start card → move → grab diamonds → score → win at 12, or get caught → **R** to
restart. Every visual is a `Polygon2D` built in code, and the sounds come from
the vendored CC0 Kenney pack plus one synthesised arpeggio — so there is still
no asset-licensing risk, and no third-party art to credit.

Use it as a parts bin. The three patterns worth copying verbatim:

- **Feel** ([player.gd](file:///d:/Hack%20club/GAME%5D/scripts/player.gd)) — velocity moves *toward* the target
  instead of snapping to it. That lag is what "weight" means.
- **Feedback** ([game.gd](file:///d:/Hack%20club/GAME%5D/scripts/game.gd)) — `_burst()` fires particles + a
  tone at the exact pickup location.
- **Pressure** ([hazard.gd](file:///d:/Hack%20club/GAME%5D/scripts/hazard.gd)) — one enemy that grows and
  accelerates removes the need for a written timer.


### Two design choices worth keeping

**Input is registered in code** ([game_state.gd](file:///d:/Hack%20club/GAME%5D/autoload/game_state.gd)),
not through the editor's Input Map panel. It is readable, diffable, and cannot
be lost to a conflict in a `.godot` cache file. Add an action by adding one line
to `KEYMAP`.

**`AudioDirector.make_tone()`** builds a real `AudioStreamWAV` in code with no
asset file. Use it for placeholder SFX, so silence never blocks progress.

---

## 4. Timeline (matched to the real Panipat schedule)

The single rule that matters: **the first web export happens around 13:30, not at
17:00.** Discovering a broken export at 17:15 is how jam entries die.

| Clock | Block | Exit condition |
| --- | --- | --- |
| 08:00–09:00 | Check-in, breakfast, find teammates | Signed in, laptops charged. |
| 09:00–10:00 | Theme reveal | One sentence: "a game where you ___". Not a genre, a verb. |
| 10:00–10:30 | Scope lock (either skip the workshops or split up) | Core verb, one screen, win state, lose state written down. |
| 10:15 / 10:30 | GitHub + Godot workshops — *optional* | Only one of you goes; the other keeps building. You already have this repo, so these are low value. |
| 10:30–13:00 | Core loop, ugly | The core verb is playable and repeatable. Art is rectangles. |
| **13:00–13:30** | **HARD GATE: export + play in browser** | `build/web` runs at `http://127.0.0.1:8080/`. Do not skip. |
| 13:00–14:00 | Lunch (eat, then use the room) | — |
| 14:00–16:00 | Content and juice | Screen shake, hit pause, particles, sound on every action. |
| 16:00–17:00 | Shell | Title screen, restart, on-screen controls, credits. |
| 17:00–17:30 | Ship | Final export, `butler push` to itch, write the page. **Deadline 17:30.** |
| 18:00–19:00 | Demos + peer voting | Be at the machine. Your pitch is 30 seconds, in person. |
| 19:15 | Awards | — |

### Cut list — decide the order of sacrifice now

When behind schedule, cut in this order, and never negotiate it mid-panic:

1. Extra levels / second enemy type
2. Menu polish, settings screen
3. Music (keep SFX — they carry more feel per minute of work)
4. Story, text, dialogue
5. **Never cut:** the core verb feeling good, the restart button, the web export

### Juice, cheapest first

Screen shake on impact -> hit-pause (2–3 frames) -> particle burst on death ->
tweened UI -> colour flash. This order gives the most perceived quality per
minute spent.

### What wins peer voting

Hack Club voting is 1–5 across **Creativity, Theming, Artwork, Audio, Enjoyment**
— so **Artwork + Audio are 40% of the score**, and it is voted on by teenagers
who play for about a minute each. Two consequences:

- A **finished, 90-second game beats an ambitious unfinished one**, every time.
- **Theme the title card, the colours, and the death screen first.** Those are
  the three frames every voter sees, whether or not they play well.



---

## 5. Web-export traps

1. **Audio is silent until the player clicks.** Browsers block AudioContext
   creation before a user gesture. Handled by `AudioDirector.unlock()`, which
   the preflight scene calls from `_input`. Keep that pattern.
2. **Never test by opening `index.html` directly.** `file://` cannot load the
   `.wasm` or `.pck`. Always use `tools/serve.py`.
3. **Keyboard focus.** The canvas needs a click before keys register. The preset
   sets `focus_canvas_on_start=true`, but if the game is in an iframe the player
   may still need to click once — say so on the itch page.
4. **First load is the biggest UX risk.** 39.5 MB of wasm, roughly 10 MB over
   the wire once compressed. itch.io caches it, but the first load is slow.
   Ship a title screen so the player has something to look at.
5. **Stay on `gl_compatibility`.** Forward+ needs WebGPU, which most voters'
   browsers do not have.
6. **Assume mobile.** A large share of itch traffic is phones. Touch and drag
   steering is wired up — `Player.set_move_target()` makes the player follow
   the finger, and a held key still overrides it. Say "best on desktop" on the
   page if the core verb turns out to need precision.
7. **A stale cache looks exactly like a broken build.** `serve.py` sends
   `Cache-Control: no-store` for this reason.

---

## 6. Assets — check the rule before you generate anything

The event page you pasted says nothing about AI. Hack Club's *other* jams forbid
AI-generated assets outright and cap AI-written code at 1/3 of the project. Those
terms may or may not apply at Panipat, and the difference is the difference
between placing and being disqualified. **Find Panipat's rules page or ask an
organiser before 10:00.**

Three plans, in order of preference:

1. **Rules are strict** (most likely) — draw the art yourselves and build every
   sound in code. That is why the reference game ships with zero asset files:
   `Polygon2D` shapes, a locked 4-colour palette, and
   [`make_tone()`](file:///d:/Hack%20club/GAME%5D/autoload/audio_director.gd) / `_build_music()` for audio. Zero
   licensing risk, and it is genuinely competitive — a strong palette beats
   mediocre generated art under peer voting anyway.
2. **Rules are silent or permissive** — still start with shapes, and only add
   generated art if the core loop is finished and exported by 15:00.
3. **You ask and are told yes** — get the answer in writing (a screenshot of the
   chat is enough) before you rely on it.

**Already downloaded, so venue Wi-Fi cannot hurt you:**

- [fonts/PressStart2P-Regular.ttf](file:///d:/Hack%20club/GAME%5D/fonts) — pixel font, OFL licensed.
  Load it in code with `load("res://fonts/PressStart2P-Regular.ttf")`.
  Use it for the **title, score, and win/lose text** — that is the 40% Artwork
  score, and it costs you one line.
- [audio/kenney_interface_sounds](file:///d:/Hack%20club/GAME%5D/audio/kenney_interface_sounds) — 100 CC0
  UI sounds. Names tell you what they are: `click_00*`, `confirmation_00*`,
  `error_00*`, `bong_001`, `drop_00*`, `back_00*`, `close_00*`.
  Grab one with `load("res://audio/kenney_interface_sounds/confirmation_001.wav")`.

Both are hand-made, not AI-generated, so they are safe even under strict rules.

Anything else you want must be grabbed **before** you leave, not at the venue.


---

## 7. Commands

**Use the script.** It runs all four steps in the right order and refuses to
export a build whose scripts do not load:

```powershell
cd "d:\Hack club\GAME]"
.\build.ps1              # import -> error check -> export -> serve on :8080
.\build.ps1 -NoServe     # build only, for the final ship
```

By hand, if you need to:

```powershell
$GODOT = "D:\Hack club\Godot_v4.7.2-stable_win64_console.exe"
$PROJ  = "d:\Hack club\GAME]"

# Catch script errors without opening the editor. JUST AFTER you add a new
# script that uses class_name, run --import FIRST or every reference to that
# class fails to parse ("Could not find type ... in the current scope").
& $GODOT --headless --path $PROJ --import
& $GODOT --headless --path $PROJ --quit-after 60

# Export a web build (takes about 4 seconds)
& $GODOT --headless --path $PROJ --export-release "Web" "build/web/index.html"

# Serve it (then open http://127.0.0.1:8080/)
python tools/serve.py "d:\Hack club\GAME]\build\web" 8080

# Open the editor
Start-Process "D:\Hack club\Godot_v4.7.2-stable_win64.exe" -ArgumentList "--path", $PROJ
```

> Remember: checking any of those output paths with `Test-Path` needs
> `-LiteralPath`, or it lies about the `]` in the folder name.

### Publishing to itch.io

First time only:

```powershell
& "D:\Hack club\tools\butler\windows-amd64\butler.exe" login
```

Then, per upload:

```powershell
& "D:\Hack club\tools\butler\windows-amd64\butler.exe" push "d:\Hack club\GAME]\build\web" "YOURUSER/YOURGAME:web"
```

The channel name must be exactly `web` — that is what tells itch.io to treat the
upload as an HTML5 playable rather than a downloadable file.

For CI, add repo secrets `BUTLER_API_KEY`, `ITCH_USER`, `ITCH_GAME`, then push a
`v*` tag.

---

## 8. Theme-reveal checklist

0. **Ask an organiser the AI question** (section 6) and screenshot the answer.
1. Write the one-sentence pitch. Read it aloud. If it is a genre, rewrite it.
2. Pick the core verb. Everything that does not serve it is out of scope.
3. Write the cut list in the order above, before writing code.
4. Reskin [game.tscn](file:///d:/Hack%20club/GAME%5D/scenes/game.tscn) instead of starting empty — swap the
   title text, the palette, and the verb. `application/run/main_scene` already
   points at it.
5. Delete `scenes/preflight.*` only after your own scene has been exported and
   played in a browser once. Until then it is your only proof the pipeline works.
6. Commit before the first big change. `git commit` early and often — a jam is
   the worst possible time to discover you have no undo. Push the repo public on
   GitHub: Hack Club requires the project to be open source.
