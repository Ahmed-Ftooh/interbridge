import json
import re
from collections import defaultdict

INPUT = '.temp-pdf/specialized_extracted_with_fonts.txt'
OUT_JSON = '.temp-pdf/specialized_parsed_questions.json'
OUT_SQL = '.temp-pdf/specialized_parsed_questions.sql'

SECTION_HEADERS = [
    ('NEURO SYSTEM', 'neurology'),
    ('CARDIO SYSTEM', 'cardiology'),
    ('RESPIRATORY SYSTEM', 'respiratory'),
    ('GASTROINTESTINAL SYSTEM', 'gastrointestinal'),
    ('ENDOCRINE SYSTEM', 'endocrinology'),
    ('RENAL SYSTEM', 'renal'),
    ('OB/GYN SYSTEM', 'ob_gyn'),
    ('ONCOLOGY', 'oncology'),
    ('DERMATOLOGY', 'dermatology'),
    ('EMERGENCY / ER', 'emergency'),
    ('EAR AND EYE', 'ear_and_eye'),
]

FONT_RE = re.compile(r'^\[font=([^\]]+)\]\s*(.*)$')
QNUM_RE = re.compile(r'^(\d{1,2})\s*[\.)]?\s*(.*)$')
OPT_INLINE_RE = re.compile(r'^\(?([A-Da-d]|[1-4])\)?\s*[\.)]\s*(.*)$')
OPT_MARKER_ONLY_RE = re.compile(r'^\(?([A-Da-d]|[1-4])\)?\s*[\.)]?\s*$')


def font_rank(font_name: str) -> int:
    m = re.search(r'f(\d+)$', font_name or '')
    return int(m.group(1)) if m else 0


def normalize_spaces(s: str) -> str:
    return re.sub(r'\s+', ' ', s).strip()


def clean_option_text(s: str) -> str:
    s = s.strip()
    s = re.sub(r'^[•\-]+\s*', '', s)
    s = normalize_spaces(s)
    return s


def looks_like_section_header(text: str):
    up = normalize_spaces(text).upper()
    for needle, sid in SECTION_HEADERS:
        if needle in up:
            return sid
    return None


def is_check_mark(text: str) -> bool:
    t = text.strip()
    return t == '✔'


def make_question(qnum=None):
    return {
        'number': qnum,
        'text_lines': [],
        'options': [],  # {text, rank}
        'correct_idx': None,
    }


def add_option(q, text, rank):
    text = clean_option_text(text)
    if not text:
        return
    q['options'].append({'text': text, 'rank': rank})


def finalize_question(section_id, q, out, issues):
    if q is None:
        return

    q_text = normalize_spaces(' '.join(q['text_lines']))
    options = q['options']

    if not q_text:
        issues.append(f'{section_id}: dropped empty question text')
        return

    # Trim to 4 options if OCR duplicated/overflowed; otherwise flag.
    if len(options) < 4:
        issues.append(f"{section_id} q{q.get('number')}: only {len(options)} options -> {q_text[:80]}")
        return
    if len(options) > 4:
        issues.append(f"{section_id} q{q.get('number')}: {len(options)} options, truncating to 4")
        options = options[:4]

    correct_idx = q['correct_idx']
    if correct_idx is None:
        # Fallback to bold/highest font rank if unique.
        ranks = [o['rank'] for o in options]
        max_rank = max(ranks)
        if ranks.count(max_rank) == 1 and max_rank > min(ranks):
            correct_idx = ranks.index(max_rank)
        else:
            # Last-resort fallback: choose option with strongest visual cue if available,
            # else default A (but log loudly).
            issues.append(f"{section_id} q{q.get('number')}: no explicit correct marker, defaulting A -> {q_text[:80]}")
            correct_idx = 0

    out[section_id].append({
        'question_text': q_text,
        'options': [o['text'] for o in options],
        'correct_option': ['A', 'B', 'C', 'D'][correct_idx],
        'number': q.get('number'),
    })


def parse():
    with open(INPUT, 'r', encoding='utf-8') as f:
        raw_lines = [line.rstrip('\n') for line in f]

    tokens = []
    for ln in raw_lines:
        ln = ln.strip()
        if not ln or ln.startswith('===== PAGE'):
            continue
        m = FONT_RE.match(ln)
        if not m:
            continue
        font, text = m.group(1), m.group(2).strip()
        if not text:
            continue
        tokens.append((font, text))

    out = defaultdict(list)
    issues = []

    current_section = None
    current_q = None
    pending_qnum = None
    pending_opt_marker = None
    in_unmarked_options = False

    def flush_question():
        nonlocal current_q, in_unmarked_options, pending_opt_marker
        if current_q is not None and current_section is not None:
            finalize_question(current_section, current_q, out, issues)
        current_q = None
        in_unmarked_options = False
        pending_opt_marker = None

    for font, text in tokens:
        sid = looks_like_section_header(text)
        if sid is not None:
            flush_question()
            current_section = sid
            pending_qnum = None
            continue

        if current_section is None:
            continue

        if is_check_mark(text):
            if current_q is not None and current_q['options']:
                current_q['correct_idx'] = len(current_q['options']) - 1
            continue

        # Start new question from pending q number.
        if pending_qnum is not None:
            flush_question()
            current_q = make_question(pending_qnum)
            current_q['text_lines'].append(text)
            pending_qnum = None
            continue

        # Option inline like "A. text" or "1. text"
        m_opt_inline = OPT_INLINE_RE.match(text)
        if m_opt_inline and (m_opt_inline.group(2) or '').strip():
            marker = m_opt_inline.group(1)
            opt_text = m_opt_inline.group(2).strip()
            if current_q is None:
                current_q = make_question(None)
            add_option(current_q, opt_text, font_rank(font))
            in_unmarked_options = False
            pending_opt_marker = None
            continue

        # Marker-only option like "A." or "1."
        m_opt_only = OPT_MARKER_ONLY_RE.match(text)
        if m_opt_only:
            mk = m_opt_only.group(1)

            # Could be question number marker if it matches expected sequence and not in options yet.
            expected_next = len(out[current_section]) + 1
            as_int = int(mk) if mk.isdigit() else None

            if as_int is not None and current_q is not None and current_q['options'] and as_int <= 4 and len(current_q['options']) < 4:
                pending_opt_marker = mk
                continue

            if as_int is not None and (as_int == expected_next or (as_int > 4 and current_q is not None and len(current_q['options']) >= 4)):
                pending_qnum = as_int
                continue

            pending_opt_marker = mk
            continue

        # Numbered question line: "12. Question text"
        m_q = QNUM_RE.match(text)
        if m_q:
            qnum = int(m_q.group(1))
            rest = m_q.group(2).strip()
            expected_next = len(out[current_section]) + 1

            # If this looks like an option while already inside options, treat as option.
            if qnum <= 4 and current_q is not None and current_q['options'] and len(current_q['options']) < 4:
                if rest:
                    add_option(current_q, rest, font_rank(font))
                else:
                    pending_opt_marker = str(qnum)
                continue

            # Question start when number progresses as expected or clearly >4
            if rest:
                if (qnum == expected_next) or (qnum > 4 and (current_q is None or len(current_q['options']) >= 2)):
                    flush_question()
                    current_q = make_question(qnum)
                    current_q['text_lines'].append(rest)
                    continue

            if not rest and ((qnum == expected_next) or qnum > 4):
                pending_qnum = qnum
                continue

        # Fill pending marker option text
        if pending_opt_marker is not None:
            if current_q is None:
                current_q = make_question(None)
            add_option(current_q, text, font_rank(font))
            pending_opt_marker = None
            in_unmarked_options = False
            continue

        # Generic content routing.
        if current_q is None:
            # First question in a section may be unnumbered.
            current_q = make_question(1 if not out[current_section] else None)
            current_q['text_lines'].append(text)
            continue

        if current_q['options']:
            # If options started and we still have <4, assume this is an unmarked option or continuation.
            if len(current_q['options']) < 4:
                # Start unmarked options when question clearly ended.
                if in_unmarked_options:
                    add_option(current_q, text, font_rank(font))
                else:
                    # If text looks like continuation (very short connector), append to last option.
                    if len(text.split()) <= 2 and current_q['options']:
                        current_q['options'][-1]['text'] = normalize_spaces(current_q['options'][-1]['text'] + ' ' + text)
                    else:
                        add_option(current_q, text, font_rank(font))
                        in_unmarked_options = True
            else:
                # 4 options already: extra text usually starts next question stem continuation.
                current_q['text_lines'].append(text)
        else:
            # No options yet: append to question text unless this appears to be first unmarked option.
            if current_q['text_lines'] and current_q['text_lines'][-1].strip().endswith((':', '?')):
                add_option(current_q, text, font_rank(font))
                in_unmarked_options = True
            else:
                current_q['text_lines'].append(text)

    # End flush
    flush_question()

    return out, issues


def generate_sql(data):
    sections = list(data.keys())
    values = []
    for sid in sections:
        for q in data[sid]:
            qt = q['question_text'].replace("'", "''")
            oa, ob, oc, od = [opt.replace("'", "''") for opt in q['options']]
            co = q['correct_option']
            values.append(
                f"  ('medical', '{sid}', '{qt}', '{oa}', '{ob}', '{oc}', '{od}', '{co}')"
            )

    section_sql = ', '.join(f"'{s}'" for s in sections)

    sql = (
        "-- Replace medical quiz banks from specialized med questions.pdf\n\n"
        "BEGIN;\n\n"
        "DELETE FROM public.quiz_questions\n"
        "WHERE quiz_type = 'medical'\n"
        f"  AND medical_section IN ({section_sql});\n\n"
        "INSERT INTO public.quiz_questions(\n"
        "  quiz_type,\n"
        "  medical_section,\n"
        "  question_text,\n"
        "  option_a,\n"
        "  option_b,\n"
        "  option_c,\n"
        "  option_d,\n"
        "  correct_option\n"
        ") VALUES\n"
        + ",\n".join(values)
        + ";\n\nCOMMIT;\n"
    )
    return sql


def main():
    data, issues = parse()

    # Sort by original question number when available.
    for sid in list(data.keys()):
        data[sid].sort(key=lambda q: (999 if q['number'] is None else q['number']))

    with open(OUT_JSON, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    sql = generate_sql(data)
    with open(OUT_SQL, 'w', encoding='utf-8') as f:
        f.write(sql)

    print('Sections parsed:', len(data))
    total = 0
    for sid in sorted(data.keys()):
        c = len(data[sid])
        total += c
        print(f'{sid}: {c}')
    print('Total questions:', total)

    if issues:
        print('\nIssues:')
        for item in issues[:200]:
            print('-', item)
        if len(issues) > 200:
            print(f'... and {len(issues)-200} more')


if __name__ == '__main__':
    main()
