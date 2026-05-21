import { S }                                          from './state.js';
import { apiUrl }                                     from './utils.js';
import { generateMockState, generateMockEvents, MOCK_USAGE_LIVE } from './mock.js';
import { renderState, renderSessionSelect }           from './components/header.js';
import { renderEvents }                               from './components/event-log.js';
import { renderTokenList }                            from './components/token-panel.js';
import { renderBottlenecks }                          from './components/bottleneck.js';
import { drawTokensGraph, renderUsageStats }          from './components/graphs.js';
import { initDrawers }                                from './components/drawers.js';
import { renderHistory, renderPatterns, renderInsights, populateProjectFilter } from './components/history.js';
import { initLogo, triggerGlitch }                    from './components/logo.js';

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

// ── Tab switching ─────────────────────────────────────────────────────────────
function switchTab(tab) {
  S.activeTab = tab;
  document.getElementById('view-live').classList.toggle('view-hidden', tab !== 'live');
  document.getElementById('view-history').classList.toggle('view-hidden', tab !== 'history');
  document.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.dataset.tab === tab));

  if (tab === 'history') fetchHistory();
}

// ── Fetch history (only for HISTORY tab) ──────────────────────────────────────
async function fetchHistory() {
  try {
    const project = S.histProjectFilter || null;
    const qs      = project ? `?project=${encodeURIComponent(project)}&limit=20` : '?limit=20';
    const [hRes, pRes, iRes] = await Promise.all([
      fetch(`/api/db/history${qs}`),
      fetch(`/api/db/patterns${project ? `?project=${encodeURIComponent(project)}` : ''}`),
      fetch('/api/db/insights'),
    ]);
    if (hRes.ok) S.dbHistory  = await hRes.json();
    if (pRes.ok) S.dbPatterns = await pRes.json();
    if (iRes.ok) S.dbInsights = await iRes.json();
    populateProjectFilter();
    renderHistory();
    renderPatterns();
    renderInsights();
  } catch {
    document.getElementById('hist-sessions').innerHTML =
      '<div class="hist-empty">Could not reach server.</div>';
  }
}

// ── Mode toggle ──────────────────────────────────────────────────────────────
function setModeUI() {
  const btn = document.getElementById('mode-toggle');
  btn.textContent = S.testMode ? 'TEST' : 'LIVE';
  btn.classList.toggle('test', S.testMode);
  localStorage.setItem('matrixDashboardMode', S.testMode ? 'test' : 'live');
}

// ── Live poll ─────────────────────────────────────────────────────────────────
async function poll() {
  try {
    if (S.testMode) {
      S.agentState = generateMockState();
      S.events     = generateMockEvents();
      S.usage      = {};
      S.usageLive  = MOCK_USAGE_LIVE;
      renderState(S.agentState);
      renderEvents(S.events);
    } else {
      const [sRes, eRes, uRes, ulRes, uhRes] = await Promise.all([
        fetch(apiUrl('/api/state',      S.selectedSession)),
        fetch(apiUrl('/api/events',     S.selectedSession)),
        fetch('/api/usage'),
        fetch(apiUrl('/api/usage-live', S.selectedSession)),
        fetch('/api/usage-history'),
      ]);
      if (sRes.ok)  { S.agentState   = await sRes.json(); renderState(S.agentState); }
      if (eRes.ok)  { S.events       = await eRes.json(); renderEvents(S.events); }
      if (uRes.ok)  { S.usage        = await uRes.json(); }
      if (ulRes.ok) { S.usageLive    = await ulRes.json(); }
      if (uhRes.ok) { S.usageHistory = await uhRes.json(); }

      const ssRes = await fetch('/api/sessions');
      if (ssRes.ok) S.sessions = await ssRes.json();
      renderSessionSelect();
    }

    renderTokenList(S.events);
    drawTokensGraph(S.events);
    renderBottlenecks(S.events, S.agentState);
    renderUsageStats();

    // Intense glitch — fires once when a high-signal condition first becomes true
    const gateArmed  = !!S.agentState?.gate_e_armed;
    const doomActive = !!(document.getElementById('b-doom')?.textContent?.includes('×'));
    const highSignal = gateArmed || doomActive;
    if (highSignal && !poll._wasHighSignal) triggerGlitch(true);
    poll._wasHighSignal = highSignal;
    document.getElementById('last-refresh').textContent = new Date().toTimeString().slice(0, 8);
  } catch {
    document.getElementById('status-text').textContent = 'SERVER DOWN';
    document.getElementById('status-dot').classList.remove('active');
  }
}

// ── Event listeners ──────────────────────────────────────────────────────────
document.querySelectorAll('.tab').forEach(tab => {
  tab.addEventListener('click', () => switchTab(tab.dataset.tab));
});

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

document.getElementById('hist-project-filter').addEventListener('change', e => {
  S.histProjectFilter = e.target.value;
  fetchHistory();
});

document.getElementById('hist-refresh-btn').addEventListener('click', fetchHistory);

// ── Boot ─────────────────────────────────────────────────────────────────────
setModeUI();
initDrawers();
initLogo();
poll();
setInterval(poll, 2000);
