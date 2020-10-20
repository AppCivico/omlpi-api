-- Deploy omlpi:0013-indicator-subindicator-percent to pg
-- requires: 0012-random-indicator-cache

BEGIN;

alter table subindicator_locale
  add column is_percentage boolean,
  add column is_big_number boolean;

update subindicator_locale
set
  is_percentage = (
    select subindicator.is_percentage
    from subindicator
    where subindicator.id = subindicator_locale.subindicator_id
  ),
  is_big_number = (
    select subindicator.is_big_number
    from subindicator
    where subindicator.id = subindicator_locale.subindicator_id
  );

alter table subindicator
  drop column is_percentage,
  drop column is_big_number;

alter table subindicator_locale
  alter column is_percentage set not null,
  alter column is_big_number set not null;

COMMIT;
