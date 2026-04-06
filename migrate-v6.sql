-- v6 Migration: 品項加入 default_safety_stock（全診所預設安全庫存）
-- 在 Supabase SQL Editor 執行

ALTER TABLE public.materials
  ADD COLUMN IF NOT EXISTS default_safety_stock INT DEFAULT 5;
