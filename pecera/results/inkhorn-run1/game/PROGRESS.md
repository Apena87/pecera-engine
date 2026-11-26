# Inkhorn Reef — Progress Log

## 07:10 — Finishing pass (this session)

What I finished:
- Read `sim.js`, `tools/solve.js`, the levels and the tests to confirm the
  deliverable state.
- Assembled `index.html` for real: embedded the eight level files at the top
  of its body (harmless `var LEVELS = ...` statement, verified to contain
  no `</script>` or comment-break sequences that would terminate the inline
  script) and inlined the canvas/audio/DOM controller (IIFE guarded on
  `window.Sim` / `window.LEVELS`). Title screen, level select with eight
  cards and `localStorage` best scores (degrading gracefully when storage
  fails), HUD with time / ink / rescued-out-of-required, camera that
  follows Ollie and keeps the level's aspect ratio, pause / win / lose
  screens, on-screen controls for touch screens, mute toggle, R / P / Space
  / arrows / WASD input, canvas-rendered octopus + seacorns + background
  (light rays and drifting particles) and Web Audio sounds (ink, bubble,
  rescue, stun, win, lose, quiet background tune) — nothing plays before
  the player has pressed a key or tapped.
- `grep -n "https?://\|src=\|href=\|url(" index.html` returns only
  `<script src="sim.js">` — no CDN links, no external files, no fonts or
  images. `node --check` on both inline `<script>` bodies passes.
- Ran `node --test tests/` — 31/31 pass (24 sim + 7 levels).
- Ran `node tools/solve.js levels/01.json 1` — wins in 376 ticks and prints
  one JSON line.
- Ran a headless Chromium 156 harness (Node 22 built-in WebSocket driving
  CDP, `Runtime.evaluate`): page loads over `file://` with no console
  errors; title screen is visible; clicking Start shows the level select
  (8 cards); clicking a card starts the game — `window.InkhornReef.state()`
  returns `"playing"`; HUD is visible; the game ticks (119 ticks, 5
  seacorns); holding ArrowRight and pressing Space keeps the game running
  (222 ticks later, status still `"playing"`); screenshot saved at
  /tmp/game_screenshot.png (133 KB).

What is NOT claimed:
- The touch controls were not driven headlessly (no touch events in a
  headless browser) — the markup and CSS for them is in place.
- Audio playback is best-effort and was not audibly verified.
- `index.html` renders correctly in Chromium, but was not checked in
  Firefox or Safari.

Next:
- Final audit against the task checklist; then stop.

## 06:43 — Tests green

What I finished:
- `sim.js` (540 lines, UMD, mulberry32, fnv1a, canonical JSON, fixed 60 tps,
  deterministic).
- Levels 01–08 written and tuned. Bot wins every level with seed 1; the
  level data passes the sanity test.
- `tools/solve.js` prints `{"result":"won","ticks":N,"inputs":"<log>"}` as
  one JSON line.
- Tests: 24 in `tests/sim.test.js` and 7 in `tests/levels.test.js`, plus
  `tests/index.js` shim so `node --test tests/` loads both. Mutating tests
  deep-clone the JSON level so shared cache is never mutated.
- `node --test tests/` → 31/31 pass.

## 06:14 — Levels + bot

- Levels 01–08 re-tuned (01: 5 seacorns/3 required/120s/1 rock/0 whirl/0
  jelly; 08: 10/7/190s/3 rocks/2 whirl/3 jelly). Bot (no ink, 16-direction
  probe avoiding rocks, whirlpools and jellyfish paths) wins level 01 all
  seeds and level 02 onwards; full 8x3 sweeps pass ≥18/24.
- Autopilot probe parameters: 16 directions, 46px probe, boundary penalty
  -2.5 at 4px margin, rock −2.5×(1−(rd−r.r)/30) within r+30px, whirlpool
  −3.0×(1−(wd−wp.r)/30) within r+30px, jelly −2.0×(1−jd/90) within 90px.

## 05:58 — Start

- Environment checked; scratch work tracked in /tmp/NOTES.md. Empty assets/
  folder removed when the deliverable was assembled.
- All scratch files live in /tmp — nothing extra in /app/game.

07:42 — Final audit session: focused on making every earlier claim honest.
Re-ran the full suite (31/31). Re-verified the 24 bot runs (all win, replay
reproduces status/tick/hash). Re-ran the headless Chromium driver over
file:// with the real game code path — title, level select, playing,
pause/resume, restart, a real-path win (world mutated, game detects and
over-screen shows), retry, and a real-path lose — everything PASS, zero
console errors, canvas non-blank, screenshot saved. Confirmed embedded
LEVELS in index.html are byte-identical to disk files. Found nothing in
the earlier work that needed fixing; the only failing check was my own
wrong expectation in a scratch harness (restart tick<10), not the game.
No files changed.
