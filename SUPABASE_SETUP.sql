-- SUPABASE_SETUP.sql
-- گردش یک پرونده با یک لینک ثابت: بازرس <-> کارشناس <-> پزشک
-- چند شاغل در یک form_data.people ذخیره می‌شوند.

create extension if not exists pgcrypto;
grant usage on schema public to anon, authenticated;

create table if not exists public.healthhouse_cases (
  id uuid primary key default gen_random_uuid(),
  access_code text not null unique,
  form_data jsonb not null default '{}'::jsonb,
  status text not null default 'آماده ارسال',
  assigned_role text,
  assigned_name text,
  last_edited_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists healthhouse_cases_access_code_idx on public.healthhouse_cases(access_code);
alter table public.healthhouse_cases enable row level security;
revoke all on table public.healthhouse_cases from anon, authenticated;

create or replace function public.healthhouse_create_case_public(
  p_form_data jsonb,
  p_status text default 'آماده ارسال',
  p_assigned_role text default null,
  p_assigned_name text default null,
  p_last_edited_by text default null
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare v_id uuid := gen_random_uuid(); v_code text;
begin
  loop
    v_code := upper(substr(encode(gen_random_bytes(8),'hex'),1,8));
    exit when not exists (select 1 from public.healthhouse_cases where access_code=v_code);
  end loop;
  insert into public.healthhouse_cases(id,access_code,form_data,status,assigned_role,assigned_name,last_edited_by)
  values(v_id,v_code,coalesce(p_form_data,'{}'::jsonb),coalesce(p_status,'آماده ارسال'),p_assigned_role,p_assigned_name,p_last_edited_by);
  return jsonb_build_object('id',v_id,'access_code',v_code,'ok',true);
end; $$;

drop function if exists public.healthhouse_update_case_public(uuid,text,jsonb,text,text,text,text);
create or replace function public.healthhouse_update_case_public(
  p_case_id uuid,
  p_access_code text,
  p_form_data jsonb,
  p_status text default null,
  p_assigned_role text default null,
  p_assigned_name text default null,
  p_last_edited_by text default null
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare v_found boolean := false;
begin
  update public.healthhouse_cases
  set form_data=coalesce(p_form_data,'{}'::jsonb),
      status=coalesce(p_status,status),
      assigned_role=coalesce(p_assigned_role,assigned_role),
      assigned_name=coalesce(p_assigned_name,assigned_name),
      last_edited_by=coalesce(p_last_edited_by,last_edited_by),
      updated_at=now()
  where id=p_case_id and access_code=p_access_code;
  v_found := found;
  return jsonb_build_object('ok',v_found,'updated',v_found,'id',p_case_id);
end; $$;

create or replace function public.healthhouse_get_case_public(p_case_id uuid,p_access_code text)
returns jsonb language plpgsql security definer set search_path=public
as $$
declare v_row public.healthhouse_cases;
begin
  select * into v_row from public.healthhouse_cases where id=p_case_id and access_code=p_access_code limit 1;
  if not found then return null; end if;
  return jsonb_build_object('id',v_row.id,'access_code',v_row.access_code,'form_data',v_row.form_data,
    'status',v_row.status,'assigned_role',v_row.assigned_role,'assigned_name',v_row.assigned_name,
    'last_edited_by',v_row.last_edited_by,'created_at',v_row.created_at,'updated_at',v_row.updated_at);
end; $$;

create or replace function public.healthhouse_delete_case_public(p_case_id uuid,p_access_code text)
returns boolean language plpgsql security definer set search_path=public
as $$
begin
  delete from public.healthhouse_cases where id=p_case_id and access_code=p_access_code;
  return found;
end; $$;

grant execute on function public.healthhouse_create_case_public(jsonb,text,text,text,text) to anon, authenticated;
grant execute on function public.healthhouse_update_case_public(uuid,text,jsonb,text,text,text,text) to anon, authenticated;
grant execute on function public.healthhouse_get_case_public(uuid,text) to anon, authenticated;
grant execute on function public.healthhouse_delete_case_public(uuid,text) to anon, authenticated;
