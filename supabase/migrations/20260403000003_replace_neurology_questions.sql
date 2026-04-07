-- Replace Neurology quiz bank with updated NEURO SYSTEM questions (25)

DELETE FROM public.quiz_questions
WHERE quiz_type = 'medical'
  AND medical_section = 'neurology';

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
('medical', 'neurology', 'What does "syncope" mean?', 'Muscle twitching', 'Loss of consciousness', 'Memory loss', 'Nerve inflammation', 'B'),
('medical', 'neurology', 'Which condition involves sudden, uncontrolled electrical activity in the brain?', 'Epilepsy', 'ALS', 'Parkinson''s disease', 'Vertigo', 'A'),
('medical', 'neurology', '"Hemiparesis" means:', 'Complete body paralysis', 'Weakness on one side of the body', 'Paralysis of both legs', 'Loss of coordination', 'B'),
('medical', 'neurology', 'Which test measures electrical activity in the brain?', 'EMG', 'EEG', 'ECG', 'MRI', 'B'),
('medical', 'neurology', 'A "ruptured aneurysm" most commonly leads to:', 'Ischemic stroke', 'Hemorrhagic stroke', 'Dementia', 'Multiple sclerosis', 'B'),
('medical', 'neurology', 'The part of the brain responsible for balance and coordination is:', 'Cerebrum', 'Brainstem', 'Cerebellum', 'Thalamus', 'C'),
('medical', 'neurology', 'Which condition is characterized by progressive muscle weakness due to nerve degeneration?', 'Parkinson''s disease', 'ALS', 'Epilepsy', 'Stroke', 'B'),
('medical', 'neurology', '"Vertigo" refers to:', 'Severe headache', 'The sensation of spinning', 'Losing memory', 'Tingling in hands', 'B'),
('medical', 'neurology', 'Which nerve disorder is caused by uncontrolled diabetes?', 'Peripheral neuropathy', 'Myopathy', 'Neuralgia', 'Hydrocephalus', 'A'),
('medical', 'neurology', 'What is "hydrocephalus"?', 'Infection of the brain', 'Fluid buildup in the brain', 'Brain tumor', 'Nerve damage in the legs', 'B'),
('medical', 'neurology', 'Medical procedure in which a needle is inserted into the spinal canal, most commonly to collect cerebrospinal fluid:', 'Epidural', 'Nerve block', 'Lumbar puncture', 'CT scan', 'C'),
('medical', 'neurology', 'Traumatic brain injury that affects brain function and can include headaches and problems with concentration, memory, balance, and coordination is called:', 'Vertigo', 'Concussion', 'Epilepsy', 'Parkinson''s disease', 'B'),
('medical', 'neurology', 'Which term describes sharp, stabbing nerve pain along the course of a nerve?', 'Neuropathy', 'Neuralgia', 'Myelopathy', 'Aphasia', 'B'),
('medical', 'neurology', 'Which term refers to spinal cord dysfunction?', 'Neuropathy', 'Myelopathy', 'Neuralgia', 'Encephalopathy', 'B'),
('medical', 'neurology', 'Which condition is described as sudden weakness on one side of the body with facial drooping and slurred speech?', 'Migraine', 'Stroke', 'Epilepsy', 'Neuralgia', 'B'),
('medical', 'neurology', 'Which condition is characterized by progressive cognitive decline affecting memory, judgment, and behavior?', 'Aphasia', 'Dementia', 'Ataxia', 'Neuralgia', 'B'),
('medical', 'neurology', 'A patient has resting tremor, rigidity, and slow movements. Which disease is most likely?', 'Alzheimer''s disease', 'Parkinson''s disease', 'Multiple sclerosis', 'Stroke', 'B'),
('medical', 'neurology', 'An elderly patient presents with progressive memory loss, confusion, and personality changes. Most likely diagnosis?', 'Parkinson''s disease', 'Alzheimer''s disease', 'Stroke', 'Epilepsy', 'B'),
('medical', 'neurology', 'A patient develops loss of movement and sensation in both legs after trauma. What is the condition?', 'Neuropathy', 'Paraplegia', 'Hemiplegia', 'Myopathy', 'B'),
('medical', 'neurology', 'A patient has brief weakness and speech difficulty that resolves within one hour. What is the most likely diagnosis?', 'Stroke', 'Transient ischemic attack (TIA)', 'Migraine', 'Seizure', 'B'),
('medical', 'neurology', 'The term for surgical operation of a portion of the skull:', 'Craniotomy', 'Lobotomy', 'Neurotomy', 'Hematotomy', 'A'),
('medical', 'neurology', 'Which specialist treats brain and nerve disorders?', 'Cardiologist', 'Neurologist', 'Pulmonologist', 'Endocrinologist', 'B'),
('medical', 'neurology', 'Which term refers to a partial or complete loss of sensation in a part of the body?', 'Tingling', 'Burning pain', 'Weakness', 'Numbness', 'D'),
('medical', 'neurology', 'Which symptom describes a "pins and needles" sensation?', 'Numbness', 'Weakness', 'Tingling', 'Paralysis', 'C'),
('medical', 'neurology', 'Which term refers to inability to coordinate voluntary muscle movements?', 'Tremor', 'Ataxia', 'Paralysis', 'Neuralgia', 'B');
