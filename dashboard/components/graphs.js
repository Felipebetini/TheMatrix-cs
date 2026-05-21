import { S } from '../state.js';
import { formatTokens } from '../utils.js';

export function drawTokensGraph(evs) {
  const cv      = document.getElementById('tok-graph-canvas');
  const ctx     = cv.getContext('2d');
  const summary = document.getElementById('tok-graph-summary');
  const meta    = document.getElementById('tok-graph-meta');

  const liveTimeline = Array.isArray(S.usageLive?.timeline) ? S.usageLive.timeline : [];
  let pointsRaw;
  if (liveTimeline.length > 0) {
    pointsRaw = liveTimeline.slice(-40)
      .map(row => ({ value: Number(row.tokens || 0), estimated: false }))
      .filter(x => Number.isFinite(x.value) && x.value > 0);
  } else {
    pointsRaw = evs.slice(0, 40).reverse()
      .map(e => ({
        value:     Number(e.total_tokens || e.estimated_tokens || 0),
        estimated: !!(e.estimated_tokens && !e.total_tokens),
      }))
      .filter(x => Number.isFinite(x.value) && x.value > 0);
  }

  const points        = pointsRaw.map(x => x.value);
  const estimatedOnly = pointsRaw.length > 0 && pointsRaw.every(x => x.estimated);

  ctx.clearRect(0, 0, cv.width, cv.height);
  ctx.fillStyle = 'rgba(2, 22, 10, 0.85)';
  ctx.fillRect(0, 0, cv.width, cv.height);

  if (!points.length) {
    summary.textContent = '';
    meta.textContent    = S.usageLive?.totals?.total_tokens_including_cache
      ? `Live session total: ${S.usageLive.totals.total_tokens_including_cache.toLocaleString()} (incl. cache)`
      : 'No token data in events yet';
    ctx.strokeStyle = '#2a7543';
    ctx.beginPath();
    ctx.moveTo(0, cv.height - 1);
    ctx.lineTo(cv.width, cv.height - 1);
    ctx.stroke();
    return;
  }

  const total = points.reduce((a, b) => a + b, 0);
  const max   = Math.max(...points);
  const min   = Math.min(...points);
  const avg   = Math.round(total / points.length);
  summary.textContent = estimatedOnly
    ? `Est · Avg: ${formatTokens(avg)} · Max: ${formatTokens(max)} · Total: ${formatTokens(total)}`
    : `Avg: ${formatTokens(avg)} · Max: ${formatTokens(max)} · Total: ${formatTokens(total)}`;

  const lt = S.usageLive?.totals;
  meta.textContent = lt?.total_tokens_including_cache
    ? `Live hook: ${lt.total_tokens_including_cache.toLocaleString()} (in ${lt.input_tokens.toLocaleString()} · out ${lt.output_tokens.toLocaleString()} · cacheR ${lt.cache_read_tokens.toLocaleString()} · cacheW ${lt.cache_write_tokens.toLocaleString()})`
    : estimatedOnly ? 'Source: event estimates' : 'Source: event usage fields';

  const pad = 5, w = cv.width - pad * 2, h = cv.height - pad * 2;
  const step  = points.length > 1 ? w / (points.length - 1) : w;
  const range = Math.max(0, max - min);
  const flat  = range === 0;

  const yFor = v => flat ? pad + h * 0.5 : pad + h - ((v - min) / range) * h;

  ctx.strokeStyle = '#66ff8f';
  ctx.lineWidth   = 2;
  ctx.beginPath();
  points.forEach((v, i) => {
    const x = pad + i * step;
    if (i === 0) ctx.moveTo(x, yFor(v)); else ctx.lineTo(x, yFor(v));
  });
  ctx.stroke();

  if (!flat) {
    ctx.fillStyle = 'rgba(102,255,143,0.18)';
    ctx.beginPath();
    points.forEach((v, i) => {
      const x = pad + i * step;
      if (i === 0) ctx.moveTo(x, yFor(v)); else ctx.lineTo(x, yFor(v));
    });
    ctx.lineTo(pad + (points.length - 1) * step, pad + h);
    ctx.lineTo(pad, pad + h);
    ctx.closePath();
    ctx.fill();
  }
}

export function filterUsageHistory(items, range) {
  if (!items?.length) return [];
  if (range === 'all') return items;
  const cutoff = Date.now() - Number(range) * 86400 * 1000;
  return items.filter(x => Number(x.captured_at || 0) * 1000 >= cutoff);
}

export function renderUsageStats() {
  const cv       = document.getElementById('usage-canvas');
  const ctx      = cv.getContext('2d');
  const meta     = document.getElementById('usage-meta');
  const filtered = filterUsageHistory(S.usageHistory, S.usageRange);

  ctx.clearRect(0, 0, cv.width, cv.height);
  ctx.fillStyle = 'rgba(2,22,10,0.85)';
  ctx.fillRect(0, 0, cv.width, cv.height);

  if (!filtered.length) {
    meta.textContent = 'No imported usage yet. Run: pbpaste | ./scripts/import-session-usage.py';
    return;
  }

  const byDay = {};
  for (const item of filtered) {
    const day = item.day || new Date((item.captured_at || 0) * 1000).toISOString().slice(0,10);
    byDay[day] = (byDay[day] || 0) + Number(item.total_tokens_including_cache || 0);
  }
  const days = Object.keys(byDay).sort();
  const vals = days.map(d => byDay[d]);
  const max  = Math.max(...vals, 1);
  const pad  = 6, w = cv.width - pad*2, h = cv.height - pad*2;
  const step = days.length > 1 ? w / (days.length - 1) : w;

  ctx.strokeStyle = '#96a8ff';
  ctx.lineWidth   = 2;
  ctx.beginPath();
  vals.forEach((v, i) => {
    const x = pad + i * step;
    const y = pad + h - (v / max) * h;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  });
  ctx.stroke();

  const modelTotals = {};
  filtered.forEach(item => {
    (item.models || []).forEach(m => {
      modelTotals[m.model] = (modelTotals[m.model] || 0) + Number(m.total_tokens_including_cache || 0);
    });
  });
  const total     = vals.reduce((a, b) => a + b, 0);
  const topModels = Object.entries(modelTotals).sort((a,b) => b[1]-a[1]).slice(0,3);
  const modelsTxt = topModels.map(([m, t]) => `${m}: ${Math.round((t / Math.max(total,1)) * 100)}%`).join(' · ');
  meta.textContent = `${days.length} day(s) · total ${total.toLocaleString()} tokens · ${modelsTxt || 'no model split'}`;
}
