-- Deploy omlpi:0002-locale-latlong to pg
-- requires: 0001-data

BEGIN;

ALTER TABLE locale ADD COLUMN latitude FLOAT(8), ADD COLUMN longitude FLOAT(8);
ALTER TABLE city ADD COLUMN latitude FLOAT(8), ADD COLUMN longitude FLOAT(8), ADD COLUMN capital BOOLEAN;
ALTER TABLE state ADD COLUMN latitude FLOAT(8), ADD COLUMN longitude FLOAT(8);

UPDATE locale
SET
  latitude = city.latitude,
  longitude = city.longitude
FROM city
WHERE city.id = locale.id;

UPDATE locale
SET
  latitude  = state.latitude,
  longitude = state.longitude
FROM state
WHERE state.id = locale.id;

COMMIT;
