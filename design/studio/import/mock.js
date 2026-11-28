// Mock-up controls only: the light/dark switch and the state buttons.
// Not part of the app. States come from data-when="a b" on any element;
// #state in the URL opens a page in that state.
function mock(states) {
  const win = document.querySelector('.win');
  const bar = document.createElement('div');
  bar.className = 'mock';
  const show = (k) => {
    win.dataset.state = k;
    document.querySelectorAll('[data-when]').forEach((e) =>
      e.classList.toggle('show', e.dataset.when.split(' ').includes(k)));
    bar.querySelectorAll('[data-k]').forEach((b) => b.classList.toggle('on', b.dataset.k === k));
    if (history.replaceState) history.replaceState(null, '', '#' + k);
  };
  if (states.length > 1) {
    bar.insertAdjacentHTML('beforeend', '<span>State</span>');
    states.forEach(([k, label]) => {
      const b = document.createElement('button');
      b.textContent = label; b.dataset.k = k; b.onclick = () => show(k);
      bar.appendChild(b);
    });
  }
  const t = document.createElement('button');
  t.textContent = 'Dark';
  t.onclick = () => {
    const dark = win.classList.toggle('th-dark');
    win.classList.toggle('th-light', !dark);
    t.textContent = dark ? 'Light' : 'Dark';
  };
  bar.insertAdjacentHTML('beforeend', '<span style="margin-left:6px">Theme</span>');
  bar.appendChild(t);
  document.body.appendChild(bar);
  const want = location.hash.slice(1);
  show(states.some((s) => s[0] === want) ? want : states[0][0]);
}

// Pose buttons on a live preview: data-pose on a .seg inside [data-preview].
document.addEventListener('click', (e) => {
  const b = e.target.closest('[data-pose]');
  if (!b) return;
  const box = document.getElementById(b.parentElement.dataset.for);
  b.parentElement.querySelectorAll('button').forEach((x) => x.classList.toggle('sel', x === b));
  const p = b.dataset.pose;
  box.classList.remove('pose-sit', 'pose-nap', 'pose-look', 'blinking');
  if (p === 'blink') {
    void box.offsetWidth; box.classList.add('pose-sit', 'blinking');
  } else if (p !== 'walk') box.classList.add('pose-' + p);
  const cap = document.getElementById(b.parentElement.dataset.for + '-cap');
  if (cap) cap.textContent = {walk: 'Walking', sit: 'Sitting', nap: 'Napping', blink: 'Blinking', look: 'Looking round'}[p];
});

// Draggable pins: any <g class="pin"> inside an <svg data-pins>.
document.addEventListener('pointerdown', (e) => {
  const pin = e.target.closest('.pin');
  if (!pin) return;
  const svg = pin.ownerSVGElement;
  const start = svg.createSVGPoint();
  const m = svg.getScreenCTM().inverse();
  const at = (ev) => { start.x = ev.clientX; start.y = ev.clientY; return start.matrixTransform(m); };
  const p0 = at(e);
  const t0 = (pin.getAttribute('transform') || 'translate(0 0)').match(/-?[\d.]+/g).map(Number);
  const move = (ev) => {
    const p = at(ev);
    pin.setAttribute('transform', `translate(${t0[0] + p.x - p0.x} ${t0[1] + p.y - p0.y})`);
    pin.classList.add('moved');
  };
  const up = () => { removeEventListener('pointermove', move); removeEventListener('pointerup', up); };
  addEventListener('pointermove', move); addEventListener('pointerup', up);
  e.preventDefault();
});

// Segmented controls and chips just select, unless they carry their own onclick.
document.addEventListener('click', (e) => {
  const b = e.target.closest('.seg button:not([data-pose])');
  if (!b || b.onclick) return;
  b.parentElement.querySelectorAll('button').forEach((x) => {
    x.classList.toggle('sel', x === b);
    x.setAttribute('aria-checked', x === b ? 'true' : 'false');
  });
});

// Picking a card in a radiogroup of cards (bodies, clips).
document.addEventListener('click', (e) => {
  const c = e.target.closest('[role=radiogroup] > [role=radio]:not(.seg *)');
  if (!c) return;
  c.parentElement.querySelectorAll(':scope > [role=radio]').forEach((x) => {
    const on = x === c;
    x.setAttribute('aria-checked', on ? 'true' : 'false');
    x.style.borderColor = on ? 'var(--outline)' : '';
    x.style.boxShadow = on ? '0 3px 0 var(--lip)' : '';
  });
});
