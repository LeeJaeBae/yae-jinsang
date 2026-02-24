-- 태그에 전화번호 끝 4자리 저장
alter table tags add column if not exists phone_last4 text;
