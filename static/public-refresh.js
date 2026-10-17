(function (root) {
  'use strict';
  function createReader(options = {}) {
    const fetcher = options.fetch || root.fetch.bind(root);
    const resources = options.resources || [];
    const optional = options.optional || [];
    const now = options.now || Date.now;
    const absentOptional = new Map();
    let snapshot = null, pending = null;
    async function read(path) {
      if (/^(?:[a-z]+:|\/|\.\.)/i.test(path)) throw new Error('Only relative same-origin data is allowed');
      const controller = new AbortController();
      let timer;
      try {
        return await Promise.race([
          (async () => {
            const response = await fetcher(path, {cache:'no-store', credentials:'same-origin', redirect:'error', signal:controller.signal});
            if (!response.ok) throw Object.assign(new Error('HTTP ' + response.status + ': ' + path), {status:response.status});
            const text = await response.text();
            return path.endsWith('.json') ? JSON.parse(text) : text;
          })(),
          new Promise((_, reject) => {timer = setTimeout(() => {
            reject(new Error('Data request deadline exceeded: ' + path));
            controller.abort();
          }, options.timeoutMs || 12000);})
        ]);
      } finally {clearTimeout(timer);}
    }
    async function readOptional(paths, values, key) {
      await Promise.all(paths.map(async path => {
        try {
          values[path] = await read(path);
          absentOptional.delete(path);
        } catch (error) {
          values[path] = null;
          if (error.status === 404 || error.status === 410) {
            absentOptional.set(path, {key, retryAt:now() + 15 * 60000});
          } else absentOptional.delete(path);
        }
      }));
    }
    async function collect() {
      const before = await read('health.json');
      if (!before || typeof before.build_time_utc !== 'string' || !before.build_time_utc) throw new Error('Invalid build health');
      const key = JSON.stringify(before);
      if (snapshot && snapshot.key === key) {
        const missing = optional.filter(path => {
          const absent = absentOptional.get(path);
          return snapshot.values[path] == null && (!absent || absent.key !== key || now() >= absent.retryAt);
        });
        if (!missing.length) return {changed:false, snapshot};
        const values = {...snapshot.values};
        await readOptional(missing, values, key);
        const optionalChanged = missing.filter(path => values[path] != null);
        if (!optionalChanged.length) return {changed:false, snapshot};
        const after = await read('health.json');
        if (key !== JSON.stringify(after)) throw new Error('Publication changed during data reads; retry later');
        snapshot = {...snapshot, values};
        return {changed:false, optionalChanged, snapshot};
      }
      const values = {'health.json':before};
      await Promise.all(resources.map(async path => {
        const value = await read(path);
        if (path.endsWith('.json') && (path.includes('/providers/') ? !value || typeof value !== 'object' || Array.isArray(value) : !Array.isArray(value))) {
          throw new Error('Invalid public data: ' + path);
        }
        values[path] = value;
      }));
      await readOptional(optional, values, key);
      const after = await read('health.json');
      if (key !== JSON.stringify(after)) throw new Error('Publication changed during data reads; retry later');
      snapshot = {key, health:before, values};
      return {changed:true, snapshot};
    }
    return {
      refresh() {
        if (!pending) pending = collect().finally(() => {pending = null;});
        return pending;
      },
      current:() => snapshot,
      async response(path) {
        if (!snapshot) throw new Error('No complete public snapshot');
        const value = snapshot.values[path];
        return new Response(value == null ? '' : typeof value === 'string' ? value : JSON.stringify(value),
          {status:value == null ? 404 : 200});
      }
    };
  }
  function watch(refresh, options = {}) {
    const target = options.target || root;
    const document = options.document || root.document;
    const run = () => document.visibilityState === 'visible' ? refresh() : undefined;
    const events = ['focus', 'online', 'pageshow'];
    events.forEach(name => target.addEventListener(name, run));
    document.addEventListener('visibilitychange', run);
    const timer = (options.setInterval || root.setInterval)(run, 60000);
    return () => {
      (options.clearInterval || root.clearInterval)(timer);
      events.forEach(name => target.removeEventListener(name, run));
      document.removeEventListener('visibilitychange', run);
    };
  }
  function preserveText(field, text) {
    if (field.value === text) return;
    const {selectionStart, selectionEnd, selectionDirection, scrollTop, scrollLeft} = field;
    field.value = text;
    field.setSelectionRange(Math.min(selectionStart,text.length), Math.min(selectionEnd,text.length), selectionDirection);
    field.scrollTop = scrollTop;
    field.scrollLeft = scrollLeft;
  }
  const api = {createReader, watch, preserveText};
  if (typeof module === 'object') {module.exports = api; return;}
  root.GoogleSSRRefresh = api;
  root.document.addEventListener('DOMContentLoaded', () => {
    const document = root.document;
    const isSource = !!document.getElementById('nodes');
    const id = new URL(root.location.href).searchParams.get('id');
    const status = document.createElement('p');
    status.setAttribute('role', 'status');
    status.style.cssText = 'font:12px/1.5 system-ui,sans-serif;padding:0 20px';
    const nav = document.querySelector('.project-support-nav');
    if (nav) nav.after(status);
    if (isSource && !/^[a-f0-9]{12}$/.test(id || '')) {
      document.getElementById('meta').textContent = '缺少或无效的源 id';
      document.getElementById('nodes').value = '';
      return;
    }
    const reader = createReader({
      resources:isSource ? ['sub/providers/'+id+'.json', 'sub/providers/'+id+'.txt'] :
        ['sub/url_meta.json', 'sub/stats_daily.json', 'sub/stats_7day_enhanced.json'],
      optional:isSource ? [] : ['data/speed_ranking.json']
    });
    api.response = path => reader.response(path);
    let refreshing = null;
    function refresh() {
      if (!refreshing) refreshing = update().finally(() => {refreshing = null;});
      return refreshing;
    }
    async function update() {
      try {
        const result = await reader.refresh();
        if (result.changed) {
          const health = result.snapshot.health;
          document.querySelectorAll('[data-health]').forEach(node => {
            const value = node.dataset.health.split('.').reduce((value,key) => value && value[key], health);
            node.textContent = value == null ? '' : String(value);
          });
          const hideQuota = ['quota_total_left','quota_total_capacity','keys_ok','keys_total'].every(key => !Number(health[key]));
          document.querySelectorAll('.stat.quota').forEach(node => {node.style.display = hideQuota ? 'none' : '';});
          if (isSource) await root.renderSource(result.snapshot.values['sub/providers/'+id+'.json'], result.snapshot.values['sub/providers/'+id+'.txt']);
          else await Promise.all(['loadMeta','loadDailyChart','loadSparklines','loadSerpAPIKeys',
            'loadRecentUrls','loadTrend7Day','loadSpeedRanking'].map(name => typeof root[name] === 'function' ? root[name]() : undefined));
        } else if (result.optionalChanged?.includes('data/speed_ranking.json') && typeof root.loadSpeedRanking === 'function') {
          await root.loadSpeedRanking();
        }
        status.textContent = '已发布数据：' + (result.snapshot.health.build_time_cn || result.snapshot.health.build_time_utc);
      } catch (_) {
        status.textContent = reader.current() ? '暂时无法更新，保留上次成功数据。' : '暂时无法加载已发布数据，请稍后重试。';
        if (isSource && !reader.current()) {
          document.getElementById('meta').textContent = '源详情暂时不可用，或该源已不在最新发布中。';
          document.getElementById('nodes').value = '';
        }
      }
    }
    watch(refresh);
    refresh();
  });
})(typeof window === 'object' ? window : globalThis);
