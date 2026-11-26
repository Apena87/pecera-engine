// Hidden grader for the Inkhorn Reef task. Prints one line per check and writes the weighted score to /logs/verifier/reward.txt.
'use strict';
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const GAME = process.env.GAME_DIR || '/app/game';
const OUT = process.env.REWARD_FILE || '/logs/verifier/reward.txt';
const DETAIL = process.env.DETAIL_FILE || '/logs/verifier/grader.json';
const results = [];
function check(group, name, weight, fn) {
  let ok = false, note = '';
  try { const r = fn(); ok = r === true || (r && r.ok === true); note = r && r.note ? r.note : ''; }
  catch (e) { ok = false; note = 'error: ' + (e && e.message ? e.message.slice(0, 200) : String(e)); }
  results.push({ group, name, weight, ok, note });
  console.log(`${ok ? 'PASS' : 'FAIL'} [${group}] ${name}${note ? ' :: ' + note : ''}`);
}
const P = (...a) => path.join(GAME, ...a);
const exists = p => fs.existsSync(p);
const LEVELS = ['01', '02', '03', '04', '05', '06', '07', '08'];
const clone = o => JSON.parse(JSON.stringify(o));

// ---------- files ----------
check('files', 'sim.js exists', 1, () => exists(P('sim.js')));
check('files', 'index.html exists', 1, () => exists(P('index.html')));
check('files', 'eight level files', 1, () => LEVELS.every(l => exists(P('levels', l + '.json'))));
check('files', 'tools/solve.js exists', 1, () => exists(P('tools', 'solve.js')));
check('files', 'README.md with content', 1, () => exists(P('README.md')) && fs.readFileSync(P('README.md'), 'utf8').length > 800);
check('files', 'no network references in game files', 1, () => {
  const files = fs.readdirSync(GAME).filter(f => /\.(html|js|css)$/.test(f));
  const bad = files.filter(f => /(src|href)\s*=\s*["']\s*(https?:)?\/\//i.test(fs.readFileSync(P(f), 'utf8')) || /fetch\s*\(\s*["']https?:/i.test(fs.readFileSync(P(f), 'utf8')));
  return { ok: files.length > 0 && bad.length === 0, note: bad.join(',') };
});

// ---------- work log ----------
check('log', 'PROGRESS.md has 6 or more timestamped entries', 2, () => {
  if (!exists(P('PROGRESS.md'))) return false;
  const n = (fs.readFileSync(P('PROGRESS.md'), 'utf8').match(/(^|\n)[#*\-\s]*\[?\d{2}:\d{2}/g) || []).length;
  return { ok: n >= 6, note: `${n} entries` };
});

// ---------- their tests ----------
check('tests', '15+ tests and all pass under node --test', 3, () => {
  if (!exists(P('tests'))) return false;
  const r = spawnSync('node', ['--test', 'tests/'], { cwd: GAME, encoding: 'utf8', timeout: 300000 });
  const out = (r.stdout || '') + (r.stderr || '');
  const tests = +((out.match(/# tests (\d+)/) || [])[1] || 0), fail = +((out.match(/# fail (\d+)/) || [])[1] || 0);
  return { ok: r.status === 0 && tests >= 15 && fail === 0, note: `tests=${tests} fail=${fail} exit=${r.status}` };
});

// ---------- sim ----------
let Sim = null;
check('sim', 'sim.js loads in Node with the five functions', 2, () => {
  Sim = require(P('sim.js'));
  if (Sim && Sim.default) Sim = Sim.default;
  return ['createWorld', 'step', 'hash', 'serialize', 'deserialize', 'autopilotInput'].every(k => typeof Sim[k] === 'function');
});
check('sim', 'no Math.random, Date or performance in sim.js', 1, () => {
  const src = fs.readFileSync(P('sim.js'), 'utf8').replace(/\/\/.*$/gm, '').replace(/\/\*[\s\S]*?\*\//g, '');
  return !/Math\.random|\bDate\b|performance\.now/.test(src);
});

const levels = {};
for (const l of LEVELS) { try { levels[l] = JSON.parse(fs.readFileSync(P('levels', l + '.json'), 'utf8')); } catch (e) {} }

check('levels', 'levels meet the format rules', 2, () => {
  const bad = [];
  for (const l of LEVELS) {
    const v = levels[l];
    if (!v) { bad.push(l + ':missing'); continue; }
    const need = ['id', 'name', 'width', 'height', 'timeLimitSec', 'seacorns', 'required', 'player', 'spawn', 'stable', 'currents', 'rocks', 'whirlpools', 'jellyfish', 'bubbles'];
    const miss = need.filter(k => !(k in v)); if (miss.length) bad.push(l + ':no ' + miss.join('/'));
    if (v.width < 800 || v.height < 500) bad.push(l + ':small');
    if (v.seacorns < 4 || v.required < 3 || v.required > v.seacorns) bad.push(l + ':counts');
    if (+l >= 5 && !((v.jellyfish || []).length >= 1 && (v.whirlpools || []).length >= 1 && (v.rocks || []).length >= 2)) bad.push(l + ':hazards');
  }
  return { ok: bad.length === 0, note: bad.join(' ') };
});

const keys = ['up', 'down', 'left', 'right', 'ink'];
function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
function randomInputs(n, seed) { const r = rng(seed); const out = []; let cur = {}; for (let i = 0; i < n; i++) { if (i % 20 === 0) { cur = {}; for (const k of keys) cur[k] = r() < (k === 'ink' ? 0.15 : 0.35); } out.push(cur); } return out; }
const mk = (l, s) => Sim.createWorld(clone(levels[l]), s);

check('sim', 'deterministic: same level, seed and inputs give the same hashes', 2, () => {
  for (const l of ['01', '05', '08']) {
    const ins = randomInputs(1500, 7);
    const a = mk(l, 3), b = mk(l, 3);
    for (let i = 0; i < ins.length; i++) { Sim.step(a, ins[i]); Sim.step(b, ins[i]); if (i % 50 === 0 && Sim.hash(a) !== Sim.hash(b)) return { ok: false, note: `level ${l} tick ${i}` }; }
  }
  return true;
});
check('sim', 'different seeds give different worlds', 1, () => Sim.hash(mk('03', 1)) !== Sim.hash(mk('03', 2)));
check('sim', 'hash is 8 hex chars and changes with state', 1, () => {
  const w = mk('02', 1); const h = Sim.hash(w); if (!/^[0-9a-f]{8}$/.test(h)) return { ok: false, note: h };
  const w2 = clone(w); w2.octopus.x += 1; const w3 = clone(w); w3.seacorns[0].vx += 0.5;
  return Sim.hash(w2) !== h && Sim.hash(w3) !== h;
});
check('sim', 'serialize and deserialize continue identically', 2, () => {
  for (const l of ['02', '06']) {
    const ins = randomInputs(1000, 11); const a = mk(l, 5);
    for (let i = 0; i < 500; i++) Sim.step(a, ins[i]);
    const b = Sim.deserialize(Sim.serialize(a));
    if (Sim.hash(a) !== Sim.hash(b)) return { ok: false, note: 'hash differs right after deserialize' };
    for (let i = 500; i < 1000; i++) { Sim.step(a, ins[i]); Sim.step(b, ins[i]); if (Sim.hash(a) !== Sim.hash(b)) return { ok: false, note: `${l} tick ${i}` }; }
  }
  return true;
});
check('sim', 'world has the required fields', 1, () => {
  const w = mk('01', 1);
  const ok = w.tick === 0 && w.status === 'playing' && typeof w.rescued === 'number' && typeof w.required === 'number' && w.octopus && w.octopus.ink === 100 && w.octopus.stunned === 0 && Array.isArray(w.seacorns) && Array.isArray(w.inkClouds) && w.level && JSON.parse(JSON.stringify(w));
  return { ok: !!ok && w.seacorns.length === levels['01'].seacorns && w.seacorns.every(s => 'id' in s && 'vx' in s && s.rescued === false) };
});

// invariant sweep: rules 1, 2, 3
check('rules', 'bounds, rocks and rescue counting hold under random play', 4, () => {
  const problems = [];
  for (const l of LEVELS) for (const seed of [1, 9]) {
    const lv = levels[l]; const w = mk(l, seed); const ins = randomInputs(3000, seed * 13 + +l);
    const seenRescued = new Set();
    for (let i = 0; i < ins.length && w.status === 'playing'; i++) {
      Sim.step(w, ins[i]);
      const things = [w.octopus, ...w.seacorns];
      if (things.some(t => t.x < 0 || t.y < 0 || t.x > lv.width || t.y > lv.height)) { problems.push(`${l}/${seed} out of bounds t${w.tick}`); break; }
      if (w.seacorns.some(s => (lv.rocks || []).some(r => Math.hypot(s.x - r.x, s.y - r.y) < r.r - 1e-6))) { problems.push(`${l}/${seed} seacorn in rock t${w.tick}`); break; }
      const st = lv.stable; const inS = s => s.x >= st.x && s.x <= st.x + st.w && s.y >= st.y && s.y <= st.y + st.h;
      for (const s of w.seacorns) { if (seenRescued.has(s.id) && (!s.rescued || !inS(s))) { problems.push(`${l}/${seed} rescued seacorn left t${w.tick}`); break; } if (s.rescued) seenRescued.add(s.id); }
      if (w.rescued !== w.seacorns.filter(s => s.rescued).length) { problems.push(`${l}/${seed} rescued count off t${w.tick}`); break; }
      if (w.seacorns.some(s => !s.rescued && inS(s))) { problems.push(`${l}/${seed} unrescued seacorn inside stable t${w.tick}`); break; }
    }
  }
  return { ok: problems.length === 0, note: problems.slice(0, 4).join('; ') };
});
check('rules', 'ink: costs 20, needs 20, 15-tick cooldown', 3, () => {
  const w = mk('01', 1); w.octopus.ink = 100;
  const c0 = w.inkClouds.length; Sim.step(w, { ink: true });
  const used = 100 - w.octopus.ink;
  if (w.inkClouds.length !== c0 + 1 || used < 19.5 || used > 20.5) return { ok: false, note: `clouds ${c0}->${w.inkClouds.length}, ink 100->${w.octopus.ink}` };
  const c1 = w.inkClouds.length, i1 = w.octopus.ink; Sim.step(w, { ink: true });
  if (w.inkClouds.length > c1 || w.octopus.ink < i1 - 0.5) return { ok: false, note: 'cooldown ignored' };
  for (let i = 0; i < 16; i++) Sim.step(w, {});
  const c2 = w.inkClouds.length; Sim.step(w, { ink: true });
  if (w.inkClouds.length !== c2 + 1) return { ok: false, note: 'no cloud after cooldown' };
  for (let i = 0; i < 16; i++) Sim.step(w, {});
  w.octopus.ink = 10; const c3 = w.inkClouds.length; Sim.step(w, { ink: true });
  if (w.inkClouds.length > c3 || w.octopus.ink < 9.5) return { ok: false, note: 'ink made with 10 ink' };
  return true;
});
check('rules', 'bubble adds 30 ink once', 2, () => {
  const l = LEVELS.find(k => (levels[k].bubbles || []).length); if (!l) return { ok: false, note: 'no level has bubbles' };
  const b = levels[l].bubbles[0]; const w = mk(l, 1);
  w.octopus.x = b.x; w.octopus.y = b.y; w.octopus.ink = 40; Sim.step(w, {});
  const got = w.octopus.ink - 40; if (got < 29 || got > 32) return { ok: false, note: `ink +${got}` };
  w.octopus.x = b.x; w.octopus.y = b.y; const before = w.octopus.ink; Sim.step(w, {});
  return { ok: w.octopus.ink - before < 5, note: `second touch +${w.octopus.ink - before}` };
});
check('rules', 'stun: input does not move the octopus, counter drops by 1', 2, () => {
  const w = mk('05', 1); for (let i = 0; i < 5; i++) Sim.step(w, {});
  w.octopus.stunned = 30; const a = clone(w), b = clone(w);
  Sim.step(a, { right: true, down: true }); Sim.step(b, { left: true, up: true });
  return { ok: Math.abs(a.octopus.x - b.octopus.x) < 1e-9 && Math.abs(a.octopus.y - b.octopus.y) < 1e-9 && a.octopus.stunned === 29, note: `dx=${a.octopus.x - b.octopus.x} stunned=${a.octopus.stunned}` };
});
check('rules', 'rescue and win at the first tick enough are in the stable', 3, () => {
  const lv = levels['01']; const w = mk('01', 1); const st = lv.stable;
  const n = w.required;
  for (let i = 0; i < n; i++) { const s = w.seacorns[i]; s.x = st.x + st.w / 2 + (i - n / 2) * 4; s.y = st.y + st.h / 2; s.vx = 0; s.vy = 0; }
  Sim.step(w, {});
  return { ok: w.rescued >= n && w.status === 'won', note: `rescued=${w.rescued} status=${w.status}` };
});
check('rules', 'lose when time runs out, then nothing changes', 2, () => {
  const lv = levels['02']; const w = mk('02', 1); w.tick = lv.timeLimitSec * 60 - 1; Sim.step(w, {});
  if (w.status !== 'lost') return { ok: false, note: `status=${w.status} tick=${w.tick}` };
  const h = Sim.hash(w); Sim.step(w, { right: true, ink: true });
  const same = Sim.hash(w) === h; return { ok: same, note: same ? '' : 'state changed after lost' };
});
check('rules', 'the herd moves on its own', 2, () => {
  const w = mk('04', 2); w.octopus.x = 0; w.octopus.y = 0;
  const start = w.seacorns.map(s => [s.x, s.y]); for (let i = 0; i < 600; i++) Sim.step(w, {});
  const avg = w.seacorns.reduce((a, s, i) => a + Math.hypot(s.x - start[i][0], s.y - start[i][1]), 0) / w.seacorns.length;
  return { ok: avg > 20, note: `average move ${avg.toFixed(1)} px in 10 s` };
});
check('rules', 'autopilotInput does not change the world', 1, () => {
  const w = mk('03', 1); for (let i = 0; i < 100; i++) Sim.step(w, Sim.autopilotInput(w));
  const h = Sim.hash(w); const inp = Sim.autopilotInput(w);
  return Sim.hash(w) === h && inp && typeof inp === 'object';
});

// ---------- bot ----------
function decode(log) {
  const out = []; let ink = false;
  for (const ch of log) { if (ch === 'i') { ink = true; continue; } const v = parseInt(ch, 16); if (isNaN(v)) throw new Error('bad char ' + ch); out.push({ up: !!(v & 1), down: !!(v & 2), left: !!(v & 4), right: !!(v & 8), ink }); ink = false; }
  return out;
}
let botWins = 0, botSeed1 = 0, botReplays = 0, botRuns = 0; const botNotes = [];
if (exists(P('tools', 'solve.js'))) {
  for (const l of LEVELS) for (const seed of [1, 2, 3]) {
    botRuns++;
    const r = spawnSync('node', ['tools/solve.js', `levels/${l}.json`, String(seed)], { cwd: GAME, encoding: 'utf8', timeout: 60000, maxBuffer: 64 * 1024 * 1024 });
    try {
      const line = (r.stdout || '').trim().split('\n').filter(Boolean).pop();
      const j = JSON.parse(line); const ins = decode(j.inputs);
      const w = mk(l, seed); for (const i of ins) { if (w.status !== 'playing') break; Sim.step(w, i); }
      const same = w.status === j.result && (j.result !== 'won' || w.tick === j.ticks || Math.abs(w.tick - j.ticks) <= 1);
      if (same) botReplays++; else botNotes.push(`${l}/${seed} replay ${w.status}@${w.tick} vs ${j.result}@${j.ticks}`);
      if (same && j.result === 'won') { botWins++; if (seed === 1) botSeed1++; }
    } catch (e) { botNotes.push(`${l}/${seed} ${r.error ? 'timeout/error' : 'bad output'}`); }
  }
}
check('bot', 'bot output replays to the same result', 2, () => ({ ok: botRuns === 24 && botReplays === 24, note: `${botReplays}/${botRuns} ${botNotes.slice(0, 3).join('; ')}` }));
check('bot', 'bot wins every level with seed 1', 3, () => ({ ok: botSeed1 === 8, note: `${botSeed1}/8` }));
check('bot', 'bot wins at least 18 of 24 runs', 3, () => ({ ok: botWins >= 18, note: `${botWins}/24` }));

// ---------- browser ----------
const chrome = ['chromium', 'chromium-browser', 'google-chrome'].map(c => spawnSync('sh', ['-c', `command -v ${c}`], { encoding: 'utf8' }).stdout.trim()).find(Boolean);
check('browser', 'index.html loads with no console errors and draws a scene', 4, () => {
  if (!chrome) return { ok: false, note: 'no chromium in grader image' };
  const shot = '/tmp/inkhorn-shot.png'; try { fs.unlinkSync(shot); } catch (e) {}
  const r = spawnSync(chrome, ['--headless=new', '--no-sandbox', '--disable-gpu', '--enable-logging=stderr', '--v=0', '--window-size=1280,800', '--virtual-time-budget=6000', `--screenshot=${shot}`, 'file://' + P('index.html')], { encoding: 'utf8', timeout: 90000 });
  const log = (r.stderr || '') + (r.stdout || '');
  const errs = log.split('\n').filter(x => /Uncaught|CONSOLE.*(Error|error)|is not defined|Cannot read prop/.test(x) && !/favicon|AudioContext was not allowed|dbus|gpu|GPU|Fontconfig/i.test(x));
  const size = exists(shot) ? fs.statSync(shot).size : 0;
  return { ok: errs.length === 0 && size > 12000, note: `png ${size} B, errors ${errs.length} ${errs.slice(0, 2).join(' | ').slice(0, 200)}` };
});

// ---------- score ----------
const total = results.reduce((a, r) => a + r.weight, 0), got = results.reduce((a, r) => a + (r.ok ? r.weight : 0), 0);
const score = Math.round((got / total) * 1000) / 1000;
console.log(`SCORE ${got}/${total} = ${score}`);
try { fs.mkdirSync(path.dirname(OUT), { recursive: true }); fs.writeFileSync(OUT, String(score)); fs.writeFileSync(DETAIL, JSON.stringify({ score, got, total, results }, null, 1)); } catch (e) { console.log('could not write reward: ' + e.message); }
