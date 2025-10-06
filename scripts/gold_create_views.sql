/******************************************************************************
GOLD LAYER: CREATING VIEWS
*******************************************************************************
Author:			Igor Mlikota
Date:			03.Oct.2025
MySQL Version:	8.4.6
*******************************************************************************
This script creates analytical views based on the cleaned tables from the silver
layer. These views consolidate and enrich data from multiple normalized sources 
to support exploratory analysis. They span both cross-sectional dimensions (e.g.
actors, companies, languages) and temporal aggregations (e.g. yearly summaries).
As such they form the gold layer of the database.

Currently, the gold layer includes the following 7 views:
    1. actors               : Summary statistics per actor
    2. directors            : Summary statistics per director
    3. production_companies : Summary statistics per production company
    4. language_usage       : Movie counts by original and spoken language
    5. production_countries : Movie counts by production country
    6. yearly_summary       : Yearly aggregates of movie metrics
    7. movies_ranked        : Movies ranked by financials and rating
******************************************************************************/


/******************************************************************************
1. ACTORS
******************************************************************************/

-- create view summarizing actor-level movie statistics
CREATE VIEW actors AS
SELECT
    p.people_name AS actor_name,
    -- total number of distinct movies actor appeared in
    COUNT(t.movie_id) AS movie_count,
    -- earliest and latest movie release dates
    MIN(mi.release_date) AS oldest_movie_date,
    MAX(mi.release_date) AS newest_movie_date,
    -- acting career span in years based on release dates
    FLOOR(DATEDIFF(MAX(mi.release_date), 
		MIN(mi.release_date)) / 365) AS career_years,
	-- aggregated financial statistics (in USD, not adjusted, exclude NULL)
    SUM(mi.budget) AS total_budget_USD,
    ROUND(AVG(mi.budget),0) AS average_budget_USD,
    SUM(mi.revenue) AS total_revenue_USD,
    ROUND(AVG(mi.revenue),0) AS average_revenue_USD,
    -- aggregated movie runtime statistics (in minutes, exclude NULL)
    SUM(mi.runtime) AS total_runtime_min,
    ROUND(AVG(mi.runtime),0) AS average_runtime_min,
    -- average movie rating (excludes NULL)
    ROUND(AVG(mr.vote_average),2) AS average_rating
FROM (   
	-- ensure each (movie, actor) pair counted only once,
    -- even if actor had multiple roles in same movie
	SELECT DISTINCT
		mc.movie_id,
		mc.people_id
	FROM movie_cast AS mc
) AS t
-- join movie metadata and ratings
LEFT JOIN movie_infos AS mi ON t.movie_id = mi.movie_id
LEFT JOIN movie_ratings AS mr ON t.movie_id = mr.movie_id
-- join actor names
LEFT JOIN people as p ON t.people_id = p.people_id
-- aggregate statistics by actor
GROUP BY t.people_id
-- order by number of movies (high to low)
ORDER BY movie_count DESC;


/******************************************************************************
2. DIRECTORS
******************************************************************************/

-- create view summarizing director-level movie statistics 
-- (focusing only on main directors, no co-directors or assistant directors)
-- (no DISTINCT needed, each (movie, director) pair is unique in movie_crew
--  by design, enforced by composite primary key)
CREATE VIEW directors AS
SELECT
    p.people_name AS director_name,
    -- total number of distinct movies a person directed
    COUNT(mc.movie_id) AS movie_count,
    -- earliest and latest movie release dates as director
    MIN(mi.release_date) AS oldest_movie_date,
    MAX(mi.release_date) AS newest_movie_date,
    -- directing career span in years based on release dates
	FLOOR(DATEDIFF(MAX(mi.release_date), 
		MIN(mi.release_date)) / 365) AS career_years,
	-- aggregated financial statistics (in USD, not adjusted, exclude NULL)
    SUM(mi.budget) AS total_budget_USD,
    ROUND(AVG(mi.budget),0) AS average_budget_USD,
    SUM(mi.revenue) AS total_revenue_USD,
    ROUND(AVG(mi.revenue),0) AS average_revenue_USD,
    -- aggregated movie runtime statistics (in minutes, exclude NULL)
    SUM(mi.runtime) AS total_runtime_min,
    ROUND(AVG(mi.runtime),0) AS average_runtime_min,
    -- average movie rating (excludes NULL)
    ROUND(AVG(mr.vote_average),2) AS average_rating
FROM movie_crew AS mc
-- join movie metadata and ratings
LEFT JOIN movie_infos AS mi ON mc.movie_id = mi.movie_id
LEFT JOIN movie_ratings AS mr ON mc.movie_id = mr.movie_id
-- join person and job names
LEFT JOIN people AS p ON mc.people_id = p.people_id
LEFT JOIN jobs AS j ON mc.job_id = j.job_id
-- select only directors
WHERE j.job_name = 'Director'
-- aggregate statistics by director
GROUP BY mc.people_id
-- order by number of movies (high to low)
ORDER BY movie_count DESC;


/******************************************************************************
3. PRODUCTION COMPANIES
******************************************************************************/

-- create view summarizing production-company-level movie statistics 
-- (no DISTINCT needed, each (movie, company) pair is unique in 
--  movie_prod_companies by design, enforced by composite primary key)
CREATE VIEW production_companies AS
SELECT
    pc.company_name,
    -- total number of distinct movies a company produced
    COUNT(mpc.movie_id) AS movie_count,
    -- earliest and latest movie release dates
    MIN(mi.release_date) AS oldest_movie_date,
    MAX(mi.release_date) AS newest_movie_date,
    -- business operation span in years based on release dates
	FLOOR(DATEDIFF(MAX(mi.release_date), 
		MIN(mi.release_date)) / 365) AS business_years,
	-- aggregated financial statistics (in USD, not adjusted, exclude NULL)
    SUM(mi.budget) AS total_budget_USD,
    ROUND(AVG(mi.budget),0) AS average_budget_USD,
    SUM(mi.revenue) AS total_revenue_USD,
    ROUND(AVG(mi.revenue),0) AS average_revenue_USD,
    -- aggregated movie runtime statistics (in minutes, exclude NULL)
    SUM(mi.runtime) AS total_runtime_min,
    ROUND(AVG(mi.runtime),0) AS average_runtime_min,
    -- average movie rating (excludes NULL)
    ROUND(AVG(mr.vote_average),2) AS average_rating
FROM movie_prod_companies AS mpc
-- join movie metadata and ratings
LEFT JOIN movie_infos AS mi ON mpc.movie_id = mi.movie_id
LEFT JOIN movie_ratings AS mr ON mpc.movie_id = mr.movie_id
-- join production company names
LEFT JOIN prod_companies AS pc ON mpc.company_id = pc.company_id
-- aggregate statistics by production company
GROUP BY mpc.company_id
-- order by number of movies (high to low)
ORDER BY movie_count DESC;


/******************************************************************************
4. LANGUAGE USAGE
******************************************************************************/

-- create view summarizing language usage across movies
-- (uses scalar subquerries instead of joins and GROUP BY, each subquerry 
--  is executed per row of main table languages, less efficient for large
--  datasets but acceptable here)
CREATE VIEW language_usage AS
SELECT
  l.language_id,
  l.language_name,
  l.language_name_en,
  -- number of movies where language is original language
  (
    SELECT COUNT(*) 
    FROM movie_infos AS mi
    WHERE mi.original_language_id = l.language_id
  ) AS count_original,
  -- number of movies where language is spoken
  (
    SELECT COUNT(*) 
    FROM movie_spoken_languages AS msl
    WHERE msl.language_id = l.language_id
  ) AS count_spoken
FROM languages AS l
-- order by number of movies as original language (high to low)
ORDER BY count_original DESC;


/******************************************************************************
5. PRODUCTION COUNTRIES
******************************************************************************/

-- create view summarizing movie counts by production country
CREATE VIEW production_countries AS
SELECT
	mpc.country_id,
    c.country_name,
    COUNT(movie_id) AS movie_count
FROM movie_prod_countries AS mpc
-- join country names
LEFT JOIN countries AS c ON mpc.country_id = c.country_id
-- aggregate by country
GROUP BY country_id
-- order by number of movies (high to low)
ORDER BY movie_count DESC;


/******************************************************************************
6. YEARLY SUMMARY
******************************************************************************/

-- create view summarizing yearly movie statistics
CREATE VIEW yearly_summary AS
-- first CTE: rank genres by movie count within each release year
WITH ranked_genres AS (
	SELECT
		YEAR(mi.release_date) AS release_year,
		g.genre_name,
		ROW_NUMBER() OVER (
			PARTITION BY YEAR(mi.release_date)
			ORDER BY COUNT(mg.movie_id) DESC
		) AS genre_year_rank
	FROM movie_genres AS mg
	LEFT JOIN movie_infos AS mi ON mg.movie_id = mi.movie_id
	LEFT JOIN genres AS g ON mg.genre_id = g.genre_id
	GROUP BY release_year, genre_name
),
-- second CTE: pivot top 3 genres per year into seperate columns
-- (nested CTE, references first CTE ranked_genres)
top_genres AS (
	SELECT
		release_year,
        -- uses MAX to collapse field into scalar per year 
		MAX(CASE WHEN genre_year_rank = 1 THEN genre_name END) AS first_genre,
		MAX(CASE WHEN genre_year_rank = 2 THEN genre_name END) AS second_genre,
		MAX(CASE WHEN genre_year_rank = 3 THEN genre_name END) AS third_genre
	FROM ranked_genres
	GROUP BY release_year
)
-- main SELECT: combine yearly movie statistics with genre rankings from CTEs
SELECT
	YEAR(mi.release_date) AS release_year,
    -- number of movies produced in given year
	COUNT(mi.movie_id) AS movie_count,
    -- aggregated financial statistics (in USD, not adjusted, exclude NULL)
	SUM(mi.budget) AS total_budget_USD,
	ROUND(AVG(mi.budget),0) AS average_budget_USD,
	SUM(mi.revenue) AS total_revenue_USD,
	ROUND(AVG(mi.revenue),0) AS average_revenue_USD,
    -- aggregated movie runtime statistics (in minutes, exclude NULL)
	SUM(mi.runtime) AS total_runtime_min,
	ROUND(AVG(mi.runtime),0) AS average_runtime_min,
    -- average movie rating (excludes NULL)
	ROUND(AVG(mr.vote_average),2) AS average_rating,
    -- average cast and crew size
	ROUND(AVG(ncast.cast_count),0) AS average_cast_count,
	ROUND(AVG(ncrew.crew_count),0) AS average_crew_count,
    -- top three genres based on movie count
	MAX(tg.first_genre) AS first_genre,
	MAX(tg.second_genre) AS second_genre,
	MAX(tg.third_genre) AS third_genre
FROM movie_infos AS mi
-- join number of cast members per movie
LEFT JOIN (
	SELECT 
		movie_id, 
		COUNT(people_id) AS cast_count
	FROM movie_cast 
	GROUP BY movie_id
) AS ncast ON mi.movie_id = ncast.movie_id
-- join number of crew members per movie
LEFT JOIN (
	SELECT
		movie_id,
		COUNT(people_id) AS crew_count
	FROM movie_crew
	GROUP BY movie_id
) AS ncrew ON mi.movie_id = ncrew.movie_id
-- join movie ratings
LEFT JOIN movie_ratings AS mr ON mi.movie_id = mr.movie_id
-- join top 3 genres per year (second CTE)
LEFT JOIN top_genres AS tg ON YEAR(mi.release_date) = tg.release_year
-- exclude movies with missing release date (only one)
WHERE mi.release_date IS NOT NULL
-- aggregate by release year
GROUP BY YEAR(mi.release_date)
-- order chronologically (earliest to latest year)
ORDER BY YEAR(mi.release_date);


/******************************************************************************
7. MOVIES RANKED
******************************************************************************/

-- create view ranking movies by financials and rating
CREATE VIEW movies_ranked AS
SELECT
    mi.title,
    -- ranked financials
    mi.budget AS budget_USD,
    DENSE_RANK() OVER (ORDER BY mi.budget DESC) AS budget_rank,
    mi.revenue AS revenue_USD,
    DENSE_RANK() OVER (ORDER BY mi.revenue DESC) AS revenue_rank,
    mi.revenue - mi.budget AS profit_USD,
    DENSE_RANK() OVER (ORDER BY mi.revenue - mi.budget DESC) AS profit_rank,
    -- ranked average rating
    mr.vote_average AS average_rating,
    DENSE_RANK() OVER (ORDER BY mr.vote_average DESC) AS rating_rank
FROM movie_infos AS mi
-- join ratings data
LEFT JOIN movie_ratings AS mr ON mi.movie_id = mr.movie_id
-- filter out movies with fewer than 10 votes to ensure rating reliability
WHERE mr.vote_count >= 10
-- order final output by revenue (high to low)
ORDER BY mi.revenue DESC;

