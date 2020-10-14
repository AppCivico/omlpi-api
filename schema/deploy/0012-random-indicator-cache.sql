-- Deploy omlpi:0012-random-indicator-cache to pg
-- requires: 0011-add-indexes

BEGIN;

create materialized view random_indicator_cache as
      WITH max_year AS (
        SELECT MAX(year.max) AS year
        FROM (
          SELECT MAX(year)
          FROM indicator_locale
          UNION SELECT MAX(year)
          FROM subindicator_locale
        ) year
      )
      SELECT
        locale.id,
        CASE
          WHEN locale.type = 'city' THEN CONCAT(locale.name, ', ', state.uf)
          ELSE locale.name
        END AS name,
        locale.type,
        locale.latitude,
        locale.longitude,
        (
          SELECT JSON_AGG("all".result)
          FROM (
            SELECT ROW_TO_JSON("row") result
            FROM (
              SELECT
                indicator.id,
                indicator.description,
                indicator.base,
                indicator.concept,
                indicator.is_percentage,
                ROW_TO_JSON(area.*) AS area,
                (
                  SELECT JSON_BUILD_OBJECT(
                    'year', indicator_locale.year,
                    'value_relative', indicator_locale.value_relative,
                    'value_absolute', indicator_locale.value_absolute
                  )
                  FROM indicator_locale
                    WHERE indicator_locale.indicator_id = indicator.id
                      AND indicator_locale.locale_id    = locale.id
                      AND indicator_locale.year         = ( SELECT year FROM max_year )
                  ORDER BY indicator_locale.year DESC
                  LIMIT 1
                ) AS values
              FROM indicator
              JOIN area
                ON area.id = indicator.area_id
              JOIN indicator_locale
                ON indicator.id = indicator_locale.indicator_id
                  AND indicator_locale.locale_id = locale.id
              WHERE indicator.id IN (105, 208, 315)
              -- WHERE indicator.id IN (
              --   SELECT random_pick(area_a1), random_pick(area_a2), random_pick(area_a3)
              --   FROM random_locale_indicator
              --   WHERE random_locale_indicator.locale_id = locale.id
              -- )
                AND indicator_locale.year = ( SELECT year FROM max_year )
              ORDER BY indicator.id
            ) AS "row"
          ) AS "all"
        ) AS indicators
      FROM locale
      LEFT JOIN city
        ON locale.type = 'city' AND locale.id = city.id
      LEFT JOIN state
        ON locale.type = 'city' AND city.state_id = state.id
      WHERE locale.id = 0
        OR ( EXISTS ( SELECT 1 FROM random_locale_indicator WHERE random_locale_indicator.locale_id = locale.id) )
      ORDER BY locale.id;

COMMIT;
