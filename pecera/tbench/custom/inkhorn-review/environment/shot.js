#!/usr/bin/env node
// Screenshot helper for reviewing a browser game.
// Usage: node /opt/shot.js <out.png> [step ...]
// Steps run in order after the page loads:
//   js:<code>        run JavaScript in the page (for example js:window.InkhornReef.startLevel(2))
//   click:<selector> click the first element matching a CSS selector
//   key:<Key>:<ms>   hold a key for ms milliseconds (Key is ArrowRight, ArrowLeft, ArrowUp, ArrowDown, Space, KeyP, KeyR, KeyM, Escape)
//   wait:<ms>        wait
//   shot:<file.png>  take an extra screenshot now
// The final screenshot goes to <out.png>. Console errors are printed at the end.
// Options by environment: PAGE (default file:///app/game/index.html), SIZE (default 1280x800).
'use strict';
const { spawn } = require('child_process');
const fs = require('fs');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const [, , out, ...steps] = process.argv;
if (!out) { console.error('usage: node /opt/shot.js <out.png> [step ...]'); process.exit(2); }
const page = process.env.PAGE || 'file:///app/game/index.html';
const [W, H] = (process.env.SIZE || '1280x800').split('x').map(Number);
const bin = ['chromium', 'google-chrome', 'chromium-browser'].find(b => { try { require('child_process').execSync('command -v ' + b, { stdio: 'ignore' }); return true; } catch (e) { return false; } });
const port = 9300 + Math.floor(Math.random() * 500) + 200;
const chrome = spawn(bin, ['--headless=new', '--no-sandbox', '--disable-gpu', `--remote-debugging-port=${port}`, `--window-size=${W},${H}`, 'about:blank'], { stdio: 'ignore' });
const codes = { ArrowRight: 39, ArrowLeft: 37, ArrowUp: 38, ArrowDown: 40, Space: 32, KeyP: 80, KeyR: 82, KeyM: 77, Escape: 27, Enter: 13 };
const keyName = { Space: ' ', KeyP: 'p', KeyR: 'r', KeyM: 'm' };
(async () => {
  let targets = null;
  for (let i = 0; i < 40 && !targets; i++) { await sleep(250); try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); } catch (e) {} }
  const tgt = targets.find(t => t.type === 'page');
  const ws = new WebSocket(tgt.webSocketDebuggerUrl); await new Promise(r => ws.onopen = r);
  let id = 0; const pend = {}; const errors = [];
  ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pend[m.id]) { pend[m.id](m); delete pend[m.id]; }
    else if (m.method === 'Runtime.exceptionThrown') errors.push(m.params.exceptionDetails.exception ? m.params.exceptionDetails.exception.description : m.params.exceptionDetails.text);
    else if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') errors.push(m.params.args.map(a => a.value || a.description).join(' ')); };
  const send = (method, params = {}) => new Promise(r => { const i = ++id; pend[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
  const snap = async f => { const r = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(f, Buffer.from(r.result.data, 'base64')); console.log('saved ' + f); };
  await send('Runtime.enable'); await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: 1, mobile: false });
  await send('Page.navigate', { url: page }); await sleep(1500);
  for (const s of steps) {
    const i = s.indexOf(':'); const kind = s.slice(0, i), arg = s.slice(i + 1);
    if (kind === 'js') { const r = await send('Runtime.evaluate', { expression: arg, returnByValue: true, awaitPromise: true }); const v = r.result.exceptionDetails ? 'ERROR ' + (r.result.exceptionDetails.exception || {}).description : JSON.stringify(r.result.result.value); console.log('js -> ' + v); }
    else if (kind === 'click') { await send('Runtime.evaluate', { expression: `(function(){var e=document.querySelector(${JSON.stringify(arg)}); if(!e) return 'not found'; e.click(); return 'clicked'})()`, returnByValue: true }).then(r => console.log('click ' + arg + ' -> ' + r.result.result.value)); }
    else if (kind === 'key') { const [k, ms] = arg.split(':'); const p = { code: k, key: keyName[k] || k, windowsVirtualKeyCode: codes[k] || 0 }; await send('Input.dispatchKeyEvent', { type: 'keyDown', ...p }); await sleep(+ms || 100); await send('Input.dispatchKeyEvent', { type: 'keyUp', ...p }); }
    else if (kind === 'wait') await sleep(+arg);
    else if (kind === 'shot') await snap(arg);
    else console.log('unknown step ' + s);
  }
  await sleep(300); await snap(out);
  console.log(errors.length ? 'CONSOLE ERRORS:\n' + errors.join('\n') : 'no console errors');
  ws.close(); chrome.kill(); process.exit(0);
})().catch(e => { console.error(e); chrome.kill(); process.exit(1); });
