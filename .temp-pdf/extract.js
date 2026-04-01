const fs = require('fs');
const path = require('path');
const pdfjsLib = require('./.temp-pdf/node_modules/pdfjs-dist/legacy/build/pdf.mjs');

(async () => {
  const filePath = path.resolve('50 General questions.pdf');
  const data = new Uint8Array(fs.readFileSync(filePath));
  const loadingTask = pdfjsLib.getDocument({ data, disableWorker: true });
  const pdf = await loadingTask.promise;
  let out = [];
  for (let p = 1; p <= pdf.numPages; p++) {
    const page = await pdf.getPage(p);
    const tc = await page.getTextContent();
    out.push(`\\n===== PAGE ${p} =====`);
    for (const item of tc.items) {
      const s = (item.str || '').trim();
      if (!s) continue;
      out.push(`[font=${item.fontName}] ${s}`);
    }
  }
  fs.writeFileSync('.temp-pdf/extracted_with_fonts.txt', out.join('\\n'));
  console.log('written .temp-pdf/extracted_with_fonts.txt');
})();
