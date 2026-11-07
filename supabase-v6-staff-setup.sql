-- NICE CAR WASH V6: create the single STAFF01 membership after Auth user creation.
-- Step 1: Supabase Dashboard > Authentication > Users > Add user
-- Email: staff01@nicecarwash.invalid
-- Set a strong password and mark Email Confirmed.
-- Step 2: Run this SQL in Supabase SQL Editor.
DO $$
DECLARE
  staff_uuid uuid;
  branch_uuid uuid := '2b52c65d-cbd7-405a-98d9-666fad041fce';
BEGIN
  SELECT id INTO staff_uuid
  FROM auth.users
  WHERE lower(email)=lower('staff01@nicecarwash.invalid')
  LIMIT 1;

  IF staff_uuid IS NULL THEN
    RAISE EXCEPTION 'STAFF01 Auth user not found. Create it in Authentication > Users first.';
  END IF;

  INSERT INTO public.v6_profiles(user_id,display_name)
  VALUES(staff_uuid,'STAFF01')
  ON CONFLICT(user_id) DO UPDATE SET display_name='STAFF01';

  INSERT INTO public.v6_branch_members(branch_id,user_id,role,active)
  VALUES(branch_uuid,staff_uuid,'staff',true)
  ON CONFLICT(branch_id,user_id)
  DO UPDATE SET role='staff',active=true;
END $$;

-- Verify: should return exactly one STAFF01 row with role=staff and active=true.
SELECT p.display_name,u.email,m.role,m.active,b.name AS branch_name
FROM public.v6_branch_members m
JOIN auth.users u ON u.id=m.user_id
LEFT JOIN public.v6_profiles p ON p.user_id=u.id
JOIN public.branches b ON b.id=m.branch_id
WHERE lower(u.email)=lower('staff01@nicecarwash.invalid');
