-- v5 Migration: 品項管理、教學 加入 created_by 欄位（自助權限控管）
-- 在 Supabase SQL Editor 執行

-- 1. materials 加 created_by（記錄誰新增的，供自助編輯/刪除判斷）
ALTER TABLE public.materials
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- 2. tutorials 加 created_by
ALTER TABLE public.tutorials
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
