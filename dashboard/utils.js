export function toolClass(tool) {
  const t = (tool || '').toLowerCase();
  if (t === 'read')                            return 't-read';
  if (t === 'write')                           return 't-write';
  if (t === 'edit')                            return 't-edit';
  if (t === 'bash')                            return 't-bash';
  if (t === 'agent')                           return 't-agent';
  if (t.includes('fetch') || t === 'webfetch') return 't-web';
  if (t.includes('search'))                    return 't-search';
  if (t === 'system')                          return 't-system';
  return 't-other';
}

export function formatTokens(n) {
  if (!n || n <= 0) return '';
  if (n >= 1000) return Math.round(n / 1000) + 'k';
  return String(n);
}

export function tokenLevel(n) {
  if (!n || n <= 0) return 'none';
  if (n < 5000)  return 'low';
  if (n < 20000) return 'med';
  return 'high';
}

export function formatTime(ts) {
  return new Date(ts * 1000).toTimeString().slice(0, 8);
}

export function formatElapsed(seconds) {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
}

export function apiUrl(path, selectedSession) {
  if (!selectedSession) return path;
  const sep = path.includes('?') ? '&' : '?';
  return `${path}${sep}session=${encodeURIComponent(selectedSession)}`;
}
