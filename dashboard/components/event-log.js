import { S } from '../state.js';
import { toolClass, formatTokens, tokenLevel, formatTime } from '../utils.js';

export function renderEvents(evs) {
  const signature = JSON.stringify(evs.map(e => [e.ts, e.tool, e.target, e.total_tokens || 0]));
  if (signature === S.lastEventsSignature) return;
  S.lastEventsSignature = signature;

  document.getElementById('log-count').textContent = evs.length + ' events';

  document.getElementById('log').innerHTML = evs.map(e => {
    const cls    = toolClass(e.tool);
    const target = (e.target || '').replace(/\/Users\/[^/]+\//g, '~/');
    const tok    = Number(e.total_tokens || e.estimated_tokens || 0);
    const tokFmt = formatTokens(tok);
    const lvl    = tokenLevel(tok);
    const tokCls = lvl !== 'none' ? `tok-${lvl}` : '';
    return `<div class="log-entry">
      <span class="log-time">${e.iso ? e.iso.slice(11,19) : formatTime(e.ts)}</span>
      <span class="log-tool ${cls}">${(e.tool || 'SYSTEM').toUpperCase()}</span>
      <span class="log-target">${target}</span>
      <span class="log-tokens ${tokCls}">${tokFmt}</span>
    </div>`;
  }).join('');
}
