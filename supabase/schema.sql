-- 얘진상 DB 스키마

-- 1. 업소 (가입 단위)
create table shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_phone text not null unique,
  password_hash text not null,
  is_active boolean default true,
  subscription_until timestamptz,
  created_at timestamptz default now()
);

-- 2. 진상 태그 (핵심 테이블)
create table tags (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  phone_hash text not null,        -- SHA-256 해시 (원본 번호 저장 안함)
  tag text not null,               -- 폭력, 먹튀, 행패 등
  memo text,                       -- 추가 메모 (본인만 볼 수 있음)
  created_at timestamptz default now()
);

-- 3. 조회 로그 (통계/분석용)
create table lookup_logs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  phone_hash text not null,
  matched boolean default false,
  created_at timestamptz default now()
);

-- 인덱스
create index idx_tags_phone_hash on tags(phone_hash);
create index idx_tags_shop_id on tags(shop_id);
create index idx_lookup_logs_phone_hash on lookup_logs(phone_hash);

-- RLS (Row Level Security)
alter table shops enable row level security;
alter table tags enable row level security;
alter table lookup_logs enable row level security;

-- 정책: 본인 업소 데이터만 CRUD
create policy "shops_own" on shops
  for all using (id = auth.uid()::uuid);

create policy "tags_own_crud" on tags
  for all using (shop_id = auth.uid()::uuid);

-- 정책: 태그 조회는 모든 활성 업소가 가능 (해시 매칭)
create policy "tags_lookup" on tags
  for select using (true);

create policy "logs_own" on lookup_logs
  for all using (shop_id = auth.uid()::uuid);

-- 해시로 진상 조회하는 함수
create or replace function lookup_jinsang(p_hash text)
returns json as $$
  select coalesce(
    json_agg(json_build_object(
      'tag', tag,
      'count', cnt
    )),
    '[]'::json
  )
  from (
    select tag, count(*) as cnt
    from tags
    where phone_hash = p_hash
    group by tag
  ) t;
$$ language sql security definer;
