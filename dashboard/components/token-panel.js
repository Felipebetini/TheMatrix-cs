import { formatTokens, tokenLevel, toolClass, formatTime } from '../utils.js';

export function renderTokenList(evs) {
  const summaryEl = document.getElementById('tokens-summary-text');
  const listEl    = document.getElementById('token-list');
  const bnRowEl   = document.getElementById('tok-bottleneck-row');

  const withTok = evs.map(e => ({
    tool:   e.tool || 'system',
    target: (e.target || '').replace(/\/Users\/[^/]+\//g, '~/'),
    tok:    Number(e.total_tokens || e.estimated_tokens || 0),
  })).filter(x => x.tok > 0);

  if (withTok.length > 0) {
    const total = withTok.reduce((a, b) => a + b.tok, 0);
    const max   = Math.max(...withTok.map(x => x.tok));
    const avg   = Math.round(total / withTok.length);
    summaryEl.textContent = `Events: ${withTok.length} · Avg: ${formatTokens(avg)} · Max: ${formatTokens(max)} · Total: ${formatTokens(total)}`;
  } else {
    summaryEl.textContent = 'No token data yet';
  }

  const top3 = [...withTok].sort((a, b) => b.tok - a.tok).slice(0, 3);
  bnRowEl.innerHTML = top3.map((x, i) => {
    const lvl       = tokenLevel(x.tok);
    const shortTool = x.tool.toUpperCase().slice(0, 6);
    const shortPath = x.target.split('/').pop() || x.target;
    return `<div class="tok-bn-card level-${lvl}">
      <div class="tok-bn-label level-${lvl}">#${i+1} · ${shortTool} · ${formatTokens(x.tok)}</div>
      <div class="tok-bn-val" title="${x.target}">${shortPath}</div>
    </div>`;
  }).join('');

  if (!evs.length) {
    listEl.innerHTML = '<div style="color:var(--text-dim);font-size:0.7rem;padding:0.15rem 0">No events yet</div>';
    return;
  }

  listEl.innerHTML = evs.map(e => {
    const tok    = Number(e.total_tokens || e.estimated_tokens || 0);
    const lvl    = tokenLevel(tok);
    const cls    = toolClass(e.tool);
    const target = (e.target || '').replace(/\/Users\/[^/]+\//g, '~/');
    const tokFmt = formatTokens(tok);
    const tokCls = lvl !== 'none' ? `tok-${lvl}` : '';
    return `<div class="tok-entry">
      <span class="tok-entry-tool ${cls}">${(e.tool||'SYS').toUpperCase().slice(0,6)}</span>
      <span class="tok-entry-path" title="${target}">${target}</span>
      <span class="tok-count ${tokCls}">${tokFmt || '—'}</span>
    </div>`;
  }).join('');
}
