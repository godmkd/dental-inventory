-- v14 Migration: 頭像欄位
-- 在 Supabase SQL Editor 執行

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';
