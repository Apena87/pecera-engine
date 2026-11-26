# Inkhorn Reef: look at what you built, then fix it

Earlier you built the browser game in `/app/game` from the task in `/app/ORIGINAL_TASK.md`. You could not see the screen then, so every visual and gameplay claim in your README and log was checked by code, not by eye. Now you can see. You have about 90 minutes.

## How to see the game

- `node /opt/shot.js <out.png> [step ...]` opens `/app/game/index.html` in headless Chromium and saves a screenshot. Steps run in order: `click:<css selector>`, `js:<code>`, `key:<Key>:<ms>` to hold a key, `wait:<ms>`, `shot:<file.png>` for an extra screenshot. Example: `node /opt/shot.js /tmp/l3.png 'click:#startBtn' wait:500 'js:window.InkhornReef.startLevel(2)' wait:2000 key:ArrowRight:1500 key:Space:100 wait:500`. Quote steps that contain brackets.
- `vision_analyze` looks at an image file and answers a question about it. Pass the png path as `image_url` and ask a specific question, for example "Is the purple ink bar in the top left filled, and about what fraction?" Each look takes about half a minute, so plan which screens you need.

## What to do

1. Take screenshots of: the title screen, the level select, the start of level 1, level 1 after a few seconds of play with ink used, the pause screen, the win screen, the lose screen, and the start of levels 5 and 8.
2. For each screenshot, check it against what `/app/ORIGINAL_TASK.md` and your own `README.md` say should be on that screen. Look for things that are missing, empty, hidden behind something else, drawn in the wrong place, too small to read, or that do not match the game state you set up.
3. Check the game as a player would, not only as a test would. Run the bot on every level and compare how long it takes with each level's time limit. Ask whether each level needs the mechanics the task describes, whether later levels are harder, and whether what the screen shows agrees with what the simulation says happened.
4. Fix what is wrong. Keep `sim.js` rules, the API, the bot output format and the tests working: run `cd /app/game && node --test tests/` and the bot on all levels after your changes.
5. Take new screenshots of every screen you changed and look at them again to confirm the fix.

## What to write

- `/app/game/REVIEW.md`: one section per screenshot with what you saw, what was wrong, what you changed, and what the new screenshot shows. Then a section on gameplay and difficulty with the bot timings before and after. Then a list of anything still wrong.
- Update `README.md` so its claims match what you saw, and add a `PROGRESS.md` entry for this session.

Hidden tests will rerun the original grader, so do not break anything that already worked. A person will compare your REVIEW.md against the screenshots.
