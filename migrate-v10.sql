-- v10 Migration: 品項排序
-- 在 Supabase SQL Editor 執行

ALTER TABLE public.materials
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

-- 依類別和名稱初始化排序
WITH ranked AS (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY name) - 1 AS rn
  FROM public.materials
)
UPDATE public.materials m SET sort_order = r.rn FROM ranked r WHERE m.id = r.id;
