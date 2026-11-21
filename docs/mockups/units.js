// Unit frame and cast bar drawing for the mockups (uses kit.js).
/* eslint-disable */
const U = (() => {
  const { C, sc, css } = K;

  // A level badge: small round coin with the level in gold.
  function badge(skin, cx, cy, lvl, dia = 18) {
    const r = K.ring(skin, cx, cy, dia, { studs: false });
    return `<i class="portrait" style="left:${cx - dia / 2}px;top:${cy - dia / 2}px;width:${dia}px;height:${dia}px;background:${css(C.panel)}"></i>${r.html}` +
      `<span class="txt" style="left:${cx}px;top:${cy - 6}px;transform:translateX(-50%);font-size:10px;color:${css(C.gold)}">${lvl}</span>`;
  }

  // p: {x, y, w, h, powerH, layout: inset|overhang|coin|none, mirror, ps (portrait scale),
  //     name, level, hp, hpText, pp, ppText, hpColor, ppColor, tex, hue, nameColor, extra}
  function frame(skin, p) {
    const e = K.edgeWidth(K.SKINS[skin].border);
    const w = p.w, h = p.h, ps = p.ps || 1, tex = p.tex || 'smooth';
    const layout = p.layout || 'inset';
    const pad = 1;
    let ringDia = 0, ringCx = 0, ringCy = h / 2, barL = e + pad, barR = w - e - pad;
    if (layout === 'inset') {
      ringDia = Math.round((h - 2 * e - 2) * ps);
      ringCx = e + 1 + ringDia / 2;
      barL = e + 2 + ringDia + 2;
    } else if (layout === 'overhang') {
      ringDia = Math.round(h * 1.25 * ps);
      ringCx = Math.round(ringDia * 0.32);
      barL = ringCx + ringDia / 2 + 2;
    } else if (layout === 'coin') {
      ringDia = Math.round(h * ps);
      ringCx = -ringDia / 2 - 4;
    }
    const mx = (x, ww) => p.mirror ? w - x - ww : x;
    const powerH = p.powerH == null ? 15 : p.powerH;
    const hTop = e + pad, pBot = h - e - pad;
    const pTop = powerH ? pBot - powerH : pBot;
    const hBot = powerH ? pTop - 1 : pBot;
    const bw = barR - barL;
    let html = K.panel(skin, { w, h, x: 0, y: 0, alpha: p.alpha, corners: layout === 'overhang' ? (p.mirror ? 'left' : 'right') : 'all' });
    html += K.bar(mx(barL, bw), hTop, bw, hBot - hTop, p.hp, p.hpColor || [0.16, 0.62, 0.22], tex, p.hpExtra || '');
    if (powerH) {
      html += K.rule(skin, mx(barL, bw), hBot, bw);
      html += K.bar(mx(barL, bw), pTop, bw, powerH, p.pp, p.ppColor || K.POWER.mana, tex);
    }
    // texts
    const hh = hBot - hTop;
    const fs = p.fs || Math.max(9, Math.min(11, Math.round(hh * 0.28)));
    const ty = hTop + (hh - fs * 1.2) / 2;
    const nL = p.mirror ? w - barR + 4 : barL + 4;
    const vR = p.mirror ? barL + 4 : w - barR + 4;
    let lvl = '';
    if (layout === 'inset' || layout === 'none') lvl = p.level ? `<b style="color:${css(C.gold)}">${p.level}</b> ` : '';
    if (p.name) html += K.text(p.mirror ? vR : nL, ty, lvl + p.name, { size: fs, color: p.nameColor, align: p.mirror ? 'right' : 'left' });
    if (p.hpText) html += K.text(p.mirror ? nL : vR, ty, p.hpText, { size: fs, align: p.mirror ? 'left' : 'right' });
    if (powerH >= 9 && p.ppText) {
      const pf = Math.min(10, powerH - 3);
      html += K.text(p.mirror ? nL : vR, pTop + (powerH - pf * 1.2) / 2, p.ppText, { size: pf, align: p.mirror ? 'left' : 'right' });
    }
    // portrait + ring
    if (layout !== 'none') {
      const cx = p.mirror ? w - ringCx : ringCx;
      const r = K.ring(skin, cx, ringCy, ringDia);
      html += `<i class="portrait" style="left:${cx - ringDia / 2 - 1}px;top:${ringCy - ringDia / 2 - 1}px;width:${ringDia + 2}px;height:${ringDia + 2}px;background:rgba(0,0,0,.6)"></i>`;
      html += K.portrait(cx, ringCy, ringDia - 2 * r.width + 2, p.hue);
      html += r.html;
      if (layout !== 'inset' && p.level) {
        const bx = cx + (p.mirror ? -1 : 1) * ringDia * 0.33, by = ringCy + ringDia * 0.36;
        html += badge(skin, bx, by, p.level);
      }
    }
    if (p.extra) html += p.extra;
    return `<div class="unit" style="left:${p.x}px;top:${p.y}px;width:${w}px;height:${h}px">${html}</div>`;
  }

  // Cast bar. p: {x, y, w, h, v, spell, time, icon, color, state: cast|channel|fail|shield}
  function cast(skin, p) {
    const e = K.edgeWidth(K.SKINS[skin].border);
    const w = p.w, h = p.h;
    const col = p.state === 'fail' ? [0.85, 0.2, 0.15] : p.state === 'channel' ? [0.35, 0.75, 0.35]
      : p.state === 'shield' ? [0.6, 0.6, 0.62] : (p.color || [1, 0.74, 0.12]);
    // The spell icon is its own square left of the bar (h x h, a 1 px border-colored
    // edge), so thick skin borders never squeeze it.
    let html = '', ox = 0;
    if (p.icon !== false) {
      html += `<i class="icon" style="left:0;top:0;width:${h}px;height:${h}px;background:${p.iconBg || 'radial-gradient(circle at 40% 35%, #ffe7a0, #e07b18 45%, #5a1c06 90%)'};box-shadow:inset 0 0 0 1px ${css(sc(C.border, 0.2))}, inset 0 0 0 2px ${css(C.border)}"></i>`;
      if (p.state === 'shield') html += `<i class="shield" style="left:${h * 0.15}px;top:${h * 0.1}px;width:${h * 0.7}px;height:${h * 0.8}px"></i>`;
      ox = h + 2;
    }
    const pw = w - ox;
    html += K.panel(skin, { w: pw, h, x: ox, y: 0, studs: h >= 24 });
    const bl = ox + e + 1;
    const bw = pw - 2 * e - 2;
    const spark = p.state === 'fail' ? '' : `<i style="position:absolute;left:${Math.round(bw * p.v) - 2}px;top:-2px;width:4px;bottom:-2px;background:radial-gradient(ellipse at center, rgba(255,250,220,.95), rgba(255,220,120,0) 70%)"></i>`;
    html += K.bar(bl, e + 1, bw, h - 2 * e - 2, p.state === 'fail' ? 1 : p.v, col, p.tex || 'smooth', spark);
    const fs = Math.max(9, Math.min(10, h - 8));
    const ty = (h - fs * 1.2) / 2;
    html += K.text(bl + 3, ty, p.state === 'fail' ? 'Interrupted' : p.spell, { size: fs });
    if (p.time && p.state !== 'fail') html += K.text(e + 4, ty, p.time, { size: fs, align: 'right' });
    return `<div class="unit" style="left:${p.x}px;top:${p.y}px;width:${w}px;height:${h}px">${html}</div>`;
  }

  return { frame, cast, badge };
})();
