/******************************************************************************
SILVER LAYER (2): CLEANING TABLES
*******************************************************************************
Author:			Igor Mlikota
Date:			...
MySQL Version:	8.4.6
*******************************************************************************
This script cleans and normalizes the tables in the silver layer, which were 
created in the script 'silver_create_tables'.

In multiple preliminary steps, all columns were inspected visually and with
querries to detect possible data collection errors (e.g. leading or trailing
spaces in string entries) and misleading encodings (e.g. zeros which actually
refer to missing values). The following code only adjusts the tables and 
columns that were detected in these preliminary steps.

The order of adjustment follows the 3 groups of tables:
	1. Main Movie Information
    2. Cast and Crew
    3. Additional Movie Information
******************************************************************************/


/******************************************************************************
1. MAIN MOVIE INFORMATION
******************************************************************************/

-- clean movie_infos table
UPDATE movie_infos
SET 
	-- replace zeros with NULL
    runtime = NULLIF(runtime, 0),
    budget = NULLIF(budget, 0),
    revenue = NULLIF(revenue, 0),
    -- replace language codes cn with zh
    original_language_id = CASE
		WHEN original_language_id = 'cn' THEN 'zh'
        ELSE original_language_id
	END,
    -- remove leading and trailing spaces
    overview = TRIM(overview),
    -- replace empty strings with NULL
	overview = NULLIF(overview, ''),
    tagline = NULLIF(tagline, ''),
    homepage = NULLIF(homepage, '');
    
-- replace zero vote_average with NULL in movie_ratings where vote_count is zero
UPDATE movie_ratings
SET vote_average = NULL
WHERE vote_count = 0;


/******************************************************************************
2. CAST AND CREW
******************************************************************************/

-- replace empty character_name with "no character name" in movie_cast table
-- (not using NULL in order to be able to set up composite primary keys)
UPDATE movie_cast
SET character_name = 'no character name'
WHERE TRIM(character_name) = '';

-- remove leading and trailing spaces in people_name in people table
UPDATE people
SET people_name = TRIM(people_name);

/* remove duplicate rows in people table (two people had each two entries, one
   with missing gender and one with correct gender) */
DELETE FROM people
WHERE people_id IN (30711, 1189293) AND gender_id = 0;


/******************************************************************************
3. ADDITIONAL MOVIE INFORMATION
******************************************************************************/

-- remove leading and trailing spaces in keyword_name in keywords table
UPDATE keywords
SET keyword_name = TRIM(keyword_name);
    
/* adjustment of languages table done by dropping and recreating whole table
   because many language names (endonyms) are missing and because a column
   with english names needs to be added */

-- drop languages table and create new empty table
DROP TABLE languages;
CREATE TABLE languages
(
	language_id CHAR(2),
    language_name VARCHAR(50),
    language_name_en VARCHAR(50)
);

-- insert languages with iso_639_1 codes, endonyms and english names
-- (source: Wikipedia, done with Microsoft Copilot AI help)
INSERT INTO languages
VALUES
	('af', 'Afrikaans', 'Afrikaans'),
	('am', 'አማርኛ', 'Amharic'),
	('ar', 'العربية', 'Arabic'),
	('bg', 'български', 'Bulgarian'),
	('bm', 'Bamanankan', 'Bambara'),
	('bn', 'বাংলা', 'Bengali'),
	('bo', 'བོད་ཡིག', 'Tibetan'),
	('br', 'Brezhoneg', 'Breton'),
	('bs', 'Bosanski', 'Bosnian'),
	('ca', 'Català', 'Catalan'),
	('ce', 'Нохчийн мотт', 'Chechen'),
	('co', 'Corsu', 'Corsican'),
	('cs', 'Český', 'Czech'),
	('cy', 'Cymraeg', 'Welsh'),
	('da', 'Dansk', 'Danish'),
	('de', 'Deutsch', 'German'),
	('dz', 'རྫོང་ཁ', 'Dzongkha'),
	('el', 'ελληνικά', 'Greek'),
	('en', 'English', 'English'),
	('eo', 'Esperanto', 'Esperanto'),
	('es', 'Español', 'Spanish'),
	('et', 'Eesti', 'Estonian'),
	('fa', 'فارسی', 'Persian'),
	('fi', 'suomi', 'Finnish'),
	('fr', 'Français', 'French'),
	('ga', 'Gaeilge', 'Irish'),
	('gd', 'Gàidhlig', 'Scottish Gaelic'),
	('gl', 'Galego', 'Galician'),
	('he', 'עִבְרִית', 'Hebrew'),
	('hi', 'हिन्दी', 'Hindi'),
	('hr', 'Hrvatski', 'Croatian'),
	('hu', 'Magyar', 'Hungarian'),
	('hy', 'Հայերեն', 'Armenian'),
	('id', 'Bahasa Indonesia', 'Indonesian'),
	('is', 'Íslenska', 'Icelandic'),
	('it', 'Italiano', 'Italian'),
	('iu', 'ᐃᓄᒃᑎᑐᑦ', 'Inuktitut'),
	('ja', '日本語', 'Japanese'),
	('ka', 'ქართული', 'Georgian'),
	('kk', 'қазақ', 'Kazakh'),
	('km', 'ភាសាខ្មែរ', 'Khmer'),
	('ko', '한국어/조선말', 'Korean'),
	('ku', 'Kurdî', 'Kurdish'),
	('kw', 'Kernewek', 'Cornish'),
	('ky', 'Кыргызча', 'Kyrgyz'),
	('la', 'Latinum', 'Latin'),
	('mi', 'Māori', 'Maori'),
	('ml', 'മലയാളം', 'Malayalam'),
	('mn', 'Монгол', 'Mongolian'),
    ('nb', 'Norwegian Bokmål', 'Norsk Bokmål'),
	('ne', 'नेपाली', 'Nepali'),
	('nl', 'Nederlands', 'Dutch'),
	('no', 'Norsk', 'Norwegian'),
	('nv', 'Diné Bizaad', 'Navajo'),
	('ny', 'Chichewa', 'Chichewa'),
	('pa', 'ਪੰਜਾਬੀ', 'Punjabi'),
	('pl', 'Polski', 'Polish'),
	('ps', 'پښتو', 'Pashto'),
	('pt', 'Português', 'Portuguese'),
	('ro', 'Română', 'Romanian'),
	('ru', 'Pусский', 'Russian'),
	('sa', 'संस्कृतम्', 'Sanskrit'),
	('sh', 'Srpskohrvatski', 'Serbo-Croatian'),
	('si', 'සිංහල', 'Sinhala'),
	('sk', 'Slovenčina', 'Slovak'),
	('sl', 'Slovenščina', 'Slovenian'),
	('so', 'Somali', 'Somali'),
	('sq', 'Shqip', 'Albanian'),
	('sr', 'Srpski', 'Serbian'),
	('st', 'Sesotho', 'Southern Sotho'),
	('sv', 'Svenska', 'Swedish'),
	('sw', 'Kiswahili', 'Swahili'),
	('ta', 'தமிழ்', 'Tamil'),
	('te', 'తెలుగు', 'Telugu'),
	('th', 'ภาษาไทย', 'Thai'),
	('tl', 'Tagalog', 'Tagalog'),
	('to', 'Faka Tonga', 'Tongan'),
	('tr', 'Türkçe', 'Turkish'),
	('uk', 'Український', 'Ukrainian'),
	('ur', 'اردو', 'Urdu'),
	('vi', 'Tiếng Việt', 'Vietnamese'),
	('wo', 'Wolof', 'Wolof'),
	('xh', 'isiXhosa', 'Xhosa'),
    ('xx', 'no language', 'no language'), -- indicator for no language
	('yi', 'ייִדיש‎', 'Yiddish'),
	('zh', '普通话', 'Chinese'),
	('zu', 'isiZulu', 'Zulu');

-- replace cn with zh in language_id in movie_spoken_languages table 
UPDATE movie_spoken_languages
SET language_id = 'zh'
WHERE language_id = 'cn';

-- remove duplicate rows in movie_spoken_languages (some had cn and zh)
CREATE TABLE movie_spoken_languages_temp AS
SELECT DISTINCT *
FROM movie_spoken_languages;
DROP TABLE movie_spoken_languages;
RENAME TABLE movie_spoken_languages_temp TO movie_spoken_languages;


/* Some production companies show up multiple times with different company_id
   in prod_companies table with either the exact same company_name or a difference
   in lower/upper cases and accents. They are accounted for in 4 steps. */

-- step 1: identify duplicate companies in prod_companies table
/* 
SELECT 
	pc.company_id,
    pc.company_name, 
    t.normalized_name
FROM prod_companies pc
JOIN (
    SELECT LOWER(company_name) AS normalized_name
    FROM prod_companies
    GROUP BY LOWER(company_name)
    HAVING COUNT(*) > 1
) AS t
ON LOWER(pc.company_name) = t.normalized_name
ORDER BY t.normalized_name;
*/

-- step 2: create a mapping between old and new company_ids for duplicates
DROP TABLE IF EXISTS company_merge_map;
CREATE TEMPORARY TABLE company_merge_map (
    old_id INT,
    new_id INT
);
INSERT INTO company_merge_map 
VALUES
	(36390, 787), (30420, 10039), (5766, 201), (28163, 7625),
	(6363, 11175), (35304, 766), (13778, 27451), (30037, 2376),
	(15278, 3324), (20777, 12745), (23616, 10611), (22656, 4253),
	(23397, 5739), (7293, 7852), (6982, 7286), (26560, 9313),
	(17513, 6417), (27897, 315), (15671, 83), (45970, 83),
	(16804, 591), (2152, 2150), (437, 7364), (15461, 4714),
	(15460, 4131), (7571, 1632), (7161, 2200), (44091, 18188),
	(20928, 2630), (20740, 2370), (27551, 11370), (22443, 4741),
	(34338, 11752), (7396, 7981), (45778, 81), (1382, 31080),
	(37163, 11487), (18880, 4343), (29099, 11341), (7320, 806),
	(12247, 446), (30994, 7248), (36326, 3801), (6633, 10255),
	(33025, 68063);

-- step 3: update the company_ids in movie_prod_companies from old to new
UPDATE movie_prod_companies AS m
JOIN company_merge_map AS map 
ON m.company_id = map.old_id
SET m.company_id = map.new_id;

-- step 4: delete duplicates (rows with old company_id) from prod_companies
DELETE FROM prod_companies
WHERE company_id IN 
(
    SELECT old_id 
    FROM company_merge_map
);

