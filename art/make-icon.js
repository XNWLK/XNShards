// Draws XNShards' icon (CurseForge avatar): two whole Soul Shards glowing in the middle, and a third one to the
// right shattering into pieces - you keep two, the rest are destroyed. Writes art/icon.svg, then art/icon-512.png
// and art/icon-400.png with Edge headless (same way as XNDR's icon).
//   node art/make-icon.js
const fs = require('fs'), path = require('path'), os = require('os'), { execFileSync } = require('child_process');
const ART = __dirname;
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const f = n => n.toFixed(2);

// a shard in unit space: tip at (0,-1), base at (0,1), ridge point M where the four faces meet
const P = { T: [0, -1], UR: [0.44, -0.42], LR: [0.36, 0.56], B: [0, 1], LL: [-0.36, 0.56], UL: [-0.44, -0.42], M: [0.06, -0.12] };
const FACES = [
  { pts: ['T', 'UL', 'M'], fill: 'url(#faceLight)' },
  { pts: ['T', 'M', 'UR'], fill: 'url(#faceMid)' },
  { pts: ['UL', 'LL', 'B', 'M'], fill: 'url(#faceDark)' },
  { pts: ['M', 'B', 'LR', 'UR'], fill: 'url(#faceDeep)' },
];
function place([x, y], cx, cy, s, rot) {
  const a = rot * Math.PI / 180;
  const px = x * s * 0.62, py = y * s; // shards are taller than wide
  return [cx + px * Math.cos(a) - py * Math.sin(a), cy + px * Math.sin(a) + py * Math.cos(a)];
}
const poly = (names, cx, cy, s, rot) => names.map(n => place(P[n], cx, cy, s, rot).map(f).join(',')).join(' ');

function shard(cx, cy, s, rot) {
  const outline = poly(['T', 'UR', 'LR', 'B', 'LL', 'UL'], cx, cy, s, rot);
  const [hx1, hy1] = place([-0.30, -0.40], cx, cy, s, rot), [hx2, hy2] = place([-0.04, -0.86], cx, cy, s, rot);
  return `<g>
    <polygon points="${outline}" fill="#B07CFF" opacity="0.55" filter="url(#glow)"/>
    ${FACES.map(face => `<polygon points="${poly(face.pts, cx, cy, s, rot)}" fill="${face.fill}"/>`).join('\n    ')}
    <polygon points="${outline}" fill="none" stroke="#14061F" stroke-width="5" stroke-linejoin="round"/>
    <line x1="${f(hx1)}" y1="${f(hy1)}" x2="${f(hx2)}" y2="${f(hy2)}" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity="0.7"/>
  </g>`;
}

// the destroyed shard: a whole shard cut into three pieces along jagged cracks, the pieces pushed apart along
// the shard and turned, with sparks flying off
const CUTS = [
  [[-0.9, -0.30], [-0.35, -0.40], [-0.05, -0.24], [0.3, -0.44], [0.9, -0.32]],
  [[-0.9, 0.30], [-0.3, 0.20], [0.05, 0.40], [0.35, 0.24], [0.9, 0.34]],
];
const PIECES = [
  [[-0.9, -1.3], [0.9, -1.3], ...CUTS[0].slice().reverse()],
  [...CUTS[0], ...CUTS[1].slice().reverse()],
  [...CUTS[1], [0.9, 1.3], [-0.9, 1.3]],
];
let clipId = 0;
function shattered(cx, cy, s, rot) {
  const outline = poly(['T', 'UR', 'LR', 'B', 'LL', 'UL'], cx, cy, s, rot);
  // along the shard (tip direction) and across it, for pushing the pieces apart
  const a = rot * Math.PI / 180, up = [Math.sin(a), -Math.cos(a)], side = [Math.cos(a), Math.sin(a)];
  const moves = [[34, -6, 16], [6, 16, -10], [-18, 10, -18]]; // along, across, turn
  const shapeId = `shape${clipId++}`;
  const defs = [`<clipPath id="${shapeId}"><polygon points="${outline}"/></clipPath>`], parts = [];
  const line = cut => cut.map(p => place(p, cx, cy, s, rot).map(f).join(',')).join(' ');
  PIECES.forEach((piece, i) => {
    const id = `piece${clipId++}`;
    defs.push(`<clipPath id="${id}"><polygon points="${line(piece)}"/></clipPath>`);
    const [along, across, turn] = moves[i];
    const dx = up[0] * along + side[0] * across, dy = up[1] * along + side[1] * across;
    const cracks = [i > 0 && CUTS[i - 1], i < CUTS.length && CUTS[i]].filter(Boolean)
      .map(cut => `<polyline points="${line(cut)}" fill="none" stroke="#14061F" stroke-width="6" stroke-linejoin="round"/>`).join('');
    // the piece: the shard clipped to its band, its edges and cracks clipped to the shard's outline
    parts.push(`<g transform="translate(${f(dx)} ${f(dy)}) rotate(${turn} ${cx} ${cy})"><g clip-path="url(#${id})"><g clip-path="url(#${shapeId})">
      ${FACES.map(face => `<polygon points="${poly(face.pts, cx, cy, s, rot)}" fill="${face.fill}"/>`).join('\n      ')}
      <polygon points="${outline}" fill="none" stroke="#14061F" stroke-width="9" stroke-linejoin="round"/>
      ${cracks}
    </g></g></g>`);
  });
  const parts_ = parts.join('\n  ');
  const sparks = [[-58, -10, 7], [52, -54, 6], [64, 18, 8], [-40, 60, 5], [10, -78, 5], [34, 70, 6], [-70, -46, 4], [78, -16, 4]]
    .map(([dx, dy, r]) => `<polygon points="${f(cx + dx)},${f(cy + dy - r)} ${f(cx + dx + r * 0.5)},${f(cy + dy)} ${f(cx + dx)},${f(cy + dy + r)} ${f(cx + dx - r * 0.5)},${f(cy + dy)}" fill="#F2E2FF"/>`)
    .join('\n  ');
  return `<g>
  <defs>${defs.join('')}</defs>
  <circle cx="${cx}" cy="${cy}" r="${f(s * 0.95)}" fill="#C79BFF" opacity="0.35" filter="url(#glow)"/>
  ${parts_}
  <g filter="url(#soft)">${sparks}</g>
  ${sparks}
</g>`;
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 400 400">
  <defs>
    <radialGradient id="field" cx="0.4" cy="0.45" r="0.85">
      <stop offset="0" stop-color="#3A1A5C"/>
      <stop offset="0.6" stop-color="#170A26"/>
      <stop offset="1" stop-color="#06030B"/>
    </radialGradient>
    <radialGradient id="light" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#A26BFF" stop-opacity="0.45"/>
      <stop offset="1" stop-color="#A26BFF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="faceLight" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#F3E6FF"/>
      <stop offset="1" stop-color="#C69BFF"/>
    </linearGradient>
    <linearGradient id="faceMid" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#C08CFF"/>
      <stop offset="1" stop-color="#8B4FE0"/>
    </linearGradient>
    <linearGradient id="faceDark" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#9A5CEB"/>
      <stop offset="1" stop-color="#5A23A8"/>
    </linearGradient>
    <linearGradient id="faceDeep" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#6A2EBF"/>
      <stop offset="1" stop-color="#2E0F63"/>
    </linearGradient>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>
    <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4"/></filter>
  </defs>

  <rect width="400" height="400" fill="url(#field)"/>
  <circle cx="190" cy="235" r="170" fill="url(#light)"/>

  <!-- the destroyed shard -->
  ${shattered(318, 112, 60, 28)}

  <!-- the two kept shards -->
  ${shard(232, 250, 104, 14)}
  ${shard(148, 236, 118, -8)}

  <!-- a frame -->
  <rect x="6" y="6" width="388" height="388" rx="28" fill="none" stroke="#0B0414" stroke-width="10"/>
  <rect x="12" y="12" width="376" height="376" rx="24" fill="none" stroke="#B48CFF" stroke-width="2" opacity="0.5"/>
</svg>`;
fs.writeFileSync(path.join(ART, 'icon.svg'), svg);

// PNGs: the SVG in a page of exactly that size, screenshot by Edge headless
for (const size of [512, 400]) {
  const html = path.join(ART, `_icon-${size}.html`), out = path.join(ART, `icon-${size}.png`);
  fs.writeFileSync(html, `<!doctype html><html><body style="margin:0;overflow:hidden;background:#06030B">` +
    svg.replace('width="400" height="400"', `width="${size}" height="${size}"`) + `</body></html>`);
  if (fs.existsSync(out)) fs.unlinkSync(out);
  execFileSync(EDGE, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
    '--user-data-dir=' + path.join(os.tmpdir(), 'xnshards-icon-edge'), `--window-size=${size},${size}`, `--screenshot=${out}`,
    'file:///' + html.replace(/\\/g, '/')], { stdio: 'ignore' });
  // Edge hands the work to another process and returns early: wait for the file
  for (let i = 0; i < 100 && !fs.existsSync(out); i++) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 200);
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
  fs.unlinkSync(html);
  console.log(out, fs.statSync(out).size, 'bytes');
}
