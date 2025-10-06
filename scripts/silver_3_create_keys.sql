/******************************************************************************
SILVER LAYER (3): CREATING KEYS IN CLEANED TABLES
*******************************************************************************
Author:			Igor Mlikota
Date:			...
MySQL Version:	8.4.6
*******************************************************************************
This script creates all the primary and foreign keys in the cleaned tables in 
the silver layer, which were first created in the script 'silver_create_tables'
and then cleaned in the script 'silver_clean_tables'.

First, a new column with nicely structured integer ids (1,2,3,...,n) is added
to the entity tables movie_infos, people, genres, keywords and prod_companies. 
These tables had ids that were taken from the raw csv data and did not follow 
a coherent structure (e.g. the 20 genres had the ids 12, 14, 16, ..., 10770).
The old ids are kept in the tables to maintain a connection to the raw data.

Second, the old ids are replaced with the new ones in all lookup tables 
movie_ratings, movie_characters, movie_crew, movie_genres, ... (e.g. in the 
lookup table movie_genres the column movie_id is mapped to the new movie_id
from the entity table movie_infos and the column genre_id is mapped to the new
genre_id from the entity table genres).

Third, the primary and foreign keys are set up in all tables of the database.
******************************************************************************/


/******************************************************************************
1. CREATE NEW IDS IN ENITY TABLES
******************************************************************************/

-- create procedure to create new ids and rename old ids
DELIMITER //
CREATE PROCEDURE create_new_id
(
    IN entity_table VARCHAR(50), -- name of entity table
    IN id_column VARCHAR(50)     -- name of id column to be changed
)
BEGIN
    -- construct statement to rename column with old ids
    SET @rename_column = CONCAT(
		'ALTER TABLE ', entity_table, ' ',
		'CHANGE ', id_column, ' ', id_column, '_old INT;'
    );
    -- construct statement to create empty column to store new ids
    SET @create_column = CONCAT(
		'ALTER TABLE ', entity_table, ' ',
		'ADD COLUMN ', id_column, ' INT FIRST;'
    );
    -- construct statement to fill new column with new ids
    SET @fill_column = CONCAT(
		'WITH new_ids AS ',
        '(',
			'SELECT ',
				id_column, '_old, ',
				'ROW_NUMBER() OVER () AS id_column_new ',
			'FROM ', entity_table,
		') ',
		'UPDATE ', entity_table, ' AS et ',
		'JOIN new_ids AS ni ON et.', id_column, '_old = ni.', id_column, '_old ',
		'SET et.', id_column, ' = ni.id_column_new;'
    );
    -- execute statement to rename column with old ids
    PREPARE stmt_rename_column FROM @rename_column;
    EXECUTE stmt_rename_column;
    DEALLOCATE PREPARE stmt_rename_column;
    -- execute statement to create empty column to store new ids
	PREPARE stmt_create_column FROM @create_column;
    EXECUTE stmt_create_column;
    DEALLOCATE PREPARE stmt_create_column;
    -- execute statement to fill new column with new ids
	PREPARE stmt_fill_column FROM @fill_column;
    EXECUTE stmt_fill_column;
    DEALLOCATE PREPARE stmt_fill_column;
END //
DELIMITER ;

-- call procedure to create new ids in entity tables
CALL create_new_id('movie_infos', 'movie_id');
CALL create_new_id('people', 'people_id');
CALL create_new_id('genres', 'genre_id');
CALL create_new_id('keywords', 'keyword_id');
CALL create_new_id('prod_companies', 'company_id');

-- drop procedure since not needed anymore
DROP PROCEDURE create_new_id;


/******************************************************************************
2. REPLACE OLD IDS IN LOOKUP TABLES
******************************************************************************/

-- create procedure to replace old with new ids in lookup tables
DELIMITER //
CREATE PROCEDURE change_id_lookup
(
	IN entity_table VARCHAR(50), -- name of entity table
    IN lookup_table VARCHAR(50), -- name of lookup table
    IN id_column VARCHAR(50)     -- name of id column
)
BEGIN
    -- construct statement to change id
    SET @change_id = CONCAT(
        'UPDATE ', lookup_table, ' AS lt ',
		'JOIN ', entity_table, ' AS et ',
        'ON lt.', id_column, ' = et.', id_column, '_old ',
        'SET lt.', id_column, ' = et.', id_column, ';'
    );
    -- execute statement to change id
    PREPARE stmt_change_id FROM @change_id;
    EXECUTE stmt_change_id;
    DEALLOCATE PREPARE stmt_change_id;
END //
DELIMITER ;

-- call procedure to change movie_id in lookup tables
CALL change_id_lookup('movie_infos', 'movie_genres', 'movie_id');
CALL change_id_lookup('movie_infos', 'movie_keywords', 'movie_id');
CALL change_id_lookup('movie_infos', 'movie_prod_companies', 'movie_id');
CALL change_id_lookup('movie_infos', 'movie_prod_countries', 'movie_id');
CALL change_id_lookup('movie_infos', 'movie_spoken_languages', 'movie_id');
CALL change_id_lookup('movie_infos', 'movie_cast', 'movie_id');
CALL change_id_lookup('movie_infos', 'movie_crew', 'movie_id');
CALL change_id_lookup('movie_infos', 'movie_ratings', 'movie_id');

-- call procedure to change people_id in lookup tables
CALL change_id_lookup('people', 'movie_cast', 'people_id');
CALL change_id_lookup('people', 'movie_crew', 'people_id');

-- call procedure to change remaining ids in lookup tables
CALL change_id_lookup('genres', 'movie_genres', 'genre_id');
CALL change_id_lookup('keywords', 'movie_keywords', 'keyword_id');
CALL change_id_lookup('prod_companies', 'movie_prod_companies', 'company_id');

-- drop procedure since not needed anymore
DROP PROCEDURE change_id_lookup;


/******************************************************************************
3. SET UP PRIMARY AND FOREIGN KEYS
******************************************************************************/

-- primary keys (single)
ALTER TABLE movie_infos
ADD PRIMARY KEY (movie_id);
ALTER TABLE people
ADD PRIMARY KEY (people_id);
ALTER TABLE genders
ADD PRIMARY KEY (gender_id);
ALTER TABLE roles
ADD PRIMARY KEY (role_id);
ALTER TABLE departments
ADD PRIMARY KEY (department_id);
ALTER TABLE jobs
ADD PRIMARY KEY (job_id);
ALTER TABLE genres
ADD PRIMARY KEY (genre_id);
ALTER TABLE keywords
ADD PRIMARY KEY (keyword_id);
ALTER TABLE prod_companies
ADD PRIMARY KEY (company_id);
ALTER TABLE countries
ADD PRIMARY KEY (country_id);
ALTER TABLE languages
ADD PRIMARY KEY (language_id);
ALTER TABLE prod_status
ADD PRIMARY KEY (prod_status_id);

-- primary keys (composite)
ALTER TABLE movie_cast
ADD PRIMARY KEY (movie_id, people_id, character_name);
ALTER TABLE movie_crew
ADD PRIMARY KEY (movie_id, people_id, department_id, job_id); 
ALTER TABLE movie_genres
ADD PRIMARY KEY (movie_id, genre_id);
ALTER TABLE movie_keywords
ADD PRIMARY KEY (movie_id, keyword_id);
ALTER TABLE movie_prod_companies
ADD PRIMARY KEY (movie_id, company_id);
ALTER TABLE movie_prod_countries
ADD PRIMARY KEY (movie_id, country_id);
ALTER TABLE movie_spoken_languages
ADD PRIMARY KEY (movie_id, language_id);

-- create procedure to add foreign key
DELIMITER //
CREATE PROCEDURE add_foreign_key
(
	IN tab_name VARCHAR(50),   -- name of table
    IN fk_col VARCHAR(50),     -- name of foreign key column in table
    IN ref_tab VARCHAR(50),    -- name of reference table
    IN ref_col VARCHAR(50)     -- name of foreign key column in reference table
)
BEGIN
    -- construct statement to add foreign key
    SET @add_fk = CONCAT(
        'ALTER TABLE ', tab_name, ' ',
		'ADD CONSTRAINT fk_', tab_name, '_', fk_col, ' ', -- name is combination of table and id_column name
			'FOREIGN KEY (', fk_col, ') ',
			'REFERENCES ', ref_tab, ' (', ref_col, ') ',
			'ON DELETE CASCADE ',
			'ON UPDATE CASCADE;'
    );
    -- execute statement to add foreign key
    PREPARE stmt_add_fk FROM @add_fk;
    EXECUTE stmt_add_fk;
    DEALLOCATE PREPARE stmt_add_fk;
END //
DELIMITER ;

-- call procedure to add foreign keys
CALL add_foreign_key('movie_infos', 'original_language_id', 'languages', 'language_id');	-- movie_infos: 			original language
CALL add_foreign_key('movie_infos', 'prod_status_id', 'prod_status', 'prod_status_id');		-- movie_infos: 			production status
CALL add_foreign_key('movie_ratings', 'movie_id', 'movie_infos', 'movie_id');				-- movie_ratings: 			movie
CALL add_foreign_key('people', 'gender_id', 'genders', 'gender_id');						-- people: 					gender
CALL add_foreign_key('people', 'role_id', 'roles', 'role_id');								-- people: 					role
CALL add_foreign_key('movie_cast', 'movie_id', 'movie_infos', 'movie_id');					-- movie_characters: 		movie
CALL add_foreign_key('movie_cast', 'people_id', 'people', 'people_id');						-- movie_characters: 		people
CALL add_foreign_key('movie_crew', 'movie_id', 'movie_infos', 'movie_id');					-- movie_crew: 				movie
CALL add_foreign_key('movie_crew', 'people_id', 'people', 'people_id');						-- movie_crew: 				people
CALL add_foreign_key('movie_crew', 'department_id', 'departments', 'department_id');		-- movie_crew: 				department
CALL add_foreign_key('movie_crew', 'job_id', 'jobs', 'job_id');								-- movie_crew: 				job
CALL add_foreign_key('movie_genres', 'movie_id', 'movie_infos', 'movie_id');				-- movie_genres: 			movie
CALL add_foreign_key('movie_genres', 'genre_id', 'genres', 'genre_id');						-- movie_genres: 			genre
CALL add_foreign_key('movie_keywords', 'movie_id', 'movie_infos', 'movie_id');				-- movie_keywords: 			movie
CALL add_foreign_key('movie_keywords', 'keyword_id', 'keywords', 'keyword_id');				-- movie_keywords: 			genre
CALL add_foreign_key('movie_prod_companies', 'movie_id', 'movie_infos', 'movie_id');		-- movie_prod_companies: 	movie
CALL add_foreign_key('movie_prod_companies', 'company_id', 'prod_companies', 'company_id');	-- movie_prod_companies: 	production company
CALL add_foreign_key('movie_prod_countries', 'movie_id', 'movie_infos', 'movie_id');		-- movie_prod_countries: 	movie
CALL add_foreign_key('movie_prod_countries', 'country_id', 'countries', 'country_id');		-- movie_prod_countries: 	production country
CALL add_foreign_key('movie_spoken_languages', 'movie_id', 'movie_infos', 'movie_id');		-- movie_spoken_languages:	movie
CALL add_foreign_key('movie_spoken_languages', 'language_id', 'languages', 'language_id');	-- movie_spoken_languages: 	spoken language

-- drop procedure since not needed anymore
DROP PROCEDURE add_foreign_key;
