import fs from 'fs';
import path from 'path';
import { getDocument } from './node_modules/pdfjs-dist/legacy/build/pdf.mjs';

const filePath = path.resolve('specialized med questions.pdf');
const data = new Uint8Array(fs.readFileSync(filePath));
const loadingTask = getDocument({ data, disableWorker: true });
const pdf = await loadingTask.promise;

let out = [];
for (let p = 1; p <= pdf.numPages; p++) {
  const page = await pdf.getPage(p);
  const tc = await page.getTextContent();

  // Build rows by Y coordinate with tolerance
  const rows = [];
  for (const item of tc.items) {
    const s = (item.str || '').trim();
    if (!s) continue;
    const x = item.transform?.[4] ?? 0;
    const y = item.transform?.[5] ?? 0;

    let row = rows.find((r) => Math.abs(r.y - y) < 2);
    if (!row) {
      row = { y, items: [] };
      rows.push(row);
    }
    row.items.push({ x, text: s, font: item.fontName || '' });
  }

  // Sort from top to bottom (descending y in PDF coordinates), then left to right.
  rows.sort((a, b) => b.y - a.y);

  out.push(`\n===== PAGE ${p} =====`);
  for (const row of rows) {
    row.items.sort((a, b) => a.x - b.x);
    const line = row.items.map((i) => i.text).join(' ').replace(/\s+/g, ' ').trim();
    if (!line) continue;

    // Include condensed font hints to preserve bold/check cues.
    const fonts = [...new Set(row.items.map((i) => i.font))].join(',');
    out.push(`[fonts=${fonts}] ${line}`);
  }
}

fs.writeFileSync('.temp-pdf/specialized_grouped_lines.txt', out.join('\n'));
console.log('written .temp-pdf/specialized_grouped_lines.txt');
