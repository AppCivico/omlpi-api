WITH random_data AS (
  SELECT
    *
    -- ARRAY_AGG(random_indicator_id) AS random_indicators,
    -- ARRAY_INTERSECT_AGG(result.locales) AS local
    --(
    --  SELECT *
    --  FROM UNNEST(ARRAY_INTERSECT_AGG(result.locales))
    --  ORDER BY RANDOM()
    --  LIMIT 1
    --) AS random_locale
  FROM
    (
      SELECT
        y.*,
        ARRAY_AGG(indicator_locale.locale_id) AS locales
      FROM (
        SELECT
          area_id,
          x.indicators
          -- ( SELECT * FROM unnest(x.indicators) ORDER BY RANDOM() LIMIT 1 ) AS random_indicator_id
        select x.r, array_agg(x.a1) as area_a1, array_agg(x.a2) as area_a2,array_agg(x.a3) as area_a3 from (
        SELECT a1.id, a1.indicator_id, a2.indicator_id, a3.indicator_id, x.locale_id
        FROM (
          SELECT
            indicator.area_id,
            indicator_locale.indicator_id,
            indicator_locale.locale_id
          FROM indicator_locale
          JOIN indicator
            ON indicator.id = indicator_locale.indicator_id
          JOIN indicator_locale il2
            ON il2.indicator_id = indicator_locale.indicator_id
              AND il2.locale_id = 1
              AND il2.year = 2019
          JOIN locale
            ON locale.id = indicator_locale.locale_id
          WHERE locale.type = 'city'
            AND indicator_locale.year = 2019  and indicator_locale.indicator_id=7
        ) x
        LEFT JOIN indicator i1
          ON i1.id = x.indicator_id
            AND i1.area_id = 1
        LEFT JOIN indicator_locale a1
          ON a1.locale_id = x.locale_id AND a1.indicator_id =  i1.id
        LEFT JOIN indicator i2
          ON i2.id = x.indicator_id
            AND i2.area_id = 2
        LEFT JOIN indicator_locale a2
          ON a2.locale_id = x.locale_id AND a2.indicator_id =  i2.id
        LEFT JOIN indicator i3
          ON i3.id = x.indicator_id
            AND i3.area_id = 3
        LEFT JOIN indicator_locale a3
          ON a3.locale_id = x.locale_id AND a3.indicator_id =  i3.id
      ) y
      JOIN indicator_locale
        ON indicator_locale.indicator_id = y.random_indicator_id
      JOIN locale
        ON indicator_locale.locale_id = locale.id AND locale.type = 'city'
      GROUP BY y.area_id, y.random_indicator_id
    ) result
)
SELECT * FROM random_data;








SELECT
  -- data.r AS locale_id
  data.*
FROM
(
  SELECT
    x.r,
    array_agg(x.a1) FILTER (WHERE x.a1 IS NOT NULL) as area_a1,
    array_agg(x.a2) FILTER (WHERE x.a2 IS NOT NULL) as area_a2,
    array_agg(x.a3) FILTER (WHERE x.a3 IS NOT NULL) as area_a3
    FROM (
      SELECT
        a1.indicator_id as a1,
        a2.indicator_id as a2, a3.
        indicator_id as a3,
        x.locale_id as r
          FROM (
            SELECT
              indicator.area_id,
              indicator_locale.indicator_id,
              indicator_locale.locale_id
            FROM indicator_locale
            JOIN indicator
              ON indicator.id = indicator_locale.indicator_id
            JOIN indicator_locale il2
              ON il2.indicator_id = indicator_locale.indicator_id
                AND il2.locale_id = 1
                AND il2.year = 2019
            JOIN locale
              ON locale.id = indicator_locale.locale_id
            WHERE locale.type = 'city'
              AND indicator_locale.year = 2019
          ) x
          LEFT JOIN indicator i1
            ON i1.id = x.indicator_id
              AND i1.area_id = 1
          LEFT JOIN indicator_locale a1
            ON a1.locale_id = x.locale_id AND a1.indicator_id =  i1.id
          LEFT JOIN indicator i2
            ON i2.id = x.indicator_id
              AND i2.area_id = 2
          LEFT JOIN indicator_locale a2
            ON a2.locale_id = x.locale_id AND a2.indicator_id =  i2.id
          LEFT JOIN indicator i3
            ON i3.id = x.indicator_id
              AND i3.area_id = 3
          LEFT JOIN indicator_locale a3
            ON a3.locale_id = x.locale_id AND a3.indicator_id =  i3.id
    ) x
    GROUP BY x.r
) data
WHERE data.area_a1 IS NOT NULL
  AND data.area_a2 IS NOT NULL
  AND data.area_a3 IS NOT NULL
;