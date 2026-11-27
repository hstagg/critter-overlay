/* The Studio's icons, in the A0 pages' style (24 grid, 2 px round strokes).
   Injected once as a sprite; pages use <svg class="i"><use href="#i-name"/></svg>. */
(function () {
  const I = {
    back: '<path d="M14.5 6l-6 6 6 6"/>',
    move: '<path d="M6 4l5.5 15 2.2-6.3L20 10.5z"/>',
    ellipse: '<ellipse cx="12" cy="12" rx="8.5" ry="6"/>',
    rect: '<rect x="3.5" y="6" width="17" height="12" rx="3.5"/>',
    tri: '<path d="M12 5l8 14H4z"/>',
    drop: '<path d="M12 4c3.2 4 6 7 6 10a6 6 0 0 1-12 0c0-3 2.8-6 6-10z"/>',
    heart: '<path d="M12 19s-7-4.4-7-9.5A3.8 3.8 0 0 1 12 7.5a3.8 3.8 0 0 1 7 2C19 14.6 12 19 12 19z"/>',
    star: '<path d="M12 4.5l2.2 4.6 5 .7-3.6 3.5.9 5-4.5-2.4-4.5 2.4.9-5-3.6-3.5 5-.7z"/>',
    blob: '<path d="M6.5 16c-2.5-3.5-.5-9.5 5-10 5-.5 8.5 2.5 7.8 6.5-.6 3.6-3 6-7.3 6-2.6 0-4.3-.8-5.5-2.5z"/>',
    line: '<path d="M4 17c2.5-7 6-7 8-3s5.5 4 8-6"/>',
    eye: '<ellipse cx="12" cy="12" rx="5.5" ry="7"/><circle cx="13.6" cy="9.6" r="1.6" fill="currentColor" stroke="none"/>',
    hand: '<path d="M8 13V7a1.5 1.5 0 0 1 3 0v4.5M11 11V5.5a1.5 1.5 0 0 1 3 0V11M14 11V7a1.5 1.5 0 0 1 3 0v7c0 3.6-2.6 6-6 6-2.4 0-4-1-5.4-3L4 14.3a1.5 1.5 0 0 1 2.4-1.8L8 14"/>',
    undo: '<path d="M9 7.5L5 11.5l4 4"/><path d="M5 11.5h9.5a4.5 4.5 0 0 1 0 9H12"/>',
    redo: '<path d="M15 7.5l4 4-4 4"/><path d="M19 11.5H9.5a4.5 4.5 0 0 0 0 9H12"/>',
    fwd: '<rect x="4" y="9" width="10" height="10" rx="2"/><rect x="10" y="5" width="10" height="10" rx="2" fill="currentColor" fill-opacity=".25"/>',
    bwd: '<rect x="10" y="5" width="10" height="10" rx="2"/><rect x="4" y="9" width="10" height="10" rx="2" fill="currentColor" fill-opacity=".25"/>',
    mirror: '<path d="M12 4v16"/><path d="M9 7.5L4 17h5zM15 7.5L20 17h-5z"/>',
    dup: '<rect x="8" y="8" width="11" height="11" rx="2.5"/><path d="M5 15.5V6.5A1.5 1.5 0 0 1 6.5 5h9"/>',
    del: '<path d="M5 7h14M10 7V5h4v2M7 7l1 12.5h8L17 7"/>',
    show: '<path d="M2.5 12S6 6 12 6s9.5 6 9.5 6S18 18 12 18 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.6"/>',
    hide: '<path d="M4 4l16 16M9.9 6.3A9 9 0 0 1 12 6c6 0 9.5 6 9.5 6a16 16 0 0 1-3 3.6M6.3 8.2A16 16 0 0 0 2.5 12S6 18 12 18a9 9 0 0 0 3.2-.6"/>',
    lock: '<rect x="5.5" y="10.5" width="13" height="9.5" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>',
    unlock: '<rect x="5.5" y="10.5" width="13" height="9.5" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 6.8-1.2"/>',
    plus: '<path d="M12 5.5v13M5.5 12h13"/>',
    auto: '<path d="M12 4v3M12 17v3M4 12h3M17 12h3M6.3 6.3l2.1 2.1M15.6 15.6l2.1 2.1M6.3 17.7l2.1-2.1M15.6 8.4l2.1-2.1"/>',
    pin: '<circle cx="12" cy="10" r="3"/><path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/>',
    shapes: '<circle cx="8" cy="8" r="4"/><rect x="13" y="13" width="7" height="7" rx="1.5"/><path d="M4 20l4-7 4 7z"/>',
    help: '<circle cx="12" cy="12" r="8.5"/><path d="M9.6 9.5a2.5 2.5 0 0 1 4.8.8c0 1.7-2.4 2.2-2.4 3.7"/><circle cx="12" cy="16.9" r=".6" fill="currentColor"/>',
    min: '<path d="M6 12h12"/>',
    max: '<rect x="6" y="6" width="12" height="12" rx="2"/>',
    close: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
    play: '<path d="M8 5.5v13l10-6.5z"/>',
    snap: '<path d="M4 18h16"/><path d="M12 4v9M8.5 9.5L12 13l3.5-3.5"/>',
    sym: '<path d="M12 3.5v17" stroke-dasharray="2 2.5"/><path d="M9 8c-3 0-5 2-5 4s2 4 5 4zM15 8c3 0 5 2 5 4s-2 4-5 4z"/>',
    warn: '<path d="M12 4.5l8.5 15h-17z"/><path d="M12 10v4.5"/><circle cx="12" cy="17.2" r=".6" fill="currentColor"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    sound: '<path d="M4 10v4h3l5 4V6L7 10z"/><path d="M15.5 9.5a3.5 3.5 0 0 1 0 5"/>',
    copy: '<rect x="8" y="8" width="11" height="11" rx="2.5"/><path d="M5 15.5V6.5A1.5 1.5 0 0 1 6.5 5h9"/>',
    reset: '<path d="M5 12a7 7 0 1 0 2.1-5"/><path d="M5 4.5V8h3.5"/>',
  };
  const sym = Object.entries(I).map(([k, v]) => `<symbol id="i-${k}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${v}</symbol>`).join('');
  const d = document.createElement('div');
  d.hidden = true;
  d.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg">${sym}</svg>`;
  document.body.prepend(d);
})();
