/******************************************************************************
SILVER LAYER (1): CREATING TABLES
*******************************************************************************
Author:			Igor Mlikota
Date:			03.Oct.2025
MySQL Version:	8.4.6
*******************************************************************************
This script creates the first iteration of all tables in the silver layer,
which are further cleand and adjusted in the scripts 'silver_clean_tables'
and 'silver_create_keys'.

The tables are created using data from the two bronze layer tables
'raw_credits' and 'raw_infos'. The two bronze layer tables have many columns
with JSON entries, which are here unpacked and turned into separate tables.

A total of 20 tables are created, which can be divided into 3 groups:
1. Main Movie Information
	- movie_infos
    - movie_ratings
    - prod_status
2. Cast and Crew
	- people
    - roles
    - genders
    - movie_cast
    - departments
    - jobs
    - movie_crew
3. Additional Movie Information
	- genres
    - movie_genres
    - keywords
    - movie_keywords
    - prod_companies
    - movie_prod_companies
    - countries
    - movie_prod_countries
    - languages
    - movie_spoken_languages
******************************************************************************/


/******************************************************************************
DROP EXISTING TABLES
******************************************************************************/

-- drop tables to avoid errors during re-run
DROP TABLE IF EXISTS movie_infos;
DROP TABLE IF EXISTS movie_ratings;
DROP TABLE IF EXISTS people;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS movie_characters;
DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS jobs;
DROP TABLE IF EXISTS movie_crew;
DROP TABLE IF EXISTS genres;
DROP TABLE IF EXISTS movie_genres;
DROP TABLE IF EXISTS keywords;
DROP TABLE IF EXISTS movie_keywords;
DROP TABLE IF EXISTS prod_companies;
DROP TABLE IF EXISTS movie_prod_companies;
DROP TABLE IF EXISTS countries;
DROP TABLE IF EXISTS movie_prod_countries;
DROP TABLE IF EXISTS languages;
DROP TABLE IF EXISTS movie_spoken_languages;


/******************************************************************************
1. MAIN MOVIE INFORMATION
******************************************************************************/

-- create movie info table
CREATE TABLE movie_infos AS
SELECT
	id AS movie_id,
	title,
    CASE 
        WHEN CAST(release_date AS CHAR) = '0000-00-00' THEN NULL
        ELSE release_date
    END AS release_date,
    runtime,
    overview,
    tagline,
    budget,
    revenue,
    homepage,
    original_language AS original_language_id,
    original_title,
    CASE
		WHEN status = 'Rumored' THEN 0
		WHEN status = 'Released' THEN 1
        WHEN status = 'Post Production' THEN 2
	END AS prod_status_id
FROM raw_infos;

-- create prod_status table to link production status id to production status
CREATE TABLE prod_status
(
	prod_status_id INT,
	prod_status_name VARCHAR(50)
);
INSERT INTO prod_status
VALUES
	(0, 'Rumored'),
    (1, 'Released'),
    (2, 'Post Production');

-- create movie ratings table
CREATE TABLE movie_ratings AS
SELECT
	id AS movie_id,
	popularity,
    vote_average,
    vote_count
FROM raw_infos;


/******************************************************************************
2. CAST AND CREW
******************************************************************************/

-- create people table to store information on cast and crew memebers
CREATE TABLE people AS
SELECT DISTINCT
	people_id,
    people_name,
    gender_id,
    -- flag people as cast members (1), crew members (2) or both (0)
    CASE 
        WHEN SUM(cast) > 0 AND SUM(crew) > 0 THEN 0 
        WHEN SUM(cast) > 0 THEN 1
        WHEN SUM(crew) > 0 THEN 2
    END AS role_id
FROM
(
	/* extract cast members (actors) from JSON column 'cast' in 'raw_credits' 
	   and flag them as cast members */
    SELECT 
		jt1.people_id, 
        jt1.people_name, 
        jt1.gender_id, 
        1 AS cast, 
        0 AS crew
    FROM raw_credits AS c
    CROSS JOIN JSON_TABLE
    (
        c.cast,
        '$[*]' COLUMNS 
        (
            people_id INT PATH '$.id',
            people_name VARCHAR(50) PATH '$.name',
            gender_id INT PATH '$.gender'
        )
    ) AS jt1
    -- unite cast members with crew members (not excluding duplicates)
    UNION
    /* extract crew members from JSON column 'crew' in 'raw_credits' 
	   and flag them as crew members */
    SELECT 
		jt2.people_id, 
        jt2.people_name, 
        jt2.gender_id, 
        0 AS cast, 
        1 AS crew
    FROM raw_credits AS c
    CROSS JOIN JSON_TABLE
    (
        c.crew,
        '$[*]' COLUMNS
        (
            people_id INT PATH '$.id',
            people_name VARCHAR(50) PATH '$.name',
            gender_id INT PATH '$.gender'
        )
    ) AS jt2
) AS combined
-- group people to check if their cast members, crew members or both
GROUP BY people_id, people_name, gender_id;


-- create roles table linking role IDs to role names
CREATE TABLE roles
(
	role_id INT,
	role_name VARCHAR(50)
);
INSERT INTO roles
VALUES
	(0, 'Cast and Crew Member'),
    (1, 'Cast Member'),
    (2, 'Crew Member');
    
    
-- create genders table linking gender IDs to gender names
CREATE TABLE genders
(
	gender_id INT,
	gender_name VARCHAR(50)
);
INSERT INTO genders
VALUES
	(0, 'Not Specified'),
    (1, 'Female'),
    (2, 'Male');


-- create departments table linking department IDs to deparment names
CREATE TABLE departments AS
SELECT
	-- create department IDs
	ROW_NUMBER() OVER () AS department_id,
    t.department_name
FROM
(
    -- extract department names from JSON column 'crew' in 'raw_credits' 
	SELECT DISTINCT
		jt.department_name
	FROM raw_credits AS c
	CROSS JOIN JSON_TABLE
	(
		c.crew,
		'$[*]' COLUMNS
		(
			department_name VARCHAR(50) PATH '$.department'
		)
	) AS jt
) AS t;


-- create jobs table linking job IDs to job names
CREATE TABLE jobs AS
SELECT
	-- create job IDs
	ROW_NUMBER() OVER () AS job_id,
    t.job_name
FROM
(
	-- extract job names from JSON column 'crew' in 'raw_credits' 
	SELECT DISTINCT
		jt.job_name
	FROM raw_credits AS c
	CROSS JOIN JSON_TABLE
	(
		c.crew,
		'$[*]' COLUMNS
		(
			job_name VARCHAR(255) PATH '$.job'
		)
	) AS jt
) AS t;


-- create movie_crew table linking movie IDs to people, department and job IDs
CREATE TABLE movie_crew AS
SELECT DISTINCT
	c.movie_id,
    jt.people_id,
    d.department_id,
    j.job_id
FROM raw_credits AS c
/* extract people IDs, department and job names from JSON column 'crew' in 
   'raw_credits' for each movie */
CROSS JOIN JSON_TABLE
(
	c.crew,
	'$[*]' COLUMNS
	(
		people_id INT PATH '$.id',
		department_name VARCHAR(50) PATH '$.department',
        job_name VARCHAR(255) PATH '$.job'
	)
) AS jt
-- replace department and job names with their IDs from departments and jobs tables
LEFT JOIN departments AS d
	ON jt.department_name = d.department_name
LEFT JOIN jobs AS j
	ON jt.job_name = j.job_name;


-- create movie_cast table linking movie IDs to people IDs and character names
CREATE TABLE movie_cast AS
SELECT DISTINCT
	c.movie_id,
    jt.people_id,
    jt.character_name
FROM raw_credits AS c
/* extract people IDs and character names from JSON column 'crew' in 'raw_credits' 
   for each movie, large VARCHAR to account for few very long names */
CROSS JOIN JSON_TABLE
(
	c.cast,
	'$[*]' COLUMNS
	(
		people_id INT PATH '$.id',
        character_name VARCHAR(512) PATH '$.character'
	)
) AS jt;


/******************************************************************************
3. ADDITIONAL MOVIE INFORMATION
******************************************************************************/

/* create procedure to dynamically create two tables from a JSON column in the 
   'raw_infos' table: (1) entity lookup table with unique IDs and names; and
   (2) link table associating movies with those entities. */
DELIMITER //
CREATE PROCEDURE extract_json_tables
(
    IN json_column VARCHAR(50),   -- name of JSON column in 'raw-infos'
    IN entity_table VARCHAR(50),  -- name of output table for distinct entities
    IN link_table VARCHAR(50),    -- name of output table linking movies to entities
    IN column_prefix VARCHAR(50), -- prefix for column names in output tables
    IN json_id_key VARCHAR(50),   -- JSON path to entity ID
    IN json_id_dtype VARCHAR(50)  -- data type of entity ID
)
BEGIN
	-- (0) drop tables if already exist
    -- construct statements to drop tables
	SET @drop_entity = CONCAT('DROP TABLE IF EXISTS ', entity_table, ';');
    SET @drop_link = CONCAT('DROP TABLE IF EXISTS ', link_table, ';');
    -- execute statement to drop entity table
    PREPARE stmt_drop_entity FROM @drop_entity;
    EXECUTE stmt_drop_entity;
    DEALLOCATE PREPARE stmt_drop_entity;
    -- execute statement to drop link table
    PREPARE stmt_drop_link FROM @drop_link;
    EXECUTE stmt_drop_link;
    DEALLOCATE PREPARE stmt_drop_link;
    -- (1) construct statement to create entity table
    SET @create_entity = CONCAT(
        'CREATE TABLE ', entity_table, ' AS ',
        'SELECT DISTINCT ', 
			'jt.id AS ', column_prefix, '_id, ',
			'jt.name AS ', column_prefix, '_name ',
        'FROM raw_infos AS i ',
        'CROSS JOIN JSON_TABLE',
        '(',
			'i.', json_column, ', ',
			'"$[*]" COLUMNS',
            '(',
				'id ', json_id_dtype, ' PATH "', json_id_key, '", ',
				'name VARCHAR(255) PATH "$.name"',
			')',
		') AS jt;'
    );
    -- (2) construct statement to create link table
    SET @create_link = CONCAT(
        'CREATE TABLE ', link_table, ' AS ',
        'SELECT DISTINCT ', 
			'i.id AS movie_id, ', 
			'jt.id AS ', column_prefix, '_id ',
        'FROM raw_infos AS i ',
        'CROSS JOIN JSON_TABLE',
        '(',
			'i.', json_column, ', ',
			'"$[*]" COLUMNS',
            '('
				'id ', json_id_dtype, ' PATH "', json_id_key, '" ',
			')',
		') AS jt;'
    );
    -- (3) execute the dynamic SQL statements
    -- create entity table
    PREPARE stmt_create_entity FROM @create_entity;
    EXECUTE stmt_create_entity;
    DEALLOCATE PREPARE stmt_create_entity;
	-- create link table
    PREPARE stmt_create_link FROM @create_link;
    EXECUTE stmt_create_link;
    DEALLOCATE PREPARE stmt_create_link;
END //
DELIMITER ;


-- create genre tables
CALL extract_json_tables
(
'genres',
'genres',
'movie_genres',
'genre',
'$.id',
'INT'
);

-- create keyword tables
CALL extract_json_tables
(
'keywords',
'keywords',
'movie_keywords',
'keyword',
'$.id',
'INT'
);

-- create production company tables
CALL extract_json_tables
(
'production_companies',
'prod_companies',
'movie_prod_companies',
'company',
'$.id',
'INT'
);

-- create production country tables
CALL extract_json_tables
(
'production_countries',
'countries',
'movie_prod_countries',
'country',
'$.iso_3166_1',
'VARCHAR(2)'
);

-- create language tables
CALL extract_json_tables
(
'spoken_languages',
'languages',
'movie_spoken_languages',
'language',
'$.iso_639_1',
'VARCHAR(2)'
);

-- drop procedure since not needed anymore
DROP PROCEDURE extract_json_tables;
