-- NICE CAR WASH V6: repair only the existing STAFF01 branch membership.
-- Safe to run more than once. Does not create/delete Auth users or touch legacy POS data.
DO $$
DECLARE
  staff_uuid uuid;
  branch_uuid uuid := '2b52c65d-cbd7-405a-98d9-666fad041fce';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.branches WHERE id = branch_uuid) THEN
    RAISE EXCEPTION 'Kota Tinggi branch ID not found. No changes made.';
  END IF;

  SELECT id INTO staff_uuid
  FROM auth.users
  WHERE lower(email) = lower('staff01@nicecarwash.invalid')
  LIMIT 1;

  IF staff_uuid IS NULL THEN
    RAISE EXCEPTION 'STAFF01 Auth account not found. No changes made; do not create a duplicate account.';
  END IF;

  INSERT INTO public.v6_profiles(user_id, display_name)
  VALUES (staff_uuid, 'STAFF01')
  ON CONFLICT (user_id)
  DO UPDATE SET display_name = EXCLUDED.display_name;

  INSERT INTO public.v6_branch_members(branch_id, user_id, role, active)
  VALUES (branch_uuid, staff_uuid, 'staff', true)
  ON CONFLICT (branch_id, user_id)
  DO UPDATE SET role = 'staff', active = true;
END $$;

-- Verification: expect exactly one row: role=staff, active=true, branch_name=Nice Car Wash Kota Tinggi.
SELECT
  u.email,
  m.user_id,
  m.branch_id,
  m.role,
  m.active,
  b.name AS branch_name
FROM auth.users u
JOIN public.v6_branch_members m ON m.user_id = u.id
JOIN public.branches b ON b.id = m.branch_id
WHERE lower(u.email) = lower('staff01@nicecarwash.invalid');
