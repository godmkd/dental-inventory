-- ============================================================
-- 牙材採購系統 — 完整資料庫結構
-- 執行順序：依序從上到下，在 Supabase SQL Editor 貼上執行
-- ============================================================


-- ==================== STEP 1：主要資料表 ====================

-- 清除舊表（首次建立時使用，已有資料請跳過）
-- DROP TABLE IF EXISTS inventory_logs CASCADE;
-- DROP TABLE IF EXISTS materials CASCADE;
-- DROP TABLE IF EXISTS suppliers CASCADE;

-- 診所
CREATE TABLE IF NOT EXISTS public.clinics (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL,
  address     TEXT DEFAULT '',
  phone       TEXT DEFAULT '',
  notes       TEXT DEFAULT '',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 使用者
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  TEXT DEFAULT '',
  role          TEXT NOT NULL DEFAULT 'clinic_manager'
                  CHECK (role IN ('owner', 'admin', 'clinic_manager')),
  clinic_id     BIGINT REFERENCES public.clinics(id) ON DELETE SET NULL,
  line_user_id  TEXT DEFAULT '',
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 品項類別
CREATE TABLE IF NOT EXISTS public.categories (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  sort_order  INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 廠商
CREATE TABLE IF NOT EXISTS public.suppliers (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        TEXT NOT NULL,
  contact     TEXT DEFAULT '',
  phone       TEXT DEFAULT '',
  notes       TEXT DEFAULT '',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 品項（全診所共用）
CREATE TABLE IF NOT EXISTS public.materials (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name         TEXT NOT NULL,
  category_id  BIGINT REFERENCES public.categories(id) ON DELETE SET NULL,
  spec         TEXT DEFAULT '',
  unit         TEXT DEFAULT '個',
  order_unit   TEXT DEFAULT '',
  unit_ratio   DECIMAL(10,2) DEFAULT 1,
  image_url    TEXT DEFAULT '',
  supplier_id  BIGINT REFERENCES public.suppliers(id) ON DELETE SET NULL,
  unit_price   DECIMAL(10,2) DEFAULT 0,
  notes        TEXT DEFAULT '',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 各診所庫存
CREATE TABLE IF NOT EXISTS public.clinic_inventory (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clinic_id     BIGINT NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  material_id   BIGINT NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,
  current_stock INT DEFAULT 0,
  safety_stock  INT DEFAULT 5,
  UNIQUE(clinic_id, material_id)
);

-- 庫存異動紀錄
CREATE TABLE IF NOT EXISTS public.inventory_logs (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clinic_id      BIGINT REFERENCES public.clinics(id) ON DELETE CASCADE,
  material_id    BIGINT REFERENCES public.materials(id) ON DELETE CASCADE,
  type           TEXT NOT NULL CHECK (type IN ('in', 'out', 'receive')),
  quantity       INT NOT NULL,
  operator_id    UUID REFERENCES auth.users(id),
  operator_name  TEXT DEFAULT '',
  notes          TEXT DEFAULT '',
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 叫貨單
CREATE TABLE IF NOT EXISTS public.orders (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  status        TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered')),
  created_by    UUID REFERENCES auth.users(id),
  confirmed_by  UUID REFERENCES auth.users(id),
  total_amount  DECIMAL(12,2) DEFAULT 0,
  notes         TEXT DEFAULT '',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at  TIMESTAMPTZ,
  shipped_at    TIMESTAMPTZ,
  delivered_at  TIMESTAMPTZ
);

-- 叫貨明細
CREATE TABLE IF NOT EXISTS public.order_items (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id            BIGINT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  material_id         BIGINT NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,
  clinic_id           BIGINT NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  quantity            INT NOT NULL,
  unit_price          DECIMAL(10,2) DEFAULT 0,
  custom_price        DECIMAL(10,2),
  is_custom_price     BOOLEAN DEFAULT false,
  item_status         TEXT NOT NULL DEFAULT 'pending'
                        CHECK (item_status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
  actual_ordered_qty  INT DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 出貨/到貨確認
CREATE TABLE IF NOT EXISTS public.delivery_confirmations (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id      BIGINT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  clinic_id     BIGINT NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed')),
  confirmed_by  UUID REFERENCES auth.users(id),
  confirmed_at  TIMESTAMPTZ,
  notes         TEXT DEFAULT ''
);

-- 角色
CREATE TABLE IF NOT EXISTS public.roles (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          TEXT NOT NULL UNIQUE,
  display_name  TEXT NOT NULL,
  permissions   JSONB DEFAULT '{}',
  is_system     BOOLEAN DEFAULT false,
  sort_order    INT DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 共用設定（泡泡版面位置等）
CREATE TABLE IF NOT EXISTS public.app_settings (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL DEFAULT '{}',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 教學文章
CREATE TABLE IF NOT EXISTS public.tutorials (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  content     TEXT,
  images      JSONB NOT NULL DEFAULT '[]',
  clinic_id   INTEGER REFERENCES public.clinics(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  author      TEXT
);


-- ==================== STEP 2：user_profiles 加 role_id ====================

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS role_id BIGINT REFERENCES public.roles(id);


-- ==================== STEP 3：Row Level Security ====================

ALTER TABLE public.clinics               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinic_inventory      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_logs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_confirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tutorials             ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated access" ON public.clinics               FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.user_profiles         FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.categories            FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.suppliers             FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.materials             FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.clinic_inventory      FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.inventory_logs        FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.orders                FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.order_items           FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.delivery_confirmations FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Authenticated access" ON public.roles                 FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "app_settings_access"  ON public.app_settings          FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "tutorials_access"     ON public.tutorials             FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ==================== STEP 4：自動更新 updated_at ====================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER materials_updated_at
  BEFORE UPDATE ON public.materials
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ==================== STEP 5：預設角色 ====================

INSERT INTO public.roles (name, display_name, permissions, is_system, sort_order) VALUES
  ('system_admin', '系統管理員',
   '{"all":true}',
   true, 0),
  ('admin', '總管理者',
   '{"manage_materials":true,"manage_categories":true,"manage_suppliers":true,"view_all_inventory":true,"view_prices":true,"manage_orders":true,"ship_orders":true}',
   false, 1),
  ('clinic_manager', '診所管理者',
   '{"view_own_inventory":true,"daily_changes":true,"create_orders":true,"receive_orders":true}',
   false, 2)
ON CONFLICT (name) DO NOTHING;


-- ==================== STEP 6：遷移舊 role 欄位到 role_id ====================
-- （僅在已有舊資料時需要執行）

UPDATE public.user_profiles
  SET role_id = (SELECT id FROM public.roles WHERE name = 'system_admin')
  WHERE role = 'owner' AND role_id IS NULL;

UPDATE public.user_profiles
  SET role_id = (SELECT id FROM public.roles WHERE name = 'admin')
  WHERE role = 'admin' AND role_id IS NULL;

UPDATE public.user_profiles
  SET role_id = (SELECT id FROM public.roles WHERE name = 'clinic_manager')
  WHERE role = 'clinic_manager' AND role_id IS NULL;
