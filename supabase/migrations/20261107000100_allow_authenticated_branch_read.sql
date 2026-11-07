-- NICE CAR WASH V6: allow signed-in users to read branch directory.
-- Limited to SELECT only; this does not grant INSERT, UPDATE, or DELETE.
-- Existing branch rows are preserved.

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON TABLE public.branches TO authenticated;

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read branches" ON public.branches;

CREATE POLICY "Authenticated users can read branches"
ON public.branches
FOR SELECT
TO authenticated
USING (true);
