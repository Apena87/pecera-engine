var test = require("node:test");
var assert = require("node:assert");
var Sim = require("../sim.js");

test("createWorld: tick=0, status=playing, required/rescued matches", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  assert.strictEqual(w.tick, 0);
  assert.strictEqual(w.status, "playing");
  assert.strictEqual(w.rescued, 0);
  assert.strictEqual(w.required, lvl.required);
  assert.strictEqual(w.seacorns.length, lvl.seacorns);
  assert.strictEqual(w.octopus.ink, 100);
  assert.strictEqual(w.octopus.stunned, 0);
});

test("createWorld: same seed twice gives identical state", function () {
  var lvl = require("../levels/01.json");
  var a = Sim.createWorld(lvl, 5);
  var b = Sim.createWorld(lvl, 5);
  assert.strictEqual(Sim.hash(a), Sim.hash(b));
});

test("createWorld: different seeds give different state", function () {
  var lvl = require("../levels/01.json");
  var a = Sim.createWorld(lvl, 1);
  var b = Sim.createWorld(lvl, 2);
  assert.notStrictEqual(Sim.hash(a), Sim.hash(b));
});

test("step: tick advances and status stays playing", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  var before = Sim.hash(w);
  Sim.step(w, { right: true });
  assert.strictEqual(w.tick, 1);
  assert.strictEqual(w.status, "playing");
  assert.notStrictEqual(Sim.hash(w), before);
});

test("hash: stable across identical steps", function () {
  var lvl = require("../levels/02.json");
  var wa = Sim.createWorld(lvl, 7);
  var wb = Sim.createWorld(lvl, 7);
  for (var i = 0; i < 30; i++) {
    var input = Sim.autopilotInput(wa);
    Sim.step(wa, input);
    Sim.step(wb, input);
  }
  assert.strictEqual(Sim.hash(wa), Sim.hash(wb));
});

test("serialize/deserialize round-trip continues identically", function () {
  var lvl = require("../levels/03.json");
  var w = Sim.createWorld(lvl, 4);
  for (var i = 0; i < 40; i++) {
    Sim.step(w, Sim.autopilotInput(w));
  }
  var s = Sim.serialize(w);
  assert.strictEqual(typeof s, "string");
  var w2 = Sim.deserialize(s);
  assert.strictEqual(Sim.hash(w), Sim.hash(w2));
  for (var j = 0; j < 30; j++) {
    var input = Sim.autopilotInput(w2);
    Sim.step(w2, input);
    Sim.step(w, input);
  }
  assert.strictEqual(Sim.hash(w), Sim.hash(w2));
});

test("octopus stays inside bounds after many steps", function () {
  var lvl = require("../levels/04.json");
  var w = Sim.createWorld(lvl, 2);
  for (var i = 0; i < 400; i++) {
    Sim.step(w, Sim.autopilotInput(w));
    assert.ok(w.octopus.x >= 0 && w.octopus.x <= lvl.width);
    assert.ok(w.octopus.y >= 0 && w.octopus.y <= lvl.height);
  }
});

test("seacorn stays inside bounds and never inside rock", function () {
  var lvl = require("../levels/05.json");
  var w = Sim.createWorld(lvl, 3);
  for (var i = 0; i < 500; i++) {
    Sim.step(w, Sim.autopilotInput(w));
    for (var j = 0; j < w.seacorns.length; j++) {
      var s = w.seacorns[j];
      assert.ok(s.x >= 0 && s.x <= lvl.width, "seacorn x bound");
      assert.ok(s.y >= 0 && s.y <= lvl.height, "seacorn y bound");
      if (!s.rescued) {
        for (var k = 0; k < lvl.rocks.length; k++) {
          var r = lvl.rocks[k];
          var d = Math.sqrt((s.x - r.x) * (s.x - r.x) + (s.y - r.y) * (s.y - r.y));
          assert.ok(d >= r.r, "seacorn not inside rock: d=" + d);
        }
      }
    }
    if (w.status !== "playing") break;
  }
});

test("ink: pressing ink with >=20 ink spawns a cloud and lowers ink by 20", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  w.octopus.ink = 50;
  w.lastInkTick = -100; // past gap
  var cloudsBefore = w.inkClouds.length;
  Sim.step(w, { ink: true });
  assert.strictEqual(w.octopus.ink, 30);
  assert.strictEqual(w.inkClouds.length, cloudsBefore + 1);
  assert.strictEqual(w.lastInkTick, 1);
});

test("ink: gap of 15 ticks enforced", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  w.octopus.ink = 100;
  w.lastInkTick = 0; // very recent ink
  Sim.step(w, { ink: true });
  assert.strictEqual(w.inkClouds.length, 0);
  assert.strictEqual(w.octopus.ink, 100);
});

test("ink: not enough ink is a no-op", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  w.octopus.ink = 19;
  Sim.step(w, { ink: true });
  assert.strictEqual(w.inkClouds.length, 0);
  assert.strictEqual(w.octopus.ink, 19);
});

test("bubble: touching adds 30 ink, up to 100", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  // place bubble exactly on octopus
  w.bubbles = [{ x: w.octopus.x, y: w.octopus.y, r: 8 }];
  w.octopus.ink = 80;
  Sim.step(w, { right: true });
  assert.strictEqual(w.octopus.ink, 100);
  assert.strictEqual(w.bubbles.length, 0);
});

test("bubble: full ink is unchanged", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  w.bubbles = [{ x: w.octopus.x, y: w.octopus.y, r: 8 }];
  w.octopus.ink = 100;
  Sim.step(w, {});
  assert.strictEqual(w.octopus.ink, 100);
});

test("jellyfish: contact stuns for STUN_TICKS", function () {
  var lvl = require("../levels/03.json");
  var w = Sim.createWorld(lvl, 1);
  // force octopus onto a jellyfish position
  var jz = lvl.jellyfish[0];
  var pos = { x: jz.path[0][0], y: jz.path[0][1] };
  // find first occurrence of the jelly on path at tick 0
  w.octopus.x = pos.x; w.octopus.y = pos.y;
  w.octopus.stunned = 0;
  Sim.step(w, {});
  assert.ok(w.octopus.stunned > 0, "octopus should be stunned");
  assert.strictEqual(w.octopus.stunned, 120);
});

test("stun: while stunned, octopus does not move and stunned decreases", function () {
  var lvl = require("../levels/03.json");
  var w = Sim.createWorld(lvl, 1);
  w.octopus.stunned = 5;
  var startX = w.octopus.x, startY = w.octopus.y;
  Sim.step(w, { right: true, down: true });
  assert.strictEqual(w.octopus.stunned, 4);
  // movement follows only when stunned == 0; when stunned, position stays
  assert.ok(Math.abs(w.octopus.x - startX) < 1e-9);
  assert.ok(Math.abs(w.octopus.y - startY) < 1e-9);
});

test("rock blocks octopus: position cannot be inside rock", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  // teleport octopus next to rock and try to move into it
  var rock = lvl.rocks[0];
  w.octopus.x = rock.x - rock.r - 1;
  w.octopus.y = rock.y;
  w.octopus.stunned = 0;
  for (var i = 0; i < 30; i++) {
    Sim.step(w, { right: true });
  }
  var d = Math.sqrt(Math.pow(w.octopus.x - rock.x, 2) + Math.pow(w.octopus.y - rock.y, 2));
  assert.ok(d >= rock.r - 0.001, "octopus outside rock: d=" + d);
});

test("whirlpool pulls a seacorn toward it", function () {
  var lvl = require("../levels/04.json");
  var w = Sim.createWorld(lvl, 1);
  var wp = lvl.whirlpools[0];
  // place a seacorn just outside whirlpool and force it to stay unrescued
  w.seacorns[0].x = wp.x + wp.r - 1;
  w.seacorns[0].y = wp.y;
  w.seacorns[0].vx = 0; w.seacorns[0].vy = 0; w.seacorns[0].rescued = false;
  var before = Math.sqrt((w.seacorns[0].x - wp.x) * (w.seacorns[0].x - wp.x) + (w.seacorns[0].y - wp.y) * (w.seacorns[0].y - wp.y));
  Sim.step(w, {});
  var after = Math.sqrt((w.seacorns[0].x - wp.x) * (w.seacorns[0].x - wp.x) + (w.seacorns[0].y - wp.y) * (w.seacorns[0].y - wp.y));
  assert.ok(after <= before, "seacorn pulled toward whirlpool, before=" + before + " after=" + after);
});

test("seacorn rescued when inside stable, stays rescued", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  // place seacorn inside stable
  w.seacorns[0].x = lvl.stable.x + 10;
  w.seacorns[0].y = lvl.stable.y + 10;
  w.seacorns[0].rescued = false;
  Sim.step(w, {});
  assert.strictEqual(w.seacorns[0].rescued, true);
  var r1 = w.rescued;
  Sim.step(w, {});
  assert.strictEqual(w.rescued, r1);
  assert.strictEqual(w.seacorns[0].rescued, true);
});

test("world becomes won when rescued >= required", function () {
  var lvl = JSON.parse(JSON.stringify(require("../levels/01.json")));
  var w = Sim.createWorld(lvl, 1);
  w.required = 1; // force a win with 1 rescue
  w.seacorns[0].x = lvl.stable.x + 10; w.seacorns[0].y = lvl.stable.y + 10;
  w.seacorns[0].rescued = false;
  Sim.step(w, {});
  assert.strictEqual(w.status, "won");
});

test("world becomes lost when time limit reached and not won", function () {
  var lvl = JSON.parse(JSON.stringify(require("../levels/01.json")));
  lvl.timeLimitSec = 1; // 60 ticks
  lvl.required = lvl.seacorns + 1; // impossible win
  var w = Sim.createWorld(lvl, 1);
  for (var i = 0; i < 70; i++) {
    Sim.step(w, {});
    if (w.status === "lost") break;
  }
  assert.strictEqual(w.status, "lost");
});

test("autopilotInput is read-only and returns valid keys", function () {
  var lvl = require("../levels/02.json");
  var w = Sim.createWorld(lvl, 1);
  var before = Sim.hash(w);
  var inp = Sim.autopilotInput(w);
  assert.ok(inp && typeof inp === "object");
  assert.ok(Object.prototype.hasOwnProperty.call(inp, "up"));
  assert.ok(Object.prototype.hasOwnProperty.call(inp, "down"));
  assert.ok(Object.prototype.hasOwnProperty.call(inp, "left"));
  assert.ok(Object.prototype.hasOwnProperty.call(inp, "right"));
  assert.ok(Object.prototype.hasOwnProperty.call(inp, "ink"));
  assert.strictEqual(Sim.hash(w), before);
});

test("autopilotInput after win returns harmless input", function () {
  var lvl = JSON.parse(JSON.stringify(require("../levels/01.json")));
  lvl.required = 1;
  var w = Sim.createWorld(lvl, 1);
  w.rescued = 1; // won
  w.status = "won";
  var inp = Sim.autopilotInput(w);
  assert.strictEqual(inp.up, false);
  assert.strictEqual(inp.down, false);
  assert.strictEqual(inp.left, false);
  assert.strictEqual(inp.right, false);
  assert.strictEqual(inp.ink, false);
});

test("spawn: seacorns spawn inside spawn circle, never inside rock or stable", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  for (var i = 0; i < w.seacorns.length; i++) {
    var s = w.seacorns[i];
    var d = Math.sqrt((s.x - lvl.spawn.x) * (s.x - lvl.spawn.x) + (s.y - lvl.spawn.y) * (s.y - lvl.spawn.y));
    assert.ok(d <= lvl.spawn.r + 1e-6, "seacorn inside spawn circle");
    var r;
    for (var k = 0; k < lvl.rocks.length; k++) {
      r = lvl.rocks[k];
      var dk = Math.sqrt((s.x - r.x) * (s.x - r.x) + (s.y - r.y) * (s.y - r.y));
      assert.ok(dk >= r.r, "seacorn not inside rock");
    }
    assert.ok(!(s.x >= lvl.stable.x && s.x <= lvl.stable.x + lvl.stable.w && s.y >= lvl.stable.y && s.y <= lvl.stable.y + lvl.stable.h), "seacorn not in stable");
  }
});

test("autopilotInput does not collide stable when already there", function () {
  var lvl = require("../levels/01.json");
  var w = Sim.createWorld(lvl, 1);
  w.octopus.x = lvl.stable.x + 10;
  w.octopus.y = lvl.stable.y + 10;
  var inp = Sim.autopilotInput(w);
  assert.strictEqual(inp.up, false);
  assert.strictEqual(inp.down, false);
  assert.strictEqual(inp.left, false);
  assert.strictEqual(inp.right, false);
});
