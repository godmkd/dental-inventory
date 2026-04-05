-- 新增 app_settings 資料表（共用設定，包含泡泡版面位置）
-- 請在 Supabase Dashboard > SQL Editor 貼上並執行

CREATE TABLE IF NOT EXISTS public.app_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 開啟 Row Level Security
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 所有登入使用者可讀取
CREATE POLICY "app_settings_read"
  ON public.app_settings FOR SELECT
  TO authenticated USING (true);

-- 所有登入使用者可寫入（前端用 arrange_layout 權限控管，不在 DB 層限制）
CREATE POLICY "app_settings_upsert"
  ON public.app_settings FOR ALL
  TO authenticated USING (true) WITH CHECK (true);
