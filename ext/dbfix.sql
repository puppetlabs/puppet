-- MySQL DB consistency check/fix
--
-- Usage:
-- cat dbfix.sql | mysql -u user -p puppet
--
-- WARNING: perform a database backup before running this script

-- Remove duplicate resources, and keep the latest one
DELETE bad_rows.*
FROM resources AS bad_rows
  INNER JOIN (
    SELECT title,restype,host_id, MAX(id) as max_id
    FROM resources
    GROUP BY title,restype,host_id
    HAVING count(*) > 1
  ) AS good_rows
  ON
    good_rows.title = bad_rows.title AND
    good_rows.restype = bad_rows.restype AND
    good_rows.host_id = bad_rows.host_id AND
    good_rows.max_id <> bad_rows.id;

-- Remove duplicate param_values, and keep the latest one
DELETE bad_rows.*
FROM param_values AS bad_rows
  INNER JOIN (
    SELECT value,param_name_id,resource_id, MAX(id) as max_id
    FROM param_values
    GROUP BY value,param_name_id,resource_id
    HAVING count(*) > 1
  ) AS good_rows
  ON
    good_rows.value = bad_rows.value AND
    good_rows.param_name_id = bad_rows.param_name_id AND
    good_rows.resource_id = bad_rows.resource_id AND
    good_rows.max_id <> bad_rows.id;

-- rewrite param_values that points to duplicated param_names
-- to point to the highest param_name id.
UPDATE
  param_values v
  INNER JOIN
  param_names n
  ON n.id = v.param_name_id
  INNER JOIN
  (
    SELECT name, MAX(id) as max_id
    FROM param_names
    GROUP BY name
    HAVING count(*) > 1
  ) nmax ON n.name = nmax.name
SET
  v.param_name_id = nmax.max_id;

-- Remove duplicate param_names, and keep the latest one
DELETE bad_rows.*
FROM param_names AS bad_rows
  INNER JOIN (
    SELECT name, MAX(id) as max_id
    FROM param_names
    GROUP BY name
    HAVING count(*) > 1
  ) AS good_rows
  ON
    good_rows.name = bad_rows.name AND
    good_rows.max_id <> bad_rows.id;

-- Remove duplicate resource_tags, and keep the highest one
DELETE bad_rows.*
FROM resource_tags AS bad_rows
  INNER JOIN (
    SELECT resource_id,puppet_tag_id, MAX(id) as max_id
    FROM resource_tags
    GROUP BY resource_id,puppet_tag_id
    HAVING count(*) > 1
  ) AS good_rows
  ON
    good_rows.resource_id = bad_rows.resource_id AND
    good_rows.puppet_tag_id = bad_rows.puppet_tag_id AND
    good_rows.max_id <> bad_rows.id;

-- rewrite resource_tags that points to duplicated puppet_tags
-- to point to the highest puppet_tags id.
UPDATE
  resource_tags v
  INNER JOIN
  puppet_tags n
  ON n.id = v.puppet_tag_id
  INNER JOIN
  (
    SELECT name, MAX(id) as max_id
    FROM puppet_tags
    GROUP BY name
    HAVING count(*) > 1
  ) nmax ON n.name = nmax.name
SET
  v.puppet_tag_id = nmax.max_id;

-- Remove duplicate puppet_tags, and keep the highest one
DELETE bad_rows.*
FROM puppet_tags AS bad_rows
  INNER JOIN (
    SELECT name, MAX(id) as max_id
    FROM puppet_tags
    GROUP BY name
    HAVING count(*) > 1
  ) AS good_rows
  ON
    good_rows.name = bad_rows.name AND
    good_rows.max_id <> bad_rows.id;

-- Fix dangling resources
-- note: we use a table to not exceed the number of InnoDB locks if there are two much
-- rows to delete.
-- this is an alternative to: DELETE resources FROM resources r LEFT JOIN hosts h ON h.id=r.host_id WHERE h.id IS NULL;
--
CREATE TABLE resources_c LIKE resources;
INSERT INTO resources_c SELECT r.* FROM resources r INNER JOIN hosts h ON h.id=r.host_id;
RENAME TABLE resources TO resources_old, resources_c TO resources;
DROP TABLE resources_old;

-- Fix dangling param_values
CREATE TABLE param_values_c LIKE param_values;
INSERT INTO param_values_c SELECT v.* FROM param_values v INNER JOIN resources r ON r.id=v.resource_id;
RENAME TABLE param_values TO param_values_old, param_values_c TO param_values;
DROP TABLE param_values_old;

-- Fix dangling resource_tags
CREATE TABLE resource_tags_c LIKE resource_tags;
INSERT INTO resource_tags_c SELECT t.* FROM resource_tags t INNER JOIN resources r ON r.id=t.resource_id;
RENAME TABLE resource_tags TO resource_tags_old, resource_tags_c TO resource_tags;
DROP TABLE resource_tags_old;
