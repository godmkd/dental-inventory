-- v3 Migration: 補齊 order_items.item_status 和 delivery_confirmations.notes 欄位
-- 在 Supabase SQL Editor 執行

-- 1. order_items 新增 item_status 欄位（個別品項狀態）
ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS item_status TEXT NOT NULL DEFAULT 'pending'
  CHECK (item_status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled'));

-- 2. delivery_confirmations 新增 notes 欄位（催貨紀錄等）
ALTER TABLE delivery_confirmations
  ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';
