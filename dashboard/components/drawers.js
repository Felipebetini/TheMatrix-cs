export function initDrawers() {
  document.getElementById('graphs-drawer-header').addEventListener('click', () => {
    const body      = document.getElementById('graphs-body');
    const btn       = document.getElementById('graphs-toggle');
    const collapsed = body.classList.toggle('collapsed');
    btn.textContent = collapsed ? '▶' : '▼';
  });

}
