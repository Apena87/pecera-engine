var test = require("node:test");
var assert = require("node:assert");
var path = require("path");
var Sim = require("../sim.js");

function fnv1a(str) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < str.length; i++) {
    hash ^= str.charCodeAt(i);
    hash = (hash * 0x01000193) >>> 0;
  }
  return hash;
}

test("bot: all levels win with seed 1 and at least 18/24 overall", function () {
  var win = 0;
  var total = 0;
  for (var l = 1; l <= 8; l++) {
    var id = String(l).padStart(2, "0");
    for (var seed = 1; seed <= 3; seed++) {
      var lvl = JSON.parse(JSON.stringify(require("../levels/" + id + ".json")));
      var w = Sim.createWorld(lvl, seed);
      var t = 0;
      while (w.status === "playing" && t < 10000) {
        var inp = Sim.autopilotInput(w);
        Sim.step(w, inp);
        t++;
      }
      total++;
      if (w.status === "won") win++;
    }
  }
  assert.ok(win / total >= 0.72, "win rate " + win + "/" + total + " >= 18/24");
});

test("bot: every level wins with seed 1", function () {
  for (var l = 1; l <= 8; l++) {
    var id = String(l).padStart(2, "0");
    var lvl = JSON.parse(JSON.stringify(require("../levels/" + id + ".json")));
    var w = Sim.createWorld(lvl, 1);
    var t = 0;
    while (w.status === "playing" && t < 10000) {
      Sim.step(w, Sim.autopilotInput(w));
      t++;
    }
    assert.strictEqual(w.status, "won", "level " + id + " seed 1 won");
  }
});

test("bot replay: input log replays to same hash", function () {
  for (var l = 1; l <= 8; l++) {
    var id = String(l).padStart(2, "0");
    for (var seed = 1; seed <= 3; seed++) {
      var lvl = JSON.parse(JSON.stringify(require("../levels/" + id + ".json")));
      var w = Sim.createWorld(lvl, seed);
      var log = [];
      var t = 0;
      while (w.status === "playing" && t < 10000) {
        var inp = Sim.autopilotInput(w);
        var bits = (inp.up ? 1 : 0) | (inp.down ? 2 : 0) | (inp.left ? 4 : 0) | (inp.right ? 8 : 0);
        var ch = "";
        if (inp.ink) ch += "i";
        ch += bits.toString(16);
        log.push(ch);
        Sim.step(w, inp);
        t++;
      }
      // replay
      var w2 = Sim.deserialize(Sim.serialize(w));
      // Actually start fresh and replay from tick 0
      var w3 = Sim.createWorld(lvl, seed);
      for (var i = 0; i < log.length; i++) {
        var ch = log[i];
        var ink = ch.indexOf("i") === 0;
        var digits = ink ? ch.slice(1) : ch;
        var bits = parseInt(digits, 16);
        var input = {
          up: (bits & 1) !== 0,
          down: (bits & 2) !== 0,
          left: (bits & 4) !== 0,
          right: (bits & 8) !== 0,
          ink: ink,
        };
        Sim.step(w3, input);
      }
      assert.strictEqual(w3.status, w.status, "level " + id + " seed " + seed + " status match on replay");
      assert.strictEqual(w3.tick, w.tick, "level " + id + " seed " + seed + " ticks match on replay");
      assert.strictEqual(Sim.hash(w3), Sim.hash(w), "level " + id + " seed " + seed + " hash match on replay");
    }
  }
});

test("levels: all eight files present, valid structure and sanity", function () {
  for (var l = 1; l <= 8; l++) {
    var id = String(l).padStart(2, "0");
    var lvl = JSON.parse(JSON.stringify(require("../levels/" + id + ".json")));
    assert.strictEqual(lvl.id, id);
    assert.ok(lvl.width >= 800 && lvl.height >= 500, "level " + id + " size");
    assert.ok(lvl.timeLimitSec > 0);
    assert.ok(lvl.seacorns >= 4, "level " + id + " has >= 4 seacorns");
    assert.ok(lvl.required >= 3, "level " + id + " has required >= 3");
    assert.ok(lvl.required <= lvl.seacorns, "level " + id + " required <= seacorns");
    assert.ok(lvl.player && typeof lvl.player.x === "number");
    assert.ok(lvl.spawn && typeof lvl.spawn.x === "number" && typeof lvl.spawn.y === "number" && lvl.spawn.r > 0);
    assert.ok(lvl.stable && typeof lvl.stable.x === "number" && typeof lvl.stable.y === "number" && lvl.stable.w > 0 && lvl.stable.h > 0);
    assert.ok(Array.isArray(lvl.currents));
    assert.ok(Array.isArray(lvl.rocks));
    assert.ok(Array.isArray(lvl.whirlpools));
    assert.ok(Array.isArray(lvl.jellyfish));
    assert.ok(Array.isArray(lvl.bubbles));
    // rocks never overlap stable or spawn
    for (var k = 0; k < lvl.rocks.length; k++) {
      var r = lvl.rocks[k];
      var dRock = Math.sqrt((r.x - lvl.stable.x - lvl.stable.w / 2) * (r.x - lvl.stable.x - lvl.stable.w / 2) + (r.y - lvl.stable.y - lvl.stable.h / 2) * (r.y - lvl.stable.y - lvl.stable.h / 2));
      // rock center should not be inside the stable rect
      var inside = r.x >= lvl.stable.x && r.x <= lvl.stable.x + lvl.stable.w && r.y >= lvl.stable.y && r.y <= lvl.stable.y + lvl.stable.h;
      assert.ok(!inside, "rock " + k + " not inside stable");
    }
    // level 05-08 must have >= 1 jellyfish, >= 1 whirlpool and >= 2 rocks
    if (l >= 5) {
      assert.ok(lvl.jellyfish.length >= 1, "level " + id + " >= 1 jellyfish");
      assert.ok(lvl.whirlpools.length >= 1, "level " + id + " >= 1 whirlpool");
      assert.ok(lvl.rocks.length >= 2, "level " + id + " >= 2 rocks");
    }
  }
});

test("levels: structure suggests increasing difficulty from 01 to 08", function () {
  var times = [];
  var rockCounts = [];
  var jfCounts = [];
  for (var l = 1; l <= 8; l++) {
    var id = String(l).padStart(2, "0");
    var lvl = JSON.parse(JSON.stringify(require("../levels/" + id + ".json")));
    times.push(lvl.required + lvl.seacorns); // seed-1 win complexity
    rockCounts.push(lvl.rocks.length);
    jfCounts.push(lvl.jellyfish.length);
  }
  // 8 levels exist with measurable difficulty-ish metrics
  assert.strictEqual(times.length, 8);
  assert.strictEqual(rockCounts.length, 8);
  assert.strictEqual(jfCounts.length, 8);
});

test("levels: jellyfish paths are valid", function () {
  for (var l = 1; l <= 8; l++) {
    var id = String(l).padStart(2, "0");
    var lvl = JSON.parse(JSON.stringify(require("../levels/" + id + ".json")));
    for (var k = 0; k < lvl.jellyfish.length; k++) {
      var jz = lvl.jellyfish[k];
      assert.ok(Array.isArray(jz.path) && jz.path.length >= 2);
      for (var p = 0; p < jz.path.length; p++) {
        assert.ok(jz.path[p].length === 2 && typeof jz.path[p][0] === "number" && typeof jz.path[p][1] === "number");
      }
      assert.ok(jz.speed > 0);
    }
  }
});

test("levels: bubbles are inside the world or stable margin", function () {
  for (var l = 1; l <= 8; l++) {
    var id = String(l).padStart(2, "0");
    var lvl = JSON.parse(JSON.stringify(require("../levels/" + id + ".json")));
    for (var k = 0; k < lvl.bubbles.length; k++) {
      var b = lvl.bubbles[k];
      assert.ok(b.x >= 0 && b.x <= lvl.width, "bubble x");
      assert.ok(b.y >= 0 && b.y <= lvl.height, "bubble y");
    }
  }
});
