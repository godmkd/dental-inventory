-- 牙材集中採購管理系統 v2
-- 先清舊表再建新表
-- 在 Supabase SQL Editor 執行

-- ========== 清除舊表 ==========
DROP TABLE IF EXISTS inventory_logs CASCADE;
DROP TABLE IF EXISTS materials CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;

-- ========== 1. 診所 ==========
CREATE TABLE clinics (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 2. 使用者角色 ==========
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT DEFAULT '',
  role TEXT NOT NULL DEFAULT 'clinic_manager' CHECK (role IN ('owner', 'admin', 'clinic_manager')),
  clinic_id BIGINT REFERENCES clinics(id) ON DELETE SET NULL,
  line_user_id TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 3. 品項類別 ==========
CREATE TABLE categories (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 4. 廠商 ==========
CREATE TABLE suppliers (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  contact TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 5. 品項（全診所共用） ==========
CREATE TABLE materials (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
  spec TEXT DEFAULT '',
  unit TEXT DEFAULT '個',
  image_url TEXT DEFAULT '',
  supplier_id BIGINT REFERENCES suppliers(id) ON DELETE SET NULL,
  unit_price DECIMAL(10,2) DEFAULT 0,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 6. 各診所庫存（每診所獨立） ==========
CREATE TABLE clinic_inventory (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clinic_id BIGINT NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
  material_id BIGINT NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  current_stock INT DEFAULT 0,
  safety_stock INT DEFAULT 5,
  UNIQUE(clinic_id, material_id)
);

-- ========== 7. 庫存異動紀錄 ==========
CREATE TABLE inventory_logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clinic_id BIGINT REFERENCES clinics(id) ON DELETE CASCADE,
  material_id BIGINT REFERENCES materials(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('in', 'out', 'receive')),
  quantity INT NOT NULL,
  operator_id UUID REFERENCES auth.users(id),
  operator_name TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 8. 叫貨單 ==========
CREATE TABLE orders (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered')),
  created_by UUID REFERENCES auth.users(id),
  confirmed_by UUID REFERENCES auth.users(id),
  total_amount DECIMAL(12,2) DEFAULT 0,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at TIMESTAMPTZ,
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ
);

-- ========== 9. 叫貨明細 ==========
CREATE TABLE order_items (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  material_id BIGINT NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  clinic_id BIGINT NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
  quantity INT NOT NULL,
  unit_price DECIMAL(10,2) DEFAULT 0,
  custom_price DECIMAL(10,2),
  is_custom_price BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 10. 出貨/到貨確認 ==========
CREATE TABLE delivery_confirmations (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  clinic_id BIGINT NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed')),
  confirmed_by UUID REFERENCES auth.users(id),
  confirmed_at TIMESTAMPTZ
);

-- ========== RLS 政策 ==========
ALTER TABLE clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinic_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_confirmations ENABLE ROW LEVEL SECURITY;

-- 暫時允許所有認證用戶讀寫（之後可依角色細分）
CREATE POLICY "Authenticated access" ON clinics FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON user_profiles FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON categories FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON suppliers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON materials FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON clinic_inventory FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON inventory_logs FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON orders FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON order_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON delivery_confirmations FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ========== 自動更新 updated_at ==========
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

-- ========== 測試資料 ==========
INSERT INTO clinics (name, address, phone) VALUES
  ('總院', '台北市大安區', '02-1234-5678'),
  ('分院A', '台北市信義區', '02-2345-6789'),
  ('分院B', '新北市板橋區', '02-3456-7890');

INSERT INTO categories (name, sort_order) VALUES
  ('填補材料', 1),
  ('根管治療', 2),
  ('印模材料', 3),
  ('耗材', 4),
  ('矯正', 5);

INSERT INTO suppliers (name, contact, phone) VALUES
  ('3M', '王先生', '02-1111-2222'),
  ('Dentsply', '李小姐', '02-3333-4444'),
  ('GC', '陳先生', '02-5555-6666');

INSERT INTO materials (name, category_id, spec, unit, supplier_id, unit_price) VALUES
  ('樹脂', 1, 'A2色', '支', 1, 850),
  ('根管銼', 2, '25mm #15', '支', 2, 120),
  ('印模材', 3, '標準型', '包', 3, 650),
  ('棉捲', 4, '標準', '包', NULL, 35),
  ('手套', 4, 'M號', '盒', NULL, 180);

-- 各診所庫存
INSERT INTO clinic_inventory (clinic_id, material_id, current_stock, safety_stock) VALUES
  (1, 1, 12, 5), (1, 2, 25, 10), (1, 3, 8, 3), (1, 4, 45, 20), (1, 5, 15, 10),
  (2, 1, 5, 5), (2, 2, 10, 10), (2, 3, 3, 3), (2, 4, 20, 20), (2, 5, 8, 10),
  (3, 1, 8, 5), (3, 2, 15, 10), (3, 3, 6, 3), (3, 4, 30, 20), (3, 5, 12, 10);
