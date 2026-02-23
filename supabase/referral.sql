-- 리퍼럴 테이블
create table referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_shop_id uuid not null references shops(id) on delete cascade,
  referred_shop_id uuid not null references shops(id) on delete cascade,
  referral_code text not null,
  created_at timestamptz default now(),
  unique(referred_shop_id)
);

-- shops 테이블에 추천코드 컬럼 추가
alter table shops add column if not exists referral_code text unique;

-- 인덱스
create index idx_referrals_referrer on referrals(referrer_shop_id);
create index idx_referrals_code on referrals(referral_code);
create index idx_shops_referral_code on shops(referral_code);

-- RLS
alter table referrals enable row level security;
create policy "referrals_read_own" on referrals for select using (referrer_shop_id = auth.uid()::uuid);
create policy "referrals_insert" on referrals for insert with check (referred_shop_id = auth.uid()::uuid);

-- 추천코드 자동 생성 (가입 시 자동 부여)
create or replace function generate_referral_code()
returns trigger as $$
begin
  new.referral_code := 'YJ-' || upper(substr(md5(random()::text), 1, 4));
  return new;
end;
$$ language plpgsql;

create trigger set_referral_code
  before insert on shops
  for each row
  when (new.referral_code is null)
  execute function generate_referral_code();

-- 기존 업소에 추천코드 부여
update shops set referral_code = 'YJ-' || upper(substr(md5(random()::text), 1, 4)) where referral_code is null;

-- 추천 적용 함수
create or replace function apply_referral(p_code text, p_new_shop_id uuid)
returns json as $$
declare
  v_referrer_id uuid;
  v_existing uuid;
begin
  select id into v_referrer_id from shops where referral_code = p_code;
  if v_referrer_id is null then
    return json_build_object('success', false, 'error', '유효하지 않은 추천코드');
  end if;

  if v_referrer_id = p_new_shop_id then
    return json_build_object('success', false, 'error', '본인 추천코드는 사용할 수 없습니다');
  end if;

  select id into v_existing from referrals where referred_shop_id = p_new_shop_id;
  if v_existing is not null then
    return json_build_object('success', false, 'error', '이미 추천코드를 사용했습니다');
  end if;

  insert into referrals (referrer_shop_id, referred_shop_id, referral_code)
  values (v_referrer_id, p_new_shop_id, p_code);

  -- 추천인: 구독 1개월 연장
  update shops
  set subscription_until = case
    when subscription_until is null or subscription_until < now()
    then now() + interval '1 month'
    else subscription_until + interval '1 month'
  end
  where id = v_referrer_id;

  return json_build_object('success', true, 'referrer_extended', true, 'message', '추천코드가 적용되었습니다');
end;
$$ language plpgsql security definer;
