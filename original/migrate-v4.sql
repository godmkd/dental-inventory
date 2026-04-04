-- v4 Migration
-- 在 Supabase SQL Editor 執行

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

-- 5. user_profiles 改 role 為 role_id (保持向下相容，先加欄位)
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS role_id BIGINT REFERENCES roles(id);

-- 6. 遷移現有 role 到 role_id
UPDATE user_profiles SET role_id = (SELECT id FROM roles WHERE name = 'system_admin') WHERE role = 'owner';
UPDATE user_profiles SET role_id = (SELECT id FROM roles WHERE name = 'admin') WHERE role = 'admin';
UPDATE user_profiles SET role_id = (SELECT id FROM roles WHERE name = 'clinic_manager') WHERE role = 'clinic_manager';

-- 7. order_items 加 actual_ordered_qty（實際已叫貨數量記錄用）
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS actual_ordered_qty INT DEFAULT 0;
