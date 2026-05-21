import { S } from '../state.js';
import { formatTokens } from '../utils.js';

export function setBValue(id, text, level) {
  const el = document.getElementById(id);
  el.textContent = text || '—';
  el.className   = 'b-value';
  if (level === 'warn')   el.classList.add('b-warn');
  if (level === 'danger') el.classList.add('b-danger');
}

function inferStage(tool, target) {
  const t = String(tool   || '').toLowerCase();
  const x = String(target || '').toLowerCase();
  if (x.includes('approved') || x.includes('waiting for') || x.includes('brief ready')) return 'waiting_approval';
  if (x.includes('seraph')) return 'seraph';
  if (x.includes('verify') || x.includes('fixed_when') || x.includes('curl') || x.includes('playwright')) return 'verify';
  if (t === 'edit' || t === 'write') return 'implement';
  if (t === 'agent' && (x.includes('implementer') || x.includes('reviewer') || x.includes('security'))) return 'implement';
  if (t === 'read' || t === 'search') return 'intake';
  return 'investigation';
}

const ALL_IDS = ['b-stage','b-wait-work','b-verify','b-hotspot','b-queue','b-burn','b-cache','b-rework','b-doom','b-ratio','b-context'];

export function renderBottlenecks(evs, agentState) {
  const recent = (evs || []).slice(0, 120).reverse();
  document.getElementById('bottleneck-updated').textContent = new Date().toTimeString().slice(0, 8);

  if (!recent.length) {
    ALL_IDS.forEach(id => setBValue(id, 'No events'));
    return;
  }

  const stageSec = {}, toolCount = {};
  let waitSec = 0, workSec = 0, verifyCount = 0, verifyFail = 0, blockedSignals = 0;

  for (let i = 0; i < recent.length; i++) {
    const cur   = recent[i];
    const nxt   = recent[i + 1];
    const stage = inferStage(cur.tool, cur.target);
    const dt    = nxt ? Math.max(1, nxt.ts - cur.ts) : 2;
    stageSec[stage] = (stageSec[stage] || 0) + dt;
    if (stage === 'waiting_approval') waitSec += dt; else workSec += dt;

    const tk = String(cur.tool || 'other').toUpperCase();
    toolCount[tk] = (toolCount[tk] || 0) + 1;

    const tgt = String(cur.target || '').toLowerCase();
    if (tgt.includes('verify') || tgt.includes('fixed_when')) verifyCount++;
    if (tgt.includes('no match') || tgt.includes('doom loop') || tgt.includes('investigation stall')) verifyFail++;
    if (tgt.includes('waiting') || tgt.includes('stall') || tgt.includes('doom loop')) blockedSignals++;
  }

  const topStage  = Object.entries(stageSec).sort((a,b) => b[1]-a[1])[0];
  const stageName = topStage ? topStage[0].replace('_',' ') : 'n/a';
  const stageMin  = topStage ? Math.round(topStage[1] / 60) : 0;
  setBValue('b-stage', `${stageName} · ${stageMin}m`, stageMin >= 15 ? 'danger' : stageMin >= 8 ? 'warn' : '');

  const totalWW = Math.max(1, waitSec + workSec);
  const waitPct = Math.round((waitSec / totalWW) * 100);
  setBValue('b-wait-work', `wait ${waitPct}% · work ${100-waitPct}%`, waitPct >= 50 ? 'danger' : waitPct >= 30 ? 'warn' : '');

  const vf = verifyCount > 0 ? Math.round((verifyFail / verifyCount) * 100) : 0;
  setBValue('b-verify', `${verifyCount} checks · ${vf}% friction`, vf >= 40 ? 'danger' : vf >= 20 ? 'warn' : '');

  const topTool = Object.entries(toolCount).sort((a,b) => b[1]-a[1])[0];
  setBValue('b-hotspot', topTool ? `${topTool[0]} × ${topTool[1]}` : 'n/a', topTool?.[1] >= 20 ? 'warn' : '');

  const gate = agentState.gate_e_armed ? 'Gate E pending' : 'Gate E clear';
  setBValue('b-queue', `${blockedSignals} block signals · ${gate}`, blockedSignals >= 3 || agentState.gate_e_armed ? 'warn' : '');

  // Token Burn Rate
  const tokEvs = recent.filter(e => Number(e.total_tokens || e.estimated_tokens || 0) > 0);
  if (tokEvs.length >= 2) {
    const spanSec  = Math.max(1, tokEvs[tokEvs.length - 1].ts - tokEvs[0].ts);
    const totalTok = tokEvs.reduce((a, e) => a + Number(e.total_tokens || e.estimated_tokens || 0), 0);
    const perMin   = Math.round((totalTok / spanSec) * 60);
    setBValue('b-burn', `${formatTokens(perMin)}/min`, perMin >= 50000 ? 'danger' : perMin >= 20000 ? 'warn' : '');
  } else if (tokEvs.length === 1) {
    setBValue('b-burn', `${formatTokens(Number(tokEvs[0].total_tokens || tokEvs[0].estimated_tokens || 0))} (1 event)`, '');
  } else {
    setBValue('b-burn', 'no token data', '');
  }

  // Cache Hit Rate
  const lt = S.usageLive?.totals;
  if (lt && (lt.input_tokens > 0 || lt.cache_read_tokens > 0)) {
    const hitPct = Math.round((lt.cache_read_tokens / (lt.input_tokens + lt.cache_read_tokens)) * 100);
    setBValue('b-cache', `${hitPct}% hit · ${formatTokens(lt.cache_read_tokens)}R`, hitPct < 20 ? 'danger' : hitPct < 50 ? 'warn' : '');
  } else {
    setBValue('b-cache', 'no hook data', '');
  }

  // Rework Index
  const editPaths = {};
  for (const e of recent) {
    const t = String(e.tool || '').toLowerCase();
    if (t === 'edit' || t === 'write') {
      const p = (e.target || '').replace(/\/Users\/[^/]+\//g, '~/');
      editPaths[p] = (editPaths[p] || 0) + 1;
    }
  }
  const editFiles   = Object.keys(editPaths).length;
  const reworkFiles = Object.values(editPaths).filter(n => n > 1).length;
  if (editFiles === 0) {
    setBValue('b-rework', 'no edits yet', '');
  } else {
    setBValue('b-rework',
      reworkFiles > 0 ? `${reworkFiles} reworked of ${editFiles} files` : `clean · ${editFiles} file${editFiles > 1 ? 's' : ''}`,
      reworkFiles >= 3 ? 'danger' : reworkFiles >= 1 ? 'warn' : '');
  }

  // Doom Loop
  const loopCount = {};
  for (const e of recent.slice(-20)) {
    const key = `${String(e.tool||'').toUpperCase()}:${(e.target||'').slice(0,60)}`;
    loopCount[key] = (loopCount[key] || 0) + 1;
  }
  const topLoop = Object.entries(loopCount).sort((a,b) => b[1]-a[1])[0];
  if (topLoop?.[1] >= 3) {
    const [key, count] = topLoop;
    const [loopTool, loopTarget] = key.split(':');
    setBValue('b-doom', `${loopTool}×${count} on ${loopTarget.split('/').pop() || loopTarget}`, count >= 5 ? 'danger' : 'warn');
  } else {
    setBValue('b-doom', 'clean', '');
  }

  // Read/Edit Ratio
  const readCount = recent.filter(e => String(e.tool||'').toLowerCase() === 'read').length;
  const editCount = recent.filter(e => ['edit','write'].includes(String(e.tool||'').toLowerCase())).length;
  if (readCount === 0 && editCount === 0) {
    setBValue('b-ratio', 'no r/w events', '');
  } else if (editCount === 0) {
    setBValue('b-ratio', `R:${readCount} · no edits yet`, readCount >= 10 ? 'warn' : '');
  } else {
    const ratio = Math.round(readCount / editCount);
    setBValue('b-ratio', `R:${readCount} E:${editCount} · ${ratio}:1`, ratio >= 20 ? 'danger' : ratio >= 10 ? 'warn' : '');
  }

  // Context Pressure
  const total   = evs.length;
  const ctxLvl  = total >= 80 ? 'danger' : total >= 60 ? 'warn' : '';
  const ctxLabel = total >= 80 ? 'high — compact soon' : total >= 60 ? 'medium — watch it' : 'low';
  setBValue('b-context', `${total} events · ${ctxLabel}`, ctxLvl);
}
