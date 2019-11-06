-- Deploy omlpi:0001-data to pg
-- requires: 0000-locales

BEGIN;

CREATE TABLE area (
    id INT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

INSERT INTO area (id, name) VALUES (1, 'Assistência social'), (2, 'Educação'), (3, 'Saúde');

CREATE TABLE indicator (
    id          INT PRIMARY KEY,
    description TEXT NOT NULL UNIQUE,
    area_id     INT NOT NULL REFERENCES area(id),
    base        TEXT
);

CREATE TABLE subindicator_category (
    id INT PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE subindicator (
    id          INT PRIMARY KEY,
    description TEXT NOT NULL UNIQUE,
    subindicator_category_id INT NOT NULL REFERENCES subindicator_category(id)
);

COMMIT;
