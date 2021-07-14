-- Deploy omlpi:0019-locale-hide-plan to pg
-- requires: 0018-fix-random-indicator
BEGIN;

ALTER TABLE locales
    ADD COLUMN hide_plan boolean;

COMMIT;

