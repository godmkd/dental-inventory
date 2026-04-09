-- v13 Migration: 急件標記
-- 在 Supabase SQL Editor 執行

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS is_urgent BOOLEAN DEFAULT FALSE;
