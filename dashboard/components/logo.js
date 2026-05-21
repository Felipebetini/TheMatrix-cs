const ORIGINAL     = 'THE MATRIX';
const GLITCH_CHARS = '!@#$%|/\\[]{}~<>^*█▓░';

function rand(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }

function corruptText(str, count) {
  const chars = str.split('');
  const candidates = chars.reduce((acc, c, i) => c !== ' ' ? [...acc, i] : acc, []);
  candidates.sort(() => Math.random() - 0.5).slice(0, count).forEach(i => {
    chars[i] = GLITCH_CHARS[rand(0, GLITCH_CHARS.length - 1)];
  });
  return chars.join('');
}

export function triggerGlitch(intense = false) {
  const el = document.getElementById('title');
  if (!el || el.dataset.glitching) return;

  const duration   = intense ? 620 : 380;
  const swapCount  = intense ? 4   : 2;
  const frames     = intense ? 10  : 6;
  const frameDelay = Math.floor(duration / frames);

  el.dataset.glitching = '1';
  el.classList.add(intense ? 'glitch-intense' : 'glitching');

  let f = 0;
  const corrupt = setInterval(() => {
    f++;
    const corrupted = corruptText(ORIGINAL, rand(1, swapCount));
    el.textContent       = corrupted;
    el.dataset.text      = corrupted;
    if (f >= frames) clearInterval(corrupt);
  }, frameDelay);

  setTimeout(() => {
    clearInterval(corrupt);
    el.textContent  = ORIGINAL;
    el.dataset.text = ORIGINAL;
    el.classList.remove('glitching', 'glitch-intense');
    delete el.dataset.glitching;
  }, duration + 60);
}

function scheduleNext() {
  setTimeout(() => {
    triggerGlitch(false);
    scheduleNext();
  }, rand(5000, 14000));
}

export function initLogo() {
  const el = document.getElementById('title');
  if (el) {
    el.textContent  = ORIGINAL;
    el.dataset.text = ORIGINAL;
  }
  // Initial glitch after a short delay so it feels alive on load
  setTimeout(() => triggerGlitch(false), rand(2000, 4000));
  scheduleNext();
}
