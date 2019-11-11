-- Deploy omlpi:0001-data to pg
-- requires: 0000-locales

BEGIN;

CREATE TABLE area (
    id INT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

INSERT INTO area (id, name) VALUES (1, 'Assistência Social'), (2, 'Educação'), (3, 'Saúde');

CREATE TABLE indicator (
    id          INT PRIMARY KEY,
    description TEXT NOT NULL UNIQUE,
    area_id     INT NOT NULL REFERENCES area(id),
    base        TEXT
);

--CREATE TABLE subindicator_category (
--    id INT PRIMARY KEY,
--    name TEXT NOT NULL
--);

CREATE TABLE subindicator (
    id          INT NOT NULL,
    indicator_id INT NOT NULL REFERENCES indicator(id),
    description TEXT NOT NULL,
    classification TEXT NOT NULL,
    PRIMARY KEY(id, indicator_id)
    --subindicator_category_id INT NOT NULL REFERENCES subindicator_category(id)
);

CREATE TABLE data (
    id INT NOT NULL,
    locale_id INT NOT NULL REFERENCES locale(id),
    indicator_id INT NOT NULL REFERENCES indicator(id),
    year INT NOT NULL,
    area_id INT NOT NULL REFERENCES area(id)
);

COMMIT;
