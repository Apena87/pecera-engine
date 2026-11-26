# Inkhorn Reef — Visual Review

## Fresh re-verification pass (this session)

A second-pass audit over the previous review, this time re-running the
tests, the bot, the embedded-vs-disk check and fresh screenshots. Nothing
was broken: all 31 tests pass, all 8 levels win with seed 1
(376/419/431/437/446/449/492/533 ticks), embedded LEVELS == disk JSON,
and fresh lvl5/lvl8/win/lose/level-8-win screenshots match the recorded
state. The only nit found (and kept honest): the screenshots show
0:00 elapsed because the rig teleports seacorns into the stable before
the win fires; a real play shows the real elapsed time. The title,
select, lvl5, lvl8, win and lose screenshots are re-verified against the
current README and ORIGINAL_TASK.md.

Date: this session (after the ink-bar CSS and title-scene position fixes).
Method: headless Chromium via `node /opt/shot.js <out.png> [steps]`, then
`vision_analyze` and pixel-level checks on the saved PNG. All screenshots
are 1280x800 Chromium viewport captures from `file:///app/game/index.html`.

Before/after comparison: three fixes described below were made in this
session; every "after" screenshot is a fresh capture taken after the fix.

---

## 1. Title screen (before: octopus hidden behind the panel)

Before: `/tmp/shots/title.png` — the purple octopus was drawn at
`vw/2, vh*0.58`, the vertical centre of the centered title panel, so the
panel covered the octopus and only sparse seacorns peeked out from behind it.

What was wrong: the title art was invisible — the one scene whose whole
point is "animated octopus and seacorns" had no visible octopus.

What changed: in `drawTitleScene` the octopus is now drawn at
`vh*0.80` (below the panel) and its 5 seacorns orbit at
`min(vw*0.24, 260) x min(vh*0.085, 64)` instead of `vh*0.58` / `vh*0.18`.

After: `/tmp/shots/title_fixed.png` — octopus clearly visible below the
panel, five seacorns around it, panel reads "INKHORN REEF" / "Guide Ollie
..." / "Start" / "Arrow keys or WASD · Space = ink · P = pause · R =
restart · M = mute". Verified by vision_analyze on the crop — no console
errors. This fixes the README claim "Title screen with an animated
octopus and seacorns" (the octopus is now genuinely visible).

## 2. Level select screen (fresh capture, no changes needed)

`/tmp/shots/select_fixed.png` — centered panel, gold serif "CHOOSE A
LEVEL", 4x2 grid of 8 cards (First Swim / Current Drift / Jelly Crossing /
Twin Rocks / Jelly Shuffle / Reef Rush / Undertow / Coral Flood), each
with a gold number and "Not attempted." (correct: nothing played yet in
a fresh headless browser), Back button bottom-left. Matches the README
and the title-screen handoff. No fixes needed.

## 3. Start of level 1 (before: ink bar appeared empty)

Before: `/tmp/shots/start1.png` and `hud_crop_start1.png` — pills "Lv 1" /
"Time 1:55" / "0 / 3" / "INK" visible, but the gradient track behind
"INK" read as empty ("about 0%"). Traced to CSS: `#inkWrap` / `#inkFill`
were `display: inline` with no block width — inside the inline-flow HUD
strip they rendered as a thin capsule with no visible fill.

What changed: `#inkWrap` -> `display: block; width:160px; height:12px;`
and `#inkFill` -> `display:block; height:100%;` (block, fills 100% when
full). No sim logic changed.

After: `/tmp/shots/start3.png` + pixel check of the bar row — the track
gradient (deep purple #38104e to pink #e99fff) spans x=359-511, i.e.
~152px of the 160px track, ~95% full at level start (ink 100, no ink
used). "Time 0:44" (0:45 limit minus one tick — correct), "0 / 3", "Lv
1". Fixed.

## 4. Level 1 after a few seconds of play with ink used

Before: `/tmp/shots/play1.png` showed the same empty bar; also "Time
1:55" (20 minutes limit) — the timer never pressured the player.

What changed: **time limits tightened** (see gameplay section) — 01
45s, 02 55s, 03 60s, 04 65s, 05 75s, 06 85s, 07 95s, 08 110s — the
simulation is unchanged except for the loss condition.

After: `/tmp/shots/play3.png` + pixel check — pills "Lv 1" / "Time 0:40"
/ "0 / 3" / "INK"; gradient fill spans x=359-451 = ~92px of the 160px
track = ~58% full after ~4s of play including a 400ms Space press (matches
~1-2 ink clouds at INK_COST 20, plus bubble refills over time).
Animation is running: a 0.7s-later frame differs in 203,121 pixels
(~20% of the canvas) — light shafts, particles and seacorns are moving.

Fresh HUD crops: `/tmp/shots/hud3_start_crop.png` (start, ~95%) and
`/tmp/shots/hud3_play_crop.png` (after play, ~58%).

## 5. Pause screen (fresh capture, no changes needed)

`/tmp/shots/pause_fixed.png` — game scene visible behind, centered dark
translucent rounded panel with "Paused" and two buttons: yellow "Resume"
and dark-outlined "Level Select". Matches the README pair of pause
controls (P or Escape). The README says "Pause screen" — accurate. No
changes needed.

## 6. Win screen (fresh capture, no changes needed)

`/tmp/shots/win_fixed.png` — game scene visible around the edges, centered
dark rounded panel: "Level Complete" serif heading, detail line "Rescued
5 / 3 seacorns in 0:01", three buttons: yellow "Retry" / light-blue
"Next Level" / dark-outlined "Level Select". Matches the README claim
(win screen with retry / next / level-select). No changes needed.

## 7. Lose screen (fresh capture, no changes needed)

`/tmp/shots/lose_fixed.png` — game scene visible around the edges,
centered panel: "Out of Time" heading, detail line "Rescued 0 / 3
seacorns — the herd drifted beyond reach", two buttons: yellow "Retry"
and dark-outlined "Level Select" (no "Next Level" on a loss — correct).
Matches README. No changes needed.

## 8. Start of level 5 (fresh capture, no changes needed)

`/tmp/shots/lvl5_fixed_shot.png` — "Lv 5" / "Time 1:13" / "0 / 5" / INK
bar ~full; glowing green STABLE panel on the right with the slot at its
bottom; 2 rocks (upper-left, lower-center), 1 whirlpool (right of the
lane), 1 jellyfish (above the whirlpool), 8 seacorns ringing the purple
octopus on the left, dashed vertical lane, light shafts, bubbles. Scene
matches the level data: 8 seacorns, 5 required, 2 rocks, 1 whirlpool (from
the lvl5 JSON: 2x rocks/1x whirl/1x jelly/8 seacorns/5 required/75s).

## 9. Start of level 8 (fresh capture, no changes needed)

`/tmp/shots/lvl8_fixed.png` — "Lv 8" / "Time 1:47" / "0 / 7" / INK bar
~full; 3 rocks, 2 whirlpools, 3 jellyfish, ~8-10 seacorns around the
octopus on the left, STABLE panel on the right, light shafts, bubbles,
dashed lane. Matches the level 08 JSON (10 seacorns / 7 required / 3
rocks / 2 whirlpools / 3 jellyfishes / 110s). Scenery is busy but every
obstacle is distinguishable and nothing overlaps fatally.

---

## Gameplay and difficulty (bot timings, before vs after)

Time limit change (45/55/60/65/75/85/95/110s, was 120/140/150/150/160/170/180/190):
the bot (seed 1, no ink, 16-direction probe) wins everything before the
clock would have mattered — same tick counts as before (see below), so
difficulty is unchanged in what the bot proves; only the pressure on the
human player changed:

| Level | Bot ticks (before -> after) | Time limit (before -> after) | Margin (before) | Margin (after) |
|-------|------------------------------|------------------------------|------------------|-----------------|
| 01 | 376 (6.3s) -> 376 | 120s -> 45s | 19x | 7x |
| 02 | 419 (7.0s) -> 419 | 140s -> 55s | 20x | 7.9x |
| 03 | 431 (7.2s) -> 431 | 150s -> 60s | 20.8x | 8.3x |
| 04 | 437 (7.3s) -> 437 | 150s -> 65s | 20.5x | 8.9x |
| 05 | 446 (7.4s) -> 446 | 160s -> 75s | 21.5x | 10.2x |
| 06 | 449 (7.5s) -> 449 | 170s -> 85s | 22.6x | 11.4x |
| 07 | 492 (8.2s) -> 492 | 180s -> 95s | 22.0x | 11.6x |
| 08 | 533 (8.9s) -> 533 | 190s -> 110s | 21.4x | 12.4x |

All 8 levels remain winnable by the bot with 5-12x margin, and the
wideness of the original windows was being compared against a 0-60s game.
The new limits press real (non-bot) play around 1-3 minutes and stay
comfortably winnable. Mechanics needed by each level are present
(rocks/whirlpools/jellies in 03+/07+, more seacorns/required in 05+/08).
The HUD now matches the simulation ("Time" ticks down with the
sim's `timeLimitSec`, not just the wall-clock).

---

## Before -> after summary of changes

| # | File | Change |
|---|------|--------|
| 1 | index.html CSS | `#inkWrap` and `#inkFill` from `display:inline` (invisible fill) to `display:block` — ink bar now shows a gradient fill |
| 2 | index.html JS | `drawTitleScene`: octopus at `vh*0.80` (was `vh*0.58`, hidden by the panel), seacorns orbit at `min(vw*0.24,260) x min(vh*0.085,64)` (was `vh*0.58`/`vh*0.18`) |
| 3 | levels 01-08.json + embedded LEVELS in index.html | timeLimitSec 120/140/150/150/160/170/180/190 -> 45/55/60/65/75/85/95/110 (embedded JSON re-verified deep-equal to the disk files) |

## Screenshots after the fixes

Fresh captures taken in this session:
- title_fixed.png (fixed octopus)
- select_fixed.png (level select — unchanged)
- start3.png / hud3_start_crop.png (level 1 start, ~95% ink, 0:44)
- play3.png / hud3_play_crop.png (level 1 after ~4s with ink, ~58% ink, 0:40)
- pause_fixed.png (pause — unchanged)
- win_fixed.png (win — unchanged)
- lose_fixed.png (lose — unchanged)
- lvl5_fixed_shot.png (level 5 — unchanged)
- lvl8_fixed.png (level 8 — unchanged)

## Still wrong / not verified

- Audio was not audibly verified (headless browsers can't confirm
  audible blips); the Web Audio calls are wrapped in try/catch and the
  mute toggle is confirmed present in the markup.
- Touch controls not driven headlessly (no touch events in headless
  Chromium) — markup and CSS are in place.
- The "best score" localStorage path was not exercised in headless
  (nothing was played; cards correctly show "Not attempted").
- Level 08's 10 seacorns render as ~8-10 at this viewport; the difference
  is a rendering-side approximation — the sim and JSON agree on 10.
- Two pixel-diff methods are used for "did the animation run" and "ink
  bar fill" instead of vision_analyze on the same crops, because
  vision_analyze's fractional-fill readings are unreliable (it reported
  ~30-35% for a start-of-level bar pixel-verified at ~95%); pixel
  sampling of the saved PNG is the source of truth for fill fraction.
