-- RLS 收緊：app_settings 只有本人能讀寫自己的 key
-- 在 Supabase SQL Editor 執行

-- 1. 刪除舊的寬鬆 policy
DROP POLICY IF EXISTS "app_settings_access" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_read" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_write" ON public.app_settings;

-- 2. 新增收緊的 policy
-- 讀取：只能讀自己的（key 包含自己的 user_id）或共用的（不含 user_id 的 key）
CREATE POLICY "app_settings_read" ON public.app_settings
  FOR SELECT TO authenticated
  USING (
    key NOT LIKE '%_%'
    OR key LIKE '%' || auth.uid()::text || '%'
    OR key IN ('bubble_positions')
  );

-- 寫入：只能寫自己的（key 包含自己的 user_id）或共用的
CREATE POLICY "app_settings_write" ON public.app_settings
  FOR INSERT TO authenticated
  WITH CHECK (
    key LIKE '%' || auth.uid()::text || '%'
    OR key IN ('bubble_positions')
  );

CREATE POLICY "app_settings_update" ON public.app_settings
  FOR UPDATE TO authenticated
  USING (
    key LIKE '%' || auth.uid()::text || '%'
    OR key IN ('bubble_positions')
  );

CREATE POLICY "app_settings_delete" ON public.app_settings
  FOR DELETE TO authenticated
  USING (
    key LIKE '%' || auth.uid()::text || '%'
  );
