-- Migration: Add medical quiz questions for all specialties
-- Sections: Neurology, Cardiology, Respiratory, Gastrointestinal, Endocrinology, Renal, OB/GYN, Oncology, Emergency, Dermatology

-- Add dermatology to medical_section_type enum if not exists
DO $$ BEGIN
  ALTER TYPE public.medical_section_type ADD VALUE IF NOT EXISTS 'dermatology';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Clear existing medical quiz questions to avoid duplicates
DELETE FROM public.quiz_questions WHERE quiz_type = 'medical';

-- =====================================================
-- NEUROLOGY - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'neurology', 'Which of the following refers to inflammation of the meninges?', 'Neuritis', 'Encephalitis', 'Meningitis', 'Myelopathy', 'C'),
('medical', 'neurology', 'What does "syncope" mean?', 'Muscle twitching', 'Fainting or loss of consciousness', 'Memory loss', 'Nerve inflammation', 'B'),
('medical', 'neurology', 'The medical term for a stroke is:', 'TIA', 'CVA', 'CAD', 'DKA', 'B'),
('medical', 'neurology', 'Which condition involves sudden, uncontrolled electrical activity in the brain?', 'Epilepsy', 'ALS', 'Parkinson''s disease', 'Vertigo', 'A'),
('medical', 'neurology', '"Hemiparesis" means:', 'Complete body paralysis', 'Weakness on one side of the body', 'Paralysis of both legs', 'Loss of coordination', 'B'),
('medical', 'neurology', 'Which test measures electrical activity in the brain?', 'EMG', 'EEG', 'ECG', 'MRI', 'B'),
('medical', 'neurology', 'What is the term for surgical repair of a nerve?', 'Neuroplasty', 'Neurectomy', 'Neurolysis', 'Neuropathy', 'A'),
('medical', 'neurology', 'A "ruptured aneurysm" most commonly leads to:', 'Ischemic stroke', 'Hemorrhagic stroke', 'Dementia', 'Multiple sclerosis', 'B'),
('medical', 'neurology', 'The part of the brain responsible for balance and coordination is:', 'Cerebrum', 'Brainstem', 'Cerebellum', 'Thalamus', 'C'),
('medical', 'neurology', 'The term "aphasia" describes:', 'Difficulty swallowing', 'Loss of speech or language ability', 'Shaking movements', 'Muscle weakness', 'B'),
('medical', 'neurology', 'Which condition is characterized by progressive muscle weakness due to nerve degeneration?', 'Parkinson''s disease', 'ALS', 'Epilepsy', 'Stroke', 'B'),
('medical', 'neurology', '"Vertigo" refers to:', 'Severe headache', 'The sensation of spinning', 'Losing memory', 'Tingling in hands', 'B'),
('medical', 'neurology', 'Which of the following is a symptom of increased intracranial pressure (ICP)?', 'Low heart rate', 'Severe headache', 'Excessive thirst', 'Yellow skin', 'B'),
('medical', 'neurology', 'The protective covering of nerves is called:', 'Myelin sheath', 'Dura mater', 'Pia mater', 'Cortex', 'A'),
('medical', 'neurology', 'A temporary mini-stroke that typically lasts minutes is:', 'CVA', 'TBI', 'TIA', 'MS', 'C'),
('medical', 'neurology', 'Which imaging test is best for detecting brain bleeding?', 'X-ray', 'CT scan', 'Ultrasound', 'Stress test', 'B'),
('medical', 'neurology', '"Dysphagia" means:', 'Difficulty speaking', 'Difficulty swallowing', 'Difficulty walking', 'Difficulty breathing', 'B'),
('medical', 'neurology', 'Which disease involves tremors, stiffness, and slow movement?', 'ALS', 'Parkinson''s disease', 'Epilepsy', 'Meningitis', 'B'),
('medical', 'neurology', 'The meaning of "paresthesia" is:', 'Numbness or tingling', 'Muscle spasm', 'Paralysis', 'Dizziness', 'A'),
('medical', 'neurology', 'Which nerve disorder is caused by uncontrolled diabetes?', 'Peripheral neuropathy', 'Myopathy', 'Neuralgia', 'Hydrocephalus', 'A'),
('medical', 'neurology', 'The term for surgical operation of a portion of the skull:', 'Craniotomy', 'Lobotomy', 'Neurotomy', 'Hematotomy', 'A'),
('medical', 'neurology', 'What is "hydrocephalus"?', 'Infection of the brain', 'Fluid buildup in the brain', 'Brain tumor', 'Nerve damage in the legs', 'B'),
('medical', 'neurology', 'Which of the following symptoms is common in multiple sclerosis (MS)?', 'Jaundice', 'Muscle weakness & vision problems', 'Chest pain', 'Hair loss', 'B'),
('medical', 'neurology', 'Sudden severe "worst headache of life" may indicate:', 'Migraine', 'Meningitis', 'Subarachnoid hemorrhage', 'Sinus infection', 'C'),
('medical', 'neurology', 'Which specialist treats brain and nerve disorders?', 'Cardiologist', 'Neurologist', 'Pulmonologist', 'Endocrinologist', 'B');

-- =====================================================
-- CARDIOLOGY - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'cardiology', 'Which of the following refers to chest pain caused by reduced blood flow to the heart?', 'Myocarditis', 'Angina pectoris', 'Arrhythmia', 'Endocarditis', 'B'),
('medical', 'cardiology', '"Tachycardia" means:', 'Slow heart rate', 'Irregular heartbeat', 'Rapid heart rate', 'Stopped heart', 'C'),
('medical', 'cardiology', 'The medical term for a heart attack is:', 'CHF', 'MI', 'CAD', 'CVA', 'B'),
('medical', 'cardiology', 'Which test records the electrical activity of the heart?', 'MRI', 'Echo', 'ECG/EKG', 'CT scan', 'C'),
('medical', 'cardiology', '"Hypertension" refers to:', 'Low blood pressure', 'High blood pressure', 'High cholesterol', 'Irregular rhythm', 'B'),
('medical', 'cardiology', 'Which condition is characterized by the heart''s inability to pump blood efficiently?', 'CHF', 'CAD', 'MI', 'A-fib', 'A'),
('medical', 'cardiology', 'The term "bradycardia" means:', 'Rapid heartbeat', 'Very slow heartbeat', 'Weak pulse', 'Irregular rhythm', 'B'),
('medical', 'cardiology', 'Which artery supplies blood to the heart muscle?', 'Femoral artery', 'Coronary artery', 'Carotid artery', 'Aortic arch', 'B'),
('medical', 'cardiology', 'A patient with fluid in the lungs due to heart failure is experiencing:', 'Pulmonary edema', 'Pleurisy', 'Pneumonia', 'Pneumothorax', 'A'),
('medical', 'cardiology', 'Which of the following is a common symptom of myocardial infarction?', 'Sharp pain in one finger', 'Jaw pain & left arm pain', 'Leg swelling only', 'Dizziness without pain', 'B'),
('medical', 'cardiology', '"Atherosclerosis" refers to:', 'Thickening of lung tissue', 'Hardening of the arteries', 'Kidney failure', 'Liver enlargement', 'B'),
('medical', 'cardiology', 'Which procedure opens blocked coronary arteries using a balloon?', 'CABG', 'Angioplasty', 'Pacemaker', 'Cardioversion', 'B'),
('medical', 'cardiology', 'CABG stands for:', 'Coronary Artery Bypass Graft', 'Cardiac Artery Broken Gland', 'Coronary Balloon Guide', 'Cardio Arrhythmia Base Gate', 'A'),
('medical', 'cardiology', 'A patient with "irregular heartbeat" most likely has:', 'Atherosclerosis', 'Arrhythmia', 'Pericardial effusion', 'MI', 'B'),
('medical', 'cardiology', '"Edema" means:', 'Chest tightness', 'Fluid retention/swelling', 'Fainting', 'Excess sweating', 'B'),
('medical', 'cardiology', 'Which diagnostic test uses ultrasound to visualize heart movement?', 'ECG', 'Echocardiogram', 'X-ray', 'Stress test', 'B'),
('medical', 'cardiology', 'A blood clot that travels to the lung is called:', 'DVT', 'PE', 'MI', 'Atherosclerosis', 'B'),
('medical', 'cardiology', 'Which of the following medications is used to thin the blood?', 'Insulin', 'Anticoagulants', 'Beta-blockers', 'Steroids', 'B'),
('medical', 'cardiology', 'The term "cyanosis" refers to:', 'Yellow skin', 'Blue discoloration due to poor oxygen', 'Red rash', 'Severe swelling', 'B'),
('medical', 'cardiology', 'Which valve separates the left atrium from the left ventricle?', 'Aortic valve', 'Pulmonic valve', 'Mitral valve', 'Tricuspid valve', 'C'),
('medical', 'cardiology', '"Pericarditis" is inflammation of:', 'Heart muscle', 'Lining around the heart', 'Heart valves', 'Arteries', 'B'),
('medical', 'cardiology', 'A stress test is used to diagnose:', 'Bone density', 'Heart function during exercise', 'Kidney failure', 'Diabetes', 'B'),
('medical', 'cardiology', 'The most common symptom of congestive heart failure is:', 'Hair loss', 'Shortness of breath', 'Abdominal cramps', 'Vision loss', 'B'),
('medical', 'cardiology', 'Which term describes a blockage of blood flow to the heart muscle?', 'Ischemia', 'Dysrhythmia', 'Cyanosis', 'Pericardial tamponade', 'A'),
('medical', 'cardiology', '"Cardiomegaly" means:', 'Small heart', 'Enlarged heart', 'Weak pulse', 'Narrowed arteries', 'B');

-- =====================================================
-- RESPIRATORY - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'respiratory', 'Which of the following refers to inflammation of the lungs?', 'Bronchitis', 'Pneumonia', 'Asthma', 'Pleural effusion', 'B'),
('medical', 'respiratory', '"Dyspnea" means:', 'Rapid heartbeat', 'Difficulty breathing', 'Chest pain', 'Coughing', 'B'),
('medical', 'respiratory', 'Which test measures oxygen saturation in the blood?', 'ECG', 'Pulse oximetry', 'Spirometry', 'Chest X-ray', 'B'),
('medical', 'respiratory', 'A patient with a "wheeze" is experiencing:', 'Crackling sound in lungs', 'High-pitched breathing sound', 'Shortness of breath', 'Chest tightness', 'B'),
('medical', 'respiratory', 'Chronic inflammation of the bronchi with cough and mucus production is called:', 'Asthma', 'Chronic bronchitis', 'Pneumothorax', 'Pulmonary embolism', 'B'),
('medical', 'respiratory', 'Which of the following describes sudden collapse of a lung?', 'Pleural effusion', 'Pneumothorax', 'Atelectasis', 'Emphysema', 'B'),
('medical', 'respiratory', 'Which condition is characterized by reversible airway obstruction, wheezing, and shortness of breath?', 'COPD', 'Asthma', 'Pneumonia', 'Tuberculosis', 'B'),
('medical', 'respiratory', 'A patient reports coughing up blood. The medical term is:', 'Hematemesis', 'Hemoptysis', 'Epistaxis', 'Hematuria', 'B'),
('medical', 'respiratory', 'Which imaging test is best for detecting fluid in the lungs?', 'ECG', 'Chest X-ray', 'MRI', 'Ultrasound', 'B'),
('medical', 'respiratory', 'The term "cyanosis" indicates:', 'Low oxygen levels', 'High blood sugar', 'Fluid overload', 'High blood pressure', 'A'),
('medical', 'respiratory', 'Which of the following is a common symptom of COPD?', 'Night sweats', 'Chronic cough & shortness of breath', 'Chest pain radiating to arm', 'Numbness in legs', 'B'),
('medical', 'respiratory', 'Which test measures lung function and volume?', 'Spirometry', 'ECG', 'Echocardiogram', 'Blood culture', 'A'),
('medical', 'respiratory', '"Pleural effusion" refers to:', 'Fluid accumulation around the lungs', 'Infection of lung tissue', 'Air in the lung', 'Collapsed alveoli', 'A'),
('medical', 'respiratory', 'Which pathogen is most commonly responsible for bacterial pneumonia?', 'Streptococcus pneumoniae', 'Influenza virus', 'Mycobacterium tuberculosis', 'RSV', 'A'),
('medical', 'respiratory', 'A patient with sleep apnea experiences:', 'Continuous low oxygen during sleep', 'Coughing up blood', 'Chest tightness only', 'Muscle weakness', 'A'),
('medical', 'respiratory', '"Hemothorax" means:', 'Air in the chest', 'Blood in the pleural space', 'Pus in lungs', 'Collapsed alveoli', 'B'),
('medical', 'respiratory', 'Which condition is characterized by progressive destruction of alveoli and difficulty exhaling?', 'Asthma', 'Emphysema', 'Pneumonia', 'Pulmonary edema', 'B'),
('medical', 'respiratory', 'Which of the following is a symptom of pulmonary embolism?', 'Sudden shortness of breath', 'Gradual cough for months', 'Night sweats', 'Fever only', 'A'),
('medical', 'respiratory', '"Bronchoscopy" is a procedure used to:', 'Check heart valves', 'Visualize airways', 'Measure oxygen', 'Remove fluid from pleura', 'B'),
('medical', 'respiratory', 'Which of the following indicates a bacterial infection in the lungs?', 'Clear sputum', 'Purulent sputum', 'Occasional dry cough', 'Mild wheezing', 'B'),
('medical', 'respiratory', '"Orthopnea" is difficulty breathing when:', 'Sitting', 'Lying down', 'Exercising', 'Standing', 'B'),
('medical', 'respiratory', 'Which condition can cause barrel chest appearance due to overinflated lungs?', 'Asthma', 'COPD', 'Pneumothorax', 'Pulmonary edema', 'B'),
('medical', 'respiratory', 'A patient has a positive Mantoux test. This indicates:', 'Tuberculosis exposure', 'Pneumonia', 'Lung cancer', 'Asthma', 'A'),
('medical', 'respiratory', 'Which term describes inflammation of the bronchioles often seen in children?', 'Bronchitis', 'Bronchiolitis', 'Pneumothorax', 'Emphysema', 'B'),
('medical', 'respiratory', 'Which of the following is a common emergency symptom of respiratory distress?', 'Severe shortness of breath & cyanosis', 'Mild cough', 'Occasional wheeze', 'Slight chest discomfort', 'A');

-- =====================================================
-- GASTROINTESTINAL - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'gastrointestinal', 'Which term describes inflammation of the stomach lining?', 'Gastritis', 'Gastroenteritis', 'Hepatitis', 'Colitis', 'A'),
('medical', 'gastrointestinal', '"Dysphagia" means:', 'Difficulty swallowing', 'Abdominal pain', 'Vomiting blood', 'Diarrhea', 'A'),
('medical', 'gastrointestinal', 'Which condition involves inflammation of both stomach and intestines, usually due to infection?', 'Gastroenteritis', 'Hepatitis', 'Pancreatitis', 'Cholecystitis', 'A'),
('medical', 'gastrointestinal', 'Hematemesis refers to:', 'Blood in stool', 'Blood in vomit', 'Yellow skin', 'Abdominal swelling', 'B'),
('medical', 'gastrointestinal', 'Which test is used to visualize the inside of the esophagus, stomach, and duodenum?', 'Colonoscopy', 'Endoscopy', 'Ultrasound', 'MRI', 'B'),
('medical', 'gastrointestinal', '"Melena" refers to:', 'Vomiting', 'Black tarry stool', 'Red blood in stool', 'Diarrhea', 'B'),
('medical', 'gastrointestinal', 'Inflammation of the appendix is called:', 'Cholecystitis', 'Appendicitis', 'Pancreatitis', 'Gastritis', 'B'),
('medical', 'gastrointestinal', 'Which liver enzyme is commonly elevated in liver inflammation?', 'AST', 'CK-MB', 'Troponin', 'BNP', 'A'),
('medical', 'gastrointestinal', 'Which condition involves the backflow of stomach acid into the esophagus?', 'GERD', 'Peptic ulcer', 'Hepatitis', 'IBS', 'A'),
('medical', 'gastrointestinal', 'Which symptom is common in pancreatitis?', 'Right arm pain', 'Upper abdominal pain radiating to the back', 'Cough', 'Shortness of breath', 'B'),
('medical', 'gastrointestinal', 'Cirrhosis is most commonly caused by:', 'Alcohol abuse', 'High blood pressure', 'Diabetes', 'Heart failure', 'A'),
('medical', 'gastrointestinal', 'Which diagnostic test measures liver function?', 'LFT (Liver Function Test)', 'ECG', 'X-ray', 'Pulmonary function test', 'A'),
('medical', 'gastrointestinal', '"Icterus" refers to:', 'Yellowing of the skin and eyes', 'Swelling of the abdomen', 'Pain in right upper quadrant', 'Vomiting', 'A'),
('medical', 'gastrointestinal', 'Which condition is characterized by inflammation of the colon?', 'Crohn''s disease', 'Ulcerative colitis', 'Pancreatitis', 'Hepatitis', 'B'),
('medical', 'gastrointestinal', 'Which symptom is common in peptic ulcer disease?', 'Sharp upper abdominal pain, often relieved by food', 'Chest tightness', 'Shortness of breath', 'Leg swelling', 'A'),
('medical', 'gastrointestinal', '"Steatorrhea" refers to:', 'Fatty stools', 'Bloody stools', 'Diarrhea', 'Vomiting', 'A'),
('medical', 'gastrointestinal', 'Which organ is affected in cholecystitis?', 'Pancreas', 'Gallbladder', 'Liver', 'Appendix', 'B'),
('medical', 'gastrointestinal', 'Jaundice indicates:', 'Low oxygen', 'High bilirubin', 'Low potassium', 'High glucose', 'B'),
('medical', 'gastrointestinal', 'Which term describes inflammation of the esophagus?', 'Gastritis', 'Esophagitis', 'Hepatitis', 'Colitis', 'B'),
('medical', 'gastrointestinal', 'Which of the following is a common complication of untreated GERD?', 'Barrett''s esophagus', 'Cirrhosis', 'Pancreatitis', 'Appendicitis', 'A'),
('medical', 'gastrointestinal', '"Constipation" refers to:', 'Difficulty passing stool', 'Diarrhea', 'Vomiting', 'Abdominal pain', 'A'),
('medical', 'gastrointestinal', 'Which condition is characterized by chronic abdominal pain, bloating, and changes in bowel habits without structural abnormality?', 'IBS', 'Crohn''s disease', 'Ulcerative colitis', 'Gastritis', 'A'),
('medical', 'gastrointestinal', 'Which enzyme is secreted by the pancreas to aid digestion?', 'Amylase', 'Troponin', 'Hemoglobin', 'Insulin', 'A'),
('medical', 'gastrointestinal', 'Which imaging test is most commonly used to detect gallstones?', 'Ultrasound', 'CT scan', 'MRI', 'ECG', 'A'),
('medical', 'gastrointestinal', 'Which of the following symptoms is considered an emergency in GI conditions?', 'Severe abdominal pain with vomiting blood', 'Mild bloating', 'Occasional diarrhea', 'Constipation', 'A');

-- =====================================================
-- ENDOCRINOLOGY - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'endocrinology', 'Which gland produces insulin?', 'Thyroid', 'Pancreas', 'Adrenal', 'Pituitary', 'B'),
('medical', 'endocrinology', '"Hyperglycemia" means:', 'Low blood sugar', 'High blood sugar', 'Low potassium', 'High sodium', 'B'),
('medical', 'endocrinology', 'Which hormone regulates metabolism?', 'Cortisol', 'Thyroid hormones', 'Insulin', 'Glucagon', 'B'),
('medical', 'endocrinology', 'A patient with polyuria, polydipsia, and weight loss likely has:', 'Diabetes mellitus', 'Hypothyroidism', 'Addison''s disease', 'Cushing''s syndrome', 'A'),
('medical', 'endocrinology', 'Which test measures long-term blood sugar control?', 'Fasting glucose', 'HbA1c', 'Random glucose', 'OGTT', 'B'),
('medical', 'endocrinology', '"Hypothyroidism" is characterized by:', 'High energy and weight loss', 'Fatigue and weight gain', 'Rapid heartbeat', 'Increased sweating', 'B'),
('medical', 'endocrinology', 'Which hormone is produced by the adrenal cortex and helps in stress response?', 'Epinephrine', 'Cortisol', 'Insulin', 'Thyroxine', 'B'),
('medical', 'endocrinology', '"Goiter" refers to:', 'Swelling of the thyroid gland', 'Swelling of lymph nodes', 'Enlarged adrenal', 'Pancreatic tumor', 'A'),
('medical', 'endocrinology', 'A patient with hyperpigmentation, fatigue, and low blood pressure may have:', 'Addison''s disease', 'Cushing''s syndrome', 'Hypothyroidism', 'Diabetes mellitus', 'A'),
('medical', 'endocrinology', '"Hyperkalemia" means:', 'Low potassium', 'High potassium', 'Low sodium', 'High calcium', 'B'),
('medical', 'endocrinology', 'Which hormone increases blood calcium levels?', 'Calcitonin', 'Parathyroid hormone', 'Insulin', 'Cortisol', 'B'),
('medical', 'endocrinology', '"Cushing''s syndrome" is caused by:', 'Excess cortisol', 'Excess insulin', 'Low thyroid hormone', 'Low cortisol', 'A'),
('medical', 'endocrinology', 'Which condition involves low blood sugar?', 'Hyperglycemia', 'Hypoglycemia', 'Diabetes', 'Hyperthyroidism', 'B'),
('medical', 'endocrinology', 'A patient with tremors, heat intolerance, and weight loss may have:', 'Hyperthyroidism', 'Hypothyroidism', 'Addison''s disease', 'Cushing''s syndrome', 'A'),
('medical', 'endocrinology', 'Which test is used to evaluate thyroid function?', 'TSH', 'HbA1c', 'Cortisol', 'Fasting glucose', 'A'),
('medical', 'endocrinology', '"Polydipsia" means:', 'Excessive urination', 'Excessive thirst', 'Excessive hunger', 'Fatigue', 'B'),
('medical', 'endocrinology', 'Which hormone is secreted by the posterior pituitary to regulate water balance?', 'Oxytocin', 'ADH', 'Growth hormone', 'TSH', 'B'),
('medical', 'endocrinology', 'A patient with rapid weight gain, moon face, and buffalo hump may have:', 'Hypothyroidism', 'Cushing''s syndrome', 'Addison''s disease', 'Hyperthyroidism', 'B'),
('medical', 'endocrinology', '"Glycosuria" refers to:', 'Sugar in urine', 'Protein in urine', 'Blood in urine', 'Ketones in urine', 'A'),
('medical', 'endocrinology', 'Which endocrine disorder is autoimmune in nature and destroys insulin-producing cells?', 'Type 1 diabetes', 'Type 2 diabetes', 'Cushing''s syndrome', 'Addison''s disease', 'A'),
('medical', 'endocrinology', '"Exophthalmos" is associated with:', 'Hypothyroidism', 'Hyperthyroidism', 'Addison''s disease', 'Diabetes', 'B'),
('medical', 'endocrinology', 'Which hormone regulates sodium and potassium balance in the body?', 'Aldosterone', 'Insulin', 'Cortisol', 'TSH', 'A'),
('medical', 'endocrinology', 'Which endocrine gland is located above the kidneys?', 'Pituitary', 'Adrenal', 'Thyroid', 'Pancreas', 'B'),
('medical', 'endocrinology', '"Macroglossia" can be a symptom of:', 'Hypothyroidism', 'Hyperthyroidism', 'Addison''s disease', 'Diabetes', 'A'),
('medical', 'endocrinology', 'Which hormone stimulates growth in children?', 'Thyroxine', 'Growth hormone', 'Cortisol', 'Insulin', 'B');

-- =====================================================
-- RENAL - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'renal', '"Hematuria" refers to:', 'Blood in urine', 'Painful urination', 'Excess urine', 'Cloudy urine', 'A'),
('medical', 'renal', 'Which test measures kidney function by assessing creatinine levels?', 'LFT', 'BUN & Creatinine', 'CBC', 'ECG', 'B'),
('medical', 'renal', '"Oliguria" means:', 'Excessive urination', 'Low urine output', 'Painful urination', 'Blood in urine', 'B'),
('medical', 'renal', 'Which condition is characterized by sudden kidney failure?', 'CKD', 'AKI', 'Nephrolithiasis', 'UTI', 'B'),
('medical', 'renal', 'A patient with flank pain and hematuria may have:', 'Kidney stones', 'Bladder infection', 'Urinary retention', 'Pyelonephritis', 'A'),
('medical', 'renal', 'Which hormone is secreted by the kidneys to stimulate red blood cell production?', 'Aldosterone', 'Erythropoietin', 'ADH', 'Renin', 'B'),
('medical', 'renal', '"Proteinuria" indicates:', 'Protein in urine', 'Blood in urine', 'Glucose in urine', 'Ketones in urine', 'A'),
('medical', 'renal', 'Which test measures urine concentration and kidney concentrating ability?', 'Urine culture', 'Urine specific gravity', 'Urine dipstick', 'Creatinine clearance', 'B'),
('medical', 'renal', '"Pyelonephritis" is:', 'Inflammation of bladder', 'Infection of kidney', 'Kidney stones', 'Urethral obstruction', 'B'),
('medical', 'renal', 'A patient with edema, hypertension, and proteinuria may have:', 'Nephrotic syndrome', 'Acute tubular necrosis', 'UTI', 'Pyelonephritis', 'A'),
('medical', 'renal', '"Polydipsia" in renal patients often indicates:', 'Fluid overload', 'Excessive thirst', 'Low blood pressure', 'Painful urination', 'B'),
('medical', 'renal', 'Which of the following is a common cause of chronic kidney disease?', 'Diabetes mellitus', 'Asthma', 'GERD', 'Hyperthyroidism', 'A'),
('medical', 'renal', 'Which electrolyte is often elevated in kidney failure and can cause cardiac arrhythmias?', 'Sodium', 'Potassium', 'Calcium', 'Magnesium', 'B'),
('medical', 'renal', '"Dysuria" refers to:', 'Painful urination', 'Excess urine', 'Blood in urine', 'Incomplete emptying', 'A'),
('medical', 'renal', 'A patient with sudden severe flank pain radiating to groin may have:', 'Kidney stones', 'Pyelonephritis', 'Bladder cancer', 'Prostatitis', 'A'),
('medical', 'renal', '"Nocturia" means:', 'Nighttime urination', 'Blood in urine', 'Excessive thirst', 'Pain in kidney', 'A'),
('medical', 'renal', 'Which procedure is used to remove excess fluid and waste in kidney failure?', 'Dialysis', 'Catheterization', 'Ultrasound', 'Cystoscopy', 'A'),
('medical', 'renal', '"Hydronephrosis" refers to:', 'Swelling of the kidneys due to urine buildup', 'Infection of the bladder', 'Kidney stones', 'Urethral obstruction', 'A'),
('medical', 'renal', 'Which test detects urinary tract infections?', 'Urine culture', 'ECG', 'Chest X-ray', 'Blood glucose', 'A'),
('medical', 'renal', 'Which condition can cause "foamy urine" due to high protein content?', 'Nephrotic syndrome', 'Kidney stones', 'Pyelonephritis', 'Urethritis', 'A'),
('medical', 'renal', '"Anuria" means:', 'No urine output', 'Low urine output', 'Painful urination', 'Blood in urine', 'A'),
('medical', 'renal', 'Which hormone regulates sodium and potassium balance in the kidneys?', 'ADH', 'Aldosterone', 'Erythropoietin', 'Insulin', 'B'),
('medical', 'renal', 'Which condition is caused by inflammation of the glomeruli?', 'Glomerulonephritis', 'Pyelonephritis', 'Nephrolithiasis', 'Cystitis', 'A'),
('medical', 'renal', '"Uremia" refers to:', 'Excess potassium in blood', 'Accumulation of waste in blood due to kidney failure', 'Low sodium', 'High glucose', 'B'),
('medical', 'renal', 'Which imaging test is commonly used to detect kidney stones?', 'Ultrasound', 'MRI', 'CT angiogram', 'ECG', 'A');

-- =====================================================
-- OB/GYN - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'ob_gyn', '"Menorrhagia" refers to:', 'Painful menstruation', 'Heavy menstrual bleeding', 'Absence of menstruation', 'Irregular periods', 'B'),
('medical', 'ob_gyn', '"Amenorrhea" means:', 'Painful menstruation', 'Heavy menstrual bleeding', 'Absence of menstruation', 'Irregular periods', 'C'),
('medical', 'ob_gyn', '"Dysmenorrhea" refers to:', 'Painful menstruation', 'Excessive bleeding', 'Irregular periods', 'Absence of menstruation', 'A'),
('medical', 'ob_gyn', 'Which test is used to detect cervical cancer?', 'Pap smear', 'Ultrasound', 'Mammography', 'MRI', 'A'),
('medical', 'ob_gyn', 'A patient with lower abdominal pain, fever, and foul-smelling discharge may have:', 'Pelvic inflammatory disease (PID)', 'Endometriosis', 'Ovarian cyst', 'Fibroids', 'A'),
('medical', 'ob_gyn', '"Ectopic pregnancy" occurs when:', 'Fertilized egg implants outside the uterus', 'Fertilized egg implants in the uterus', 'Ovulation fails', 'Menstruation stops', 'A'),
('medical', 'ob_gyn', 'Which hormone is primarily responsible for maintaining pregnancy?', 'Progesterone', 'Estrogen', 'LH', 'FSH', 'A'),
('medical', 'ob_gyn', '"Preeclampsia" is characterized by:', 'High blood pressure and proteinuria during pregnancy', 'Low blood sugar', 'Excessive bleeding', 'Irregular periods', 'A'),
('medical', 'ob_gyn', 'Which test measures fetal heart rate and contractions?', 'Ultrasound', 'Non-stress test (NST)', 'Pap smear', 'Amniocentesis', 'B'),
('medical', 'ob_gyn', '"Polyhydramnios" means:', 'Excess amniotic fluid', 'Low amniotic fluid', 'Premature rupture of membranes', 'Placental abruption', 'A'),
('medical', 'ob_gyn', 'Which condition is characterized by endometrial tissue outside the uterus?', 'Fibroids', 'Endometriosis', 'PID', 'Ovarian cyst', 'B'),
('medical', 'ob_gyn', '"Menopause" refers to:', 'Start of menstruation', 'End of menstruation', 'Heavy bleeding', 'Painful periods', 'B'),
('medical', 'ob_gyn', 'Which hormone triggers ovulation?', 'FSH', 'LH', 'Estrogen', 'Progesterone', 'B'),
('medical', 'ob_gyn', 'A patient with severe pelvic pain and a history of missed periods may have:', 'Ectopic pregnancy', 'Endometriosis', 'PID', 'Fibroids', 'A'),
('medical', 'ob_gyn', '"Oligohydramnios" refers to:', 'Excess amniotic fluid', 'Low amniotic fluid', 'Premature labor', 'Placenta previa', 'B'),
('medical', 'ob_gyn', 'Which imaging test is first-line for evaluating ovarian cysts?', 'MRI', 'Ultrasound', 'CT scan', 'X-ray', 'B'),
('medical', 'ob_gyn', '"Placenta previa" means:', 'Placenta covers the cervix', 'Placenta detaches prematurely', 'Placenta is infected', 'Placenta is too small', 'A'),
('medical', 'ob_gyn', 'Which hormone stimulates milk production after birth?', 'Oxytocin', 'Prolactin', 'Estrogen', 'Progesterone', 'B'),
('medical', 'ob_gyn', 'A patient presents with sudden abdominal pain and vaginal bleeding in late pregnancy. Most likely diagnosis:', 'Placental abruption', 'Ectopic pregnancy', 'Fibroids', 'PID', 'A'),
('medical', 'ob_gyn', '"Amenorrhea" lasting more than 3 months in a non-pregnant woman requires evaluation for:', 'Hormonal disorders', 'Kidney disease', 'Diabetes', 'Hypertension', 'A'),
('medical', 'ob_gyn', 'Which condition involves non-cancerous growths in the uterus?', 'Fibroids', 'Endometriosis', 'Ovarian cysts', 'PID', 'A'),
('medical', 'ob_gyn', '"Menometrorrhagia" refers to:', 'Painful periods', 'Irregular and heavy menstrual bleeding', 'Absence of periods', 'Short menstrual cycles', 'B'),
('medical', 'ob_gyn', 'Which procedure removes the uterus?', 'Hysterectomy', 'Oophorectomy', 'Salpingectomy', 'Dilation & curettage', 'A'),
('medical', 'ob_gyn', 'Which pregnancy complication involves high blood pressure and organ damage?', 'Ectopic pregnancy', 'Preeclampsia', 'Gestational diabetes', 'Placenta previa', 'B'),
('medical', 'ob_gyn', 'Which test is used to assess fetal lung maturity?', 'Ultrasound', 'Amniocentesis', 'NST', 'Pap smear', 'B');

-- =====================================================
-- ONCOLOGY - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'oncology', '"Neoplasm" refers to:', 'New and abnormal tissue growth', 'Normal cell repair', 'Chronic infection', 'Muscle inflammation', 'A'),
('medical', 'oncology', 'Which finding is more concerning for breast cancer?', 'A hard, non-painful lump', 'Pain during exercise', 'Redness after shaving', 'Itching in the shoulder', 'A'),
('medical', 'oncology', '"Metastatic cancer" means the cancer:', 'Has spread to a distant site', 'Is small and localized', 'Is not harmful', 'Causes allergy', 'A'),
('medical', 'oncology', 'If a doctor orders a "biopsy," the purpose is to:', 'Confirm whether the tissue is cancerous', 'Lower blood pressure', 'Remove a whole organ', 'Test kidney function', 'A'),
('medical', 'oncology', 'A patient with lymphoma may report:', 'Night sweats and painless swollen lymph nodes', 'Knee pain', 'Ear discharge', 'Tooth sensitivity', 'A'),
('medical', 'oncology', 'Which imaging test is the primary tool for early breast cancer detection?', 'Mammography', 'PET scan', 'Ultrasound only', 'Bone scan', 'A'),
('medical', 'oncology', '"Carcinoma in situ" means the cancer:', 'Has not spread beyond where it started', 'Is widely metastatic', 'Is benign', 'Causes internal bleeding', 'A'),
('medical', 'oncology', 'A patient undergoing chemotherapy is suddenly febrile. This can indicate:', 'Neutropenic fever', 'Normal treatment reaction', 'Allergic rhinitis', 'High sugar level', 'A'),
('medical', 'oncology', 'Which symptom may suggest colorectal cancer?', 'A change in bowel habits', 'Eye redness', 'Hand tremors', 'Neck stiffness', 'A'),
('medical', 'oncology', '"Palliative care" focuses on:', 'Symptom relief and quality of life', 'Only curing cancer', 'Physical therapy', 'Routine checkups', 'A'),
('medical', 'oncology', 'A PET scan is commonly used to:', 'Detect metabolically active (possible cancer) areas', 'Check lung capacity', 'Evaluate hearing', 'Test blood sugar', 'A'),
('medical', 'oncology', 'A rapidly enlarging neck mass could suggest:', 'Thyroid cancer', 'Tonsillitis only', 'Skin allergy', 'Simple dehydration', 'A'),
('medical', 'oncology', '"Oncologist" refers to a doctor who:', 'Diagnoses and treats cancer', 'Treats bones', 'Manages infections only', 'Focuses on digestive system', 'A'),
('medical', 'oncology', 'Which of the following is a common side effect of radiation therapy to the chest?', 'Skin irritation', 'Excessive hunger', 'Severe weight gain', 'Ear pain', 'A'),
('medical', 'oncology', 'A patient reports unintended weight loss, fatigue, and a persistent cough. Possible concern:', 'Lung cancer', 'Food allergy', 'Muscle spasm', 'Thyroid storm', 'A'),
('medical', 'oncology', '"Remission" means the cancer:', 'Shows no signs or is significantly reduced', 'Has spread to the liver', 'Is worsening', 'Is cured permanently', 'A'),
('medical', 'oncology', 'A doctor says: "The tumor is pressing on surrounding organs." This means:', 'Mass effect', 'Infection', 'Blood clot', 'Low oxygen', 'A'),
('medical', 'oncology', 'A patient with leukemia often has:', 'Frequent infections and low blood counts', 'Ear pain', 'Back rash', 'Normal appetite', 'A'),
('medical', 'oncology', '"Tumor markers" (like PSA, CA-125) are used to:', 'Monitor progress or recurrence', 'Diagnose skin diseases', 'Treat anemia', 'Measure lung pressure', 'A'),
('medical', 'oncology', 'A patient receiving chemotherapy should avoid:', 'Exposure to infections', 'Drinking water', 'Walking', 'Speaking loudly', 'A'),
('medical', 'oncology', '"Localized cancer" means:', 'It is limited to its original area', 'It spread to the brain', 'It is terminal', 'It needs no treatment', 'A'),
('medical', 'oncology', 'Which is a common sign of leukemia?', 'Easy bruising and bleeding', 'Joint fractures', 'High vision', 'Improved circulation', 'A'),
('medical', 'oncology', 'A carcinogen is:', 'A substance that causes cancer', 'A nerve disorder', 'A muscle injury', 'A benign mass', 'A'),
('medical', 'oncology', 'A biopsy is essential because it:', 'Confirms cancer by analyzing tissue', 'Measures oxygen', 'Treats infection', 'Reduces tumor size', 'A'),
('medical', 'oncology', '"Cachexia" in cancer patients means:', 'Severe weight loss and muscle wasting', 'Nausea only', 'Fatigue', 'Pain', 'A');

-- =====================================================
-- EMERGENCY - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'emergency', 'A patient arrives with sudden chest pain radiating to the left arm. Likely diagnosis:', 'Myocardial infarction (heart attack)', 'Asthma', 'Stroke', 'Pneumonia', 'A'),
('medical', 'emergency', '"Dyspnea" means:', 'Shortness of breath', 'Chest pain', 'Dizziness', 'Cough', 'A'),
('medical', 'emergency', 'Which symptom is critical for identifying a stroke?', 'Facial droop, arm weakness, speech difficulty', 'Fever', 'Rash', 'Nausea', 'A'),
('medical', 'emergency', 'A patient presents with a severe allergic reaction, swelling of face and throat. Immediate action:', 'Administer epinephrine', 'Give acetaminophen', 'Apply ice', 'Start IV fluids', 'A'),
('medical', 'emergency', '"Hemorrhage" refers to:', 'Excessive bleeding', 'Infection', 'Swelling', 'Fracture', 'A'),
('medical', 'emergency', 'A patient fell from height and is unconscious. First step:', 'Assess airway, breathing, circulation (ABC)', 'Start physical therapy', 'Take vitals only', 'Give painkillers', 'A'),
('medical', 'emergency', '"Tachycardia" means:', 'Fast heart rate', 'Slow heart rate', 'Chest pain', 'Shortness of breath', 'A'),
('medical', 'emergency', 'Which imaging is first choice for suspected traumatic brain injury?', 'CT scan', 'MRI', 'Ultrasound', 'X-ray', 'A'),
('medical', 'emergency', '"Hypotension" refers to:', 'Low blood pressure', 'High blood pressure', 'Chest pain', 'Shortness of breath', 'A'),
('medical', 'emergency', 'A patient presents with severe abdominal pain, nausea, and vomiting. Possible ER diagnosis:', 'Appendicitis', 'Migraine', 'Skin infection', 'Anxiety', 'A'),
('medical', 'emergency', '"Sepsis" is defined as:', 'Life-threatening organ dysfunction due to infection', 'Heart attack', 'Stroke', 'Asthma', 'A'),
('medical', 'emergency', 'Which type of shock is caused by severe infection?', 'Septic shock', 'Cardiogenic shock', 'Hypovolemic shock', 'Neurogenic shock', 'A'),
('medical', 'emergency', 'A patient has sudden, severe shortness of breath and wheezing after allergen exposure. Likely:', 'Anaphylaxis', 'Pneumonia', 'Heart attack', 'Stroke', 'A'),
('medical', 'emergency', '"Fracture" refers to:', 'Broken bone', 'Sprained joint', 'Dislocated joint', 'Muscle tear', 'A'),
('medical', 'emergency', 'Which medication is first-line in acute asthma attack?', 'Short-acting beta-agonist (e.g., albuterol)', 'Steroid cream', 'Antibiotics', 'Antidepressants', 'A'),
('medical', 'emergency', '"Hypoxia" means:', 'Low oxygen in the blood', 'High blood pressure', 'Low heart rate', 'Fever', 'A'),
('medical', 'emergency', 'Patient with severe burn injury: first priority:', 'Airway, breathing, circulation', 'Pain relief', 'Apply ointment only', 'Take X-ray', 'A'),
('medical', 'emergency', 'Which is a sign of internal bleeding?', 'Low blood pressure, rapid pulse', 'High blood pressure', 'Rash', 'Headache', 'A'),
('medical', 'emergency', '"Cardiac arrest" is:', 'Heart stops beating effectively', 'Heart rate too fast', 'Chest pain only', 'Shortness of breath', 'A'),
('medical', 'emergency', 'Which is a critical symptom in meningitis?', 'Fever, neck stiffness, headache', 'Rash only', 'Cough', 'Dizziness', 'A'),
('medical', 'emergency', 'A patient presents with severe trauma and unconscious. What is the Glasgow Coma Scale (GCS) used for?', 'Assess level of consciousness', 'Measure heart rate', 'Measure blood pressure', 'Diagnose fracture', 'A'),
('medical', 'emergency', '"Hypovolemic shock" results from:', 'Severe blood or fluid loss', 'Heart failure', 'Infection', 'Allergic reaction', 'A'),
('medical', 'emergency', 'Which drug is commonly used in cardiac arrest?', 'Epinephrine', 'Aspirin', 'Metformin', 'Antibiotics', 'A'),
('medical', 'emergency', '"Airway obstruction" is a life-threatening emergency because:', 'Oxygen cannot reach lungs', 'Blood pressure rises', 'Heart rate slows', 'Pain increases', 'A'),
('medical', 'emergency', 'A patient with seizures at the ER should first receive:', 'Ensure safety and monitor ABC', 'Give antibiotics', 'Start physical therapy', 'Prescribe antidepressants', 'A');

-- =====================================================
-- DERMATOLOGY - 25 Questions
-- =====================================================
INSERT INTO public.quiz_questions(quiz_type, medical_section, question_text, option_a, option_b, option_c, option_d, correct_option) VALUES
('medical', 'dermatology', '"Eczema" refers to:', 'Chronic inflammatory skin condition', 'Skin cancer', 'Bacterial infection', 'Allergic rash', 'A'),
('medical', 'dermatology', '"Psoriasis" is characterized by:', 'Red, scaly patches on the skin', 'Fluid-filled blisters', 'Pustules with pus', 'Skin necrosis', 'A'),
('medical', 'dermatology', '"Acne vulgaris" is most commonly caused by:', 'Hormonal changes', 'Fungal infection', 'Sun exposure', 'Allergic reaction', 'A'),
('medical', 'dermatology', '"Melanoma" refers to:', 'Skin cancer originating from melanocytes', 'Benign mole', 'Bacterial rash', 'Chronic dermatitis', 'A'),
('medical', 'dermatology', '"Dermatitis herpetiformis" is usually associated with:', 'Celiac disease', 'Diabetes', 'Hypertension', 'Asthma', 'A'),
('medical', 'dermatology', '"Biopsy" in dermatology is used to:', 'Diagnose skin lesions', 'Treat skin infection', 'Remove warts', 'Reduce inflammation', 'A'),
('medical', 'dermatology', '"Urticaria" is also known as:', 'Hives', 'Psoriasis', 'Eczema', 'Rosacea', 'A'),
('medical', 'dermatology', '"Rosacea" typically affects:', 'Face', 'Scalp', 'Hands', 'Feet', 'A'),
('medical', 'dermatology', '"Vitiligo" is a condition of:', 'Skin depigmentation', 'Hair loss', 'Red rash', 'Blistering', 'A'),
('medical', 'dermatology', '"Impetigo" is:', 'Bacterial skin infection', 'Fungal infection', 'Viral infection', 'Autoimmune rash', 'A'),
('medical', 'dermatology', '"Shingles" is caused by:', 'Varicella-zoster virus', 'Herpes simplex virus', 'Staphylococcus', 'Streptococcus', 'A'),
('medical', 'dermatology', '"Tinea corporis" refers to:', 'Ringworm', 'Psoriasis', 'Eczema', 'Acne', 'A'),
('medical', 'dermatology', '"Seborrheic dermatitis" often affects:', 'Scalp', 'Palms', 'Soles', 'Nails', 'A'),
('medical', 'dermatology', '"Lichen planus" presents with:', 'Flat-topped, purple lesions', 'Blisters', 'Pustules', 'Ulcers', 'A'),
('medical', 'dermatology', '"Molluscum contagiosum" is caused by:', 'Poxvirus', 'Herpes virus', 'Fungal infection', 'Bacterial infection', 'A'),
('medical', 'dermatology', '"Actinic keratosis" is considered:', 'Precancerous skin lesion', 'Benign lesion', 'Viral rash', 'Allergic rash', 'A'),
('medical', 'dermatology', '"Contact dermatitis" is triggered by:', 'Allergens or irritants', 'Bacteria', 'Hormones', 'Genetics', 'A'),
('medical', 'dermatology', '"Mole (nevus)" that changes color or size may indicate:', 'Melanoma', 'Acne', 'Eczema', 'Psoriasis', 'A'),
('medical', 'dermatology', '"Phototherapy" in dermatology is mainly used to treat:', 'Psoriasis', 'Skin infections', 'Burns', 'Acne', 'A'),
('medical', 'dermatology', '"Scabies" is caused by:', 'Mite', 'Bacteria', 'Virus', 'Fungus', 'A'),
('medical', 'dermatology', '"Hyperpigmentation" refers to:', 'Darkening of the skin', 'Loss of skin color', 'Redness', 'Blistering', 'A'),
('medical', 'dermatology', '"Hypopigmentation" refers to:', 'Light patches on the skin', 'Dark spots', 'Rash with pus', 'Red scaly patches', 'A'),
('medical', 'dermatology', 'A patient has itchy, red, raised wheals after eating seafood. This is most likely:', 'Urticaria', 'Eczema', 'Psoriasis', 'Rosacea', 'A'),
('medical', 'dermatology', '"Topical corticosteroids" are mainly used to:', 'Reduce inflammation', 'Kill bacteria', 'Treat fungal infections', 'Stimulate hair growth', 'A'),
('medical', 'dermatology', 'A patient presents with blistering on lips and mouth after stress. Likely diagnosis:', 'Cold sores (Herpes labialis)', 'Canker sores', 'Impetigo', 'Eczema', 'A');

-- Verify the count
DO $$
DECLARE
  total_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_count FROM public.quiz_questions WHERE quiz_type = 'medical';
  RAISE NOTICE 'Total medical quiz questions inserted: %', total_count;
END $$;
