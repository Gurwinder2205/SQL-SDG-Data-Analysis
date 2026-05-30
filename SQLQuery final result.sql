SELECT * FROM [SDG]


EXEC sp_rename 'SDG_Cleaned', 'SDG_Final';



SELECT name
FROM sys.views
WHERE name = 'SDG_Final';


SELECT TOP 5 *
FROM SDG;


SELECT TOP 5 *
FROM SDG_Final;

SELECT
    country_code,
    year,
    indicator_code,
    COUNT(*) AS duplicate_count
FROM SDG_Final
GROUP BY
    country_code,
    year,
    indicator_code
HAVING COUNT(*) > 1;


SELECT *
INTO SDG_Cleaned_Table
FROM SDG_Final;


SELECT COUNT(*) AS total_rows
FROM SDG_Cleaned_Table;


ALTER TABLE SDG_Cleaned_Table
ADD duplicate_flag VARCHAR(10);


UPDATE SDG_Cleaned_Table
SET duplicate_flag = 'No';


WITH DuplicateKeys AS
(
    SELECT
        country_code,
        year,
        indicator_code
    FROM SDG_Cleaned_Table
    GROUP BY country_code, year, indicator_code
    HAVING COUNT(*) > 1
)
UPDATE s
SET duplicate_flag = 'Yes'
FROM SDG_Cleaned_Table s
INNER JOIN DuplicateKeys d
ON s.country_code = d.country_code
AND s.year = d.year
AND s.indicator_code = d.indicator_code;



SELECT duplicate_flag, COUNT(*) AS total_rows
FROM SDG_Cleaned_Table
GROUP BY duplicate_flag;


ALTER TABLE SDG_Cleaned_Table
ADD plausible_range_flag VARCHAR(20);



UPDATE SDG_Cleaned_Table
SET plausible_range_flag =
CASE
    WHEN LOWER(unit) = 'percent'
         AND (value_num < 0 OR value_num > 100)
    THEN 'Out of Range'

    WHEN value_num < 0
    THEN 'Negative Value'

    ELSE 'Valid'
END;


SELECT
    plausible_range_flag,
    COUNT(*) AS total_rows
FROM SDG_Cleaned_Table
GROUP BY plausible_range_flag;


SELECT TOP 20 last_updated
FROM SDG_Cleaned_Table;



CREATE TABLE Cleaning_Log
(
    issue_id INT IDENTITY(1,1) PRIMARY KEY,
    observation_id INT,
    issue_type VARCHAR(50),
    decision VARCHAR(50),
    reason VARCHAR(255),
    analyst_initials VARCHAR(10)
);



INSERT INTO Cleaning_Log
(
    observation_id,
    issue_type,
    decision,
    reason,
    analyst_initials
)
SELECT
    observation_id,
    'Duplicate',
    'Retained',
    'Duplicate natural key identified',
    'GS'
FROM SDG_Cleaned_Table
WHERE duplicate_flag = 'Yes';




INSERT INTO Cleaning_Log
(
    observation_id,
    issue_type,
    decision,
    reason,
    analyst_initials
)
SELECT
    observation_id,
    'Range',
    'Escalated',
    'Percent value outside 0-100 range',
    'GS'
FROM SDG_Cleaned_Table
WHERE plausible_range_flag = 'Out of Range';



SELECT *
FROM Cleaning_Log;


Business Purpose: Preview the cleaned dataset and understand the structure.

SELECT TOP 20 *
FROM SDG_Cleaned_Table;


-Business Purpose: List all unique categories used in the dataset.

SELECT DISTINCT region
FROM SDG_Cleaned_Table;



SELECT DISTINCT income_group
FROM SDG_Cleaned_Table;



SELECT DISTINCT sdg_goal
FROM SDG_Cleaned_Table;



SELECT DISTINCT reporting_status
FROM SDG_Cleaned_Table;


-Business Purpose: Analyse SDG 4 education-related indicators between 2021 and 2024.

SELECT *
FROM SDG_Cleaned_Table
WHERE sdg_goal LIKE '%SDG 4%'
AND year BETWEEN 2021 AND 2024
ORDER BY country_name, year;


Business Purpose: Identify observations related to mortality, poverty, and electricity.

SELECT *
FROM SDG_Cleaned_Table
WHERE indicator_name LIKE '%mortality%'
   OR indicator_name LIKE '%poverty%'
   OR indicator_name LIKE '%electricity%';



  Business Purpose: Compare SDG observations across two major regions.

SELECT *
FROM SDG_Cleaned_Table
WHERE region IN ('South Asia', 'Sub-Saharan Africa')
AND year BETWEEN 2020 AND 2024
ORDER BY region, country_name, year;



 Business Purpose: Generate high-level dataset KPIs.

SELECT
    COUNT(*) AS total_observations,
    COUNT(DISTINCT country_code) AS unique_countries,
    COUNT(DISTINCT indicator_code) AS unique_indicators,
    COUNT(DISTINCT year) AS years_covered
FROM SDG_Cleaned_Table;



-- Business Purpose: Compare 2024 performance by region and indicator.

SELECT
    region,
    indicator_name,
    AVG(value_num) AS avg_value
FROM SDG_Cleaned_Table
WHERE year = 2024
AND value_num IS NOT NULL
GROUP BY
    region,
    indicator_name
ORDER BY
    region,
    indicator_name;



 Business Purpose: Identify areas with significant missing data.

SELECT
    region,
    indicator_name,
    COUNT(*) AS missing_count
FROM SDG_Cleaned_Table
WHERE value_num IS NULL
GROUP BY
    region,
    indicator_name
HAVING COUNT(*) > 10
ORDER BY missing_count DESC;



Business Purpose: Validate uniqueness of the natural key.

SELECT
    country_code,
    year,
    indicator_code,
    COUNT(*) AS duplicate_count
FROM SDG_Cleaned_Table
GROUP BY
    country_code,
    year,
    indicator_code
HAVING COUNT(*) > 1;


Business Purpose: Detect potentially invalid percentage values.

SELECT *
FROM SDG_Cleaned_Table
WHERE LOWER(unit) = 'percent'
AND (value_num < 0 OR value_num > 100);



-- Business Purpose: Create a reusable country reference table.

SELECT DISTINCT
    country_code,
    country_name,
    region,
    income_group
INTO country_dim
FROM SDG_Cleaned_Table;


-- Business Purpose: Create a reusable indicator reference table.

SELECT DISTINCT
    indicator_code,
    indicator_name,
    sdg_goal,
    unit
INTO indicator_dim




-- Business Purpose: Combine observation data with reference dimensions.

SELECT TOP 50
    o.observation_id,
    c.country_name,
    c.region,
    i.indicator_name,
    i.sdg_goal,
    o.year,
    o.value_num
FROM SDG_Cleaned_Table o
INNER JOIN country_dim c
    ON o.country_code = c.country_code
INNER JOIN indicator_dim i
    ON o.indicator_code = i.indicator_code;
FROM SDG_Cleaned_Table;



-- Business Purpose: Show all countries and their 2024 poverty observations.

SELECT
    c.country_name,
    p.value_num
FROM country_dim c
LEFT JOIN SDG_Cleaned_Table p
    ON c.country_code = p.country_code
    AND p.year = 2024
    AND p.indicator_code = 'SI.POV.NAHC'
ORDER BY c.country_name;



-- Business Purpose: Find the latest available value for every country and indicator.

WITH LatestValues AS
(
    SELECT *,
           ROW_NUMBER() OVER
           (
               PARTITION BY country_code, indicator_code
               ORDER BY year DESC
           ) AS rn
    FROM SDG_Cleaned_Table
)
SELECT *
FROM LatestValues
WHERE rn = 1;




-- Business Purpose: Rank countries within each region by internet usage.

WITH InternetData AS
(
    SELECT
        country_name,
        region,
        value_num
    FROM SDG_Cleaned_Table
    WHERE indicator_code = 'IT.NET.USER.ZS'
)
SELECT
    country_name,
    region,
    value_num,
    RANK() OVER
    (
        PARTITION BY region
        ORDER BY value_num DESC
    ) AS region_rank
FROM InternetData;



SELECT
    sdg_goal,
    COUNT(*) AS total_records,
    SUM(CASE WHEN value_num IS NULL THEN 1 ELSE 0 END) AS missing_values
FROM SDG_Cleaned_Table
GROUP BY sdg_goal
ORDER BY total_records DESC;


SELECT
    region,
    AVG(CASE WHEN year = 2017 THEN value_num END) AS avg_2017,
    AVG(CASE WHEN year = 2024 THEN value_num END) AS avg_2024,
    AVG(CASE WHEN year = 2024 THEN value_num END)
    - AVG(CASE WHEN year = 2017 THEN value_num END) AS improvement
FROM SDG_Cleaned_Table
WHERE indicator_code = 'SE.SEC.ENRR'
GROUP BY region
ORDER BY improvement DESC;



SELECT
    country_name,
    region,
    indicator_name,
    AVG(value_num) AS avg_value
FROM SDG_Cleaned_Table
WHERE indicator_code IN ('SI.POV.NAHC','SH.DYN.MORT')
GROUP BY
    country_name,
    region,
    indicator_name
ORDER BY avg_value DESC;


SELECT
    country_name,
    region,
    MIN(CASE WHEN year = 2017 THEN value_num END) AS value_2017,
    MAX(CASE WHEN year = 2024 THEN value_num END) AS value_2024,
    MAX(CASE WHEN year = 2024 THEN value_num END)
      - MIN(CASE WHEN year = 2017 THEN value_num END) AS improvement
FROM SDG_Cleaned_Table
WHERE indicator_code = 'IT.NET.USER.ZS'
GROUP BY
    country_name,
    region
ORDER BY improvement DESC;



SELECT
    income_group,
    indicator_name,
    AVG(value_num) AS avg_value
FROM SDG_Cleaned_Table
WHERE indicator_code IN
(
    'EN.ATM.CO2E.PC',
    'AG.LND.FRST.ZS',
    'ER.H2O.FWTL.ZS'
)
GROUP BY
    income_group,
    indicator_name
ORDER BY
    indicator_name,
    income_group;



    SELECT
    COUNT(*) AS duplicate_records
FROM SDG_Cleaned_Table
WHERE duplicate_flag = 'Yes';

SELECT
    COUNT(*) AS out_of_range_records
FROM SDG_Cleaned_Table
WHERE plausible_range_flag = 'Out of Range';