-- 업소명 공개 동의 컬럼 추가 (기본값: 비공개)
ALTER TABLE shops ADD COLUMN IF NOT EXISTS show_name boolean DEFAULT false;

-- lookup_jinsang RPC 업데이트: 동의한 업소만 이름 반환
CREATE OR REPLACE FUNCTION lookup_jinsang(p_hash text)
RETURNS TABLE(tag text, count bigint, region text, category text, shop_name text) AS $$
  SELECT 
    t.tag,
    COUNT(*)::bigint as count,
    COALESCE(s.region, '미설정') as region,
    COALESCE(s.category, '미설정') as category,
    CASE WHEN s.show_name = true THEN s.name ELSE NULL END as shop_name
  FROM tags t
  JOIN shops s ON s.id = t.shop_id
  WHERE t.phone_hash = p_hash
  GROUP BY t.tag, s.region, s.category, s.show_name, s.name;
$$ LANGUAGE sql SECURITY DEFINER;
