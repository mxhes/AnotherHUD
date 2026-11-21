// AnotherHUD mockup kit: draws frames in the four AnotherLedger skins.
// Colors and skin rules come from AnotherLedger's Theme.lua (Theme.colors,
// Theme.edgeRects, Theme.skinScales, Widgets.BUTTON_*). Mockup only: the
// addon builds the real art after the player approves a page.
/* eslint-disable */
const K = (() => {
  const C = {
    panel: [0.15, 0.10, 0.06], border: [0.55, 0.42, 0.24], gold: [1, 0.82, 0],
    goldLine: [1, 0.82, 0.20], ink: [1, 1, 1], hint: [0.68, 0.63, 0.55],
    buttonFill: [0.10, 0.07, 0.04], inputFill: [0.06, 0.04, 0.02],
    warn: [0.95, 0.38, 0.32], good: [0.45, 0.85, 0.35], tagAh: [0.50, 0.82, 1.00],
  };
  const S = { edgeDark: 0.2, edgeLight: 1.7, grooveDark: 0.3, grooveLight: 2.0,
    raisedLight: 3.5, raisedDark: 0.3, plainMix: 0.5, listBox: 0.5 };
  const sc = (c, k) => c.map(v => Math.min(1, Math.max(0, v * k)));
  const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
  const css = (c, a = 1) => `rgba(${c.map(v => Math.round(v * 255)).join(',')},${a})`;

  const SKINS = {
    classic: { label: 'Classic', border: 'round', buttons: 'bronze', lines: 'gold' },
    forge: { label: 'Forge', border: 'bevel', buttons: 'raised', lines: 'groove' },
    slate: { label: 'Slate', border: 'thin', buttons: 'flat', lines: 'plain' },
    gilded: { label: 'Gilded', border: 'gilded', buttons: 'bronze', lines: 'dotted' },
  };
  const d = S.edgeDark, l = S.edgeLight;
  // Theme.edgeRects: shades from the outside in.
  const EDGES = {
    round: null,
    thin: [d, 1],
    bevel: [d, l, 1, 1, d],
    gilded: [d, l, d, d, l, d],
  };

  // Inset box-shadow stack for a border (first entry is drawn on top).
  function edgeShadow(border, col = C.border) {
    if (border === 'round') {
      return `inset 0 0 0 1px ${css(sc(col, 0.35))}, inset 0 0 0 3px ${css(col)}, inset 0 0 0 4px ${css(sc(col, 0.45))}, 0 0 0 1px rgba(0,0,0,.55)`;
    }
    return EDGES[border].map((k, i) => `inset 0 0 0 ${i + 1}px ${css(sc(col, k))}`).join(', ');
  }
  function edgeWidth(border) { return border === 'round' ? 4 : EDGES[border].length; }

  function stud(x, y, size = 10, col = C.border) {
    const hi = css(sc(col, 1.9)), mid = css(col), lo = css(sc(col, 0.25));
    return `<i class="stud" style="left:${x - size / 2}px;top:${y - size / 2}px;width:${size}px;height:${size}px;background:radial-gradient(circle at 35% 30%, ${hi} 0 18%, ${mid} 45%, ${lo} 72%, rgba(0,0,0,.6) 74%, transparent 78%)"></i>`;
  }

  // A skinned panel. opts: {w, h, x, y, alpha, studs (bool), inner (html), cls}
  function panel(skin, o) {
    const s = SKINS[skin];
    const r = s.border === 'round' ? 5 : 0;
    const a = o.alpha == null ? 0.92 : o.alpha;
    let studs = '';
    if (s.border === 'gilded' && o.studs !== false) {
      const L = o.corners !== 'right', R = o.corners !== 'left';
      const X = o.x || 0, Y = o.y || 0;
      if (L) studs += stud(X + 1, Y + 1) + stud(X + 1, Y + o.h - 1);
      if (R) studs += stud(X + o.w - 1, Y + 1) + stud(X + o.w - 1, Y + o.h - 1);
    }
    return `<div class="panel ${o.cls || ''}" style="left:${o.x || 0}px;top:${o.y || 0}px;width:${o.w}px;height:${o.h}px;border-radius:${r}px;background:${css(C.panel, a)};box-shadow:${edgeShadow(s.border)}">${o.inner || ''}</div>${studs}`;
  }

  // A styled line (Lines pick) of width w at x, y.
  function rule(skin, x, y, w, vertical) {
    const s = SKINS[skin];
    const dim = vertical ? `width:1px;height:${w}px` : `width:${w}px;height:1px`;
    const pos = `position:absolute;left:${x}px;top:${y}px;`;
    if (s.lines === 'groove') {
      const off = vertical ? `left:${x + 1}px;top:${y}px` : `left:${x}px;top:${y + 1}px`;
      return `<i style="${pos}${dim};background:${css(sc(C.goldLine, S.grooveDark))}"></i><i style="position:absolute;${off};${dim};background:${css(sc(C.goldLine, S.grooveLight), 0.55)}"></i>`;
    }
    if (s.lines === 'plain') {
      return `<i style="${pos}${dim};background:${css(mix(mix(C.goldLine, [.5, .5, .5], .5), C.panel, .5))}"></i>`;
    }
    if (s.lines === 'dotted') {
      const dir = vertical ? 'to bottom' : 'to right';
      return `<i style="${pos}${dim};background:repeating-linear-gradient(${dir}, ${css(C.goldLine, .85)} 0 4px, transparent 4px 8px)"></i>`;
    }
    return `<i style="${pos}${dim};background:${css(C.goldLine, .85)}"></i>`;
  }

  // Concentric ring of the skin's border lines (border pick bent into a circle).
  // Returns {html, width}. cx, cy: center; d: outer diameter.
  function ring(skin, cx, cy, dia, opts = {}) {
    const s = SKINS[skin];
    const col = opts.col || C.border;
    let shades = EDGES[s.border];
    if (!shades) shades = [0.35, 1, 1, 0.45]; // round: soft tooltip-like edge
    if (opts.thick) shades = shades.flatMap(k => [k, k]);
    const w = shades.length;
    let html = '';
    shades.forEach((k, i) => {
      const di = dia - i * 2;
      html += `<i class="ringline" style="left:${cx - di / 2}px;top:${cy - di / 2}px;width:${di}px;height:${di}px;border:1px solid ${css(sc(col, k))}"></i>`;
    });
    if (s.border === 'gilded' && opts.studs !== false) {
      const rr = dia / 2 - w / 2;
      [45, 135, 225, 315].forEach(a => {
        const t = a * Math.PI / 180;
        html += stud(cx + rr * Math.cos(t), cy + rr * Math.sin(t), 9, col);
      });
    }
    return { html, width: w };
  }

  // Round portrait (placeholder face drawn with gradients, no game art).
  function portrait(cx, cy, dia, hue = 28) {
    return `<i class="portrait" style="left:${cx - dia / 2}px;top:${cy - dia / 2}px;width:${dia}px;height:${dia}px;background:
      radial-gradient(ellipse 34% 30% at 50% 44%, hsl(${hue},45%,62%) 0 60%, hsl(${hue},40%,45%) 75%, transparent 77%),
      radial-gradient(ellipse 60% 40% at 50% 108%, hsl(${hue + 180},25%,32%) 0 70%, transparent 72%),
      radial-gradient(circle at 50% 40%, #3a4a5e, #10161f 75%)"></i>`;
  }

  // Bar fill textures (Look: bar texture).
  const TEX = {
    smooth: c => `linear-gradient(to bottom, ${css(sc(c, 1.25))} 0%, ${css(c)} 45%, ${css(sc(c, 0.72))} 100%)`,
    flat: c => css(c),
    gloss: c => `linear-gradient(to bottom, ${css(mix(c, [1, 1, 1], .45))} 0%, ${css(sc(c, 1.05))} 38%, ${css(sc(c, .82))} 52%, ${css(sc(c, .62))} 100%)`,
  };
  // A status bar: x, y, w, h, value 0..1, color [r,g,b], tex key.
  function bar(x, y, w, h, value, color, tex = 'smooth', extra = '') {
    const bg = css(sc(color, 0.18), 0.9);
    return `<div class="bar" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px;background:${bg}">
      <i style="position:absolute;left:0;top:0;bottom:0;width:${Math.round(w * value)}px;background:${TEX[tex](color)}"></i>${extra}</div>`;
  }
  function text(x, y, str, o = {}) {
    const al = o.align || 'left';
    const pos = al === 'right' ? `right:${x}px` : al === 'center' ? `left:${x}px;transform:translateX(-50%)` : `left:${x}px`;
    return `<span class="txt" style="${pos};top:${y}px;font-size:${o.size || 11}px;color:${o.color ? css(o.color) : '#fff'};${o.style || ''}">${str}</span>`;
  }

  const CLASS = {
    paladin: [0.96, 0.55, 0.73], mage: [0.25, 0.78, 0.92], warrior: [0.78, 0.61, 0.43],
    priest: [1, 1, 1], rogue: [1, 0.96, 0.41], druid: [1, 0.49, 0.04], hunter: [0.67, 0.83, 0.45],
    shaman: [0, 0.44, 0.87], warlock: [0.53, 0.53, 0.93], dk: [0.77, 0.12, 0.23], monk: [0, 1, 0.6],
    evoker: [0.2, 0.58, 0.5], dh: [0.64, 0.19, 0.79],
  };
  const POWER = { mana: [0.0, 0.44, 0.87], rage: [0.85, 0.12, 0.12], energy: [1, 0.86, 0.1],
    focus: [1, 0.5, 0.25], runic: [0, 0.82, 1] };
  const REACT = { hostile: [0.85, 0.2, 0.15], neutral: [0.95, 0.82, 0.2], friendly: [0.25, 0.75, 0.25] };

  // Page scaffolding: a skin picker + zoom; render(skin) returns html of one cell.
  function page(opts) {
    const state = { skins: ['classic', 'forge'], zoom: opts.zoom || 2 };
    const root = document.getElementById('cells');
    const pick = document.getElementById('skins');
    pick.innerHTML = Object.keys(SKINS).map(k =>
      `<label><input type="checkbox" value="${k}" ${state.skins.includes(k) ? 'checked' : ''}> ${SKINS[k].label}</label>`).join('') +
      ` <span class="sep">|</span> Zoom <select id="zoom">${[1, 1.5, 2].map(z => `<option value="${z}" ${z === state.zoom ? 'selected' : ''}>${z}x</option>`).join('')}</select>`;
    function draw() {
      root.innerHTML = opts.variants.map(v => `<section class="variant"><h2>${v.title}</h2><p class="note">${v.note || ''}</p><div class="row">` +
        state.skins.map(sk => `<figure><figcaption>${SKINS[sk].label}</figcaption><div class="stage" style="width:${v.w * state.zoom}px;height:${v.h * state.zoom}px"><div class="scene" style="width:${v.w}px;height:${v.h}px;transform:scale(${state.zoom})">${v.render(sk)}</div></div></figure>`).join('') +
        `</div></section>`).join('');
    }
    pick.addEventListener('change', e => {
      if (e.target.id === 'zoom') state.zoom = +e.target.value;
      else state.skins = [...pick.querySelectorAll('input:checked')].map(i => i.value);
      draw();
    });
    draw();
  }

  return { C, S, SKINS, sc, mix, css, panel, rule, ring, portrait, bar, text, stud, edgeWidth, CLASS, POWER, REACT, TEX, page };
})();
