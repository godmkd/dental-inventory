-- v15 Migration: 一人多診所
-- 在 Supabase SQL Editor 執行

-- 1. 建立使用者-診所關聯表
CREATE TABLE IF NOT EXISTS public.user_clinics (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  clinic_id BIGINT NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, clinic_id)
);

-- 2. RLS
ALTER TABLE public.user_clinics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_clinics_access" ON public.user_clinics
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 3. 將現有 user_profiles.clinic_id 資料遷移到 user_clinics
INSERT INTO public.user_clinics (user_id, clinic_id)
SELECT id, clinic_id FROM public.user_profiles WHERE clinic_id IS NOT NULL
ON CONFLICT (user_id, clinic_id) DO NOTHING;
