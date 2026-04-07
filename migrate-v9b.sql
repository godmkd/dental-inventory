-- v9b Migration: material_suppliers 加規格/叫貨單位/換算比例
-- 在 Supabase SQL Editor 執行

ALTER TABLE public.material_suppliers
  ADD COLUMN IF NOT EXISTS spec       TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS order_unit TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS unit_ratio DECIMAL(10,2) DEFAULT 1;
