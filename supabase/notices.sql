-- 공지사항 테이블
create table notices (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  category text default '공지',  -- 공지, 업데이트, 이벤트, 점검
  is_pinned boolean default false,
  created_at timestamptz default now()
);

-- 누구나 읽기 가능
alter table notices enable row level security;
create policy "notices_public_read" on notices for select using (true);

-- 인덱스
create index idx_notices_created on notices(created_at desc);
create index idx_notices_pinned on notices(is_pinned desc, created_at desc);
