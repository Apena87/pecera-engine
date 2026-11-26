// Inkhorn Reef — game simulation. No DOM, no drawing, no dependencies.
// Loads in browser via a <script> tag (sets global Math.Sim) or in Node via
// require('./sim.js') (module.exports).
//
// Fixed timestep: 60 ticks per second. Fully deterministic: no Math.random,
// Date, performance.now or anything outside the inputs inside this file.

(function (root, factory) {
  var api = factory();
  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.Sim = api;
  }
})(typeof self !== "undefined" ? self : globalThis, function () {
  "use strict";

  var TICKS_PER_SEC = 60;
  var OCCUPUS_SPEED = 4.6;      // px per tick
  var SEACORN_SPEED = 3.0;      // px per tick (soft cap)
  var INK_COST = 20;
  var INK_MIN = 20;
  var INK_GAP_TICKS = 15;       // cooldown between clouds
  var CLOUD_TTL = 75;           // ticks each ink cloud lives
  var CLOUD_MAX_R = 62;
  var BUBBLE_INK = 30;
  var STUN_TICKS = 120;         // 2 seconds at 60 ticks/sec
  var INK_RADIUS = 16;          // octopus body radius used for rock collision

  // ---- deterministic RNG (mulberry32) --------------------------------------
  function mulberry32(a) {
    return function () {
      a |= 0;
      a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }
  function dist(x1, y1, x2, y2) { var dx = x2 - x1, dy = y2 - y1; return Math.sqrt(dx * dx + dy * dy); }

  function inRect(px, py, r) {
    return px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h;
  }


  function spawnSeacornPositions(level, count, rng) {
    var spawn = level.spawn;
    var s = clamp(spawn.r, 1, 2000);
    var list = [];
    var tries = 0;
    while (list.length < count && tries < 200) {
      tries++;
      var ang = rng() * Math.PI * 2;
      var rad = Math.sqrt(rng()) * spawn.r;
      var x = clamp(spawn.x + Math.cos(ang) * rad, 4, level.width - 4);
      var y = clamp(spawn.y + Math.sin(ang) * rad, 4, level.height - 4);
      var bad = false;
      if (inRect(x, y, level.stable)) bad = true;
      if (!bad && level.rocks) {
        for (var i = 0; i < level.rocks.length; i++) {
          var rk = level.rocks[i];
          if (dist(x, y, rk.x, rk.y) < rk.r + 20) bad = true;
        }
      }
      for (var j = 0; j < list.length; j++) {
        if (dist(x, y, list[j].x, list[j].y) < 46) bad = true;
      }
      if (!bad) list.push({ x: x, y: y });
    }
    // fallback: ring around spawn centre, deterministic
    var fallbackIdx = 0;
    while (list.length < count && fallbackIdx < 50) {
      fallbackIdx++;
      var a2 = (fallbackIdx * 2.39996);
      var r2 = (spawn.r * 0.6) * Math.sqrt((fallbackIdx % 7) / 7);
      var x2 = clamp(spawn.x + Math.cos(a2) * r2, 4, level.width - 4);
      var y2 = clamp(spawn.y + Math.sin(a2) * r2, 4, level.height - 4);
      var ok = true;
      if (inRect(x2, y2, level.stable)) ok = false;
      if (ok && level.rocks) {
        for (var i2 = 0; i2 < level.rocks.length; i2++) {
          var rk2 = level.rocks[i2];
          if (dist(x2, y2, rk2.x, rk2.y) < rk2.r + 20) ok = false;
        }
      }
      if (ok) list.push({ x: x2, y: y2 });
    }
    return list;
  }

  function jellyPosition(jl, tick) {
    // Ping-pong along the polyline path.
    var path = jl.path;
    if (!path || path.length < 2) return { x: path && path[0] ? path[0][0] : 0, y: path && path[0] ? path[0][1] : 0 };
    var segs = [];
    var total = 0;
    var i;
    for (i = 0; i < path.length - 1; i++) {
      var dx = path[i + 1][0] - path[i][0];
      var dy = path[i + 1][1] - path[i][1];
      var len = Math.sqrt(dx * dx + dy * dy);
      segs.push(len);
      total += len;
    }
    if (total <= 0) return { x: path[0][0], y: path[0][1] };
    var speed = (jl.speed != null ? jl.speed : 1.5);
    var d = (tick * speed) % (2 * total);
    var dir = 1;
    if (d > total) { d = 2 * total - d; dir = -1; }
    var acc = 0;
    for (i = 0; i < segs.length; i++) {
      if (acc + segs[i] >= d) {
        var t = segs[i] <= 0 ? 0 : (d - acc) / segs[i];
        var x = path[i][0] + (path[i + 1][0] - path[i][0]) * t;
        var y = path[i][1] + (path[i + 1][1] - path[i][1]) * t;
        return { x: x, y: y };
      }
      acc += segs[i];
    }
    var last = path[path.length - 1];
    return { x: last[0], y: last[1] };
  }

  function createWorld(level, seed) {
    var rng = mulberry32(seed | 0);
    // Prepare a fresh deep-ish copy of the level so step() never mutates it.
    var lvl = JSON.parse(JSON.stringify(level));
    if (!lvl.seacorns) lvl.seacorns = 0;
    if (!lvl.required) lvl.required = 0;
    if (!lvl.rocks) lvl.rocks = [];
    if (!lvl.whirlpools) lvl.whirlpools = [];
    if (!lvl.jellyfish) lvl.jellyfish = [];
    if (!lvl.currents) lvl.currents = [];
    if (!lvl.bubbles) lvl.bubbles = [];
    if (!lvl.stable) lvl.stable = { x: 0, y: 0, w: 10, h: 10 };
    if (!lvl.spawn) lvl.spawn = { x: lvl.width / 2, y: lvl.height / 2, r: 100 };
    if (!lvl.player) lvl.player = { x: 60, y: 60 };
    if (!lvl.timeLimitSec) lvl.timeLimitSec = 120;

    var count = lvl.seacorns;
    var positions = spawnSeacornPositions(lvl, count, rng);
    var seacorns = [];
    for (var i = 0; i < count; i++) {
      var p = positions[i] || { x: lvl.spawn.x, y: lvl.spawn.y };
      seacorns.push({ id: i, x: p.x, y: p.y, vx: 0, vy: 0, rescued: false });
    }
    var bubbleObj = [];
    for (var b = 0; b < lvl.bubbles.length; b++) {
      bubbleObj.push({ x: lvl.bubbles[b].x, y: lvl.bubbles[b].y });
    }
    var world = {
      tick: 0,
      status: "playing",
      rescued: 0,
      required: lvl.required,
      octopus: { x: lvl.player.x, y: lvl.player.y, ink: 100, stunned: 0 },
      seacorns: seacorns,
      inkClouds: [],
      bubbles: bubbleObj,
      lastInkTick: -100000,
      level: lvl
    };
    return world;
  }

  function seacornForces(world, s, forces, unrescued, ox, oy) {
    // follow octopus loosely: stronger when far, stops when close
    var d = dist(s.x, s.y, ox, oy);
    if (d > 40) {
      var w = clamp((d - 40) / 70, 0, 1.4);
      forces.x += ((ox - s.x) / (d || 1)) * w * 0.55;
      forces.y += ((oy - s.y) / (d || 1)) * w * 0.55;
    }
    // flocking: cohesion + separation + alignment with nearby unrescued seacorns
    var cx = 0, cy = 0, n = 0, ax = 0, ay = 0, sepX = 0, sepY = 0;
    for (var j = 0; j < unrescued.length; j++) {
      var o = unrescued[j];
      if (o.id === s.id) continue;
      var dd = dist(s.x, s.y, o.x, o.y);
      if (dd < 140) {
        cx += o.x; cy += o.y; ax += o.vx; ay += o.vy; n++;
        if (dd < 55) {
          var ws = (55 - dd) / 55;
          sepX += (s.x - o.x) / (dd || 1) * ws * 2.1;
          sepY += (s.y - o.y) / (dd || 1) * ws * 2.1;
        }
      }
    }
    if (n > 0) {
      cx /= n; cy /= n; ax /= n; ay /= n;
      forces.x += clamp((cx - s.x) * 0.0016, -0.09, 0.09);
      forces.y += clamp((cy - s.y) * 0.0016, -0.09, 0.09);
      forces.x += (ax - s.vx) * 0.12;
      forces.y += (ay - s.vy) * 0.12;
    }
    forces.x += sepX;
    forces.y += sepY;
  }

  function step(world, input) {
    if (!world) return world;
    if (world.status !== "playing") return world;
    input = input || {};
    var lvl = world.level;
    world.tick += 1;

    // ---- octopus ---------------------------------------------------
    var oc = world.octopus;
    var dxIn = 0, dyIn = 0;
    if (input.left) dxIn -= 1;
    if (input.right) dxIn += 1;
    if (input.up) dyIn -= 1;
    if (input.down) dyIn += 1;

    if (oc.stunned > 0) {
      oc.stunned -= 1;
    } else if (dxIn !== 0 || dyIn !== 0) {
      var mag = Math.sqrt(dxIn * dxIn + dyIn * dyIn);
      oc.x += (dxIn / mag) * OCCUPUS_SPEED;
      oc.y += (dyIn / mag) * OCCUPUS_SPEED;
    }

    // apply whirlpool pull to octopus
    var i;
    for (i = 0; i < lvl.whirlpools.length; i++) {
      var wp = lvl.whirlpools[i];
      var d = dist(oc.x, oc.y, wp.x, wp.y);
      if (d < wp.r && d > 1) {
        var pull = wp.strength * (1 - d / wp.r);
        oc.x += ((wp.x - oc.x) / d) * pull;
        oc.y += ((wp.y - oc.y) / d) * pull;
      }
    }

    // keep octopus inside bounds
    oc.x = clamp(oc.x, 0, lvl.width);
    oc.y = clamp(oc.y, 0, lvl.height);

    // rocks block octopus
    for (i = 0; i < lvl.rocks.length; i++) {
      var rk = lvl.rocks[i];
      var rd = dist(oc.x, oc.y, rk.x, rk.y);
      var min = rk.r + INK_RADIUS;
      if (rd < min) {
        var nx = (oc.x - rk.x) / (rd || 1);
        var ny = (oc.y - rk.y) / (rd || 1);
        oc.x = rk.x + nx * min;
        oc.y = rk.y + ny * min;
      }
    }

    // jellyfish stun (only when not already stunned)
    if (oc.stunned <= 0) {
      for (i = 0; i < lvl.jellyfish.length; i++) {
        var jz = jellyPosition(lvl.jellyfish[i], world.tick);
        if (dist(oc.x, oc.y, jz.x, jz.y) < 34) {
          oc.stunned = STUN_TICKS;
          break;
        }
      }
    }

    // bubbles: touch to collect
    var remaining = [];
    for (i = 0; i < world.bubbles.length; i++) {
      var b = world.bubbles[i];
      if (dist(oc.x, oc.y, b.x, b.y) < 26) {
        oc.ink = Math.min(100, oc.ink + BUBBLE_INK);
      } else {
        remaining.push(b);
      }
    }
    world.bubbles = remaining;

    // ink cloud creation
    if (input.ink && oc.ink >= INK_MIN && (world.tick - world.lastInkTick) >= INK_GAP_TICKS) {
      oc.ink -= INK_COST;
      world.lastInkTick = world.tick;
      world.inkClouds.push({ x: oc.x, y: oc.y, r: 10, ttl: CLOUD_TTL });
    }

    // age ink clouds
    for (i = 0; i < world.inkClouds.length; i++) {
      var cl = world.inkClouds[i];
      cl.ttl -= 1;
      cl.r = Math.min(cl.r + 0.85, CLOUD_MAX_R);
    }
    world.inkClouds = world.inkClouds.filter(function (c) { return c.ttl > 0; });

    // ---- seacorns ---------------------------------------------------
    var unrescued = [];
    for (i = 0; i < world.seacorns.length; i++) {
      if (!world.seacorns[i].rescued) unrescued.push(world.seacorns[i]);
    }
    for (i = 0; i < unrescued.length; i++) {
      var s = unrescued[i];
      var forces = { x: 0, y: 0 };

      seacornForces(world, s, forces, unrescued, oc.x, oc.y);

      // currents push the herd
      for (var ci = 0; ci < lvl.currents.length; ci++) {
        var cur = lvl.currents[ci];
        if (s.x >= cur.x && s.x <= cur.x + cur.w && s.y >= cur.y && s.y <= cur.y + cur.h) {
          forces.x += cur.dx * 0.14;
          forces.y += cur.dy * 0.14;
        }
      }

      // ink cloud repulsion
      for (var kc = 0; kc < world.inkClouds.length; kc++) {
        var c = world.inkClouds[kc];
        var dc = dist(s.x, s.y, c.x, c.y);
        var reach = c.r + 26;
        if (dc < reach && dc > 0.5) {
          var f = (reach - dc) / reach * 1.7;
          forces.x += ((s.x - c.x) / dc) * f;
          forces.y += ((s.y - c.y) / dc) * f;
        }
      }

      // whirlpools pull seacorns
      for (var wi = 0; wi < lvl.whirlpools.length; wi++) {
        var w = lvl.whirlpools[wi];
        var d2 = dist(s.x, s.y, w.x, w.y);
        if (d2 < w.r && d2 > 1) {
          var wp2 = w.strength * (1 - d2 / w.r);
          s.vx += ((w.x - s.x) / d2) * wp2 * 0.10;
          s.vy += ((w.y - s.y) / d2) * wp2 * 0.10;
        }
      }

      s.vx += forces.x;
      s.vy += forces.y;
      // damping
      s.vx *= 0.86;
      s.vy *= 0.86;
      // speed cap
      var sp = Math.sqrt(s.vx * s.vx + s.vy * s.vy);
      if (sp > SEACORN_SPEED) {
        s.vx = (s.vx / sp) * SEACORN_SPEED;
        s.vy = (s.vy / sp) * SEACORN_SPEED;
      }
      s.x += s.vx;
      s.y += s.vy;

      // rocks: push out so centre never inside rock
      for (var ri = 0; ri < lvl.rocks.length; ri++) {
        var rr = lvl.rocks[ri];
        var dR = dist(s.x, s.y, rr.x, rr.y);
        if (dR < rr.r) {
          var mx = (s.x - rr.x) / (dR || 1);
          var my = (s.y - rr.y) / (dR || 1);
          s.x = rr.x + mx * rr.r;
          s.y = rr.y + my * rr.r;
        }
      }

      // bounds
      s.x = clamp(s.x, 0, lvl.width);
      s.y = clamp(s.y, 0, lvl.height);

      // rescue check
      if (!s.rescued && inRect(s.x, s.y, lvl.stable)) {
        s.rescued = true;
        s.vx = 0;
        s.vy = 0;
        // keep it inside the stable
        s.x = clamp(s.x, lvl.stable.x + 4, lvl.stable.x + lvl.stable.w - 4);
        s.y = clamp(s.y, lvl.stable.y + 4, lvl.stable.y + lvl.stable.h - 4);
      }
    }

    // rescued count must always match rescued flags
    var count = 0;
    for (i = 0; i < world.seacorns.length; i++) {
      if (world.seacorns[i].rescued) count += 1;
    }
    world.rescued = count;

    // keep rescued ones pinned inside the stable
    for (i = 0; i < world.seacorns.length; i++) {
      var sr = world.seacorns[i];
      if (sr.rescued) {
        sr.x = clamp(sr.x, lvl.stable.x + 2, lvl.stable.x + lvl.stable.w - 2);
        sr.y = clamp(sr.y, lvl.stable.y + 2, lvl.stable.y + lvl.stable.h - 2);
        sr.vx = 0;
        sr.vy = 0;
      }
    }

    // win / lose
    if (world.rescued >= world.required) {
      world.status = "won";
    } else if (world.tick >= lvl.timeLimitSec * TICKS_PER_SEC) {
      world.status = "lost";
    }

    return world;
  }

  // ----- content hashing -------------------------------------------------
  function canonical(v) {
    if (v === null || typeof v !== "object") return JSON.stringify(v);
    if (Array.isArray(v)) {
      return "[" + v.map(canonical).join(",") + "]";
    }
    var keys = Object.keys(v).sort();
    var parts = [];
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      parts.push(JSON.stringify(k) + ":" + canonical(v[k]));
    }
    return "{" + parts.join(",") + "}";
  }

  function fnv1a(str, seed) {
    var h = seed >>> 0;
    for (var i = 0; i < str.length; i++) {
      h ^= str.charCodeAt(i);
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h >>> 0;
  }

  function hash(world) {
    var s = canonical(world);
    var h1 = fnv1a(s, 0x811c9dc5);
    var h2 = fnv1a(s + "#r", 0xdeadbeef);
    var h = (h1 ^ ((h2 >>> 9) >>> 0)) >>> 0;
    h ^= fnv1a(s + "?", 0x9e3779b9);
    return (h >>> 0).toString(16).padStart(8, "0");
  }

  function serialize(world) {
    return JSON.stringify(world);
  }

  function deserialize(str) {
    var w = JSON.parse(str);
    return w;
  }

  // ----- autopilot (read-only) -------------------------------------------------
  function autopilotInput(world) {
    var lvl = world.level;
    var oc = world.octopus;
    var i;
    if (world.status !== "playing") {
      return { up: false, down: false, left: false, right: false, ink: false };
    }

    var anyUnrescued = false;
    for (i = 0; i < world.seacorns.length; i++) {
      if (!world.seacorns[i].rescued) anyUnrescued = true;
    }
    if (!anyUnrescued) {
      return { up: false, down: false, left: false, right: false, ink: false };
    }

    var sx = lvl.stable.x + lvl.stable.w / 2;
    var sy = lvl.stable.y + lvl.stable.h / 2;
    var dxS = sx - oc.x;
    var dyS = sy - oc.y;
    var dS = Math.sqrt(dxS * dxS + dyS * dyS) || 1;
    var dirX = dxS / dS;
    var dirY = dyS / dS;

    if (inRect(oc.x, oc.y, lvl.stable)) {
      return { up: false, down: false, left: false, right: false, ink: false };
    }

    var jzPos = [];
    for (i = 0; i < lvl.jellyfish.length; i++) {
      jzPos.push(jellyPosition(lvl.jellyfish[i], world.tick));
    }

    var bestScore = -Infinity;
    var bestDx = dirX;
    var bestDy = dirY;
    var probe = 130;
    var bestCandidate = null;
    for (var k = 0; k < 16; k++) {
      var a = (k / 16) * Math.PI * 2;
      var dxc = Math.cos(a);
      var dyc = Math.sin(a);
      var tx = oc.x + dxc * probe;
      var ty = oc.y + dyc * probe;
      var score = dxc * dirX + dyc * dirY;

      if (tx < 4 || tx > lvl.width - 4 || ty < 4 || ty > lvl.height - 4) score -= 2.5;

      for (i = 0; i < lvl.rocks.length; i++) {
        var r = lvl.rocks[i];
        var rd = Math.sqrt((tx - r.x) * (tx - r.x) + (ty - r.y) * (ty - r.y));
        var reach = r.r + 70;
        if (rd < reach) score -= 4.0 * (1 - (rd - r.r) / 70);
      }
      for (i = 0; i < lvl.whirlpools.length; i++) {
        var wp = lvl.whirlpools[i];
        var wd = Math.sqrt((tx - wp.x) * (tx - wp.x) + (ty - wp.y) * (ty - wp.y));
        var wr = wp.r + 50;
        if (wd < wr) score -= 4.0 * (1 - (wd - wp.r) / 50);
      }
      for (i = 0; i < jzPos.length; i++) {
        var jd = Math.sqrt((tx - jzPos[i].x) * (tx - jzPos[i].x) + (ty - jzPos[i].y) * (ty - jzPos[i].y));
        if (jd < 100) score -= 2.0 * (1 - jd / 100);
      }

      if (score > bestScore) {
        bestScore = score;
        bestDx = dxc; bestDy = dyc;
      }
    }

    var input = { up: false, down: false, left: false, right: false, ink: false };
    if (bestDx < -0.3) input.left = true;
    if (bestDx > 0.3) input.right = true;
    if (bestDy < -0.3) input.up = true;
    if (bestDy > 0.3) input.down = true;
    return input;
  }

  return {
    createWorld: createWorld,
    step: step,
    hash: hash,
    serialize: serialize,
    deserialize: deserialize,
    autopilotInput: autopilotInput,
    TICKS_PER_SEC: TICKS_PER_SEC,
    _mulberry32: mulberry32,
    _jellyPosition: jellyPosition,
    _VERSION: 1
  };
});
