/* Critter art for the D0 mock-ups.
 *
 * A small JavaScript copy of godot/studio/shape_svg.gd, so every critter on
 * these pages is drawn the way the Shape Builder will draw it: shapes.json
 * shapes (section 5.3 of the build plan) in the cast's 300 x 280 frame,
 * facing left, standing on y 262; each layer in two passes (the outline at
 * twice the width under every fill, so overlapping shapes get one outline),
 * "inside" shapes clipped to the rest of the layer, preset eyes, blush, and
 * the automatic parts (far legs and ears, mirrored ears and wings, closed
 * eyes). The starters are the eight in step D5.
 *
 * Any element with data-art="<starter>" gets that critter as inline SVG.
 * Optional: data-pose (walk, sit, nap), data-anim (on), data-view (a viewBox).
 */
(function () {
  const LINE = '#5B3A29', WIDTH = 6, BLUSH = '#F29C9C', GROUND = 262;
  const f = n => Math.round(n * 100) / 100;
  let uid = 0;

  function tint(hex, k) {
    const n = parseInt(hex.slice(1), 16);
    const c = [n >> 16, (n >> 8) & 255, n & 255].map(v => Math.round(v * k));
    return '#' + c.map(v => v.toString(16).padStart(2, '0')).join('').toUpperCase();
  }

  function curve(pts, closed) {
    // Catmull-Rom through the points, as cubic Beziers.
    const n = pts.length, P = i => closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))];
    let d = `M${f(pts[0][0])} ${f(pts[0][1])}`;
    const last = closed ? n : n - 1;
    for (let i = 0; i < last; i++) {
      const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
      d += ` C${f(p1[0] + (p2[0] - p0[0]) / 6)} ${f(p1[1] + (p2[1] - p0[1]) / 6)} ${f(p2[0] - (p3[0] - p1[0]) / 6)} ${f(p2[1] - (p3[1] - p1[1]) / 6)} ${f(p2[0])} ${f(p2[1])}`;
    }
    return d + (closed ? 'Z' : '');
  }

  function geom(s) {
    // [tag, geometry attributes] centred on 0,0 (blob and stroke: absolute).
    const w = s.w / 2, h = s.h / 2;
    switch (s.t) {
      case 'ellipse': return ['ellipse', `cx="0" cy="0" rx="${f(w)}" ry="${f(h)}"`];
      case 'rect': return ['rect', `x="${f(-w)}" y="${f(-h)}" width="${f(s.w)}" height="${f(s.h)}" rx="${f(s.r || 0)}"`];
      case 'tri': {
        const ax = -w + (s.apex == null ? 0.5 : s.apex) * s.w;
        return ['path', `d="M${f(ax)} ${f(-h)} L${f(w)} ${f(h)} L${f(-w)} ${f(h)} Z" stroke-linejoin="round"`];
      }
      case 'drop': return ['path', `d="M0 ${f(-h)} C${f(w * 0.7)} ${f(-h * 0.2)} ${f(w)} ${f(h * 0.2)} ${f(w)} ${f(h * 0.4)} A${f(w)} ${f(h * 0.6)} 0 0 1 ${f(-w)} ${f(h * 0.4)} C${f(-w)} ${f(h * 0.2)} ${f(-w * 0.7)} ${f(-h * 0.2)} 0 ${f(-h)}Z"`];
      case 'heart': return ['path', `d="M0 ${f(h * 0.9)} C${f(-w * 1.1)} ${f(h * 0.1)} ${f(-w * 0.9)} ${f(-h)} ${f(-w * 0.45)} ${f(-h)} C${f(-w * 0.2)} ${f(-h)} 0 ${f(-h * 0.8)} 0 ${f(-h * 0.5)} C0 ${f(-h * 0.8)} ${f(w * 0.2)} ${f(-h)} ${f(w * 0.45)} ${f(-h)} C${f(w * 0.9)} ${f(-h)} ${f(w * 1.1)} ${f(h * 0.1)} 0 ${f(h * 0.9)}Z"`];
      case 'star': {
        const n = s.n || 5; let d = '';
        for (let i = 0; i < n * 2; i++) {
          const a = -Math.PI / 2 + i * Math.PI / n, k = i % 2 ? 0.5 : 1;
          d += (i ? 'L' : 'M') + f(Math.cos(a) * w * k) + ' ' + f(Math.sin(a) * h * k) + ' ';
        }
        return ['path', `d="${d}Z" stroke-linejoin="round"`];
      }
      case 'blob': return ['path', `d="${curve(s.pts, true)}"`];
      case 'stroke': return ['path', `d="${curve(s.pts, false)}"`];
    }
    return ['g', ''];
  }

  function el(s, attrs) {
    const [tag, g] = geom(s);
    const tf = (s.t === 'blob' || s.t === 'stroke') ? '' :
      ` transform="translate(${f(s.x)} ${f(s.y)})${s.rot ? ` rotate(${s.rot})` : ''}${s.flip ? ' scale(-1 1)' : ''}"`;
    return `<${tag} ${g}${tf} ${attrs}/>`;
  }

  function eye(s) {
    const x = s.x, y = s.y, w = s.w / 2, h = s.h / 2, fill = s.fill || '#3A2A22';
    const base = `<ellipse cx="${f(x)}" cy="${f(y)}" rx="${f(w)}" ry="${f(h)}" fill="${fill}"/>`;
    if (s.preset === 'dot') return base;
    if (s.preset === 'round') return base + `<circle cx="${f(x + w * 0.3)}" cy="${f(y - h * 0.35)}" r="${f(Math.min(w, h) * 0.3)}" fill="#FFFFFF"/>`;
    let out = base + `<circle cx="${f(x + w * 0.28)}" cy="${f(y - h * 0.38)}" r="${f(Math.min(w, h) * 0.38)}" fill="#FFFFFF"/>` +
      `<circle cx="${f(x - w * 0.3)}" cy="${f(y + h * 0.35)}" r="${f(Math.min(w, h) * 0.16)}" fill="#FFFFFF" opacity="0.8"/>`;
    if (s.preset === 'lash') {
      const side = s.flip ? -1 : 1;
      out += `<path d="M${f(x + side * w * 0.7)} ${f(y - h * 0.7)} Q${f(x + side * w * 1.2)} ${f(y - h)} ${f(x + side * w * 1.4)} ${f(y - h * 1.4)}" fill="none" stroke="${fill}" stroke-width="${f(Math.max(1.5, w * 0.2))}" stroke-linecap="round"/>`;
    }
    return out;
  }

  function closedEyes(eyes) {
    return eyes.map(s => {
      const w = s.w * 0.6;
      return `<path d="M${f(s.x - w)} ${f(s.y)} Q${f(s.x)} ${f(s.y + s.h * 0.45)} ${f(s.x + w)} ${f(s.y)}" fill="none" stroke="${LINE}" stroke-width="${f(Math.max(2.5, s.w * 0.16))}" stroke-linecap="round"/>`;
    }).join('');
  }

  function blush(eyes) {
    return eyes.map(s => `<ellipse cx="${f(s.x)}" cy="${f(s.y + s.h * 0.75)}" rx="${f(s.w * 0.55)}" ry="${f(s.w * 0.3)}" fill="${BLUSH}" opacity="0.7"/>`).join('');
  }

  function layer(shapes, extra) {
    // The two-pass layer, as shape_svg.gd layer() writes it.
    const outlined = shapes.filter(s => s.line !== false && !s.inside && s.t !== 'eye');
    const plain = shapes.filter(s => !s.inside && s.t !== 'eye');
    const marks = shapes.filter(s => s.inside && s.t !== 'eye');
    let svg = '';
    if (outlined.length) {
      svg += '<g>' + outlined.map(s => s.t === 'stroke'
        ? el(s, `fill="none" stroke="${LINE}" stroke-width="${f(s.width + 2 * WIDTH)}" stroke-linecap="round" stroke-linejoin="round"`)
        : el(s, `fill="${LINE}" stroke="${LINE}" stroke-width="${2 * WIDTH}" stroke-linejoin="round"`)).join('') + '</g>';
    }
    svg += plain.map(s => s.t === 'stroke'
      ? el(s, `fill="none" stroke="${s.fill}" stroke-width="${f(s.width)}" stroke-linecap="round" stroke-linejoin="round"`)
      : el(s, `fill="${s.fill}"`)).join('');
    if (marks.length || extra) {
      const id = 'cl' + (++uid);
      svg += `<defs><clipPath id="${id}">${plain.filter(s => s.t !== 'stroke').map(s => el(s, '')).join('')}</clipPath></defs><g clip-path="url(#${id})">` +
        marks.map(s => el(s, `fill="${s.fill}"`)).join('') + (extra || '') + '</g>';
    }
    return svg + shapes.filter(s => s.t === 'eye').map(eye).join('');
  }

  // ---- The automatic parts (kit_data.gd and shape_svg.gd) ----
  const shift = (shapes, dx, k) => shapes.map(s => Object.assign({}, s, {
    x: s.x + dx, pts: s.pts && s.pts.map(p => [p[0] + dx, p[1]]), fill: tint(s.fill, k)
  }));
  const mirror = (shapes, cx, k) => shapes.map(s => Object.assign({}, s, {
    x: 2 * cx - s.x, rot: -(s.rot || 0), flip: !s.flip, pts: s.pts && s.pts.map(p => [2 * cx - p[0], p[1]]),
    fill: k ? tint(s.fill, k) : s.fill
  }));

  function filled(doc) {
    // part -> shapes, with the automatic parts made; auto[part] = true for those.
    const L = Object.assign({}, doc.layers), auto = {};
    const make = (part, fn) => { if (!L[part] && fn()) { L[part] = fn(); auto[part] = true; } };
    if (doc.plan === 'side') {
      make('leg-front-far', () => L['leg-front'] && shift(L['leg-front'], 8, 0.82));
      make('leg-back-far', () => L['leg-back'] && shift(L['leg-back'], 8, 0.82));
      make('ear-r', () => L['ear-l'] && shift(L['ear-l'], 10, 0.82));
    } else {
      make('ear-r', () => L['ear-l'] && mirror(L['ear-l'], 150));
      make('wing-r', () => L['wing-l'] && mirror(L['wing-l'], 150));
      make('foot-r', () => L['foot-l'] && mirror(L['foot-l'], 150));
      make('leg-far', () => L['leg-near'] && mirror(L['leg-near'], 150, 0.82));
    }
    return { L, auto };
  }

  const ORDER = {
    side: ['tail', 'leg-back-far', 'leg-front-far', 'back-extra', 'walk-body', 'leg-back', 'leg-front', 'front-extra', 'ear-r', 'ear-l', 'head', 'eyes', 'nose', 'head-front'],
    front: ['tail', 'ear-l', 'ear-r', 'back-extra', 'body', 'foot-l', 'foot-r', 'front-extra', 'head', 'eyes', 'nose', 'head-front'],
    upright: ['leg-far', 'leg-near', 'tail', 'back-extra', 'body', 'wing-r', 'wing-l', 'front-extra', 'tuft', 'head', 'eyes', 'head-front'],
    blob: ['tail', 'ear-l', 'ear-r', 'back-extra', 'body', 'head', 'eyes', 'head-front'],
  };
  const HEADS = ['ear-l', 'ear-r', 'head', 'eyes', 'nose', 'head-front', 'tuft'];

  function inner(doc, o) {
    // The critter's SVG markup (no <svg> wrapper).
    o = o || {};
    const { L } = filled(doc);
    const pose = o.pose || 'walk', anim = !!o.anim;
    const eyes = L.eyes || [];
    const blushOn = doc.blush !== false && eyes.length;
    const draw = part => {
      if (!L[part] || (o.hide && o.hide.includes(part))) return '';
      if (part === 'eyes' && pose === 'nap') return `<g data-layer="eyes-closed">${closedEyes(eyes)}</g>`;
      const extra = blushOn && (part === 'head' || (part === 'body' && !L.head)) ? blush(eyes) : '';
      const op = o.focus && o.focus !== part ? ` opacity="${o.faint == null ? 0.32 : o.faint}"` : '';
      return `<g data-layer="${part}"${op}>${layer(L[part], extra)}</g>`;
    };
    const P = doc.pins || {};
    const org = (p, d) => { const v = P[p] || d; return `transform-origin:${v[0]}px ${v[1]}px`; };
    const order = ORDER[doc.plan];
    if (doc.plan !== 'side') {
      // Facing-you and blob critters are drawn as they sit (or bounce).
      const body = order.map(draw).join('');
      if (pose === 'nap') return `<g class="${anim ? 'a-breathe' : ''}" style="transform-origin:150px ${GROUND}px" transform="translate(0 ${GROUND}) scale(1.1 0.8) translate(0 -${GROUND})">${body}</g>`;
      const cls = anim ? (doc.plan === 'blob' ? (doc.gait === 'float' ? 'a-float' : 'a-bounce') : 'a-waddle') : '';
      return `<g class="${cls}" style="transform-origin:150px ${GROUND}px">${body}</g>`;
    }
    // Side-on: legs swing about their hips, the head bobs, the tail swishes.
    const legs = (part, phase) => {
      const s = draw(part); if (!s) return '';
      const hip = part.includes('front') ? (P['hip-front'] || [116, 220]) : (P['hip-back'] || [204, 220]);
      const far = part.endsWith('far') ? [8, 0] : [0, 0];
      const style = `transform-origin:${hip[0] + far[0]}px ${hip[1]}px`;
      if (pose === 'nap') return '';
      if (pose === 'sit' && part.startsWith('leg-back')) return `<g style="${style}" transform-origin="${hip[0] + far[0]} ${hip[1]}" transform="scale(1 0.55)">${s}</g>`;
      return `<g class="${anim && pose === 'walk' ? 'a-leg' + phase : ''}" style="${style}">${s}</g>`;
    };
    let body = '';
    for (const part of order) {
      if (HEADS.includes(part)) continue;
      if (part === 'tail') body += `<g class="${anim ? 'a-tail' : ''}" style="${org('tail', [224, 196])}">${draw('tail')}</g>`;
      else if (part.startsWith('leg-')) body += legs(part, part === 'leg-front' || part === 'leg-back-far' ? 'a' : 'b');
      else body += draw(part);
    }
    const head = order.filter(p => HEADS.includes(p)).map(draw).join('');
    const neck = P['neck-walk'] || [118, 190];
    const headG = `<g class="${anim && pose === 'walk' ? 'a-bob' : ''}" style="transform-origin:${neck[0]}px ${neck[1]}px">${head}</g>`;
    if (pose === 'nap') {
      return `<g class="${anim ? 'a-breathe' : ''}" style="transform-origin:150px ${GROUND}px"><g transform="translate(0 ${GROUND}) scale(1.04 0.85) translate(0 ${22 - GROUND})">${body}<g transform="translate(6 14) rotate(-8 ${neck[0]} ${neck[1]})">${head}</g></g></g>`;
    }
    if (pose === 'sit') {
      return `<g transform="rotate(10 116 ${GROUND})">${body}<g transform="rotate(-14 ${neck[0]} ${neck[1]})">${head}</g></g>`;
    }
    return `<g class="${anim ? 'a-step' : ''}">${body}${headG}</g>`;
  }

  function svg(doc, o) {
    o = o || {};
    const view = o.view || doc.view || '10 30 280 240';
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${view}" width="100%" height="100%" preserveAspectRatio="xMidYMax meet" aria-hidden="true">${inner(doc, o)}</svg>`;
  }

  // ---- Shape helpers for handles on the canvas ----
  function box(s) {
    if (s.pts) {
      const xs = s.pts.map(p => p[0]), ys = s.pts.map(p => p[1]);
      return [Math.min(...xs), Math.min(...ys), Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys)];
    }
    return [s.x - s.w / 2, s.y - s.h / 2, s.w, s.h];
  }

  // ---- The starters (step D5), plus Mochi from the A0 pages ----
  const E = (x, y, w, h, fill, more) => Object.assign({ t: 'ellipse', x, y, w, h, fill }, more);
  const R = (x, y, w, h, r, fill) => ({ t: 'rect', x, y, w, h, r, fill });
  const T = (x, y, w, h, apex, fill, more) => Object.assign({ t: 'tri', x, y, w, h, apex, fill }, more);
  const D = (x, y, w, h, rot, fill, more) => Object.assign({ t: 'drop', x, y, w, h, rot, fill }, more);
  const EYE = (x, y, w, h, preset) => ({ t: 'eye', preset: preset || 'big', x, y, w, h, fill: '#3A2A22' });
  const ST = (pts, width, fill) => ({ t: 'stroke', pts, width, fill });
  const IN = { inside: true };

  function cat(c, belly, ear, extra) {
    return {
      plan: 'side', gait: 'trot',
      layers: Object.assign({
        'walk-body': [E(160, 200, 150, 78, c), E(150, 224, 84, 30, belly, IN)],
        'head': [E(100, 148, 118, 102, c), E(98, 172, 48, 26, belly, IN)],
        'ear-l': [T(76, 104, 38, 46, 0.4, c), T(77, 110, 18, 24, 0.4, ear, IN)],
        'ear-r': [T(124, 102, 36, 44, 0.6, c), T(123, 108, 16, 22, 0.6, ear, IN)],
        'eyes': [EYE(80, 146, 18, 22), EYE(118, 146, 18, 22)],
        'nose': [{ t: 'heart', x: 99, y: 163, w: 11, h: 9, fill: '#F59C9C', line: false }],
        'leg-front': [R(116, 240, 22, 44, 9, c)],
        'leg-back': [R(204, 240, 22, 44, 9, c)],
        'tail': [ST([[224, 196], [248, 184], [262, 158], [258, 132]], 13, c)],
      }, extra || {}),
      pins: { 'neck-walk': [112, 194], 'hip-front': [116, 220], 'hip-back': [204, 220], 'tail': [224, 196], 'ear-l': [78, 124], 'ear-r': [122, 122], 'eyes': [99, 146] },
    };
  }

  const S = {
    mochi: cat('#C9A0E8', '#F1E4FA', '#F7A9A2'),
    cat: cat('#F6C28F', '#FFF1E2', '#F7A9A2', {
      'head': [E(100, 148, 118, 102, '#F6C28F'), E(98, 172, 48, 26, '#FFF1E2', IN), E(100, 104, 10, 26, '#E0823F', IN), E(84, 108, 8, 20, '#E0823F', { inside: true, rot: -18 }), E(116, 108, 8, 20, '#E0823F', { inside: true, rot: 18 })],
    }),
    dog: {
      plan: 'side', gait: 'trot',
      layers: {
        'walk-body': [E(162, 202, 150, 76, '#F9DDBF'), E(190, 190, 56, 50, '#A98468', IN)],
        'head': [E(104, 146, 106, 96, '#F9DDBF'), E(66, 170, 50, 36, '#F9DDBF'), E(118, 134, 34, 30, '#A98468', IN)],
        'ear-l': [D(128, 158, 32, 64, 18, '#A98468')],
        'eyes': [EYE(86, 142, 16, 20, 'round'), EYE(118, 140, 16, 20, 'round')],
        'nose': [E(46, 164, 18, 13, '#3B3437', { line: false })],
        'leg-front': [R(120, 240, 22, 44, 9, '#F9DDBF')],
        'leg-back': [R(206, 240, 22, 44, 9, '#F9DDBF')],
        'tail': [ST([[230, 192], [246, 176], [252, 154]], 12, '#F9DDBF')],
      },
      pins: { 'neck-walk': [118, 192], 'hip-front': [120, 220], 'hip-back': [206, 220], 'tail': [230, 192] },
    },
    bear: {
      plan: 'front', gait: 'plod',
      layers: {
        'body': [E(150, 208, 150, 112, '#A98468'), E(150, 224, 84, 70, '#F9DDBF', IN)],
        'foot-l': [E(110, 254, 48, 24, '#A98468'), E(110, 255, 24, 12, '#F9DDBF', IN)],
        'head': [E(150, 124, 132, 112, '#A98468'), E(150, 148, 58, 40, '#F9DDBF', IN)],
        'ear-l': [E(102, 78, 42, 42, '#A98468'), E(102, 80, 20, 20, '#F9DDBF', IN)],
        'eyes': [EYE(126, 120, 17, 21), EYE(174, 120, 17, 21)],
        'nose': [E(150, 138, 20, 13, '#3B3437', { line: false })],
      },
    },
    mouse: {
      plan: 'front', gait: 'scurry',
      layers: {
        'tail': [ST([[200, 244], [236, 236], [254, 214], [246, 192]], 8, '#F7A9A2')],
        'body': [E(150, 216, 120, 94, '#E9DED3'), E(150, 228, 64, 56, '#FBF4EC', IN)],
        'foot-l': [E(124, 258, 30, 14, '#F7A9A2')],
        'head': [E(150, 140, 116, 100, '#E9DED3')],
        'ear-l': [E(96, 90, 62, 62, '#E9DED3'), E(98, 92, 36, 36, '#F7A9A2', IN)],
        'eyes': [EYE(128, 136, 18, 22), EYE(172, 136, 18, 22)],
        'nose': [{ t: 'heart', x: 150, y: 156, w: 12, h: 10, fill: '#F59C9C', line: false }],
      },
    },
    chick: {
      plan: 'upright', gait: 'waddle',
      layers: {
        'leg-near': [ST([[134, 232], [134, 258]], 7, '#F7A04A'), ST([[124, 260], [144, 260]], 7, '#F7A04A')],
        'body': [E(150, 196, 124, 108, '#FFE07A'), E(150, 212, 70, 56, '#FFF1E2', IN)],
        'wing-l': [D(92, 198, 30, 52, -30, '#FFE07A')],
        'tuft': [ST([[150, 78], [144, 62], [156, 54]], 7, '#FFE07A')],
        'head': [E(150, 126, 112, 100, '#FFE07A'), T(150, 152, 26, 18, 0.5, '#F7A04A', { rot: 180 })],
        'eyes': [EYE(127, 120, 17, 21), EYE(173, 120, 17, 21)],
      },
    },
    penguin: {
      plan: 'upright', gait: 'waddle',
      layers: {
        'leg-near': [E(128, 258, 32, 12, '#F7A04A')],
        'body': [E(150, 190, 128, 132, '#4F4A5E'), E(150, 206, 86, 100, '#FBF4EC', IN)],
        'wing-l': [D(90, 196, 26, 64, -24, '#4F4A5E')],
        'head': [E(150, 118, 112, 96, '#4F4A5E'), E(132, 124, 46, 50, '#FBF4EC', IN), E(168, 124, 46, 50, '#FBF4EC', IN), T(150, 146, 22, 15, 0.5, '#F7A04A', { rot: 180 })],
        'eyes': [EYE(133, 120, 15, 19), EYE(167, 120, 15, 19)],
      },
    },
    slime: {
      plan: 'blob', gait: 'blob_bounce',
      layers: {
        'body': [{ t: 'blob', fill: '#A9D99B', pts: [[70, 262], [230, 262], [240, 232], [216, 172], [178, 126], [150, 114], [122, 126], [84, 172], [60, 232]] },
          E(110, 166, 20, 34, '#E4F5DC', { inside: true, rot: 24 })],
        'eyes': [EYE(128, 200, 18, 24), EYE(172, 200, 18, 24)],
      },
    },
    ghost: {
      plan: 'blob', gait: 'float',
      layers: {
        'body': [{ t: 'blob', fill: '#FBF4EC', pts: [[150, 92], [200, 108], [224, 160], [226, 236], [206, 254], [186, 238], [168, 256], [150, 240], [132, 256], [114, 238], [94, 254], [74, 236], [76, 160], [100, 108]] }],
        'eyes': [EYE(130, 160, 18, 24), EYE(170, 160, 18, 24)],
      },
    },
  };

  window.CR = { svg, inner, box, filled, starters: S, LINE, GROUND };

  function fill() {
    document.querySelectorAll('[data-art]').forEach(n => {
      const doc = S[n.dataset.art]; if (!doc) return;
      n.innerHTML = svg(doc, { pose: n.dataset.pose || (doc.plan === 'front' || doc.plan === 'upright' ? 'sit' : 'walk'), anim: n.dataset.anim === 'on', view: n.dataset.view });
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fill); else fill();
})();
