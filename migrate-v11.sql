-- v11 Migration: 廠商加 LINE ID
-- 在 Supabase SQL Editor 執行

ALTER TABLE public.suppliers
  ADD COLUMN IF NOT EXISTS line_id TEXT DEFAULT '';
