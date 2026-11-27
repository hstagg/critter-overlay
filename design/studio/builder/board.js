/* The mock-up board's toggles (not part of the app): light or dark theme,
   segmented buttons and chips that select one of a group, and anything with
   data-show="id" that shows or hides an element. */
(function () {
  function theme(dark) {
    document.querySelectorAll('.win').forEach(w => { w.classList.toggle('th-dark', dark); w.classList.toggle('th-light', !dark); });
    document.body.classList.toggle('dark-board', dark);
    const b = document.getElementById('themebtn'); if (b) b.textContent = dark ? 'Light theme' : 'Dark theme';
  }
  document.addEventListener('click', e => {
    const t = e.target.closest('button, [data-show]'); if (!t) return;
    if (t.id === 'themebtn') { theme(!document.body.classList.contains('dark-board')); return; }
    if (t.dataset.show) {
      const el = document.getElementById(t.dataset.show);
      if (el) el.hidden = !el.hidden;
      e.preventDefault(); return;
    }
    const g = t.closest('[data-one]');
    if (g) {
      g.querySelectorAll(':scope > button, :scope > .lr, :scope > [data-pick]').forEach(b => { b.classList.remove('sel'); b.setAttribute('aria-checked', 'false'); });
      t.classList.add('sel'); t.setAttribute('aria-checked', 'true');
      g.dispatchEvent(new CustomEvent('pick', { detail: t.dataset.v || t.textContent.trim() }));
    }
  });
  if (location.hash === '#dark') document.addEventListener('DOMContentLoaded', () => theme(true));
})();
