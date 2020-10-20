-- Deploy omlpi:0013-indicator-subindicator-percent to pg
-- requires: 0012-random-indicator-cache

BEGIN;

alter table subindicator_locale rename to subindicator_locale_old;
alter table subindicator rename to subindicator_old;

COMMIT;
