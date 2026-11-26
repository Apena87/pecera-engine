# Inkhorn Reef

Build a complete browser game in `/app/game`. You have about six hours. This is a long task: plan it, track it, and check your own work as you go, because nobody will look at it until you are finished.

## The game

Ollie is an octopus who looks after a herd of seacorns: small sea ponies with a spiral unicorn horn and a rainbow mane. Ocean currents keep scattering the herd. Ollie swims around the reef, and the seacorns follow him loosely as a flock. He can squirt clouds of ink, which seacorns swim away from, to steer them. A level is won when enough seacorns are guided into the Coral Stable before the timer runs out. Rescued seacorns stay in the stable, and their horns glow.

Hazards: jellyfish drift on fixed paths and stun Ollie for 2 seconds on contact. Whirlpools pull everything near them toward their centre. Rocks block movement. Rainbow bubbles refill Ollie's ink.

## Files to deliver

All paths are inside `/app/game`. Everything must work offline: no CDN links, no network requests, no image, audio or font files. Draw everything with the canvas API and make sound with the Web Audio API.

| Path | What it is |
|---|---|
| `sim.js` | The whole game simulation, with no drawing and no DOM access. It must load both in a browser through a `<script>` tag (defining a global `Sim`) and in Node through `require('./sim.js')` (exporting the same object). No dependencies. |
| `index.html` | The game. It loads `sim.js` with a relative `<script src="sim.js">` and may load other local `.js` files. It must also work when opened straight from disk with a `file://` URL. |
| `levels/01.json` to `levels/08.json` | Eight levels, getting harder from 01 to 08. |
| `tools/solve.js` | A bot that plays a level and wins it (see below). |
| `tests/*.test.js` | At least 15 tests that run with `cd /app/game && node --test tests/`. All must pass. |
| `README.md` | How to play, the controls, how the code is organised, and an honest list of known problems. |
| `PROGRESS.md` | Your work log (see below). |

Nothing else needs to be in `/app/game`. Keep scratch work in `/tmp`.

## The simulation API (`sim.js`)

The simulation runs at a fixed 60 ticks per second. It must be deterministic: the same level, seed and sequence of inputs always give the same result. Do not use `Math.random`, `Date`, `performance.now` or anything else outside the inputs inside `sim.js`. Write your own seeded random generator.

`Sim` must provide exactly these functions:

- `Sim.createWorld(level, seed)` takes a parsed level object and an integer seed. It returns a new world.
- `Sim.step(world, input)` advances the world by one tick and returns it. `input` is `{up, down, left, right, ink}`, all booleans. Missing keys count as false.
- `Sim.hash(world)` returns an 8-character lowercase hex string computed from the world's full state. Two worlds with the same state give the same hash. A change to any position, velocity, counter or status changes it.
- `Sim.serialize(world)` returns a string. `Sim.deserialize(string)` returns a world that continues stepping exactly like the original: the same inputs give the same hashes from then on.
- `Sim.autopilotInput(world)` returns an input object that a computer player would press this tick. It must only read the world, never change it.

A world is a plain object that `JSON.stringify` can store. It has at least these fields, with these meanings:

- `tick`: number of steps taken, starting at 0.
- `status`: `"playing"`, `"won"` or `"lost"`. Once it is `"won"` or `"lost"`, `step` changes nothing.
- `rescued`: number of seacorns in the stable. `required`: how many must be rescued to win.
- `octopus`: `{x, y, ink, stunned}`. `ink` goes from 0 to 100 and starts at 100. `stunned` is the number of ticks left in a stun, 0 when not stunned.
- `seacorns`: an array of `{id, x, y, vx, vy, rescued}`.
- `inkClouds`: an array of `{x, y, r, ttl}`.
- `level`: the level object it was created from.

Rules the hidden tests will check:

1. The octopus and every seacorn stay inside `0 <= x <= level.width` and `0 <= y <= level.height`.
2. No seacorn centre is ever inside a rock: its distance from each rock centre is at least that rock's `r`.
3. A seacorn is rescued at the first tick its centre is inside the stable rectangle. After that it stays rescued, stays inside the stable, and is never counted twice. `rescued` always equals the number of seacorns with `rescued: true`.
4. Pressing `ink` when `ink >= 20` and no ink cloud was made in the last 15 ticks makes one new cloud at the octopus and lowers `ink` by exactly 20. Otherwise nothing happens.
5. Touching a bubble removes it and adds 30 ink, up to 100.
6. While `stunned > 0`, the octopus does not move by its own input and `stunned` goes down by 1 each tick.
7. The world becomes `"won"` at the first tick where `rescued >= required`. It becomes `"lost"` at the first tick where `tick >= level.timeLimitSec * 60` and the level is not won.
8. When no seacorn is near an ink cloud and the octopus is far away, the herd must still move, because of currents and flocking. A herd that never moves on its own is not a game.

## Level format

Each level file is JSON with these fields. You may add more.

```
{
  "id": "01", "name": "First Swim",
  "width": 1600, "height": 1000, "timeLimitSec": 120,
  "seacorns": 6, "required": 4,
  "player": {"x": 200, "y": 500},
  "spawn": {"x": 500, "y": 500, "r": 120},
  "stable": {"x": 1300, "y": 350, "w": 200, "h": 300},
  "currents": [{"x": 0, "y": 0, "w": 800, "h": 300, "dx": 0.6, "dy": 0}],
  "rocks": [{"x": 900, "y": 500, "r": 60}],
  "whirlpools": [{"x": 1000, "y": 800, "r": 150, "strength": 1.2}],
  "jellyfish": [{"path": [[600, 200], [900, 200]], "speed": 1.5}],
  "bubbles": [{"x": 700, "y": 650}]
}
```

`width` and `height` are at least 800 by 500. Every level has at least 4 seacorns, `required` is at least 3, and seacorns spawn inside the `spawn` circle, never inside a rock or the stable. Later levels add more hazards. Levels 05 to 08 each have at least one jellyfish, one whirlpool and two rocks.

## The bot (`tools/solve.js`)

`node tools/solve.js <level file> <seed>` plays the level from `Sim.createWorld` with `Sim.autopilotInput` and `Sim.step` until the game ends. It prints exactly one line:

```
{"result":"won","ticks":1234,"inputs":"<input log>"}
```

`result` is `"won"` or `"lost"`. `inputs` is the whole input log, one character per tick, where the character is a single hexadecimal digit of the bits up=1, down=2, left=4, right=8, plus `"i"` before the digit on ticks where ink is pressed. For example `"8"` is right only, `"i9"` is up and right with ink, `"0"` is nothing pressed.

The hidden tests run the bot on every level with seeds 1, 2 and 3, then replay each input log through your `sim.js` and check that it reaches the same result. The bot must win at least 18 of those 24 runs and must win every level with seed 1. Each run must finish within 60 seconds.

## The game in the browser (`index.html`)

- A title screen with the game name, a short animation of the octopus and seacorns, and a way to start.
- A level select showing all eight levels and the best score for each. Store scores in `localStorage`, and keep the game working when storage is not available.
- Play with the arrow keys or WASD, Space for ink, P or Escape to pause, R to restart, M to mute. On touch screens, show on-screen controls.
- A HUD with time left, an ink bar, and rescued out of required.
- A screen for winning and one for losing, each with a way to retry or go on.
- The canvas fills the window and keeps its aspect ratio. The camera follows Ollie when the level is larger than the screen.
- Animation: Ollie's eight tentacles wave, the seacorns' manes ripple in rainbow colours, rescued horns glow, ink clouds billow and fade, bubbles wobble, the background has light rays and drifting particles.
- Sound: short procedural sounds for ink, bubble pickup, rescue, stun, win and lose, and a quiet background tune. Nothing plays until the player has pressed a key or tapped, because browsers block that.
- No errors in the browser console during normal play.

## Your work log (`PROGRESS.md`)

Keep this file current. Each entry starts with the UTC time from `date -u +%H:%M`, then says what you finished, what you checked and how, and what comes next. Write an entry at least every 45 minutes and at the end of each milestone below. Do not write that something works unless you ran a check that showed it.

Work in these milestones, in order. Each one leaves the game in a working state.

1. `sim.js` core: world, movement, bounds, rocks, determinism, hash, serialize. Tests for these.
2. Seacorns: flocking, currents, the stable, rescue, win and lose. Tests.
3. Ink, bubbles, jellyfish, whirlpools. Tests.
4. Eight levels and the bot. Make the bot win, and adjust levels so they are fair.
5. `index.html` playable: drawing, input, HUD, camera, screens.
6. Animation and sound polish.
7. Title screen, level select, saved scores, touch controls.
8. Final check of everything above, `README.md`, and a last log entry with an honest summary of what does not work.

## How this is graded

Hidden tests run after you stop. They check the files above, run your tests, check every rule in the simulation section against your `sim.js` with their own inputs, run the bot on all levels and replay its logs, and load `index.html` in a headless browser to look for console errors and a drawn canvas. A person will then play the game and read your log and README, comparing what they say against what actually works.
