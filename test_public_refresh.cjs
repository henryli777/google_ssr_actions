const {test} = require('node:test');
const assert = require('node:assert/strict');
const {createReader, watch, preserveText} = require('./static/public-refresh.js');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');

function server(files) {
  return async path => {
    const value = typeof files[path] === 'function' ? files[path]() : files[path];
    return new Response(value === undefined ? '' : JSON.stringify(value), {status:value === undefined ? 404 : 200});
  };
}
const health = stamp => ({build_time_utc:stamp, source_alive:1});

test('deadline includes a stalled body and permits a subsequent retry', async () => {
  let stalled = true;
  const reader = createReader({timeoutMs:15, resources:['sub/url_meta.json'], fetch:async path => {
    if (stalled) return {ok:true, text:() => new Promise(() => {})};
    return server({'health.json':health('one'), 'sub/url_meta.json':[]})(path);
  }});
  await assert.rejects(reader.refresh(), /deadline/);
  stalled = false;
  assert.equal((await reader.refresh()).changed, true);
});

test('only a complete consistent snapshot replaces last success', async () => {
  const files = {'health.json':health('one'), 'sub/url_meta.json':[{url:'old'}]};
  const reader = createReader({fetch:server(files), resources:['sub/url_meta.json']});
  await reader.refresh();
  files['health.json'] = health('two');
  delete files['sub/url_meta.json'];
  await assert.rejects(reader.refresh(), /404/);
  assert.deepEqual(await (await reader.response('sub/url_meta.json')).json(), [{url:'old'}]);
  files['sub/url_meta.json'] = [{url:'new'}];
  assert.equal((await reader.refresh()).changed, true);
  assert.deepEqual(await (await reader.response('sub/url_meta.json')).json(), [{url:'new'}]);
  assert.equal((await reader.refresh()).changed, false);
});

test('deployment changing during reads is rejected without mixing generations', async () => {
  let stamp = 0;
  const reader = createReader({resources:['sub/url_meta.json'], fetch:server({
    'health.json':() => health(String(++stamp)), 'sub/url_meta.json':[]
  })});
  await assert.rejects(reader.refresh(), /changed during/);
  assert.equal(reader.current(), null);
});

test('malformed data keeps the previous verified generation', async () => {
  const files = {'health.json':health('one'), 'sub/url_meta.json':[]};
  const reader = createReader({fetch:server(files), resources:['sub/url_meta.json']});
  await reader.refresh();
  files['health.json'] = health('two');
  files['sub/url_meta.json'] = {not:'an array'};
  await assert.rejects(reader.refresh(), /Invalid public data/);
  assert.equal(reader.current().health.build_time_utc, 'one');
});

test('simultaneous refreshes coalesce and optional failures do not poison required data', async () => {
  const reader = createReader({fetch:server({'health.json':health('one'), 'sub/url_meta.json':[]}),
    resources:['sub/url_meta.json'], optional:['data/speed_ranking.json']});
  const first = reader.refresh();
  assert.equal(reader.refresh(), first);
  await first;
  assert.equal((await reader.response('data/speed_ranking.json')).status, 404);
});

test('missing optional data retries without replacing unchanged primary data', async () => {
  const files = {'health.json':health('one'), 'sub/url_meta.json':[{url:'published'}]};
  const calls = [];
  const serve = server(files);
  const reader = createReader({fetch:async path => {calls.push(path); return serve(path);},
    resources:['sub/url_meta.json'], optional:['data/speed_ranking.json']});
  await reader.refresh();
  const original = reader.current();
  calls.length = 0;
  files['data/speed_ranking.json'] = {ranking:[{rank:1}]};
  const recovered = await reader.refresh();
  assert.equal(recovered.changed, false);
  assert.deepEqual(recovered.optionalChanged, ['data/speed_ranking.json']);
  assert.equal(reader.current().values['sub/url_meta.json'], original.values['sub/url_meta.json']);
  assert.equal(calls.includes('sub/url_meta.json'), false);
  assert.deepEqual(await (await reader.response('data/speed_ranking.json')).json(), files['data/speed_ranking.json']);
  calls.length = 0;
  assert.equal((await reader.refresh()).changed, false);
  assert.deepEqual(calls, ['health.json']);
});

test('optional recovery rejects a publication switch and retains last complete data', async () => {
  const files = {'health.json':health('one'), 'sub/url_meta.json':[]};
  const serve = server(files);
  const reader = createReader({fetch:async path => {
    const response = await serve(path);
    if (path === 'data/speed_ranking.json' && files[path]) files['health.json'] = health('two');
    return response;
  }, resources:['sub/url_meta.json'], optional:['data/speed_ranking.json']});
  await reader.refresh();
  files['data/speed_ranking.json'] = {ranking:[{rank:1}]};
  await assert.rejects(reader.refresh(), /changed during/);
  assert.equal(reader.current().health.build_time_utc, 'one');
  assert.equal((await reader.response('data/speed_ranking.json')).status, 404);
});

test('browser optional recovery redraws only its own view without resetting primary controls', async () => {
  const files = {'health.json':health('one'), 'sub/url_meta.json':[],
    'sub/stats_daily.json':[], 'sub/stats_7day_enhanced.json':[]};
  const handlers = {};
  const status = {style:{}, setAttribute:()=>{}};
  let primaryLoads = 0, speedLoads = 0;
  const window = {fetch:server(files), location:{href:'https://fixture.invalid/'},
    addEventListener:(name, fn) => {handlers[name] = fn;},
    removeEventListener:()=>{}, setInterval:()=>1, clearInterval:()=>{},
    loadMeta:() => {primaryLoads++;}, loadSpeedRanking:() => {speedLoads++;},
    document:{visibilityState:'visible', getElementById:() => null, querySelector:() => null,
      querySelectorAll:() => [], createElement:() => status,
      addEventListener:(name, fn) => {handlers[name] = fn;}, removeEventListener:()=>{}}};
  const scope = vm.createContext({window, URL, Response, AbortController, setTimeout, clearTimeout});
  vm.runInContext(readFileSync('./static/public-refresh.js', 'utf8'), scope);
  handlers.DOMContentLoaded();
  await handlers.focus();
  assert.equal(primaryLoads, 1);
  assert.equal(speedLoads, 1);
  files['data/speed_ranking.json'] = {ranking:[{rank:1}]};
  await handlers.focus();
  assert.equal(primaryLoads, 1);
  assert.equal(speedLoads, 2);
});

test('watch refreshes every 60 seconds only in foreground and on focus', async () => {
  const handlers = {};
  let tick, interval, calls = 0;
  const target = {addEventListener:(name, fn) => handlers[name] = fn, removeEventListener:()=>{}};
  const document = {...target, visibilityState:'visible'};
  const stop = watch(async () => {calls++;}, {target, document,
    setInterval:(fn, ms) => {tick=fn; interval=ms; return 1;}, clearInterval:()=>{}});
  assert.equal(interval, 60000);
  await tick();
  document.visibilityState = 'hidden';
  await tick();
  assert.equal(calls, 1);
  document.visibilityState = 'visible';
  await handlers.focus();
  assert.equal(calls, 2);
  stop();
});

test('source text updates preserve selection and scroll and do not rewrite unchanged content', () => {
  let writes = 0, value = 'old nodes';
  const field = {get value(){return value;}, set value(next){writes++; value=next;},
    selectionStart:2, selectionEnd:5, selectionDirection:'backward', scrollTop:70,
    setSelectionRange(start,end,direction){this.selectionStart=start;this.selectionEnd=end;this.selectionDirection=direction;}};
  preserveText(field, 'old nodes');
  assert.equal(writes, 0);
  preserveText(field, 'new nodes and more');
  assert.equal(writes, 1);
  assert.equal(field.selectionStart, 2);
  assert.equal(field.selectionEnd, 5);
  assert.equal(field.scrollTop, 70);
});

test('trend recovers after an empty published generation', async () => {
  let values = [];
  const context2d = new Proxy({}, {get:() => () => {}});
  const canvas = {style:{}, clientWidth:400, getContext:() => context2d};
  const scope = vm.createContext({
    console,
    document:{getElementById:() => canvas},
    GoogleSSRRefresh:{response:async () => new Response(JSON.stringify(values))}
  });
  const template = readFileSync('./static/index.html.tpl', 'utf8');
  const scripts = [...template.matchAll(/<script>([\s\S]*?)<\/script>/g)];
  vm.runInContext(scripts[1][1], scope);
  await scope.loadTrend7Day();
  assert.equal(canvas.style.display, 'none');
  values = [{date:'2026-10-15', new_added:2, alive_count:5}, {date:'2026-10-16', new_added:1, alive_count:6}];
  await scope.loadTrend7Day();
  assert.notEqual(canvas.style.display, 'none');
});
