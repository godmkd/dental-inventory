-- v12 Migration: 診所排序
-- 在 Supabase SQL Editor 執行

ALTER TABLE public.clinics
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;
