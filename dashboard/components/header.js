import { S } from '../state.js';
import { toolClass, formatElapsed } from '../utils.js';

export function updateElapsed() {
  if (!S.startedAt) return;
  const elapsed = Math.floor(Date.now() / 1000 - S.startedAt);
  document.getElementById('elapsed-display').textContent = formatElapsed(elapsed);
}

export function normalizeProject(p) {
  if (p && p !== 'unknown') return p;
  const combined = [S.agentState.last_tool?.target || '', ...S.events.map(e => e.target || '')].join('\n');
  const localMatch = combined.match(/Local Sites\/([^/]+)\/app\/public/i);
  if (localMatch?.[1]) return localMatch[1];
  const projectMatch = combined.match(/projects\/([^/]+)\//i);
  if (projectMatch?.[1]) return projectMatch[1];
  return '';
}

export function renderState(s) {
  const active = s.status === 'active';

  document.getElementById('idle-overlay').classList.toggle('show', !active && !s.agent);
  document.getElementById('status-dot').classList.toggle('active', active);
  document.getElementById('status-text').textContent = active ? 'ACTIVE' : 'IDLE';

  const setVal = (id, val, cls) => {
    const el = document.getElementById(id);
    el.textContent = val || '—';
    el.className = 'stat-value ' + (val ? (cls || '') : 'dim');
  };

  setVal('stat-agent',   s.agent ? s.agent.toUpperCase() : '', '');
  setVal('stat-project', normalizeProject(s.project), '');
  setVal('stat-model',   s.model, '');
  setVal('stat-tools',   s.tool_calls > 0 ? String(s.tool_calls) : '0', '');

  if (s.gate_e_armed) {
    setVal('stat-gate', 'ARMED', 'gate-armed');
  } else {
    setVal('stat-gate', active ? 'clear' : '—', active ? '' : 'dim');
  }

  if (s.last_tool && active) {
    const toolEl = document.getElementById('action-tool');
    toolEl.textContent = (s.last_tool.name || '—').toUpperCase();
    toolEl.className   = toolClass(s.last_tool.name);
    document.getElementById('action-target').textContent = s.last_tool.target || '...';
  } else {
    document.getElementById('action-tool').textContent  = '—';
    document.getElementById('action-tool').className    = 't-other';
    document.getElementById('action-target').textContent = active ? 'Waiting...' : 'No active session';
  }

  if (s.started_at && active) {
    if (!S.startedAt || S.startedAt !== s.started_at) {
      S.startedAt = s.started_at;
      clearInterval(S.elapsedTimer);
      S.elapsedTimer = setInterval(updateElapsed, 1000);
      updateElapsed();
    }
  } else {
    S.startedAt = null;
    clearInterval(S.elapsedTimer);
    document.getElementById('elapsed-display').textContent = '--:--';
  }
}

export function renderSessionSelect() {
  const sel = document.getElementById('session-select');
  if (!sel) return;
  const opts = [`<option value="">Auto latest</option>`].concat(
    (S.sessions || []).map(s => {
      const label = `${s.project || 'unknown'} · ${s.agent || '-'} · ${s.model || '-'} · ${s.session_id || ''}`;
      return `<option value="${s.session_id || ''}">${label.slice(0, 80)}</option>`;
    })
  );
  sel.innerHTML  = opts.join('');
  sel.value      = S.selectedSession;
}
