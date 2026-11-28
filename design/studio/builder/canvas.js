/* The Studio canvas for the mock-ups: the cast's 300 x 280 frame with 120
   units of headroom above it (for hats), the ground line at 262, the centre
   line, an optional faint guide critter, the critter itself and selection
   handles. Units are the frame's own (shapes.json coordinates). */
(function () {
  const VIEW = '-50 -130 400 470';

  function frame(o) {
    o = o || {};
    let s = '';
    s += '<rect x="0" y="-120" width="300" height="400" rx="6" style="fill:var(--surface);stroke:var(--line)" stroke-width="1.6"/>';
    s += '<rect x="0" y="-120" width="300" height="120" rx="6" style="fill:var(--ground)" opacity=".7"/>';
    s += '<line x1="0" y1="0" x2="300" y2="0" style="stroke:var(--dash)" stroke-width="1.2" stroke-dasharray="4 4"/>';
    s += '<text x="8" y="-108" style="fill:var(--ink3)" font-family="Nunito,sans-serif" font-weight="700" font-size="9">Room for hats</text>';
    s += '<line x1="150" y1="-120" x2="150" y2="280" style="stroke:var(--dash)" stroke-width="1" stroke-dasharray="1 5" stroke-linecap="round"/>';
    if (o.grid) {
      for (let x = 10; x < 300; x += 10) s += `<line x1="${x}" y1="-120" x2="${x}" y2="280" style="stroke:var(--div)" stroke-width=".5"/>`;
      for (let y = -110; y < 280; y += 10) s += `<line x1="0" y1="${y}" x2="300" y2="${y}" style="stroke:var(--div)" stroke-width=".5"/>`;
    }
    return s;
  }

  function ground() {
    return '<line x1="-30" y1="262" x2="330" y2="262" style="stroke:var(--acc-ink)" stroke-width="1.6" stroke-dasharray="6 4"/>' +
      '<text x="296" y="275" text-anchor="end" style="fill:var(--acc-ink)" font-family="Nunito,sans-serif" font-weight="800" font-size="9.5">Ground</text>';
  }

  function guide(name) {
    return `<g opacity=".16" style="filter:grayscale(1)">${CR.inner(CR.starters[name || 'cat'], { pose: 'walk' })}</g>`;
  }

  function handles(b, o) {
    // b = [x, y, w, h]: a dashed box, eight handles, a turn handle, a size tag.
    o = o || {};
    const [x, y, w, h] = b, p = 3, hs = 6;
    let s = `<rect x="${x - p}" y="${y - p}" width="${w + 2 * p}" height="${h + 2 * p}" fill="none" style="stroke:var(--acc-ink)" stroke-width="1.3" stroke-dasharray="4 3"/>`;
    const X = [x - p, x + w / 2, x + w + p], Y = [y - p, y + h / 2, y + h + p];
    for (const yy of Y) for (const xx of X) {
      if (xx === X[1] && yy === Y[1]) continue;
      s += `<rect x="${xx - hs / 2}" y="${yy - hs / 2}" width="${hs}" height="${hs}" rx="1.5" style="fill:var(--knob);stroke:var(--acc-ink)" stroke-width="1.4"/>`;
    }
    s += `<line x1="${X[1]}" y1="${Y[0]}" x2="${X[1]}" y2="${Y[0] - 16}" style="stroke:var(--acc-ink)" stroke-width="1.3"/>`;
    s += `<circle cx="${X[1]}" cy="${Y[0] - 19}" r="4" style="fill:var(--knob);stroke:var(--acc-ink)" stroke-width="1.4"/>`;
    if (o.size !== false) {
      const t = `${Math.round(w)} x ${Math.round(h)}`;
      s += `<rect x="${X[1] - 22}" y="${Y[2] + 6}" width="44" height="14" rx="7" style="fill:var(--tip-bg)"/>` +
        `<text x="${X[1]}" y="${Y[2] + 16}" text-anchor="middle" style="fill:var(--tip-ink)" font-family="Nunito,sans-serif" font-weight="800" font-size="8.5">${t}</text>`;
    }
    return s;
  }

  function draw(el, parts) {
    el.innerHTML = `<svg class="canvas" xmlns="http://www.w3.org/2000/svg" viewBox="${el.dataset.view || VIEW}" preserveAspectRatio="xMidYMid meet" aria-label="Canvas">${parts.join('')}</svg>`;
  }

  window.CV = { frame, ground, guide, handles, draw, VIEW };
})();
