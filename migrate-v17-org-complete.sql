-- v17 Migration: 組織完全獨立
-- 在 Supabase SQL Editor 執行

-- 1. organizations 加 mode 欄位
ALTER TABLE public.organizations ADD COLUMN IF NOT EXISTS mode TEXT DEFAULT 'full'; -- 'full' or 'simple'

-- 2. user_organizations 加 role_id 欄位（per org 角色）
ALTER TABLE public.user_organizations ADD COLUMN IF NOT EXISTS role_id BIGINT REFERENCES public.roles(id);

-- 3. materials 加 org_id
ALTER TABLE public.materials ADD COLUMN IF NOT EXISTS org_id BIGINT REFERENCES public.organizations(id);

-- 4. categories 加 org_id
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS org_id BIGINT REFERENCES public.organizations(id);

-- 5. suppliers 加 org_id
ALTER TABLE public.suppliers ADD COLUMN IF NOT EXISTS org_id BIGINT REFERENCES public.organizations(id);

-- 6. orders 加 org_id
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS org_id BIGINT REFERENCES public.organizations(id);

-- 7. roles 加 org_id（角色定義也可以按組織分開，但預設共用）
-- ALTER TABLE public.roles ADD COLUMN IF NOT EXISTS org_id BIGINT REFERENCES public.organizations(id);

-- Done! 現有資料的 org_id 為 NULL，代表「共用/未分配」
-- 建立組織後，到各管理頁面把品項/類別/廠商指定給組織
