-- v16 Migration: 組織（多租戶）架構
-- 在 Supabase SQL Editor 執行

-- 1. 建立組織表
CREATE TABLE IF NOT EXISTS public.organizations (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT UNIQUE, -- 邀請碼/專屬代碼
  owner_id UUID REFERENCES auth.users(id), -- 組織主管
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "org_access" ON public.organizations
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 2. clinics 加 org_id
ALTER TABLE public.clinics ADD COLUMN IF NOT EXISTS org_id BIGINT REFERENCES public.organizations(id);

-- 3. user_profiles 加 org_id (主要組織) 和 org_role
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS org_id BIGINT REFERENCES public.organizations(id);
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS org_role TEXT DEFAULT 'member'; -- 'org_admin' or 'member'

-- 4. 使用者-組織關聯表（支援跨組織）
CREATE TABLE IF NOT EXISTS public.user_organizations (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  org_id BIGINT NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member', -- 'org_admin' or 'member'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, org_id)
);

ALTER TABLE public.user_organizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_org_access" ON public.user_organizations
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 5. tutorials 加 org_id
ALTER TABLE public.tutorials ADD COLUMN IF NOT EXISTS org_id BIGINT REFERENCES public.organizations(id);

-- 6. 為現有資料建立預設組織
-- INSERT INTO public.organizations (name, code) VALUES ('預設組織', 'DEFAULT');
-- 執行後手動設定 org_id
