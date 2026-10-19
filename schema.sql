-- Builder Crew: live build lists volunteers open without an account.
create table if not exists public.crew_assign (
  id text primary key,
  project text not null,
  project_name text,
  title text,
  items jsonb not null default '[]'::jsonb,
  done jsonb not null default '{}'::jsonb,
  active jsonb,
  notes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.crew_assign enable row level security;
-- no table policies: the public key can only use the functions below, and only with a list's unguessable id
create or replace function public.crew_get(aid text) returns json language sql security definer set search_path=public as $$
  select json_build_object('id',id,'title',title,'project_name',project_name,'items',items,'done',done,'active',active,'updated_at',updated_at) from crew_assign where id=aid $$;
create or replace function public.crew_tick(aid text, k text, d boolean, who text) returns void language plpgsql security definer set search_path=public as $$
begin
  if length(k)>200 or length(coalesce(who,''))>40 then raise exception 'too long'; end if;
  if not exists (select 1 from crew_assign where id=aid and items @> jsonb_build_array(jsonb_build_object('key',k))) then raise exception 'no such item'; end if;
  if d then update crew_assign set done = done || jsonb_build_object(k, jsonb_build_object('at', (extract(epoch from now())*1000)::bigint, 'by', left(coalesce(who,'Builder'),40))), updated_at=now() where id=aid;
  else update crew_assign set done = done - k, updated_at=now() where id=aid; end if;
end $$;
create or replace function public.crew_here(aid text, k text, who text) returns void language sql security definer set search_path=public as $$
  update crew_assign set active=jsonb_build_object('item',left(k,200),'who',left(coalesce(who,'Builder'),40),'at',(extract(epoch from now())*1000)::bigint), updated_at=now() where id=aid $$;
create or replace function public.crew_note(aid text, txt text, who text) returns void language sql security definer set search_path=public as $$
  update crew_assign set notes = notes || jsonb_build_array(jsonb_build_object('txt',left(txt,600),'who',left(coalesce(who,'Builder'),40),'at',(extract(epoch from now())*1000)::bigint)), updated_at=now()
  where id=aid and jsonb_array_length(notes) < 200 $$;
revoke all on public.crew_assign from anon, authenticated;
grant execute on function public.crew_get(text), public.crew_tick(text,text,boolean,text), public.crew_here(text,text,text), public.crew_note(text,text,text) to anon;
