/******************************************************************************
BRONZE LAYER: CREATING DATABASE AND RAW TABLES
*******************************************************************************
Author:			Igor Mlikota
Date:			...
MySQL Version:	8.4.6
*******************************************************************************
This script creates the 'tmdb_movies' database with two tables 'raw_credits'
and 'raw_infos', which contain data from the files 'tmdb_5000_credits.csv' 
and 'tmdb_5000_movies.csv', respectively.
******************************************************************************/


/******************************************************************************
DATABASE tmdb_movies
******************************************************************************/

-- drop existing database to avoid errors during re-run
DROP DATABASE IF EXISTS tmdb_movies;

-- create database
CREATE DATABASE tmdb_movies;

-- use database
USE tmdb_movies;


/******************************************************************************
TABLE raw_credits FROM tmdb_5000_credits.csv
******************************************************************************/

-- create empty table for movie credits
CREATE TABLE raw_credits 
(
    movie_id INT,
    title VARCHAR(255),
    cast TEXT,
    crew TEXT
);

-- fill credits table with data from tmdb_5000_credits.csv
-- (uses ESCAPED BY '' to overwrite default of '\\', which causes 26 rows to be incomplete)
LOAD DATA LOCAL INFILE '/Users/igormlikota/Documents/Coding Projects/SQL_Movies/data/tmdb_5000_credits.csv'
INTO TABLE raw_credits
FIELDS TERMINATED BY ',' 
       OPTIONALLY ENCLOSED BY '"' 
       ESCAPED BY ''
LINES STARTING BY ''
      TERMINATED BY '\n'
IGNORE 1 ROWS;


/******************************************************************************
TABLE raw_infos FROM tmdb_5000_movies.csv
******************************************************************************/

-- create empty table for movie informations
-- (use BIGINT for revenue since max value for INT is too low)
CREATE TABLE raw_infos 
(
    budget INT,
    genres TEXT,
    homepage TEXT,
    id INT,
    keywords TEXT,
    original_language VARCHAR(2),
    original_title VARCHAR(255),
    overview TEXT,
    popularity FLOAT,
    production_companies TEXT,
    production_countries TEXT,
    release_date DATE,
    revenue BIGINT,
    runtime INT,
    spoken_languages TEXT,
    status VARCHAR(50),
    tagline VARCHAR(255),
    title VARCHAR(255),
    vote_average FLOAT,
    vote_count INT
);

-- fill infos table with data from tmdb_5000_movies.csv
-- (warnings will be accounted for when cleaning data)
-- (empty strings in runtime and release_data are set to 0 and 0000-00-00 by default)
LOAD DATA LOCAL INFILE '/Users/igormlikota/Documents/Coding Projects/SQL_Movies/data/tmdb_5000_movies.csv'
INTO TABLE raw_infos
FIELDS TERMINATED BY ',' 
       OPTIONALLY ENCLOSED BY '"' 
       ESCAPED BY ''
LINES STARTING BY ''
      TERMINATED BY '\n'
IGNORE 1 ROWS;

