-- v8 Migration: 叫貨範本
-- 在 Supabase SQL Editor 執行

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
