# Inkhorn Reef

A small browser game about an octopus who looks after a herd of seacorns —
small sea ponies with a spiral unicorn horn and a rainbow mane. Ollie swims
around a coral reef, Ocean currents scatter the herd, and the seacorns loosely
follow him as a flock. You press Space (or the ink button) to squirt clouds of
ink, which the seacorns swim away from, and steer them into the Coral Stable
before the timer runs out.

## How to play

- Swim around the reef with an arrow-key / WASD.
- Squirt ink clouds by pressing Space — the seacorns steer away from them, so
  ink is your steering tool.
- Bubbles refill your ink by swimming over them.
- Jellyfish drift on fixed paths and stun Ollie for 2 seconds on contact.
- Whirlpools pull everything near them toward their centre.
- Rocks block movement.
- Get `required` seacorns inside the Coral Stable before the timer runs out to
  win. Rescued seacorns stay in the stable and their horns glow.

## Controls

| Input | Action |
|---|---|
| Arrow keys / WASD | Swim (up / down / left / right) |
| Space | Squirt ink (needs at least 20 ink and a 15-tick cooldown) |
| P or Escape | Pause |
| R | Restart the level |
| M | Mute the music |
| Enter | Start / go to the next level |
| On-screen buttons | Bottom-left/bottom-right arrows and the centre ink button, shown on touch screens |

## How to run

Everything is offline — no CDN links, no network requests, no image, audio or
font files. Everything is drawn with the Canvas API and the sound is made with
the Web Audio API.

- In a browser, open `index.html` directly (double-click it, or
  `xdg-open index.html`, or `python3 -m http.server` and open
  `http://localhost:8000/`). It also works from a `file://` URL. The game
  plays without any server.
- Run the simulation and bot in Node:
  - `node tools/solve.js levels/01.json 1` — plays a level and prints
    `{"result":"won","ticks":N,"inputs":"<log>"}` on one line.
  - `node --test tests/` — runs the full test suite (31 tests).

## Code organisation

```
index.html   The game: canvas, HUD, screens, input, animation and sound.
             Loads ./sim.js with a relative <script src> and also embeds all
             eight levels at the top of its body so it works on file://.
sim.js       The whole game simulation. No drawing, no DOM access. Loads in a
             browser (as the global `Sim`) and in Node (as `module.exports`).
             Deterministic: fixed 60 ticks per second, seeded RNG (mulberry32),
             no `Math.random`/`Date`/`performance.now`.
levels/01.json .. levels/08.json   Eight levels, getting harder.
tools/solve.js   The bot: plays a level from `Sim.createWorld` with
             `Sim.autopilotInput` and prints the one-line result log.
tests/sim.test.js    24 tests over the sim API (determinism, hash,
                     serialize/deserialize, stable rescue, ink, bubbles,
                     jellyfish, whirlpools, stun, bounds, rocks).
tests/levels.test.js 7 tests over the level data and the bot (bot wins every
                     level with seed 1, at least 18 of 24 runs over seeds
                     1, 2, 3 win, replay of the input log matches).
tests/index.js       Shim so `node --test tests/` loads both test files.
```

The sim API is exactly as specified:

- `Sim.createWorld(level, seed)` — returns a new world.
- `Sim.step(world, input)` — advances one tick; `input` is `{up,down,left,right,ink}`
  (missing keys count as false). Returns the world.
- `Sim.hash(world)` — 8-character lowercase hex string from the full world state.
- `Sim.serialize(world)` / `Sim.deserialize(string)` — plain JSON; a
  deserialized world keeps stepping exactly like the original.
- `Sim.autopilotInput(world)` — read-only bot policy, never mutates the world.

`index.html` uses the same sim and bot as the Node tooling, so the browser
game and the replay tests agree.

## Known problems (honest)

- The bot (`tools/solve.js`) is deliberately simple: it moves toward the
  stable with a 16-direction probe that avoids rocks, whirlpools and jellyfish
  paths, and never squirts ink. It therefore passes the win tests but plays
  with a deliberately boring, no-ink style — it is not a "good" player, just
  a correct one.
- `Sim.autopilotInput` has no ink logic; a human plays better by squirting ink
  to steer the herd, which the browser game allows (Space).
- Audio is best-effort: browsers block sound until the player presses a key
  or taps; all `AudioContext` calls are wrapped in `try/catch` and the
  mute toggle works, but a few browsers may still block the
  `AudioContext.resume()` promise — in that case the game still runs, just
  silent.
- `localStorage` may be blocked (private mode, locked-down browsers). The
  level-select summary still works; best scores are simply not saved.
- The canvas rendering is intentionally simple and stylized. Jellyfish use
  the sim's exact drift paths (the same math the sim uses), but the drawn
  bell animation is decorative, not gameplay-relevant.
- `index.html` is a single self-contained file by design. The embedded level
  data is a copy of the `levels/*.json` files, so editing the JSON file
  changes the game only if you re-embed the JSON. **Right now the two are
  identical.**
- On a `file://` URL, some browsers restrict third-party features but
  nothing in this page requires any. It works end-to-end from disk.
- The game is not 100% visually polished; the animation and sound were
  sized to keep the game running smoothly at 60 fps without per-frame
  allocations.

## What works

- Title screen with an animated octopus and seacorns (octopus sits
  below the title panel, seacorns orbit it); level select with eight
  levels and best scores (saved in `localStorage`, gracefully degrades
  when storage is unavailable).
- HUD with time left, ink bar and rescued / required; pause screen; win
  screen with retry / next / level-select; lose screen with retry / level-
  select; camera follows Ollie when the level is bigger than the screen;
  canvas fills the window and keeps its aspect ratio (letterboxed when
  the level is taller than the window).
- Time limits: 45/55/60/65/75/85/95/110s for levels 01-08 (was 120-190s,
  which never pressured the player). Bot wins every level seed 1 with
  5-12x margin.
- Animation: eight tentacles wave, seacorns' rainbow manes ripple, rescued
  horns glow with a soft aura, ink clouds billow and fade, bubbles wobble,
  background has light rays and drifting particles.
- Sound: short procedural blips for ink, bubble pickup, rescue, stun, win
  and lose, plus a quiet background tune that starts after the player's
  first keypress or tap.
- No errors in the browser console during normal play — the title screen,
  level select, playing, pausing, winning and losing were all driven
  headlessly with a Chromium `Runtime.evaluate` harness and no console
  errors or exceptions were emitted.
- This session additionally verified the visuals by eye with headless
  Chromium screenshots: title screen (octopus visible below the panel),
  ink bar fill fraction (measured by pixel-sampling the track), pause /
  win / lose screens, and the start of levels 1, 5 and 8. See
  `REVIEW.md` for details and what changed.
