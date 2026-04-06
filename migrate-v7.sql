-- v7 Migration: 低庫存通知 once per level, 催貨通知 once per order
-- 在 Supabase SQL Editor 執行

-- 1. clinic_inventory 加 notify_level（0=未通知, 1=低庫存已通知, 2=半數以下已通知）
--    當庫存恢復到安全量以上時，系統會自動重置為 0
ALTER TABLE public.clinic_inventory
  ADD COLUMN IF NOT EXISTS notify_level INT DEFAULT 0;

-- 2. delivery_confirmations 加 rush_notified（每張單只發一次催貨通知）
ALTER TABLE public.delivery_confirmations
  ADD COLUMN IF NOT EXISTS rush_notified BOOLEAN DEFAULT FALSE;
