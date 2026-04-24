import json
import re

def process():
    with open('parse_quizzes.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    text = content.split('text = """')[1].split('"""')[0].strip()

    section_names = [
        ('cardiology', 'CARDIO SYSTEM – 25 Questions'),
        ('respiratory', 'RESPIRATORY SYSTEM – 25 Questions'),
        ('gastrointestinal', 'GASTROINTESTINAL SYSTEM – 25 Questions'),
        ('endocrinology', 'ENDOCRINE SYSTEM'),
        ('renal', 'RENAL SYSTEM'),
        ('ob_gyn', 'OB/GYN SYSTEM'),
        ('oncology', 'Oncology'),
        ('dermatology', 'Dermatology'),
        ('emergency', 'EMERGENCY / ER'),
        ('ear_and_eye', 'Ear and eye')
    ]

    # Split text into sections using the exact headers
    splits = {}
    remaining = text
    for i in range(len(section_names)):
        cat_id, header = section_names[i]
        
        if i < len(section_names) - 1:
            next_header = section_names[i+1][1]
            parts = remaining.split(next_header, 1)
            splits[cat_id] = parts[0].replace(header, "").strip()
            remaining = parts[1]
        else:
            splits[cat_id] = remaining.replace(header, "").strip()

    sql_inserts = []
    
    for cat_id, questions_str in splits.items():
        # Split by numbering: e.g., "1. ", "2. 3.", "12.", "4.."
        # We'll use a regex that matches start of line, optional spaces, digits, then dots, then space.
        raw_qs = re.split(r'\n\s*\d+\s*(?:\.\s*\d+\.\s*|\.+)\s*', '\n' + questions_str)
        # First element is usually empty
        raw_qs = [q.strip() for q in raw_qs if q.strip()]

        for idx, q_blob in enumerate(raw_qs):
            # Parse the question blob
            lines = [l.strip() for l in q_blob.split('\n') if l.strip()]
            if not lines: continue
            
            question_text = ""
            options = []
            
            # Find options (they come at the end, usually 4 of them)
            # Find the index of the first option which could be A/B/C/D or just text.
            # Usually the last 4 non-empty lines (excluding Answer: X).
            
            # Remove "Answer: X" if present
            correct_option_letter = None
            if lines[-1].lower().startswith("answer:"):
                ans_line = lines.pop()
                ans_val = ans_line.split(":")[-1].strip().upper()
                if ans_val in ['A', 'B', 'C', 'D']:
                    correct_option_letter = ans_val
                elif ans_val in ['1', '2', '3', '4']:
                    mapping = {'1': 'A', '2': 'B', '3': 'C', '4': 'D'}
                    correct_option_letter = mapping[ans_val]
            
            # Now we look for options (last 4 lines or they might be numbered)
            raw_options = []
            q_lines = []
            
            in_options = False
            # Count backward or we just take the last 4 lines that don't look like questions
            # A better way: find lines with ✔
            # Usually options are the lines immediately following the question.
            # Let's separate question text from options. Options often start with "A.", "B.", or just text.
            # Number of options = 4. 
            
            if len(lines) >= 5:
                q_text_lines = lines[:-4]
                option_lines = lines[-4:]
            else:
                q_text_lines = [lines[0]]
                option_lines = lines[1:]
                
            question_text = " ".join(q_text_lines)
            
            # Options cleansing
            clean_opts = []
            found_correct_index = -1
            
            for o_idx, opt in enumerate(option_lines):
                is_correct = '✔' in opt
                if is_correct:
                    found_correct_index = o_idx
                
                # Strip leading A., B., C., D. or 1., 2., 3., 4.
                opt_text = opt.replace('✔', '').strip()
                opt_text = re.sub(r'^(?:[A-D]|\d+)\s*\.\s*', '', opt_text).strip()
                clean_opts.append(opt_text)
            
            if found_correct_index != -1:
                letters = ['A', 'B', 'C', 'D']
                correct_option_letter = letters[found_correct_index] if found_correct_index < 4 else 'A'
                
            if not correct_option_letter:
                # Default fallback
                correct_option_letter = 'A'
            
            # Pad options if less than 4
            while len(clean_opts) < 4:
                clean_opts.append("None of the above")
            
            # Format SQL
            qt = question_text.replace("'", "''")
            oA = clean_opts[0].replace("'", "''")
            oB = clean_opts[1].replace("'", "''")
            oC = clean_opts[2].replace("'", "''")
            oD = clean_opts[3].replace("'", "''")
            
            sql_inserts.append(f"('medical', '{cat_id}', '{qt}', '{oA}', '{oB}', '{oC}', '{oD}', '{correct_option_letter}')")

    final_sql = f"""-- Replace remaining medical quiz banks with updated questions

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'ear_and_eye' 
    AND enumtypid = 'medical_section_type'::regtype
  ) THEN
    ALTER TYPE medical_section_type ADD VALUE 'ear_and_eye';
  END IF;
END $$;

DELETE FROM public.quiz_questions
WHERE quiz_type = 'medical'
  AND medical_section IN (
    'cardiology', 'respiratory', 'gastrointestinal', 'endocrinology', 
    'renal', 'ob_gyn', 'oncology', 'dermatology', 'emergency', 'ear_and_eye'
  );

INSERT INTO public.quiz_questions(
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
) VALUES
{",\\n".join(sql_inserts)};
"""

    with open('supabase/migrations/20260406000003_replace_remaining_medical_questions.sql', 'w', encoding='utf-8') as f:
        f.write(final_sql)

if __name__ == '__main__':
    process()
