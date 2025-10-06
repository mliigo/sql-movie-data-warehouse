# SQL Movie Data Warehouse

Welcome to my movie data warehouse project! 👋

---

## 📖 Project Overview

This project builds a data warehouse in MySQL using a dataset of approximately 5000 movies sourced from [The Movie Database (TMDb) API](https://developer.themoviedb.org/docs/getting-started) and made available on [kaggle](https://www.kaggle.com/datasets/tmdb/tmdb-movie-metadata/data?select=tmdb_5000_movies.csv). The raw data is provided in two CSV files:
* **tmdb_5000_credits.csv**:  information on cast and crew members for each movie (e.g. names, departments, jobs)
* **tmdb_5000_movies.csv**:   metadata of each movie (e.g. release date, runtime, genre, budget, revenue, rating)

Several columns in these files contain nested JSON-like lists, which are parsed and transformed into normalized SQL tables. The project focuses on cleaning and restructuring this semi-structured data to ensure consistency, eliminate redundancy, and enforce relational integrity.

Once the core tables are established and cleaned, a series of SQL views are created to combine and aggregate information across entities. These views provide high-level summaries and insights, such as statistics by actor, director, production company, language, and country, as well as yearly breakdowns of movie trends including top genres, financial performance, and audience ratings.


## 🏗️ Data Architecture

This project follows the [Medallion Architecture](https://dataengineering.wiki/Concepts/Data+Architecture/Medallion+Architecture), which organizes data by gradually improving its quality and accessability as it flows through three distinct layers:

1. **Bronze Layer**: Initial point of data ingestion from source systems into database. Stores raw unprocessed data.

2. **Silver Layer**: Creation of cleaned and normalized tables. Prepares standardized data for analysis.

3. **Gold Layer**: Creation of views that combine and aggregate data for business/analytics requirments.

![Data Architecture](docs/data_flow_diagram.png)

The silver layer contains a total of twenty cleaned and normalized tables:

![Silver Layer ERD](docs/entity_relation_diagram.png)


## 📂 Repository Structure
```
sql-movie-data-warehouse/
│
├── datasets/                           # Raw CSV files containing data used for the project
│   ├── tmdb_5000_credits.csv           # CSV file with movie cast and crew data
│   └── tmdb_5000_movies.csv            # CSV file with movie metadata
│
├── docs/                               # Project documentation and support files
│   ├── data_flow_diagram.html          # HTML file of diagram showing data flow through architecture layers
│   ├── data_flow_diagram.png           # PNG file of diagram showing data flow through architecture layers
│   ├── entity_relation_diagram.html    # HTML file of diagram showing network of silver layer tables
│   └── entity_relation_diagram.html    # PNG file of diagram showing network of silver layer tables
│
├── scripts/                            # SQL scripts for creating the data warehouse
│   ├── bronze_create_database.sql      # Script for creating database and reading raw CSV files
│   ├── silver_1_create_tables.sql      # Script for creating/extracting tables from raw data
│   ├── silver_2_clean_tables.sql       # Script for cleaning and normalizing tables
│   ├── silver_3_create_keys.sql        # Script for declaring primary and foreign keys
│   └── gold_create_views.sql           # Script for creating views based on clean tables
│
└── README.md                           # Project summary and instructions
```

