-- ============================================================
-- 牙材採購系統 — 所有 SQL 遷移合集
-- 按執行順序排列，紀錄所有在 Supabase SQL Editor 執行過的內容
-- ============================================================


-- ************************************************************
-- setup.sql — 初始版本（v1）
-- ************************************************************

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

-- 6. 插入測試資料
INSERT INTO materials (name, category, spec, unit, safety_stock, current_stock, supplier, unit_price) VALUES
  ('樹脂', '填補材料', 'A2色', '支', 5, 12, '3M', 850),
  ('根管銼', '根管治療', '25mm #15', '支', 10, 25, 'Dentsply', 120),
  ('印模材', '印模材料', '標準型', '包', 3, 8, 'GC', 650),
  ('棉捲', '耗材', '標準', '包', 20, 45, '一般供應商', 35),
  ('手套', '耗材', 'M號', '盒', 10, 15, '一般供應商', 180);


-- ************************************************************
-- setup-v2.sql — 多診所架構重建
-- ************************************************************

-- 清除舊表
DROP TABLE IF EXISTS inventory_logs CASCADE;
DROP TABLE IF EXISTS materials CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;

-- 1. 診所
CREATE TABLE clinics (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 使用者角色
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT DEFAULT '',
  role TEXT NOT NULL DEFAULT 'clinic_manager' CHECK (role IN ('owner', 'admin', 'clinic_manager')),
  clinic_id BIGINT REFERENCES clinics(id) ON DELETE SET NULL,
  line_user_id TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 品項類別
CREATE TABLE categories (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 廠商
CREATE TABLE suppliers (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  contact TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. 品項（全診所共用）
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

-- 6. 各診所庫存（每診所獨立）
CREATE TABLE clinic_inventory (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clinic_id BIGINT NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
  material_id BIGINT NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  current_stock INT DEFAULT 0,
  safety_stock INT DEFAULT 5,
  UNIQUE(clinic_id, material_id)
);

-- 7. 庫存異動紀錄
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

-- 8. 叫貨單
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

-- 9. 叫貨明細
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

-- 10. 出貨/到貨確認
CREATE TABLE delivery_confirmations (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  clinic_id BIGINT NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed')),
  confirmed_by UUID REFERENCES auth.users(id),
  confirmed_at TIMESTAMPTZ
);

-- RLS 政策
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

-- 自動更新 updated_at
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

-- 測試資料
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

INSERT INTO clinic_inventory (clinic_id, material_id, current_stock, safety_stock) VALUES
  (1, 1, 12, 5), (1, 2, 25, 10), (1, 3, 8, 3), (1, 4, 45, 20), (1, 5, 15, 10),
  (2, 1, 5, 5), (2, 2, 10, 10), (2, 3, 3, 3), (2, 4, 20, 20), (2, 5, 8, 10),
  (3, 1, 8, 5), (3, 2, 15, 10), (3, 3, 6, 3), (3, 4, 30, 20), (3, 5, 12, 10);


-- ************************************************************
-- migrate-v3.sql — 補齊 order_items 和 delivery_confirmations 欄位
-- ************************************************************

ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS item_status TEXT NOT NULL DEFAULT 'pending'
  CHECK (item_status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled'));

ALTER TABLE delivery_confirmations
  ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';


-- ************************************************************
-- migrate-v4.sql — 叫貨單位、角色系統、實際叫貨數量
-- ************************************************************

-- 1. materials 加叫貨單位和換算比例
ALTER TABLE materials ADD COLUMN IF NOT EXISTS order_unit TEXT DEFAULT '';
ALTER TABLE materials ADD COLUMN IF NOT EXISTS unit_ratio DECIMAL(10,2) DEFAULT 1;

-- 2. 角色系統改造 — 新增 roles 表
CREATE TABLE IF NOT EXISTS roles (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  permissions JSONB DEFAULT '{}',
  is_system BOOLEAN DEFAULT false,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 預設角色
INSERT INTO roles (name, display_name, permissions, is_system, sort_order) VALUES
  ('system_admin', '系統管理員', '{"all":true}', true, 0),
  ('admin', '總管理者', '{"manage_materials":true,"manage_categories":true,"manage_suppliers":true,"view_all_inventory":true,"view_prices":true,"manage_orders":true,"ship_orders":true}', false, 1),
  ('clinic_manager', '診所管理者', '{"view_own_inventory":true,"daily_changes":true,"create_orders":true,"receive_orders":true}', false, 2)
ON CONFLICT (name) DO NOTHING;

-- 4. RLS for roles
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated access" ON roles FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 5. user_profiles 加 role_id
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS role_id BIGINT REFERENCES roles(id);

-- 6. 遷移現有 role 到 role_id
UPDATE user_profiles SET role_id = (SELECT id FROM roles WHERE name = 'system_admin') WHERE role = 'owner';
UPDATE user_profiles SET role_id = (SELECT id FROM roles WHERE name = 'admin') WHERE role = 'admin';
UPDATE user_profiles SET role_id = (SELECT id FROM roles WHERE name = 'clinic_manager') WHERE role = 'clinic_manager';

-- 7. order_items 加 actual_ordered_qty
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS actual_ordered_qty INT DEFAULT 0;


-- ************************************************************
-- app_settings.sql — 共用設定表
-- ************************************************************

CREATE TABLE IF NOT EXISTS public.app_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_settings_read"
  ON public.app_settings FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "app_settings_upsert"
  ON public.app_settings FOR ALL
  TO authenticated USING (true) WITH CHECK (true);


-- ************************************************************
-- tutorials.sql — 教學文章表
-- ************************************************************

CREATE TABLE IF NOT EXISTS public.tutorials (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  content     TEXT,
  images      JSONB NOT NULL DEFAULT '[]',
  clinic_id   INTEGER REFERENCES public.clinics(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  author      TEXT
);

ALTER TABLE public.tutorials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tutorials_read"
  ON public.tutorials FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "tutorials_write"
  ON public.tutorials FOR ALL
  TO authenticated USING (true) WITH CHECK (true);


-- ************************************************************
-- migrate-v5.sql — 品項和教學加 created_by
-- ************************************************************

ALTER TABLE public.materials
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

ALTER TABLE public.tutorials
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);


-- ************************************************************
-- migrate-v6.sql — 品項加預設安全庫存
-- ************************************************************

ALTER TABLE public.materials
  ADD COLUMN IF NOT EXISTS default_safety_stock INT DEFAULT 5;


-- ************************************************************
-- migrate-v7.sql — 低庫存通知和催貨通知欄位
-- ************************************************************

-- clinic_inventory 加 notify_level（0=未通知, 1=低庫存已通知, 2=半數以下已通知）
ALTER TABLE public.clinic_inventory
  ADD COLUMN IF NOT EXISTS notify_level INT DEFAULT 0;

-- delivery_confirmations 加 rush_notified（每張單只發一次催貨通知）
ALTER TABLE public.delivery_confirmations
  ADD COLUMN IF NOT EXISTS rush_notified BOOLEAN DEFAULT FALSE;


-- ************************************************************
-- migrate-v8.sql — 叫貨範本表
-- ************************************************************

CREATE TABLE IF NOT EXISTS public.order_templates (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL,
  items       JSONB NOT NULL DEFAULT '[]',
  created_by  UUID REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.order_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "order_templates_access" ON public.order_templates
  FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ************************************************************
-- migrate-v9.sql — 類別類型 + 品項多廠商 + 叫貨單廠商欄位
-- ************************************************************

-- 1. 類別加類型（耗材 / 器械）
ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS item_type TEXT DEFAULT 'consumable'
    CHECK (item_type IN ('consumable', 'equipment'));

-- 2. 品項多廠商對照表
CREATE TABLE IF NOT EXISTS public.material_suppliers (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  material_id BIGINT NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,
  supplier_id BIGINT NOT NULL REFERENCES public.suppliers(id) ON DELETE CASCADE,
  unit_price  DECIMAL(10,2) DEFAULT 0,
  is_default  BOOLEAN DEFAULT false,
  notes       TEXT DEFAULT ''
);
ALTER TABLE public.material_suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "material_suppliers_access" ON public.material_suppliers
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 3. 叫貨明細加廠商欄位
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS order_supplier_id BIGINT REFERENCES public.suppliers(id) ON DELETE SET NULL;

-- 4. 把現有 materials 的 supplier_id + unit_price 遷移到 material_suppliers
INSERT INTO public.material_suppliers (material_id, supplier_id, unit_price, is_default)
SELECT id, supplier_id, unit_price, true
FROM public.materials
WHERE supplier_id IS NOT NULL
ON CONFLICT DO NOTHING;


-- ************************************************************
-- migrate-v9b.sql — material_suppliers 加規格/叫貨單位/換算比例
-- ************************************************************

ALTER TABLE public.material_suppliers
  ADD COLUMN IF NOT EXISTS spec       TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS order_unit TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS unit_ratio DECIMAL(10,2) DEFAULT 1;


-- ************************************************************
-- database.sql — 完整資料庫結構（最終狀態參考）
-- 注意：此為所有遷移後的最終結構，不需要重複執行
-- ************************************************************
-- （見 database.sql 檔案）
