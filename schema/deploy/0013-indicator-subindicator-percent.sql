-- Deploy omlpi:0013-indicator-subindicator-percent to pg
-- requires: 0012-random-indicator-cache

BEGIN;

alter table subindicator_locale rename to subindicator_locale_old;
alter table subindicator rename to subindicator_old;

-- Subindicator
create table subindicator (
  id integer not null,
  indicator_id int not null references indicator(id),
  description text not null,
  classification text not null,
  is_percentage boolean,
  is_big_number boolean
);

alter table only subindicator
  add constraint subindicator_pkey primary key (id, indicator_id);

-- Subindicator locale
create table subindicator_locale (
  id integer generated by default as identity primary key,
  indicator_id integer NOT NULL references indicator(id),
  subindicator_id integer NOT NULL references subindicator(id),
  locale_id integer NOT NULL,
  year integer NOT NULL,
  value_relative text,
  value_absolute text
);

alter table only subindicator_locale
  add constraint subindicator_locale_pkey primary key (id);

alter table only subindicator_locale
    add constraint subindicator_locale_subindicator_id_indicator_id_locale_id__key unique (subindicator_id, indicator_id, locale_id, year);

create index idx_subindicator_locale_year on subindicator_locale using gin (indicator_id, subindicator_id, locale_id, year);

alter table only subindicator_locale
    add constraint subindicator_locale_indicator_id_fkey foreign key (indicator_id) references indicator(id);

alter table only subindicator_locale
    add constraint subindicator_locale_locale_id_fkey foreign key (locale_id) references locale(id);

alter table only subindicator_locale
    add constraint subindicator_locale_subindicator_id_fkey foreign key (subindicator_id) references subindicator(id);

COMMIT;
