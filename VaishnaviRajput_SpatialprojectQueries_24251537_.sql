---Name :Vaishnavi Rajput
---Studentid: 24251537
---Spatial Database Project

select * from dentistireland
select * from countylayer


---1)How many dental clinics are situated within a 1 km radius of Logic House in Maynooth, considering geographic proximity?

DROP VIEW IF EXISTS Dentists_near_Logic_House;

CREATE OR REPLACE VIEW Dentists_near_Logic_House AS
SELECT
    d.*,
    ST_Distance(
        ST_Transform(m.wkb_geometry, 2157),
        ST_Transform(d.wkb_geometry, 2157)
    ) AS distance_to_logic_house
FROM
    dentistireland d,
    (SELECT wkb_geometry FROM maynoothlayer WHERE name = 'Logic House') m
WHERE
    ST_Distance(
        ST_Transform(m.wkb_geometry, 2157),
        ST_Transform(d.wkb_geometry, 2157)
    ) <= 1000
ORDER BY
    distance_to_logic_house;




---2) What is the number of dentists within a 5 km buffer zone around Maynooth and Dublin, and how does this compare in terms of geographic accessibility and service availability?
SELECT
    'Maynooth' AS city,
    COUNT(*) AS dentists_within_radius
FROM maynoothdentist
WHERE ST_Distance(
        wkb_geometry,
        ST_SetSRID(ST_MakePoint(-6.593, 53.380), 4326)
    ) <= 5000 -- 5 km radius

UNION ALL

SELECT
    'Dublin',
    COUNT(*)
FROM dentistireland
WHERE ST_Distance(
        wkb_geometry,
        ST_SetSRID(ST_MakePoint(-6.2603, 53.3498), 4326)
    ) <= 5000;
----3) How can the spatial distribution of clinics be analyzed to determine the count within each state, leveraging advanced geospatial techniques for accurate aggregation and visualization?
Alter Table countylayer ADD COLUMN NumCasesDensity REAL DEFAULT 0.0;
SELECT ogc_fid,name_tag,NumCasesDensity from countylayer;


SELECT Polys.ogc_fid,Polys.name_tag,count(*)/(ST_AREA(ST_TRANSFORM(Polys.wkb_geometry,32629))/1000000) as CasesPerKM2
FROM countylayer as Polys, dentistireland as pts
where ST_CONTAINS(POLYS.wkb_geometry,Pts.wkb_geometry)
GROUP BY Polys.ogc_fid;


SELECT Polys.ogc_fid,Polys.name_tag,Polys.NumCases,
(ST_AREA(ST_TRANSFORM(Polys.wkb_geometry,32629))/1000000) as PolyAreaKM2
FROM countylayer as Polys order by PolyAreaKM2 desc;


WITH PolygonQuery AS (
  SELECT 
    Polys.ogc_fid,         -- Primary key of the polygon
    Polys.name_tag,        -- Name tag of the polygon
    COUNT(*)/(ST_AREA(ST_TRANSFORM(Polys.wkb_geometry,32629))/1000000) as CasesPerKM2 -- Count of points within the polygon
  FROM 
    countylayer AS Polys,
    dentistireland AS pts
  WHERE 
    ST_CONTAINS(Polys.wkb_geometry, pts.wkb_geometry) -- Correct geometry reference
  GROUP BY 
    Polys.ogc_fid, Polys.name_tag -- Group by polygon identifiers
)
UPDATE 
  countylayer 
SET 
  NumCasesDensity = PolygonQuery.CasesPerKM2 -- Update the NumCases column
FROM 
  PolygonQuery
WHERE 
  PolygonQuery.ogc_fid = countylayer.ogc_fid; -- Match polygons by primary key

SELECT ogc_fid, name_tag,NumCasesDensity,NumCases,
ST_AREA(ST_TRANSFORM(wkb_geometry,32629))/1000000 as EDAREA
FROM countylayer
ORDER BY NumCasesDensity DESC 
LIMIT 10;

---4)How does the spatial distribution of dentists per 1,000 people vary across different regions, and what geographic or demographic factors influence these variations?


SELECT 
    c.name_tag, 
    COUNT(d.ogc_fid) AS total_dentists
FROM 
    countylayer AS c
LEFT JOIN 
    dentistireland AS d
ON 
    ST_Contains(c.wkb_geometry, d.wkb_geometry) -- Check if dentist is within the county boundary
GROUP BY 
    c.name_tag
ORDER BY 
    total_dentists DESC;

Alter Table countylayer ADD COLUMN NumCasesDensity REAL DEFAULT 0.0;
SELECT ogc_fid,name_tag,NumCasesDensity from countylayer;

SELECT Polys.ogc_fid,Polys.name_tag,count(*)/(ST_AREA(ST_TRANSFORM(Polys.wkb_geometry,32629))/1000000) as CasesPerKM2
FROM countylayer as Polys, dentistireland as pts
where ST_CONTAINS(POLYS.wkb_geometry,Pts.wkb_geometry)
GROUP BY Polys.ogc_fid;


SELECT Polys.ogc_fid,Polys.name_tag,Polys.NumCases,
(ST_AREA(ST_TRANSFORM(Polys.wkb_geometry,32629))/1000000) as PolyAreaKM2
FROM countylayer as Polys order by PolyAreaKM2 desc;


WITH PolygonQuery AS (
  SELECT 
    Polys.ogc_fid,         -- Primary key of the polygon
    Polys.name_tag,        -- Name tag of the polygon
    COUNT(*)/(ST_AREA(ST_TRANSFORM(Polys.wkb_geometry,32629))/1000000) as CasesPerKM2 -- Count of points within the polygon
  FROM 
    countylayer AS Polys,
    dentistireland AS pts
  WHERE 
    ST_CONTAINS(Polys.wkb_geometry, pts.wkb_geometry) -- Correct geometry reference
  GROUP BY 
    Polys.ogc_fid, Polys.name_tag -- Group by polygon identifiers
)
UPDATE 
  countylayer 
SET 
  NumCasesDensity = PolygonQuery.CasesPerKM2 -- Update the NumCases column
FROM 
  PolygonQuery
WHERE 
  PolygonQuery.ogc_fid = countylayer.ogc_fid; -- Match polygons by primary key

SELECT ogc_fid, name_tag,NumCasesDensity,NumCases,
ST_AREA(ST_TRANSFORM(wkb_geometry,32629))/1000000 as EDAREA
FROM countylayer
ORDER BY NumCasesDensity DESC 
LIMIT 10;

ALTER TABLE countylayer ADD COLUMN EstimatedPopulation REAL;

UPDATE countylayer
SET EstimatedPopulation = 
    (ST_AREA(ST_TRANSFORM(wkb_geometry, 32629)) / 1000000) * 72;

ALTER TABLE countylayer ADD COLUMN DentistsPer1000Population REAL;

UPDATE countylayer
SET DentistsPer1000Population = 
    (COALESCE(NumCases, 0) / NULLIF(EstimatedPopulation, 0)) * 1000;

SELECT name_tag AS County, EstimatedPopulation, DentistsPer1000Population
FROM countylayer
ORDER BY DentistsPer1000Population DESC;


---5)Which counties in Ireland are currently underserved in terms of healthcare access, as indicated by having no clinics?

-- Create a table for underserved counties with zero clinics
CREATE TABLE underserved_dublin_counties AS
SELECT
    dl.name_tag AS region_name,
    dl.wkb_geometry
FROM
    countylayer dl
LEFT JOIN
    dentistireland dd
ON
    ST_Intersects(dl.wkb_geometry, dd.wkb_geometry)
GROUP BY
    dl.name_tag, dl.wkb_geometry
HAVING
    COUNT(dd.ogc_fid) = 0;

----Thank you
