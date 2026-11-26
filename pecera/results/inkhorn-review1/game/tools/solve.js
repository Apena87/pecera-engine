#!/usr/bin/env node
// Plays a level of Inkhorn Reef with Sim.autopilotInput and prints the result line.
// Usage: node tools/solve.js <level file> <seed>
var fs = require('fs');
var path = require('path');
var Sim = require('../sim.js');

var levelPath = process.argv[2];
var seedArg = parseInt(process.argv[3] || "1", 10);
if (!levelPath) {
  console.error("usage: node tools/solve.js <level file> <seed>");
  process.exit(2);
}
var level = JSON.parse(fs.readFileSync(levelPath, "utf8"));

var world = Sim.createWorld(level, seedArg);
var log = "";
var maxTicks = 60 * (level.timeLimitSec + 5); // a bit beyond
var ticks = 0;
while (world.status === "playing" && ticks < maxTicks) {
  var input = Sim.autopilotInput(world);
  var bits = 0;
  if (input.up) bits |= 1;
  if (input.down) bits |= 2;
  if (input.left) bits |= 4;
  if (input.right) bits |= 8;
  var ch = input.ink ? "i" + bits.toString(16) : bits.toString(16);
  log += ch;
  Sim.step(world, input);
  ticks += 1;
}

var result = world.status === "won" ? "won" : "lost";
console.log(JSON.stringify({ result: result, ticks: ticks, inputs: log }));
