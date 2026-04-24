import fs from 'fs';

const INPUT = '.temp-pdf/specialized_extracted_with_fonts.txt';
const OUT_JSON = '.temp-pdf/specialized_parsed_questions.json';
const OUT_SQL = '.temp-pdf/specialized_parsed_questions.sql';

const SECTION_HEADERS = [
  ['NEURO SYSTEM', 'neurology'],
  ['CARDIO SYSTEM', 'cardiology'],
  ['RESPIRATORY SYSTEM', 'respiratory'],
  ['GASTROINTESTINAL SYSTEM', 'gastrointestinal'],
  ['ENDOCRINE SYSTEM', 'endocrinology'],
  ['RENAL SYSTEM', 'renal'],
  ['OB/GYN SYSTEM', 'ob_gyn'],
  ['ONCOLOGY', 'oncology'],
  ['DERMATOLOGY', 'dermatology'],
  ['EMERGENCY / ER', 'emergency'],
  ['EAR AND EYE', 'ear_and_eye'],
];

const fontRe = /^\[font=([^\]]+)\]\s*(.*)$/;
const qNumRe = /^(\d{1,2})\s*[\.)]?\s*(.*)$/;
const optInlineRe = /^\(?([A-Da-d]|[1-4])\)?\s*[\.)]\s*(.*)$/;
const optMarkerOnlyRe = /^\(?([A-Da-d]|[1-4])\)?\s*[\.)]?\s*$/;

function normalizeSpaces(s) {
  return (s || '').replace(/\s+/g, ' ').trim();
}

function fontRank(fontName) {
  const m = /f(\d+)$/.exec(fontName || '');
  return m ? Number(m[1]) : 0;
}

function cleanOptionText(s) {
  return normalizeSpaces((s || '').replace(/^[•\-]+\s*/, ''));
}

function looksLikeSectionHeader(text) {
  const up = normalizeSpaces(text).toUpperCase();
  for (const [needle, id] of SECTION_HEADERS) {
    if (up.includes(needle)) return id;
  }
  return null;
}

function isCheckMark(text) {
  return normalizeSpaces(text) === '✔';
}

function makeQuestion(qnum = null) {
  return {
    number: qnum,
    textLines: [],
    options: [], // { text, rank }
    correctIdx: null,
  };
}

function addOption(q, text, rank) {
  const t = cleanOptionText(text);
  if (!t) return;
  q.options.push({ text: t, rank });
}

function finalizeQuestion(sectionId, q, out, issues) {
  if (!q) return;
  const qText = normalizeSpaces(q.textLines.join(' '));
  let options = q.options;

  if (!qText) {
    issues.push(`${sectionId}: dropped empty question text`);
    return;
  }

  if (options.length < 4) {
    issues.push(`${sectionId} q${q.number ?? '?'}: only ${options.length} options -> ${qText.slice(0, 90)}`);
    return;
  }
  if (options.length > 4) {
    issues.push(`${sectionId} q${q.number ?? '?'}: ${options.length} options, truncating to 4`);
    options = options.slice(0, 4);
  }

  let correctIdx = q.correctIdx;
  if (correctIdx == null) {
    const ranks = options.map((o) => o.rank);
    const maxRank = Math.max(...ranks);
    const minRank = Math.min(...ranks);
    const maxCount = ranks.filter((r) => r === maxRank).length;
    if (maxCount === 1 && maxRank > minRank) {
      correctIdx = ranks.indexOf(maxRank);
    } else {
      issues.push(`${sectionId} q${q.number ?? '?'}: no explicit correct marker, defaulting A -> ${qText.slice(0, 90)}`);
      correctIdx = 0;
    }
  }

  out[sectionId].push({
    number: q.number,
    questionText: qText,
    options: options.map((o) => o.text),
    correctOption: ['A', 'B', 'C', 'D'][correctIdx],
  });
}

function parseTokens(tokens) {
  const out = {};
  const issues = [];
  for (const [, sid] of SECTION_HEADERS) out[sid] = [];

  let currentSection = null;
  let currentQ = null;
  let pendingQnum = null;
  let pendingOptMarker = null;
  let inUnmarkedOptions = false;

  const flushQuestion = () => {
    if (currentQ && currentSection) finalizeQuestion(currentSection, currentQ, out, issues);
    currentQ = null;
    pendingOptMarker = null;
    inUnmarkedOptions = false;
  };

  for (const { font, text } of tokens) {
    const section = looksLikeSectionHeader(text);
    if (section) {
      flushQuestion();
      currentSection = section;
      pendingQnum = null;
      continue;
    }

    if (!currentSection) continue;

    if (isCheckMark(text)) {
      if (currentQ && currentQ.options.length) currentQ.correctIdx = currentQ.options.length - 1;
      continue;
    }

    if (pendingQnum != null) {
      flushQuestion();
      currentQ = makeQuestion(pendingQnum);
      currentQ.textLines.push(text);
      pendingQnum = null;
      continue;
    }

    const mInline = optInlineRe.exec(text);
    if (mInline && normalizeSpaces(mInline[2])) {
      if (!currentQ) currentQ = makeQuestion(null);
      addOption(currentQ, mInline[2], fontRank(font));
      pendingOptMarker = null;
      inUnmarkedOptions = false;
      continue;
    }

    const mOnly = optMarkerOnlyRe.exec(text);
    if (mOnly) {
      const mk = mOnly[1];
      const asInt = /^\d+$/.test(mk) ? Number(mk) : null;
      const expectedNext = out[currentSection].length + 1;

      if (
        asInt != null &&
        currentQ &&
        currentQ.options.length > 0 &&
        asInt <= 4 &&
        currentQ.options.length < 4
      ) {
        pendingOptMarker = mk;
        continue;
      }

      if (asInt != null && (asInt === expectedNext || asInt > 4)) {
        pendingQnum = asInt;
        continue;
      }

      pendingOptMarker = mk;
      continue;
    }

    const mQ = qNumRe.exec(text);
    if (mQ) {
      const qnum = Number(mQ[1]);
      const rest = normalizeSpaces(mQ[2]);
      const expectedNext = out[currentSection].length + 1;

      if (qnum <= 4 && currentQ && currentQ.options.length > 0 && currentQ.options.length < 4) {
        if (rest) addOption(currentQ, rest, fontRank(font));
        else pendingOptMarker = String(qnum);
        continue;
      }

      if (rest) {
        if (qnum === expectedNext || (qnum > 4 && (!currentQ || currentQ.options.length >= 2))) {
          flushQuestion();
          currentQ = makeQuestion(qnum);
          currentQ.textLines.push(rest);
          continue;
        }
      } else if (qnum === expectedNext || qnum > 4) {
        pendingQnum = qnum;
        continue;
      }
    }

    if (pendingOptMarker != null) {
      if (!currentQ) currentQ = makeQuestion(null);
      addOption(currentQ, text, fontRank(font));
      pendingOptMarker = null;
      inUnmarkedOptions = false;
      continue;
    }

    if (!currentQ) {
      currentQ = makeQuestion(out[currentSection].length === 0 ? 1 : null);
      currentQ.textLines.push(text);
      continue;
    }

    if (currentQ.options.length > 0) {
      if (currentQ.options.length < 4) {
        if (inUnmarkedOptions) {
          addOption(currentQ, text, fontRank(font));
        } else {
          if (text.split(/\s+/).length <= 2) {
            const prev = currentQ.options[currentQ.options.length - 1];
            prev.text = normalizeSpaces(`${prev.text} ${text}`);
          } else {
            addOption(currentQ, text, fontRank(font));
            inUnmarkedOptions = true;
          }
        }
      } else {
        currentQ.textLines.push(text);
      }
    } else {
      const lastText = currentQ.textLines[currentQ.textLines.length - 1] || '';
      if (/[\?:]$/.test(lastText)) {
        addOption(currentQ, text, fontRank(font));
        inUnmarkedOptions = true;
      } else {
        currentQ.textLines.push(text);
      }
    }
  }

  if (currentQ && currentSection) finalizeQuestion(currentSection, currentQ, out, issues);

  for (const sid of Object.keys(out)) {
    out[sid].sort((a, b) => (a.number ?? 999) - (b.number ?? 999));
  }

  return { out, issues };
}

function buildSql(data) {
  const sectionIds = Object.keys(data).filter((sid) => data[sid].length > 0);
  const rows = [];
  for (const sid of sectionIds) {
    for (const q of data[sid]) {
      const qt = q.questionText.replace(/'/g, "''");
      const [oa, ob, oc, od] = q.options.map((v) => v.replace(/'/g, "''"));
      rows.push(`  ('medical', '${sid}', '${qt}', '${oa}', '${ob}', '${oc}', '${od}', '${q.correctOption}')`);
    }
  }

  return `-- Replace medical quiz banks from specialized med questions.pdf\n\nBEGIN;\n\nDELETE FROM public.quiz_questions\nWHERE quiz_type = 'medical'\n  AND medical_section IN (${sectionIds.map((s) => `'${s}'`).join(', ')});\n\nINSERT INTO public.quiz_questions(\n  quiz_type,\n  medical_section,\n  question_text,\n  option_a,\n  option_b,\n  option_c,\n  option_d,\n  correct_option\n) VALUES\n${rows.join(',\n')};\n\nCOMMIT;\n`;
}

function main() {
  const raw = fs.readFileSync(INPUT, 'utf-8').split(/\r?\n/);
  const tokens = [];
  for (const line of raw) {
    const s = line.trim();
    if (!s || s.startsWith('===== PAGE')) continue;
    const m = fontRe.exec(s);
    if (!m) continue;
    const text = normalizeSpaces(m[2]);
    if (!text) continue;
    tokens.push({ font: m[1], text });
  }

  const { out, issues } = parseTokens(tokens);

  fs.writeFileSync(OUT_JSON, JSON.stringify(out, null, 2), 'utf-8');
  fs.writeFileSync(OUT_SQL, buildSql(out), 'utf-8');

  const sectionCounts = Object.fromEntries(Object.entries(out).map(([k, v]) => [k, v.length]));
  const total = Object.values(sectionCounts).reduce((a, b) => a + b, 0);

  console.log('Sections parsed:', Object.keys(out).length);
  for (const sid of Object.keys(sectionCounts).sort()) {
    console.log(`${sid}: ${sectionCounts[sid]}`);
  }
  console.log('Total questions:', total);
  console.log('Issues:', issues.length);
  for (const item of issues.slice(0, 200)) {
    console.log('-', item);
  }
  if (issues.length > 200) {
    console.log(`... and ${issues.length - 200} more`);
  }
}

main();
