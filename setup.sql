-- 牙材管理系統 資料庫結構
-- 在 Supabase Dashboard → SQL Editor 裡執行

-- 1. 牙材品項
CREATE TABLE materials (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT DEFAULT '',
  spec TEXT DEFAULT '',
  unit TEXT DEFAULT '個',
  safety_stock INT DEFAULT 5,
  current_stock INT DEFAULT 0,
  supplier TEXT DEFAULT '',
  unit_price DECIMAL(10,2) DEFAULT 0,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 進出紀錄
CREATE TABLE inventory_logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  material_id BIGINT REFERENCES materials(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('in', 'out')),
  quantity INT NOT NULL,
  operator TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 供應商
CREATE TABLE suppliers (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  contact TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 開啟 Row Level Security (RLS) 但允許匿名存取
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

-- 允許所有人讀寫（簡單版，之後可加登入限制）
CREATE POLICY "Allow all" ON materials FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON inventory_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON suppliers FOR ALL USING (true) WITH CHECK (true);

-- 5. 自動更新 updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER materials_updated_at
  BEFORE UPDATE ON materials
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 6. 插入一些測試資料
INSERT INTO materials (name, category, spec, unit, safety_stock, current_stock, supplier, unit_price) VALUES
  ('樹脂', '填補材料', 'A2色', '支', 5, 12, '3M', 850),
  ('根管銼', '根管治療', '25mm #15', '支', 10, 25, 'Dentsply', 120),
  ('印模材', '印模材料', '標準型', '包', 3, 8, 'GC', 650),
  ('棉捲', '耗材', '標準', '包', 20, 45, '一般供應商', 35),
  ('手套', '耗材', 'M號', '盒', 10, 15, '一般供應商', 180);
