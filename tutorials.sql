-- 新增 tutorials 資料表（教學文章，所有登入使用者可讀）
-- 請在 Supabase Dashboard > SQL Editor 貼上並執行

CREATE TABLE IF NOT EXISTS public.tutorials (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  content     TEXT,
  images      JSONB NOT NULL DEFAULT '[]',
  clinic_id   INTEGER REFERENCES public.clinics(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  author      TEXT
);

-- 開啟 Row Level Security
ALTER TABLE public.tutorials ENABLE ROW LEVEL SECURITY;

-- 所有登入使用者可讀取
CREATE POLICY "tutorials_read"
  ON public.tutorials FOR SELECT
  TO authenticated USING (true);

-- 所有登入使用者可寫入（前端用 manage_materials 權限控管）
CREATE POLICY "tutorials_write"
  ON public.tutorials FOR ALL
  TO authenticated USING (true) WITH CHECK (true);
