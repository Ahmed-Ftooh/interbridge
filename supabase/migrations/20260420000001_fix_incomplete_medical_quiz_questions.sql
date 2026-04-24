-- Fix incomplete medical quiz banks caused by malformed merged question rows.
-- This migration:
-- 1) Removes corrupted rows that accidentally merged two questions into one.
-- 2) Inserts the missing questions so each medical section has 25 questions.

BEGIN;

-- Remove malformed merged rows (one row containing two question prompts).
DELETE FROM public.quiz_questions
WHERE quiz_type = 'medical'
  AND medical_section = 'cardiology'
  AND POSITION('24What does' IN question_text) > 0;

DELETE FROM public.quiz_questions
WHERE quiz_type = 'medical'
  AND medical_section = 'respiratory'
  AND POSITION('24, A patient who' IN question_text) > 0;

DELETE FROM public.quiz_questions
WHERE quiz_type = 'medical'
  AND medical_section = 'renal'
  AND POSITION('wakes up multiple times at night to urinate' IN question_text) > 0;

DELETE FROM public.quiz_questions
WHERE quiz_type = 'medical'
  AND medical_section = 'ob_gyn'
  AND POSITION('24, A patient presents with sudden abdominal pain and vaginal bleeding' IN question_text) > 0;

DELETE FROM public.quiz_questions
WHERE quiz_type = 'medical'
  AND medical_section = 'dermatology'
  AND POSITION('15Application of extreme cold to freeze and destroy abnormal tissue' IN question_text) > 0;

-- Cardiology split fix (restores Q23 and Q24 as separate rows).
INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'cardiology',
  'Which chamber of the heart pumps oxygenated blood to the body?',
  'Right atrium',
  'Right ventricle',
  'Left ventricle',
  'Left atrium',
  'C'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'cardiology'
    AND question_text = 'Which chamber of the heart pumps oxygenated blood to the body?'
);

INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'cardiology',
  'What does bradycardia mean?',
  'Fast heart rate',
  'Irregular heart rhythm',
  'Slow heart rate',
  'Weak heartbeat',
  'C'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'cardiology'
    AND question_text = 'What does bradycardia mean?'
);

-- Respiratory split fix (restores Q23 and Q24 as separate rows).
INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'respiratory',
  'Tachypnea refers to:',
  'Slow breathing',
  'Painful breathing',
  'Rapid breathing',
  'Irregular breathing',
  'C'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'respiratory'
    AND question_text = 'Tachypnea refers to:'
);

INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'respiratory',
  'A patient who inhales food or liquid into the airway is experiencing:',
  'Aspiration',
  'Inhalation therapy',
  'Ventilation',
  'Perfusion',
  'A'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'respiratory'
    AND question_text = 'A patient who inhales food or liquid into the airway is experiencing:'
);

-- Renal split fix (restores Q2 and Q3 as separate rows).
INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'renal',
  'Pyelonephritis is:',
  'Inflammation of bladder',
  'Infection of kidney',
  'Kidney stones',
  'Urethral obstruction',
  'B'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'renal'
    AND question_text = 'Pyelonephritis is:'
);

INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'renal',
  'A patient who wakes up multiple times at night to urinate has:',
  'Polyuria',
  'Nocturia',
  'Dysuria',
  'Retention',
  'B'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'renal'
    AND question_text = 'A patient who wakes up multiple times at night to urinate has:'
);

-- OB/GYN split fix (restores Q23 and Q24 as separate rows).
INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'ob_gyn',
  'Which hormone stimulates milk production after birth?',
  'Oxytocin',
  'Prolactin',
  'Estrogen',
  'Progesterone',
  'B'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'ob_gyn'
    AND question_text = 'Which hormone stimulates milk production after birth?'
);

INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'ob_gyn',
  'A patient presents with sudden abdominal pain and vaginal bleeding in late pregnancy. Most likely diagnosis:',
  'Placental abruption',
  'Ectopic pregnancy',
  'Fibroids',
  'PID',
  'A'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'ob_gyn'
    AND question_text = 'A patient presents with sudden abdominal pain and vaginal bleeding in late pregnancy. Most likely diagnosis:'
);

-- Dermatology split fix (restores Q14 and Q15 as separate rows).
INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'dermatology',
  'What is a mole (nevus)?',
  'Malignant tumor',
  'Benign growth of pigmented skin cells',
  'Infection',
  'Rash',
  'B'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'dermatology'
    AND question_text = 'What is a mole (nevus)?'
);

INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'dermatology',
  'Application of extreme cold to freeze and destroy abnormal tissue refers to:',
  'Surgical removal',
  'Burning of part of a body to remove or close off part of it',
  'Cryotherapy',
  'Grafting',
  'C'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'dermatology'
    AND question_text = 'Application of extreme cold to freeze and destroy abnormal tissue refers to:'
);

-- Emergency top-up: add 5 missing questions to reach 25.
INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'emergency',
  'Which symptom is critical for identifying a stroke?',
  'Facial droop, arm weakness, speech difficulty',
  'Fever',
  'Rash',
  'Nausea',
  'A'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'emergency'
    AND question_text = 'Which symptom is critical for identifying a stroke?'
);

INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'emergency',
  'A patient fell from height and is unconscious. First step:',
  'Assess airway, breathing, circulation (ABC)',
  'Start physical therapy',
  'Take vitals only',
  'Give painkillers',
  'A'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'emergency'
    AND question_text = 'A patient fell from height and is unconscious. First step:'
);

INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'emergency',
  'Which imaging is first choice for suspected traumatic brain injury?',
  'CT scan',
  'MRI',
  'Ultrasound',
  'X-ray',
  'A'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'emergency'
    AND question_text = 'Which imaging is first choice for suspected traumatic brain injury?'
);

INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'emergency',
  'Hypotension refers to:',
  'Low blood pressure',
  'High blood pressure',
  'Chest pain',
  'Shortness of breath',
  'A'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'emergency'
    AND question_text = 'Hypotension refers to:'
);

INSERT INTO public.quiz_questions (
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
)
SELECT
  'medical',
  'emergency',
  'A patient presents with severe abdominal pain, nausea, and vomiting. Possible ER diagnosis:',
  'Appendicitis',
  'Migraine',
  'Skin infection',
  'Anxiety',
  'A'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_questions
  WHERE quiz_type = 'medical'
    AND medical_section = 'emergency'
    AND question_text = 'A patient presents with severe abdominal pain, nausea, and vomiting. Possible ER diagnosis:'
);

COMMIT;