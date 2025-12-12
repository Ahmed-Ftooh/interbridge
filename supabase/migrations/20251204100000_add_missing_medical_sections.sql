-- Add missing medical sections to the enum
ALTER TYPE public.medical_section_type ADD VALUE IF NOT EXISTS 'psychiatry';
ALTER TYPE public.medical_section_type ADD VALUE IF NOT EXISTS 'internal_medicine';
