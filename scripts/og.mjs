// Builds public/og.png (1200x630), the image shown when the site is shared.
// Run with: node scripts/og.mjs
import sharp from 'sharp';

const W = 1200;
const H = 630;
const panelH = 452;
const panelW = Math.round((758 * panelH) / 1024);
const padX = 28;
const padTop = 34;
const padBottom = 64;
const bezelW = panelW + padX * 2;
const bezelH = panelH + padTop + padBottom;
const bx = W - bezelW - 96;
const by = Math.round((H - bezelH) / 2);

const svg = `<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%" fill="#f3f1ea"/>
  <rect x="96" y="150" width="14" height="14" rx="3" fill="#141414"/>
  <text x="122" y="164" font-family="Menlo, monospace" font-size="21" letter-spacing="2" fill="#4a4944">STREAMDECKIFY</text>
  <text x="92" y="268" font-family="Georgia, serif" font-size="82" font-weight="700" fill="#141414">Any screen</text>
  <text x="92" y="360" font-family="Georgia, serif" font-size="82" font-weight="700" fill="#141414">can be a</text>
  <text x="92" y="452" font-family="Georgia, serif" font-size="82" font-style="italic" fill="#141414">Stream Deck.</text>
  <text x="96" y="526" font-family="Menlo, monospace" font-size="21" fill="#77756d">One prompt. An old Kindle. 200 ms a tap.</text>
  <rect x="${bx}" y="${by}" width="${bezelW}" height="${bezelH}" rx="38" fill="#1c1c1b"/>
  <rect x="${bx + bezelW / 2 - 26}" y="${by + bezelH - 36}" width="52" height="6" rx="3" fill="#3a3a38"/>
</svg>`;

const panel = await sharp('src/content/decks/enzo-kindle-pw2-mac.png').resize(panelW, panelH).toBuffer();
await sharp(Buffer.from(svg))
  .composite([{ input: panel, left: bx + padX, top: by + padTop }])
  .png({ compressionLevel: 9 })
  .toFile('public/og.png');
console.log('public/og.png written');
