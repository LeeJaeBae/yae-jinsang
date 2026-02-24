-- shops 테이블에 프로필 컬럼 추가
alter table shops add column if not exists region text;
alter table shops add column if not exists category text;
