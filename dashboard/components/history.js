import { S } from '../state.js';

function signalLevel(value, warn, danger) {
  if (value == null) return '';
  if (value >= danger) return 'tok-high';
  if (value >= warn)   return 'tok-med';
  return 'tok-low';
}

function cacheLevel(pct) {
  if (pct == null) return '';
  if (pct < 20) return 'tok-high';
  if (pct < 50) return 'tok-med';
  return 'tok-low';
}

function fmt(v, suffix = '') {
  if (v == null || v === '') return '—';
  return `${v}${suffix}`;
}

function fmtTok(n) {
  if (!n) return '—';
  return n >= 1000 ? Math.round(n / 1000) + 'k' : String(n);
}

function fmtDate(ts) {
  if (!ts) return '—';
  return new Date(ts * 1000).toLocaleString('en-GB', {
    month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

// ── Project filter dropdown ───────────────────────────────────────────────────
export function populateProjectFilter() {
  const sel = document.getElementById('hist-project-filter');
  if (!sel) return;
  const projects = [...new Set(S.dbHistory.map(r => r.project).filter(Boolean))].sort();
  const current  = S.histProjectFilter;
  sel.innerHTML  = `<option value="">All projects</option>` +
    projects.map(p => `<option value="${p}" ${p === current ? 'selected' : ''}>${p}</option>`).join('');
}

// ── Sessions list ─────────────────────────────────────────────────────────────
export function renderHistory() {
  const el      = document.getElementById('hist-sessions');
  const countEl = document.getElementById('hist-session-count');
  if (!el) return;

  const rows = S.histProjectFilter
    ? S.dbHistory.filter(r => r.project === S.histProjectFilter)
    : S.dbHistory;

  countEl.textContent = `${rows.length} session${rows.length !== 1 ? 's' : ''}`;

  if (!rows.length) {
    el.innerHTML = `<div class="hist-empty">No sessions saved yet. Sessions are written to DB at Gate E close.<br>
      Run: <code>python3 scripts/matrix_db.py save &lt;session_id&gt;</code></div>`;
    return;
  }

  el.innerHTML = rows.map(r => {
    const doomBadge = r.doom_loop
      ? `<span class="hist-badge danger">DOOM LOOP</span>` : '';
    const reworkBadge = r.rework_files > 0
      ? `<span class="hist-badge warn">REWORK ×${r.rework_files}</span>` : '';

    const signals = [
      { label: 'Events',     val: fmt(r.event_count),                                  cls: signalLevel(r.event_count, 60, 80) },
      { label: 'Tokens',     val: fmtTok(r.total_tokens),                              cls: '' },
      { label: 'Cache',      val: fmt(r.cache_hit_pct, '%'),                           cls: cacheLevel(r.cache_hit_pct) },
      { label: 'Duration',   val: r.duration_min ? `${Math.round(r.duration_min)}min` : '—', cls: '' },
      { label: 'Burn Rate',  val: r.burn_rate ? fmtTok(r.burn_rate) + '/min' : '—',   cls: signalLevel(r.burn_rate, 20000, 50000) },
      { label: 'Wait',       val: fmt(r.wait_pct, '%'),                                cls: signalLevel(r.wait_pct, 30, 50) },
      { label: 'R/E Ratio',  val: fmt(r.read_edit_ratio, ':1'),                        cls: signalLevel(r.read_edit_ratio, 10, 20) },
      { label: 'Stage',      val: r.top_stage || '—',                                 cls: '' },
      { label: 'Hotspot',    val: r.tool_hotspot || '—',                               cls: '' },
    ];

    return `<div class="hist-row">
      <div class="hist-row-header">
        <span class="hist-date">${fmtDate(r.closed_at)}</span>
        <span class="hist-project">${r.project || '?'}</span>
        <span class="hist-agent">${(r.agent || '?').toUpperCase()}</span>
        <span class="hist-model">${r.model || ''}</span>
        <div class="hist-badges">${doomBadge}${reworkBadge}</div>
      </div>
      <div class="hist-signals-grid">
        ${signals.map(s => `
          <div class="hist-signal-cell">
            <span class="hist-signal-label">${s.label}</span>
            <span class="hist-signal-val ${s.cls}">${s.val}</span>
          </div>`).join('')}
      </div>
    </div>`;
  }).join('');
}

// ── Patterns grid ─────────────────────────────────────────────────────────────
export function renderPatterns() {
  const el = document.getElementById('hist-patterns');
  if (!el) return;

  const data     = S.dbPatterns;
  const projects = Object.keys(data).filter(p =>
    !S.histProjectFilter || p === S.histProjectFilter
  );

  if (!projects.length) {
    el.innerHTML = `<div class="hist-empty">No pattern data yet.</div>`;
    return;
  }

  el.innerHTML = `<div class="hist-patterns-grid">` + projects.map(proj => {
    const p = data[proj];
    const fields = [
      { label: 'Sessions',      val: p.session_count },
      { label: 'Models',        val: p.model_breakdown || '—' },
      { label: 'Avg Duration',  val: p.avg_duration_min ? `${p.avg_duration_min}min` : '—' },
      { label: 'Avg Tokens',    val: fmtTok(p.avg_tokens) },
      { label: 'Avg Cache Hit', val: fmt(p.avg_cache_hit_pct, '%'),    cls: cacheLevel(p.avg_cache_hit_pct) },
      { label: 'Avg Rework',    val: fmt(p.avg_rework, ' files'),       cls: signalLevel(p.avg_rework, 1, 3) },
      { label: 'Avg Burn Rate', val: p.avg_burn_rate ? fmtTok(p.avg_burn_rate) + '/min' : '—', cls: signalLevel(p.avg_burn_rate, 20000, 50000) },
      { label: 'Avg Wait',      val: fmt(p.avg_wait_pct, '%'),          cls: signalLevel(p.avg_wait_pct, 30, 50) },
      { label: 'Doom Loops',    val: fmt(p.total_doom_loops),           cls: p.total_doom_loops > 0 ? 'tok-high' : '' },
      { label: 'R/E Ratio',     val: fmt(p.avg_read_edit_ratio, ':1'),  cls: signalLevel(p.avg_read_edit_ratio, 10, 20) },
      { label: 'Top Hotspot',   val: p.top_hotspot || '—' },
    ];
    return `<div class="hist-pattern-card">
      <div class="hist-pattern-title">${proj}</div>
      ${fields.map(f => `
        <div class="hist-pattern-row">
          <span class="hist-pattern-label">${f.label}</span>
          <span class="hist-pattern-val ${f.cls || ''}">${f.val}</span>
        </div>`).join('')}
    </div>`;
  }).join('') + `</div>`;
}
