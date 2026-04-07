-- v9 Migration: 類別類型 + 品項多廠商 + 叫貨單廠商欄位
-- 在 Supabase SQL Editor 執行

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

-- 3. 叫貨明細加廠商欄位（記錄實際下單廠商）
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS order_supplier_id BIGINT REFERENCES public.suppliers(id) ON DELETE SET NULL;

-- 4. 把現有 materials 的 supplier_id + unit_price 遷移到 material_suppliers（預設廠商）
INSERT INTO public.material_suppliers (material_id, supplier_id, unit_price, is_default)
SELECT id, supplier_id, unit_price, true
FROM public.materials
WHERE supplier_id IS NOT NULL
ON CONFLICT DO NOTHING;
