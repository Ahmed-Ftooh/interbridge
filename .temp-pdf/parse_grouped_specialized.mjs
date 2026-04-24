import fs from 'fs';

const INPUT = '.temp-pdf/specialized_grouped_lines.txt';
const OUT_JSON = '.temp-pdf/specialized_grouped_parsed.json';
const OUT_SQL = '.temp-pdf/specialized_grouped_parsed.sql';

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

const lineRe = /^\[fonts=([^\]]+)\]\s*(.*)$/;
const leadingNumRe = /^(\d{1,2})\s*[\.)]?\s*(.*)$/;
const optionInlineRe = /^\(?([A-Da-d]|\d{1,2})\)?[\.)]\s*(.+)$/;
const optionMarkerOnlyRe = /^\(?([A-Da-d]|\d{1,2})\)?[\.)]\s*$/;

function normalize(s) {
  return (s || '').replace(/\s+/g, ' ').trim();
}

function sectionFromHeader(text) {
  const up = normalize(text).toUpperCase();
  for (const [needle, sid] of SECTION_HEADERS) {
    if (up.includes(needle)) return sid;
  }
  return null;
}

function maxFontRank(fonts) {
  let max = 0;
  for (const f of (fonts || '').split(',')) {
    const m = /f(\d+)$/.exec(f.trim());
    if (m) max = Math.max(max, Number(m[1]));
  }
  return max;
}

function cleanQuestionText(s) {
  let t = normalize(s);
  t = t.replace(/^\d{1,2}\s*[\.)]\s*/, '');
  t = t.replace(/^\d{1,2}\s*[\.)]\s*/, '');
  t = t.replace(/^\.+\s*/, '');
  return normalize(t);
}

function cleanOptionText(s) {
  let t = normalize(s);
  t = t.replace(/^\.+\s*/, '');
  t = t.replace(/^\(?([A-Da-d]|\d{1,2})\)?[\.)]\s*/, '');
  return normalize(t);
}

function looksQuestionLike(text, fonts = '') {
  const t = normalize(text);
  if (!t) return false;
  if (/[\?:]$/.test(t)) return true;
  if (t.split(' ').length >= 7) return true;
  if (/(f2|f4|f5)/.test(fonts) && t.split(' ').length >= 4) return true;
  return false;
}

function parseSection(lines, sectionId) {
  const questions = [];
  const issues = [];

  let expected = 1;
  let q = null;
  let pendingOption = false;

  function startQuestion(qnum, initialText = '') {
    q = {
      number: qnum,
      textLines: [],
      options: [], // { text, rank }
      correctIdx: null,
    };
    const t = cleanQuestionText(initialText);
    if (t) q.textLines.push(t);
  }

  function pushOption(text, rank, checked) {
    const t = cleanOptionText(text);
    if (!t) return;
    q.options.push({ text: t, rank });
    if (checked) q.correctIdx = q.options.length - 1;
  }

  function finalizeQuestion() {
    if (!q) return;

    const questionText = cleanQuestionText(q.textLines.join(' '));
    const opts = q.options
      .map((o) => ({ ...o, text: cleanOptionText(o.text) }))
      .filter((o) => o.text);

    if (!questionText) {
      issues.push(`${sectionId} q${q.number}: empty question text`);
      q = null;
      return;
    }

    if (opts.length !== 4) {
      issues.push(
        `${sectionId} q${q.number}: options=${opts.length} -> ${questionText.slice(0, 90)}`,
      );
      q = null;
      return;
    }

    let correctIdx = q.correctIdx;
    if (correctIdx == null) {
      const ranks = opts.map((o) => o.rank);
      const max = Math.max(...ranks);
      const min = Math.min(...ranks);
      const maxCount = ranks.filter((r) => r === max).length;
      if (maxCount === 1 && max > min) {
        correctIdx = ranks.indexOf(max);
      } else {
        issues.push(`${sectionId} q${q.number}: no clear correct marker, defaulting A`);
        correctIdx = 0;
      }
    }

    questions.push({
      number: q.number,
      questionText,
      options: opts.map((o) => o.text),
      correctOption: ['A', 'B', 'C', 'D'][correctIdx],
    });

    q = null;
    pendingOption = false;
  }

  function explicitQuestionStart(lineText, fonts) {
    const m = leadingNumRe.exec(lineText);
    if (!m) return null;

    const num = Number(m[1]);
    if (num !== expected) return null;

    let rest = cleanQuestionText(m[2]);

    if (expected > 4) {
      return { num, rest };
    }

    // For early questions (1-4), avoid confusing option lines like "2. ALS".
    if (q && q.options.length > 0 && q.options.length < 4) {
      if (!looksQuestionLike(rest, fonts)) return null;
    }

    if (!rest && !(fonts || '').match(/f2|f4|f5/)) {
      return null;
    }

    return { num, rest };
  }

  for (const { fonts, text } of lines) {
    const rank = maxFontRank(fonts);
    const checked = text.includes('✔');
    const stripped = normalize(text.replace(/✔/g, ''));
    if (!stripped) continue;

    if (!q) {
      const qStart = explicitQuestionStart(stripped, fonts);
      if (qStart) {
        startQuestion(expected, qStart.rest);
      } else {
        // Unnumbered first question in section.
        startQuestion(expected, stripped);
      }
      expected += 1;
      continue;
    }

    const qStart = explicitQuestionStart(stripped, fonts);
    if (qStart) {
      finalizeQuestion();
      startQuestion(expected, qStart.rest);
      expected += 1;
      continue;
    }

    // Some OCR lines lose numbering; after 4 options, treat next question-like line as a new question.
    if (q.options.length === 4 && looksQuestionLike(stripped, fonts)) {
      finalizeQuestion();
      startQuestion(expected, stripped);
      expected += 1;
      continue;
    }

    if (pendingOption) {
      pushOption(stripped, rank, checked);
      pendingOption = false;
      continue;
    }

    if (optionMarkerOnlyRe.test(stripped)) {
      pendingOption = true;
      continue;
    }

    const mOpt = optionInlineRe.exec(stripped);
    if (mOpt) {
      pushOption(mOpt[2], rank, checked);
      continue;
    }

    // Plain line handling.
    if (q.options.length === 0) {
      const stem = normalize(q.textLines.join(' '));
      if (/[\?:]$/.test(stem)) {
        // unlabeled options block starts after the stem.
        pushOption(stripped, rank, checked);
      } else {
        q.textLines.push(stripped);
      }
      continue;
    }

    if (q.options.length < 4) {
      // Remaining unlabeled options or wrapped option text.
      const prev = q.options[q.options.length - 1];
      if (prev && prev.text.split(' ').length > 10 && /^[a-z(]/.test(stripped)) {
        prev.text = normalize(`${prev.text} ${stripped}`);
        if (checked) q.correctIdx = q.options.length - 1;
      } else {
        pushOption(stripped, rank, checked);
      }
      continue;
    }

    // Extra tail after 4 options: usually wrapped text for the last option.
    const prev = q.options[q.options.length - 1];
    prev.text = normalize(`${prev.text} ${stripped}`);
    if (checked) q.correctIdx = q.options.length - 1;
  }

  finalizeQuestion();
  questions.sort((a, b) => a.number - b.number);
  return { questions, issues };
}

function buildSql(data) {
  const sectionIds = Object.keys(data).filter((sid) => data[sid].length > 0);
  const rows = [];

  for (const sid of sectionIds) {
    for (const q of data[sid]) {
      const qt = q.questionText.replace(/'/g, "''");
      const [oa, ob, oc, od] = q.options.map((o) => o.replace(/'/g, "''"));
      rows.push(`  ('medical', '${sid}', '${qt}', '${oa}', '${ob}', '${oc}', '${od}', '${q.correctOption}')`);
    }
  }

  return `-- Replace medical quizzes from specialized med questions.pdf\n\nBEGIN;\n\nDELETE FROM public.quiz_questions\nWHERE quiz_type = 'medical'\n  AND medical_section IN (${sectionIds.map((s) => `'${s}'`).join(', ')});\n\nINSERT INTO public.quiz_questions(\n  quiz_type,\n  medical_section,\n  question_text,\n  option_a,\n  option_b,\n  option_c,\n  option_d,\n  correct_option\n) VALUES\n${rows.join(',\n')};\n\nCOMMIT;\n`;
}

function main() {
  const raw = fs.readFileSync(INPUT, 'utf-8').split(/\r?\n/);
  const tokens = [];
  for (const line of raw) {
    const s = line.trim();
    if (!s || s.startsWith('===== PAGE')) continue;
    const m = lineRe.exec(s);
    if (!m) continue;
    tokens.push({ fonts: m[1], text: normalize(m[2]) });
  }

  const bySection = {};
  for (const [, sid] of SECTION_HEADERS) bySection[sid] = [];

  let currentSection = null;
  for (const t of tokens) {
    const sid = sectionFromHeader(t.text);
    if (sid) {
      currentSection = sid;
      continue;
    }
    if (!currentSection) continue;
    bySection[currentSection].push(t);
  }

  const parsed = {};
  const allIssues = [];
  let total = 0;

  for (const [, sid] of SECTION_HEADERS) {
    const { questions, issues } = parseSection(bySection[sid], sid);
    parsed[sid] = questions;
    total += questions.length;
    allIssues.push(...issues);
  }

  fs.writeFileSync(OUT_JSON, JSON.stringify(parsed, null, 2), 'utf-8');
  fs.writeFileSync(OUT_SQL, buildSql(parsed), 'utf-8');

  console.log('Section counts:');
  for (const sid of Object.keys(parsed)) {
    console.log(`${sid}: ${parsed[sid].length}`);
  }
  console.log('Total:', total);
  console.log('Issues:', allIssues.length);
  for (const issue of allIssues.slice(0, 120)) {
    console.log('-', issue);
  }
  if (allIssues.length > 120) {
    console.log(`... and ${allIssues.length - 120} more`);
  }
}

main();
