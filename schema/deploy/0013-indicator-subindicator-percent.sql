-- Deploy omlpi:0013-indicator-subindicator-percent to pg
-- requires: 0012-random-indicator-cache

BEGIN;

alter table subindicator_locale rename to subindicator_locale_old;
alter table subindicator rename to subindicator_old;
alter index subindicator_locale_subindicator_id_indicator_id_locale_id__key
  rename to subindicator_locale_subindicator_old_id_indicator_id_locale_id__key;
alter index idx_subindicator_locale_year
  rename to idx_subindicator_locale_old_year;

-- Subindicator
create table subindicator (
  id integer generated by default as identity not null,
  indicator_id int not null references indicator(id),
  description text not null,
  classification text not null,
  is_percentage boolean,
  is_big_number boolean,
  primary key(id, indicator_id)
);

-- Subindicator locale
create table subindicator_locale (
  id integer generated by default as identity primary key,
  indicator_id integer NOT NULL,
  subindicator_id integer NOT NULL,
  locale_id integer NOT NULL references locale(id),
  year integer NOT NULL,
  value_relative text,
  value_absolute text,
  foreign key (indicator_id, subindicator_id) REFERENCES subindicator(indicator_id, id)
);

alter table only subindicator_locale
  add constraint subindicator_locale_subindicator_id_indicator_id_locale_id__key unique (subindicator_id, indicator_id, locale_id, year);

create index idx_subindicator_locale_year on subindicator_locale using gin (indicator_id, subindicator_id, locale_id, year);

-- Repopulate data
insert into subindicator (id, indicator_id, description, classification, is_percentage, is_big_number)
select
  s.id,
  i.id,
  s.description,
  s.classification,
  s.is_percentage,
  s.is_big_number
from subindicator_old s
cross join indicator i;

insert into subindicator_locale (indicator_id, subindicator_id, locale_id, year, value_relative, value_absolute)
select
  indicator_id,
  subindicator_id,
  locale_id,
  year,
  value_relative,
  value_absolute
from subindicator_locale_old;

drop table subindicator_locale_old cascade;
drop table subindicator_old;

COMMIT;
