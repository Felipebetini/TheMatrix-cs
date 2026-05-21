import { S }                                    from './state.js';
import { apiUrl }                               from './utils.js';
import { generateMockState, generateMockEvents, MOCK_USAGE_LIVE } from './mock.js';
import { renderState, renderSessionSelect }     from './components/header.js';
import { renderEvents }                         from './components/event-log.js';
import { renderTokenList }                      from './components/token-panel.js';
import { renderBottlenecks }                    from './components/bottleneck.js';
import { drawTokensGraph, renderUsageStats }    from './components/graphs.js';
import { initDrawers }                          from './components/drawers.js';

// ── Matrix rain ──────────────────────────────────────────────────────────────
const rainCanvas = document.getElementById('rain');
const rainCtx    = rainCanvas.getContext('2d');
const CHARS      = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$+-*/=%\"'#&_(),.;:?!|{}<>[]^~";
const FS         = 13;

function resizeRain() {
  rainCanvas.width  = window.innerWidth;
  rainCanvas.height = window.innerHeight;
}
resizeRain();
window.addEventListener('resize', resizeRain);

const drops = Array(Math.floor(window.innerWidth / FS)).fill(1);
function rain() {
  rainCtx.fillStyle = 'rgba(0,0,0,0.05)';
  rainCtx.fillRect(0, 0, rainCanvas.width, rainCanvas.height);
  rainCtx.fillStyle = '#0f0';
  rainCtx.font      = FS + 'px monospace';
  drops.forEach((y, i) => {
    rainCtx.fillText(CHARS[Math.floor(Math.random() * CHARS.length)], i * FS, y * FS);
    if (y * FS > rainCanvas.height && Math.random() > 0.975) drops[i] = 0;
    drops[i]++;
  });
}
setInterval(rain, 40);

// ── Mode toggle ──────────────────────────────────────────────────────────────
function setModeUI() {
  const btn = document.getElementById('mode-toggle');
  btn.textContent = S.testMode ? 'TEST' : 'LIVE';
  btn.classList.toggle('test', S.testMode);
  localStorage.setItem('matrixDashboardMode', S.testMode ? 'test' : 'live');
}

// ── Poll ─────────────────────────────────────────────────────────────────────
async function poll() {
  try {
    if (S.testMode) {
      S.agentState  = generateMockState();
      S.events      = generateMockEvents();
      S.usage       = {};
      S.usageLive   = MOCK_USAGE_LIVE;
      renderState(S.agentState);
      renderEvents(S.events);
    } else {
      const [sRes, eRes, uRes, ulRes, uhRes] = await Promise.all([
        fetch(apiUrl('/api/state',        S.selectedSession)),
        fetch(apiUrl('/api/events',       S.selectedSession)),
        fetch('/api/usage'),
        fetch(apiUrl('/api/usage-live',   S.selectedSession)),
        fetch('/api/usage-history'),
      ]);
      if (sRes.ok)  { S.agentState    = await sRes.json();  renderState(S.agentState); }
      if (eRes.ok)  { S.events        = await eRes.json();  renderEvents(S.events); }
      if (uRes.ok)  { S.usage         = await uRes.json(); }
      if (ulRes.ok) { S.usageLive     = await ulRes.json(); }
      if (uhRes.ok) { S.usageHistory  = await uhRes.json(); }

      const ssRes = await fetch('/api/sessions');
      if (ssRes.ok) S.sessions = await ssRes.json();
      renderSessionSelect();
    }

    renderTokenList(S.events);
    drawTokensGraph(S.events);
    renderBottlenecks(S.events, S.agentState);
    renderUsageStats();
    document.getElementById('last-refresh').textContent = new Date().toTimeString().slice(0, 8);
  } catch {
    document.getElementById('status-text').textContent = 'SERVER DOWN';
    document.getElementById('status-dot').classList.remove('active');
  }
}

// ── Event listeners ──────────────────────────────────────────────────────────
document.getElementById('mode-toggle').addEventListener('click', () => {
  S.testMode = !S.testMode;
  setModeUI();
  poll();
});

document.querySelectorAll('.usage-tab').forEach(tab => {
  tab.addEventListener('click', ev => {
    ev.stopPropagation();
    S.usageRange = tab.dataset.range;
    document.querySelectorAll('.usage-tab').forEach(t => t.classList.remove('active'));
    tab.classList.add('active');
    renderUsageStats();
  });
});

document.getElementById('session-select').addEventListener('change', e => {
  S.selectedSession = e.target.value || '';
  const url = new URL(window.location.href);
  if (S.selectedSession) url.searchParams.set('session', S.selectedSession);
  else url.searchParams.delete('session');
  window.history.replaceState({}, '', url.toString());
  poll();
});

// ── Boot ─────────────────────────────────────────────────────────────────────
setModeUI();
initDrawers();
poll();
setInterval(poll, 2000);
