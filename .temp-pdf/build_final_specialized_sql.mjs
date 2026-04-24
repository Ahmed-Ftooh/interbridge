import fs from 'fs';

const INPUT_JSON = '.temp-pdf/specialized_grouped_parsed.json';
const OUT_JSON = '.temp-pdf/specialized_final_parsed.json';
const OUT_SQL = '.temp-pdf/specialized_final_replace.sql';

const data = JSON.parse(fs.readFileSync(INPUT_JSON, 'utf-8'));

function byNum(section, n) {
  return section.find((q) => q.number === n);
}

function normalizeText(s) {
  return (s || '').replace(/\s+/g, ' ').trim();
}

function setQuestion(section, n, payload) {
  const idx = section.findIndex((q) => q.number === n);
  if (idx === -1) {
    section.push({ number: n, ...payload });
  } else {
    section[idx] = { ...section[idx], ...payload, number: n };
  }
}

// --- Patch malformed cardiology questions (OCR split issue) ---
setQuestion(data.cardiology, 11, {
  questionText:
    'A patient reports: "I feel dizzy and almost faint when I stand up quickly." This may indicate:',
  options: ['Hypertensive crisis', 'Orthostatic hypotension', 'Tachycardia', 'Hyperglycemia'],
  correctOption: 'B',
});

setQuestion(data.cardiology, 19, {
  questionText:
    'The provider says: "The patient has fluid buildup in the lungs due to heart failure." This condition is called:',
  options: ['Pleural effusion', 'Pulmonary edema', 'Pneumonia', 'Bronchitis'],
  correctOption: 'B',
});

setQuestion(data.cardiology, 22, {
  questionText:
    'A patient says: "I feel like my heart is skipping beats and then racing all of a sudden." This most likely refers to:',
  options: ['Stable angina', 'Heart murmur', 'Cardiac arrest', 'Palpitations'],
  correctOption: 'D',
});

// --- Add missing respiratory Q25 from PDF ---
setQuestion(data.respiratory, 25, {
  questionText: 'Ventilator support is used when:',
  options: [
    'The patient has high blood pressure',
    'The patient cannot breathe adequately on their own',
    'The patient has a mild cough',
    'The patient has chest pain only',
  ],
  correctOption: 'B',
});

// --- Replace GI section fully from uploaded PDF to fix early OCR numbering corruption ---
data.gastrointestinal = [
  {
    number: 1,
    questionText: 'A patient with "heartburn" most likely has:',
    options: ['Gastritis', 'GERD (acid reflux)', 'Appendicitis', 'Hepatitis'],
    correctOption: 'B',
  },
  {
    number: 2,
    questionText: 'Which procedure uses a camera to examine the upper GI tract?',
    options: ['Colonoscopy', 'CT scan', 'Ultrasound', 'Endoscopy (EGD)'],
    correctOption: 'D',
  },
  {
    number: 3,
    questionText: 'Which organ is affected in cholecystitis?',
    options: ['Gallbladder', 'Pancreas', 'Liver', 'Appendix'],
    correctOption: 'A',
  },
  {
    number: 4,
    questionText: 'Ascites refers to:',
    options: [
      'Gas in the stomach',
      'Fluid buildup in the abdomen',
      'Liver infection',
      'Intestinal blockage',
    ],
    correctOption: 'B',
  },
  {
    number: 5,
    questionText: 'Hepatitis is:',
    options: [
      'Inflammation of the liver',
      'Infection of the stomach',
      'Colon inflammation',
      'Pancreatic failure',
    ],
    correctOption: 'A',
  },
  {
    number: 6,
    questionText: 'Jaundice refers to:',
    options: ['Red skin', 'Swelling of the abdomen', 'Yellowing of the skin and eyes', 'Dark urine only'],
    correctOption: 'C',
  },
  {
    number: 7,
    questionText: 'Dysphagia refers to:',
    options: ['Painful swallowing', 'Difficulty swallowing', 'Vomiting blood', 'Loss of appetite'],
    correctOption: 'B',
  },
  {
    number: 8,
    questionText: 'Proton pump inhibitors (PPIs) are used to:',
    options: ['Treat diarrhea', 'Reduce stomach acid', 'Increase bile production', 'Treat constipation'],
    correctOption: 'B',
  },
  {
    number: 9,
    questionText: 'Laxatives are medications used to:',
    options: ['Stop vomiting', 'Reduce stomach acid', 'Treat liver disease', 'Soften stool and relieve constipation'],
    correctOption: 'D',
  },
  {
    number: 10,
    questionText: 'Nasogastric (NG) tube is used to:',
    options: [
      'Remove fluid or deliver nutrition to the stomach',
      'Measure lung capacity',
      'Deliver oxygen',
      'Test heart rhythm',
    ],
    correctOption: 'A',
  },
  {
    number: 11,
    questionText: 'Colonic polyp removal is a procedure done during:',
    options: ['Endoscopy', 'Colonoscopy', 'ERCP', 'Gastroscopy'],
    correctOption: 'B',
  },
  {
    number: 12,
    questionText: 'Antacids are used to:',
    options: [
      'Relieve stomach acid symptoms',
      'Increase bile production',
      'Stop diarrhea',
      'Treat pancreatic inflammation',
    ],
    correctOption: 'A',
  },
  {
    number: 13,
    questionText: 'H. pylori test is done to:',
    options: [
      'Check colon polyps',
      'Measure bile production',
      'Test for liver disease',
      'Detect bacteria causing stomach ulcers',
    ],
    correctOption: 'D',
  },
  {
    number: 14,
    questionText: 'Endoscopic biopsy means:',
    options: [
      'Taking tissue samples through an endoscope',
      'Removing polyps surgically',
      'Measuring stomach acid',
      'Administering IV medication',
    ],
    correctOption: 'A',
  },
  {
    number: 15,
    questionText: 'Cirrhosis refers to:',
    options: ['Inflammation of the pancreas', 'Stomach ulcer', 'Scarring of the liver', 'Intestinal blockage'],
    correctOption: 'C',
  },
  {
    number: 16,
    questionText: 'Bowel prep before a colonoscopy means:',
    options: ['Patient fasts completely', 'Cleaning out the intestines', 'Administering IV fluids', 'Taking antibiotics'],
    correctOption: 'B',
  },
  {
    number: 17,
    questionText: 'Antiemetics are medications that:',
    options: ['Stop nausea and vomiting', 'Reduce stomach acid', 'Relieve constipation', 'Treat liver disease'],
    correctOption: 'A',
  },
  {
    number: 18,
    questionText: 'Which organ produces bile?',
    options: ['Pancreas', 'Liver', 'Stomach', 'Small intestine'],
    correctOption: 'B',
  },
  {
    number: 19,
    questionText: 'Crohn’s disease is a type of:',
    options: ['Liver disease', 'Inflammatory bowel disease', 'Stomach ulcer', 'Pancreatic disorder'],
    correctOption: 'B',
  },
  {
    number: 20,
    questionText: 'Which of the following symptoms is considered an emergency in GI conditions?',
    options: ['Severe abdominal pain with vomiting blood', 'Mild bloating', 'Occasional diarrhea', 'Constipation'],
    correctOption: 'A',
  },
  {
    number: 21,
    questionText: 'Which imaging test is most commonly used to detect gallstones?',
    options: ['Ultrasound', 'CT scan', 'MRI', 'ECG'],
    correctOption: 'A',
  },
  {
    number: 22,
    questionText: 'Lithotripsy is a procedure to:',
    options: ['Remove liver cysts', 'Break stones into smaller pieces', 'Place a stent', 'Treat ulcers'],
    correctOption: 'B',
  },
  {
    number: 23,
    questionText: 'Steatorrhea refers to:',
    options: ['Fatty stools', 'Bloody stools', 'Diarrhea', 'Vomiting'],
    correctOption: 'A',
  },
  {
    number: 24,
    questionText: 'Hematemesis refers to:',
    options: ['Blood in stool', 'Blood in vomit', 'Yellow skin', 'Abdominal swelling'],
    correctOption: 'B',
  },
  {
    number: 25,
    questionText: 'Probiotics are used to:',
    options: ['Treat liver disease', 'Reduce stomach acid', 'Treat constipation only', 'Restore healthy gut bacteria'],
    correctOption: 'D',
  },
];

// --- Replace dermatology fully from uploaded PDF (fixes missing Q16-25 and Answer:B artifacts) ---
data.dermatology = [
  { number: 1, questionText: 'Psoriasis is characterized by:', options: ['Red, scaly patches on the skin', 'Fluid-filled blisters', 'Pustules with pus', 'Skin necrosis'], correctOption: 'A' },
  { number: 2, questionText: 'Urticaria is also known as:', options: ['Psoriasis', 'Hives', 'Eczema', 'Rosacea'], correctOption: 'B' },
  { number: 3, questionText: 'Vitiligo is a condition of:', options: ['Hair loss', 'Red rash', 'Skin depigmentation', 'Blistering'], correctOption: 'C' },
  { number: 4, questionText: 'Hair loss that can affect just your scalp or your entire body, and it can be temporary or permanent', options: ['Vitiligo', 'Lupus', 'Alopecia', 'Acne'], correctOption: 'C' },
  { number: 5, questionText: 'A thickened, hardened area of skin that develops due to repeated friction, pressure, or irritation.', options: ['Callus', 'Moles', 'Vitiligo', 'Warts'], correctOption: 'A' },
  { number: 6, questionText: 'A painful, pus-filled bump that forms under your skin when bacteria infect and inflame one or more of your hair follicles', options: ['Rash', 'Eczema', 'Boil', 'Hives'], correctOption: 'C' },
  { number: 7, questionText: 'What is cauterization?', options: ['Surgical removal', 'Burning of part of a body to remove or close off a part of it', 'Application of extreme cold to freeze and destroy abnormal tissue', 'Grafting'], correctOption: 'B' },
  { number: 8, questionText: 'A localized collection of pus that forms due to infection.', options: ['Abscess', 'Callus', 'Inflammation of the skin', 'Scar'], correctOption: 'A' },
  { number: 9, questionText: 'A medical doctor who specializes in diagnosing and treating conditions of the skin, hair, and nails.', options: ['Neurologist', 'Cardiologist', 'Dermatologist', 'Podiatrist'], correctOption: 'C' },
  { number: 10, questionText: 'Shingles is caused by:', options: ['Herpes simplex', 'Varicella zoster', 'HPV', 'Gonorrhea'], correctOption: 'B' },
  { number: 11, questionText: 'What is eczema?', options: ['Bacterial skin infection', 'Chronic inflammation of the skin', 'Skin cancer', 'Viral disease'], correctOption: 'B' },
  { number: 12, questionText: 'Fluid-filled pocket on the skin refers to:', options: ['Solid lump', 'Dry patch', 'Blister', 'Scar tissue'], correctOption: 'C' },
  { number: 13, questionText: 'A genetic condition with little or no pigment in skin, hair, and eyes refers to:', options: ['Skin infection', 'Albinism', 'Cancer', 'Allergy'], correctOption: 'B' },
  { number: 14, questionText: 'What is a mole (nevus)?', options: ['Malignant tumor', 'Benign growth of pigmented skin cells', 'Infection', 'Rash'], correctOption: 'B' },
  { number: 15, questionText: 'Application of extreme cold to freeze and destroy abnormal tissue refers to:', options: ['Surgical removal', 'Burning of part of a body to remove or close off a part of it', 'Cryotherapy', 'Grafting'], correctOption: 'C' },
  { number: 16, questionText: 'Contact dermatitis is triggered by:', options: ['Allergens or irritants', 'Bacteria', 'Hormones', 'Genetics'], correctOption: 'A' },
  { number: 17, questionText: 'Biopsy in dermatology is used to:', options: ['Treat skin infection', 'Remove warts', 'Diagnose skin lesions', 'Reduce inflammation'], correctOption: 'C' },
  { number: 18, questionText: 'Rosacea typically affects:', options: ['Scalp', 'Face', 'Hands', 'Feet'], correctOption: 'B' },
  { number: 19, questionText: 'A contagious skin infection characterized by red, ring-shaped rash refers to:', options: ['Psoriasis', 'Ringworm', 'Albinism', 'Urticaria'], correctOption: 'B' },
  { number: 20, questionText: 'Hyperpigmentation refers to:', options: ['Loss of skin color', 'Darkening of the skin', 'Redness', 'Blistering'], correctOption: 'B' },
  { number: 21, questionText: 'Hypopigmentation refers to:', options: ['Light patches on the skin', 'Dark spots', 'Rash with pus', 'Red scaly patches'], correctOption: 'A' },
  { number: 22, questionText: 'A patient has itchy, red, raised wheals after eating seafood. This is most likely:', options: ['Eczema', 'Urticaria', 'Psoriasis', 'Rosacea'], correctOption: 'B' },
  { number: 23, questionText: 'Topical corticosteroids are mainly used to:', options: ['Kill bacteria', 'Reduce inflammation', 'Treat fungal infections', 'Stimulate hair growth'], correctOption: 'B' },
  { number: 24, questionText: 'A patient presents with blistering on lips and mouth after stress. Likely diagnosis:', options: ['Cold sores', 'Canker sores', 'Impetigo', 'Eczema'], correctOption: 'A' },
  { number: 25, questionText: 'Red, inflamed skin caused by overexposure to the sun refers to:', options: ['Acne', 'Sunburn', 'Eczema', 'Infection'], correctOption: 'B' },
];

// --- Minor cleanup on OCR punctuation artifacts ---
const obgyn15 = byNum(data.ob_gyn, 15);
if (obgyn15) {
  obgyn15.options[0] = 'Ultrasound';
}
const obgyn24 = byNum(data.ob_gyn, 24);
if (obgyn24) {
  obgyn24.questionText = obgyn24.questionText.replace(/^\s*[,\.]+\s*/, '');
}
const resp24 = byNum(data.respiratory, 24);
if (resp24) {
  resp24.questionText = resp24.questionText.replace(/^\s*[,\.]+\s*/, '');
}
const onco15 = byNum(data.oncology, 15);
if (onco15) {
  onco15.questionText = onco15.questionText.replace(/^\s*\d+\s*[,\.]\s*/, '');
}

// Ensure stable order and normalize text.
for (const sectionName of Object.keys(data)) {
  data[sectionName] = data[sectionName]
    .map((q) => ({
      ...q,
      questionText: normalizeText(q.questionText),
      options: q.options.map((o) => normalizeText(o)),
    }))
    .sort((a, b) => a.number - b.number);
}

function buildSql(quizData) {
  const sectionIds = Object.keys(quizData).filter((sid) => quizData[sid].length > 0);
  const rows = [];

  for (const sid of sectionIds) {
    for (const q of quizData[sid]) {
      const qt = q.questionText.replace(/'/g, "''");
      const [oa, ob, oc, od] = q.options.map((o) => o.replace(/'/g, "''"));
      rows.push(
        `  ('medical', '${sid}', '${qt}', '${oa}', '${ob}', '${oc}', '${od}', '${q.correctOption}')`,
      );
    }
  }

  return `-- Replace medical quizzes from specialized med questions.pdf\n\nBEGIN;\n\nDELETE FROM public.quiz_questions\nWHERE quiz_type = 'medical'\n  AND medical_section IN (${sectionIds.map((s) => `'${s}'`).join(', ')});\n\nINSERT INTO public.quiz_questions(\n  quiz_type,\n  medical_section,\n  question_text,\n  option_a,\n  option_b,\n  option_c,\n  option_d,\n  correct_option\n) VALUES\n${rows.join(',\n')};\n\nCOMMIT;\n`;
}

fs.writeFileSync(OUT_JSON, JSON.stringify(data, null, 2), 'utf-8');
const sql = buildSql(data);
fs.writeFileSync(OUT_SQL, sql, 'utf-8');

let total = 0;
console.log('Final section counts:');
for (const sid of Object.keys(data)) {
  const c = data[sid].length;
  total += c;
  console.log(`${sid}: ${c}`);
}
console.log('Total questions:', total);
