------------------------------------------------------------------------
-- SECTION 3: Creating a Spatial Database --
--

-- What version of PostGIS do we have?
SELECT postgis_full_version();

------------------------------------------------------------------------
-- SECTION 4: Loading spatial data --
--

-- What SRS are we using?
SELECT srtext FROM spatial_ref_sys WHERE srid = 26918;

------------------------------------------------------------------------
-- SECTION 6: Simple SQL --
--

-- What are the names of the neighborhoods?
SELECT name FROM nyc_neighborhoods;

-- What are the names of all the neighborhoods in Brooklyn?
SELECT name
  FROM nyc_neighborhoods
  WHERE boroname = 'Brooklyn';

-- What is the number of letters in the names of all the 
-- neighborhoods in Brooklyn?
SELECT char_length(name)
  FROM nyc_neighborhoods
  WHERE boroname = 'Brooklyn';

-- What is the average number of letters and standard 
-- deviation of number of letters in the names of all the 
-- neighborhoods in Brooklyn?
SELECT avg(char_length(name)), stddev(char_length(name))
  FROM nyc_neighborhoods
  WHERE boroname = 'Brooklyn';

------------------------------------------------------------------------
-- SECTION 7: Simple SQL Exercises

-- How many records are in the nyc_streets table?
SELECT Count(*)  
 FROM nyc_streets;
 
-- What is the population of New York City?
SELECT Sum(popn_total) AS population
  FROM nyc_census_blocks;

-- What is the population of the Bronx?
SELECT Sum(popn_total) AS population
  FROM nyc_census_blocks
  WHERE boroname = 'The Bronx';

-- How many "neighborhoods" are in each borough?
SELECT Count(*), boroname  
  FROM nyc_neighborhoods 
  GROUP BY boroname;
 
-- For each borough, what percentage of the population is white?
SELECT
    boroname,
    100.0 * Sum(popn_white)/Sum(popn_total) AS white_pct
FROM nyc_census_blocks
GROUP BY boroname;

------------------------------------------------------------------------
-- SECTION 8: Geometries

-- Load example data table
CREATE TABLE geometries (name varchar, geom geometry);
INSERT INTO geometries VALUES
  ('Point', 'POINT(0 0)'),
  ('Linestring', 'LINESTRING(0 0, 1 1, 2 1, 2 2)'),
  ('Polygon', 'POLYGON((0 0, 1 0, 1 1, 0 1, 0 0))'),
  ('PolygonWithHole', 'POLYGON((0 0, 10 0, 10 10, 0 10, 0 0),(1 1, 1 2, 2 2, 2 1, 1 1))'),
  ('Collection', 'GEOMETRYCOLLECTION(POINT(2 0),POLYGON((0 0, 1 0, 1 1, 0 1, 0 0)))');
SELECT name, ST_AsText(geom) FROM geometries;

-- What does the geometry_columns table hold?
SELECT * FROM geometry_columns;

-- What are common features of all geometries?
SELECT name, ST_GeometryType(geom), ST_NDims(geom), ST_SRID(geom)
  FROM geometries;

-- What do points look like?
SELECT ST_AsText(geom)
  FROM geometries
  WHERE name = 'Point';

-- What are the components of a point?
SELECT ST_X(geom), ST_Y(geom)
  FROM geometries
  WHERE name = 'Point';

-- What do the subway station points look like?
SELECT name, ST_AsText(geom)
  FROM nyc_subway_stations
  LIMIT 1;

-- What do lines look like?
SELECT ST_AsText(geom)
  FROM geometries
  WHERE name = 'Linestring';

-- How long is our example line?
SELECT ST_Length(geom)
  FROM geometries
  WHERE name = 'Linestring';

-- What do our polygons look like?
SELECT ST_AsText(geom)
  FROM geometries
  WHERE name LIKE 'Polygon%';

-- What are the areas of our polygons?
SELECT name, ST_Area(geom)
  FROM geometries
  WHERE name LIKE 'Polygon%';

-- What does a collection look like?
SELECT name, ST_Area(geom)
  FROM geometries
  WHERE name = 'Collection';

-- How does what ST_GeomFromText accepts differ
-- form what ST_AsText emits?
SELECT ST_AsText(ST_GeometryFromText('LINESTRING(0 0 0,1 0 0,1 1 2)'));

-- Can we build from GML and output to JSON?
SELECT ST_AsGeoJSON(ST_GeomFromGML('<gml:Point><gml:coordinates>1,1</gml:coordinates></gml:Point>'));

-- How can we create a geometry? So many ways!!!
-- Using ST_GeomFromText with the SRID parameter
SELECT ST_GeomFromText('POINT(2 2)',4326);

-- Using ST_GeomFromText without the SRID parameter
SELECT ST_SetSRID(ST_GeomFromText('POINT(2 2)'),4326);

-- Using a ST_Make* function
SELECT ST_SetSRID(ST_MakePoint(2, 2), 4326);

-- Using PostgreSQL casting syntax and ISO WKT
SELECT ST_SetSRID('POINT(2 2)'::geometry, 4326);

-- Using PostgreSQL casting syntax and extended WKT
SELECT 'SRID=4326;POINT(2 2)'::geometry;



------------------------------------------------------------------------
-- SECTION 9: Geometry Exercises
--

-- What is the area of the 'West Village' neighborhood?
SELECT ST_Area(geom)
FROM nyc_neighborhoods
WHERE name = 'West Village';

-- What is the geometry type of 'Pelham St'? The length?
SELECT ST_GeometryType(geom), ST_Length(geom)
FROM nyc_streets
WHERE name = 'Pelham St';

-- What is the GML representation of ‘Broad St’ subway station?
SELECT ST_AsGML(geom)
FROM nyc_subway_stations
WHERE name = 'Broad St';

-- How many census blocks in New York City have a hole in them? 
SELECT Count(*)
FROM nyc_census_blocks
WHERE ST_NumInteriorRings(ST_GeometryN(geom,1)) > 0;

-- What is the most westerly subway station? 
SELECT ST_X(geom), name
FROM nyc_subway_stations
ORDER BY ST_X(geom) 
LIMIT 1;

-- What is the area of Manhattan in acres? 
SELECT Sum(ST_Area(geom)) / 4047
FROM nyc_neighborhoods
WHERE boroname = 'Manhattan';
-- or
SELECT Sum(ST_Area(geom)) / 4047
FROM nyc_census_blocks
WHERE boroname = 'Manhattan';

------------------------------------------------------------------------
-- SECTION 10: Spatial Relationships
--

-- What is the geometry representation of Broad St station?
SELECT geom
FROM nyc_subway_stations
WHERE name = 'Broad St';

-- Use that geometry representation to query back to get the name!
SELECT name
FROM nyc_subway_stations
WHERE ST_Equals(geom, '0101000020266900000EEBD4CF27CF2141BC17D69516315141');

-- What neighborhood is that geometry in?
SELECT name, ST_AsText(geom)
FROM nyc_subway_stations 
WHERE name = 'Broad St';               

SELECT name, boroname 
FROM nyc_neighborhoods
WHERE ST_Intersects(geom, ST_GeomFromText('POINT(583571 4506714)',26918));

-- What is the distance between two geometries?
SELECT ST_Distance(
  ST_GeometryFromText('POINT(0 5)'),
  ST_GeometryFromText('LINESTRING(-2 2, 2 2)'));

-- What streets are near the Broad Street station?
SELECT name
FROM nyc_streets
WHERE ST_DWithin(
        geom,
        ST_GeomFromText('POINT(583571 4506714)',26918),
        10
      );

------------------------------------------------------------------------
-- SECTION 11: Spatial Relationships Exercises
--

-- What is the well-known text for the street 'Atlantic Commons'? 
SELECT ST_AsText(geom)
  FROM nyc_streets
  WHERE name = 'Atlantic Commons';

-- What neighborhood and borough is 'LINESTRING(586782 4504202,586864 4504216)' () in?
SELECT name, boroname 
FROM nyc_neighborhoods 
WHERE ST_Intersects(
  geom,
  ST_GeomFromText('LINESTRING(586782 4504202,586864 4504216)', 26918)
);

-- How many people live within 50 meters of 'POINT(586782 4504202)'?
SELECT Sum(popn_total)
FROM nyc_census_blocks
WHERE ST_DWithin(
   geom,
   ST_GeomFromText('POINT(586782 4504202)', 26918),
   50
);

-- For ‘LINESTRING(0 0, 2 2)’ and ‘POINT(1 1)’ which of these relationships are true? 
-- Intersects, Touches, Contains, Disjoint, Overlaps, Crosses, Within.
SELECT 
  ST_Intersects(l,p), ST_Touches(l,p), 
  ST_Contains(l,p), ST_Disjoint(l,p), 
  ST_Overlaps(l,p), ST_Crosses(l,p), 
  ST_Within(l,p)
FROM ( 
  SELECT 
    ST_GeomFromText('LINESTRING(0 0, 2 2)') AS l, 
    ST_GeomFromText('POINT(1 1)') AS p 
) AS subquery;

-- How far apart are 'Columbus Cir' and 'Fulton Ave'?
SELECT ST_Distance(a.geom, b.geom)
FROM nyc_streets a, nyc_streets b
WHERE a.name = 'Fulton Ave' AND b.name = 'Columbus Cir';


------------------------------------------------------------------------
-- SECTION 12: Spatial Joins
--

-- What neighborhood is the 'Broad St' station in?
SELECT
  subways.name AS subway_name,
  neighborhoods.name AS neighborhood_name,
  neighborhoods.boroname AS borough
FROM nyc_neighborhoods AS neighborhoods
JOIN nyc_subway_stations AS subways
ON ST_Contains(neighborhoods.geom, subways.geom)
WHERE subways.name = 'Broad St';

-- What is the population and racial make-up of the neighborhoods 
-- of Manhattan?
SELECT
  neighborhoods.name AS neighborhood_name,
  Sum(census.popn_total) AS population,
  100.0 * Sum(census.popn_white) / Sum(census.popn_total) AS white_pct,
  100.0 * Sum(census.popn_black) / Sum(census.popn_total) AS black_pct
FROM nyc_neighborhoods AS neighborhoods
JOIN nyc_census_blocks AS census
ON ST_Intersects(neighborhoods.geom, census.geom)
WHERE neighborhoods.boroname = 'Manhattan'
GROUP BY neighborhoods.name
ORDER BY white_pct DESC;

-- What is the overall racial make-up of New York?
SELECT
  100.0 * Sum(popn_white) / Sum(popn_total) AS white_pct,
  100.0 * Sum(popn_black) / Sum(popn_total) AS black_pct,
  Sum(popn_total) AS popn_total
FROM nyc_census_blocks;

-- What do subway stop identifiers look like?
SELECT DISTINCT routes FROM nyc_subway_stations;

-- What are the stops on the A-Train?
SELECT DISTINCT routes
FROM nyc_subway_stations AS subways
WHERE strpos(subways.routes,'A') > 0;

-- What is the racial makeup of stops along the A-Train?
SELECT
  100.0 * Sum(popn_white) / Sum(popn_total) AS white_pct,
  100.0 * Sum(popn_black) / Sum(popn_total) AS black_pct,
  Sum(popn_total) AS popn_total
FROM nyc_census_blocks AS census
JOIN nyc_subway_stations AS subways
ON ST_DWithin(census.geom, subways.geom, 200)
WHERE strpos(subways.routes,'A') > 0;

-- What is the racial makeup of all New York Subway lines?
-- Create extra table
CREATE TABLE subway_lines ( route char(1) );
INSERT INTO subway_lines (route) VALUES 
('A'),('B'),('C'),('D'),('E'),('F'),('G'),
('J'),('L'),('M'),('N'),('Q'),('R'),('S'),
('Z'),('1'),('2'),('3'),('4'),('5'),('6'),
('7');
-- Run the query
SELECT
  lines.route,
  100.0 * Sum(popn_white) / Sum(popn_total) AS white_pct,
  100.0 * Sum(popn_black) / Sum(popn_total) AS black_pct,
  Sum(popn_total) AS popn_total
FROM nyc_census_blocks AS census
JOIN nyc_subway_stations AS subways
ON ST_DWithin(census.geom, subways.geom, 200)
JOIN subway_lines AS lines
ON strpos(subways.routes, lines.route) > 0
GROUP BY lines.route
ORDER BY black_pct DESC;

------------------------------------------------------------------------
-- SECTION 13: Spatial Joins Exercises
--

-- What subway station is in 'Little Italy'?
SELECT s.name
FROM nyc_subway_stations AS s
JOIN nyc_neighborhoods AS n
ON ST_Contains(n.geom, s.geom)
WHERE n.name = 'Little Italy';

-- What are all the neighborhoods served by the 6-train?
SELECT DISTINCT n.name, n.boroname
FROM nyc_subway_stations AS s
JOIN nyc_neighborhoods AS n
ON ST_Contains(n.geom, s.geom)
WHERE strpos(s.routes,'6') > 0;

-- After 9/11, the 'Battery Park' neighborhood was off-limits
-- for several days. How many people had to be evacuated?
SELECT Sum(popn_total)
FROM nyc_neighborhoods AS n
JOIN nyc_census_blocks AS c
ON ST_Intersects(n.geom, c.geom)
WHERE n.name = 'Battery Park';

-- What are the population density (people / km^2) of the 
-- 'Upper West Side' and 'Upper East Side'?
SELECT
  n.name,
  Sum(c.popn_total) / (ST_Area(n.geom) / 1000000.0) AS popn_per_sqkm
FROM nyc_census_blocks AS c
JOIN nyc_neighborhoods AS n
ON ST_Intersects(c.geom, n.geom)
WHERE n.name = 'Upper West Side'
OR n.name = 'Upper East Side'
GROUP BY n.name, n.geom;

------------------------------------------------------------------------
-- SECTION 14: Spatial Indexing
--

-- Drop a spatial index
DROP INDEX nyc_census_blocks_geom_gist;

-- Try a query without the spatial index (watch the timer)
SELECT blocks.blkid
FROM nyc_census_blocks blocks
JOIN nyc_subway_stations subways
ON ST_Contains(blocks.geom, subways.geom)
WHERE subways.name = 'Broad St';

-- Add the index back
CREATE INDEX nyc_census_blocks_geom_gist ON nyc_census_blocks USING GIST (geom);

-- Try the query again (watch the timer)
SELECT blocks.blkid
FROM nyc_census_blocks blocks
JOIN nyc_subway_stations subways
ON ST_Contains(blocks.geom, subways.geom)
WHERE subways.name = 'Broad St';

-- Index-only summary query (uses bounding boxes)
SELECT Sum(popn_total)
FROM nyc_neighborhoods neighborhoods
JOIN nyc_census_blocks blocks
ON neighborhoods.geom && blocks.geom
WHERE neighborhoods.name = 'West Village';

-- Standard summary query (uses exact test)
SELECT Sum(popn_total)
FROM nyc_neighborhoods neighborhoods
JOIN nyc_census_blocks blocks
ON ST_Intersects(neighborhoods.geom, blocks.geom)
WHERE neighborhoods.name = 'West Village';

------------------------------------------------------------------------
-- SECTION 15: Projecting Data
--

-- What is the SRID of our data?
SELECT ST_SRID(geom) FROM nyc_streets LIMIT 1;

-- What does SRID of 26918 mean?
SELECT proj4text FROM spatial_ref_sys WHERE srid = 26918;

-- What does the SRID of 4326 mean (in street)?
SELECT srtext FROM spatial_ref_sys WHERE srid = 4326;

-- What is the 4326 coordinate of Broad St station?
SELECT ST_AsText(ST_Transform(geom,4326))
FROM nyc_subway_stations
WHERE name = 'Broad St';

-- What are the table-level SRID values for our geometries?
SELECT f_table_name AS name, srid
FROM geometry_columns;

------------------------------------------------------------------------
-- SECTION 16: Projection Exercises
--

-- What is the SRID of the nyc_streets table?  
-- What projection does that SRID represent?
SELECT srid 
FROM geometry_columns 
WHERE f_table_name = 'nyc_streets';

SELECT srtext 
FROM spatial_ref_sys 
WHERE srid = 26918;

-- What is the length of all streets in New York, as measured in UTM 18?
SELECT Sum(ST_Length(geom))
FROM nyc_streets;

-- What is the length of all NY streets in Long Island stateplane?
SELECT Sum(ST_Length(
         ST_Transform(geom,2831)
       ))
FROM nyc_streets;

-- How many distinct streets cross the 74th meridian?
SELECT Count(*) 
FROM nyc_streets 
WHERE 
  ST_Intersects(
    ST_Transform(geom, 4326),
    ST_GeomFromText('LINESTRING(-74 40, -74 41)',4326)
  );

------------------------------------------------------------------------
-- SECTION 17: Geography
--

-- What is the cartesian "distance" from LAX to CDG?
SELECT ST_Distance(
  -- Los Angeles (LAX)
  ST_GeometryFromText('POINT(-118.4079 33.9434)', 4326),
  -- Paris (CDG)
  ST_GeometryFromText('POINT(2.5559 49.0083)', 4326)     
  );

-- What is the spheroidal distance from LAX to CDG?
SELECT ST_Distance(
  ST_GeographyFromText('POINT(-118.4079 33.9434)'), -- Los Angeles (LAX)
  ST_GeographyFromText('POINT(2.5559 49.0083)')     -- Paris (CDG)
  );

-- How close would a flight from LAX to CDG come to Iceland?
SELECT ST_Distance(
  -- LAX-CDG
  ST_GeographyFromText('LINESTRING(-118.4079 33.9434, 2.5559 49.0083)'),
  -- Iceland
  ST_GeographyFromText('POINT(-21.8628 64.1286)')
);

-- What are the cartesian *and* spherical distances 
-- between LAX and NRT (Tokyo Narita)
SELECT ST_Distance(
  ST_GeometryFromText('Point(-118.4079 33.9434)'),  -- LAX
  ST_GeometryFromText('Point(139.733 35.567)'))     -- NRT (Tokyo/Narita)
    AS geometry_distance,
ST_Distance(
  ST_GeographyFromText('Point(-118.4079 33.9434)'), -- LAX
  ST_GeographyFromText('Point(139.733 35.567)'))    -- NRT (Tokyo/Narita)
    AS geography_distance;

-- Make a geography table with subway stops
CREATE TABLE nyc_subway_stations_geog AS
SELECT
  Geography(ST_Transform(geom,4326)) AS geog,
  name,
  routes
FROM nyc_subway_stations;

-- Create a geography index on those subway stops
CREATE INDEX nyc_subway_stations_geog_gix
ON nyc_subway_stations_geog USING GIST (geog);

-- Make a geography table with airports
CREATE TABLE airports (
  code VARCHAR(3),
  geog GEOGRAPHY(Point)
);

-- Add airport data
INSERT INTO airports VALUES 
  ('LAX', 'POINT(-118.4079 33.9434)'),
  ('CDG', 'POINT(2.5559 49.0083)'),
  ('REK', 'POINT(-21.8628 64.1286)');

-- Calculate distances between all airports
SELECT a.code, a.code,
  ST_Distance(a.geog, b.geog)
FROM 
  airports a,
  airports b;

-- Run geometry functions on geography data
SELECT 
  code, 
  ST_X(geog::geometry) AS longitude 
FROM airports;


------------------------------------------------------------------------
-- SECTION 17: Geography Exercises
--

-- How far is New York from Seattle? What are the units of the answer?
SELECT ST_Distance(
         ST_GeogFromText('POINT(-74.0064 40.7142)'),
         ST_GeogFromText('POINT(-122.3331 47.6097)'));
    
-- What is the total length of all streets in New York, calculated on the spheroid?
SELECT Sum(ST_Length(Geography(ST_Transform(geom,4326))))
FROM nyc_streets;

-- Does 'POINT(1 2.0001)' intersect with 'POLYGON((0 0, 0 2, 2 2, 2 0, 0 0))' in geography? 
-- In geometry? Why the difference?

------------------------------------------------------------------------
-- SECTION 18: Constructive Functions
--

-- Centroid of a box
select st_astext(st_centroid('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))'));

-- Centroid of a box with a spiky gap
select st_astext(st_centroid('POLYGON((0 0, 0 1, 0.4 1, 0.5 0.1, 0.6 1, 1 1, 1 0, 0 0))'));

-- Centroid isn't inside
select st_contains(
'POLYGON((0 0, 0 1, 0.4 1, 0.5 0.1, 0.6 1, 1 1, 1 0, 0 0))'::geometry, 
 st_centroid('POLYGON((0 0, 0 1, 0.4 1, 0.5 0.1, 0.6 1, 1 1, 1 0, 0 0))'));

-- Point on surface is different
select st_astext(st_pointonsurface(
'POLYGON((0 0, 0 1, 0.4 1, 0.5 0.1, 0.6 1, 1 1, 1 0, 0 0))'
));

-- Point on surface is inside
select st_contains(
'POLYGON((0 0, 0 1, 0.4 1, 0.5 0.1, 0.6 1, 1 1, 1 0, 0 0))', 
st_astext(st_pointonsurface(
'POLYGON((0 0, 0 1, 0.4 1, 0.5 0.1, 0.6 1, 1 1, 1 0, 0 0))'
)));

-- New table with a Liberty Island 500m buffer zone
CREATE TABLE liberty_island_zone AS
SELECT 
  1 AS id, 
  ST_Buffer(geom, 500)::Geometry(Polygon,26918) AS geom
FROM nyc_census_blocks
WHERE blkid = '360610001001001';

ALTER TABLE liberty_island_zone ADD PRIMARY KEY (id);


-- Add a negative buffer too
INSERT INTO liberty_island_zone
SELECT 2 AS id, ST_Buffer(geom, -50)::Geometry(Polygon,26918) AS geom
FROM nyc_census_blocks
WHERE blkid = '360610001001001';

-- Intersection of two circles
SELECT ST_AsText(ST_Intersection(
  ST_Buffer('POINT(0 0)', 2),
  ST_Buffer('POINT(3 0)', 2)
));

-- Union of two circles
SELECT ST_AsText(ST_Union(
  ST_Buffer('POINT(0 0)', 2),
  ST_Buffer('POINT(3 0)', 2)
));


-- Use a substring on the block id to get the county id
-- There's five, that's good.
SELECT 
DISTINCT SubStr(blkid,1,5) AS countyid
FROM nyc_census_blocks;

-- An nyc_census_counties table by merging census blocks
CREATE TABLE nyc_census_counties AS
SELECT
  ST_Union(geom)::Geometry(MultiPolygon, 26918) AS geom,
  SubStr(blkid,1,5) AS countyid
FROM nyc_census_blocks
GROUP BY countyid;

ALTER TABLE nyc_census_counties ADD PRIMARY KEY (countyid);

-- Compare area of counties with area of original data
-- Old areas
SELECT SubStr(blkid,1,5) AS countyid, Sum(ST_Area(geom)) AS area
FROM nyc_census_blocks
GROUP BY countyid;
-- New areas
SELECT countyid, ST_Area(geom) AS area
FROM nyc_census_counties;


------------------------------------------------------------------------
-- SECTION 18: Geometry Construction Exercises
--

-- How many census blocks don’t contain their own centroid?
SELECT Count(*) 
FROM nyc_census_blocks 
WHERE NOT ST_Contains(geom, ST_Centroid(geom));

-- Union all the census blocks into a single output. 
-- What kind of geometry is it? How many parts does it have?
CREATE TABLE nyc_census_blocks_merge
AS SELECT ST_Union(geom)::Geometry(MultiPolygon,26918) AS geom
FROM nyc_census_blocks;

SELECT ST_GeometryType(geom)
FROM nyc_census_blocks_merge;

SELECT ST_NumGeometries(geom)
FROM nyc_census_blocks_merge;

-- What is the area of a one unit buffer around the origin? 
-- How different is it from what you would expect? Why?
SELECT ST_Area(ST_Buffer('POINT(0 0)', 1));
SELECT pi(), ST_Area(ST_Buffer('POINT(0 0)', 1, 100));

-- The Brooklyn neighborhoods of ‘Park Slope’ and ‘Carroll Gardens’ are going to war! 
-- Construct a polygon delineating a 100 meter wide DMZ on the border 
-- between the neighborhoods. What is the area of the DMZ?
CREATE TABLE brooklyn_dmz AS
SELECT
  ST_Intersection(
    ST_Buffer(ps.geom, 50),
    ST_Buffer(cg.geom, 50))::Geometry(Polygon,26918)
  AS geom
FROM
  nyc_neighborhoods ps,
  nyc_neighborhoods cg
WHERE ps.name = 'Park Slope'
AND cg.name = 'Carroll Gardens';

------------------------------------------------------------------------
-- SECTION 19: More spatial joins
--

-- Make the tracts table
CREATE TABLE nyc_census_tract_geoms AS
SELECT
  ST_Multi(ST_Union(geom))::Geometry(MultiPolygon,26918) AS geom,
  SubStr(blkid,1,11) AS tractid
FROM nyc_census_blocks
GROUP BY tractid;

-- Index the tractid
CREATE INDEX nyc_census_tract_geoms_tractid_idx 
ON nyc_census_tract_geoms (tractid);

-- Make the tracts table
CREATE TABLE nyc_census_tracts AS
SELECT
  g.geom::Geometry(MultiPolygon,26918),
  a.*
FROM nyc_census_tract_geoms g
JOIN nyc_census_sociodata a
ON g.tractid = a.tractid;

-- Index the geometries
CREATE INDEX nyc_census_tract_gidx ON nyc_census_tracts USING GIST (geom);

-- Add a primary key
ALTER TABLE nyc_census_tracts ADD PRIMARY KEY (tractid);


-- Top 10 neighborhoods with graduate degrees 
SELECT
  100.0 * Sum(t.edu_graduate_dipl) / Sum(t.edu_total) AS graduate_pct,
  n.name, n.boroname
FROM nyc_neighborhoods n
JOIN nyc_census_tracts t
ON ST_Intersects(n.geom, t.geom)
WHERE t.edu_total > 0
GROUP BY n.name, n.boroname
ORDER BY graduate_pct DESC
LIMIT 10;

-- Top 10 neighborhoods with graduate degrees
-- using a centroid-based condition
SELECT
  100.0 * Sum(t.edu_graduate_dipl) / Sum(t.edu_total) AS graduate_pct,
  n.name, n.boroname
FROM nyc_neighborhoods n
JOIN nyc_census_tracts t
ON ST_Contains(n.geom, ST_Centroid(t.geom))
WHERE t.edu_total > 0
GROUP BY n.name, n.boroname
ORDER BY graduate_pct DESC
LIMIT 10;


-- population of the people in New York 
SELECT Sum(popn_total)
FROM nyc_census_blocks;

-- population of the people in New York 
-- within 500 meters of a subway station
SELECT Sum(popn_total)
FROM nyc_census_blocks census
JOIN nyc_subway_stations subway
ON ST_DWithin(census.geom, subway.geom, 500);

-- population of the people in New York 
-- within 500 meters of a subway station
WITH distinct_blocks AS (
    SELECT DISTINCT ON (blkid) popn_total
    FROM nyc_census_blocks census
    JOIN nyc_subway_stations subway
    ON ST_DWithin(census.geom, subway.geom, 500)
)
SELECT Sum(popn_total)
FROM distinct_blocks;


------------------------------------------------------------------------
-- SECTION 20: Validity
--

-- Area of invalid figure-8 polygon
SELECT ST_Area('POLYGON((0 0, 0 1, 1 1, 2 1, 2 2, 1 2, 1 1, 1 0, 0 0))');

-- Validity test
SELECT ST_IsValid(
         'POLYGON((0 0, 0 1, 1 1, 2 1, 2 2, 1 2, 1 1, 1 0, 0 0))'
       );

-- Validity Reason
SELECT ST_IsValidReason('POLYGON((0 0, 0 1, 1 1, 2 1, 2 2, 1 2, 1 1, 1 0, 0 0))');

-- Find all the invalid neighborhood polygons and what their problem is
SELECT name, boroname, ST_IsValidReason(geom)
FROM nyc_neighborhoods
WHERE NOT ST_IsValid(geom);


------------------------------------------------------------------------
-- SECTION 21: Equality
--

-- Create example table
CREATE TABLE polygons (id integer, name varchar, poly geometry);
INSERT INTO polygons VALUES 
  (1, 'Polygon 1', 'POLYGON((-1 1.732,1 1.732,2 0,1 -1.732,
      -1 -1.732,-2 0,-1 1.732))'),
  (2, 'Polygon 2', 'POLYGON((-1 1.732,-2 0,-1 -1.732,1 -1.732,
      2 0,1 1.732,-1 1.732))'),
  (3, 'Polygon 3', 'POLYGON((1 -1.732,2 0,1 1.732,-1 1.732,
      -2 0,-1 -1.732,1 -1.732))'),
  (4, 'Polygon 4', 'POLYGON((-1 1.732,0 1.732, 1 1.732,1.5 0.866,
      2 0,1.5 -0.866,1 -1.732,0 -1.732,-1 -1.732,-1.5 -0.866,
      -2 0,-1.5 0.866,-1 1.732))'),
  (5, 'Polygon 5', 'POLYGON((-2 -1.732,2 -1.732,2 1.732, 
      -2 1.732,-2 -1.732))');


-- Exact equality
SELECT a.name, b.name, ST_OrderingEquals(a.poly, b.poly) 
FROM polygons a, polygons b
WHERE ST_OrderingEquals(a.poly, b.poly);

-- Spatial equality
SELECT a.name, b.name, ST_Equals(a.poly, b.poly) 
FROM polygons a, polygons b
WHERE ST_Equals(a.poly, b.poly);

-- Bounds equality
SELECT a.name, b.name, a.poly = b.poly
FROM polygons a, polygons b
WHERE a.poly = b.poly;


------------------------------------------------------------------------
-- SECTION 22: Linear Referencing
--

-- Simple example of locating a point half-way along a line
SELECT ST_LineLocatePoint('LINESTRING(0 0, 2 2)', 'POINT(1 1)');
-- Answer 0.5

-- What if the point is not on the line? It projects to closest point
SELECT ST_LineLocatePoint('LINESTRING(0 0, 2 2)', 'POINT(0 2)');
-- Answer 0.5


-- All the SQL below is in aid of creating the new event table
CREATE TABLE nyc_subway_station_events AS
-- We first need to get a candidate set of maybe-closest
-- streets, ordered by id and distance...
WITH ordered_nearest AS (
SELECT
  ST_GeometryN(streets.geom,1) AS streets_geom,
  streets.gid AS streets_gid,
  subways.geom AS subways_geom,
  subways.gid AS subways_gid,
  ST_Distance(streets.geom, subways.geom) AS distance
FROM nyc_streets streets
  JOIN nyc_subway_stations subways
  ON ST_DWithin(streets.geom, subways.geom, 200)
ORDER BY subways_gid, distance ASC
)
-- We use the 'distinct on' PostgreSQL feature to get the first
-- street (the nearest) for each unique street gid. We can then
-- pass that one street into st_line_locate_point along with
-- its candidate subway station to calculate the measure.
SELECT
  DISTINCT ON (subways_gid)
  subways_gid,
  streets_gid,
  ST_LineLocatePoint(streets_geom, subways_geom) AS measure,
  distance
FROM ordered_nearest;

-- Primary keys are useful for visualization softwares
ALTER TABLE nyc_subway_station_events ADD PRIMARY KEY (subways_gid);

-- Simple example of locating a point half-way along a line
SELECT ST_AsText(ST_LineInterpolatePoint('LINESTRING(0 0, 2 2)', 0.5));

-- Answer POINT(1 1)

-- New view that turns events back into spatial objects
CREATE OR REPLACE VIEW nyc_subway_stations_lrs AS
SELECT
  events.subways_gid,
  ST_LineInterpolatePoint(ST_GeometryN(streets.geom, 1), events.measure)::Geometry(Point,26918) AS geom,
  events.streets_gid
FROM nyc_subway_station_events events
JOIN nyc_streets streets
ON (streets.gid = events.streets_gid);



------------------------------------------------------------------------
-- SECTION 23: DE9IM
--

-- Polygon with line sticking in
SELECT ST_Relate(
         'LINESTRING(0 0, 2 0)',
         'POLYGON((1 -1, 1 1, 3 1, 3 -1, 1 -1))'
       );
       
-- Some test tables
CREATE TABLE lakes ( id serial primary key, geom geometry );
CREATE TABLE docks ( id serial primary key, good boolean, geom geometry );

-- Load a lake
INSERT INTO lakes ( geom )
 VALUES ( 'POLYGON ((100 200, 140 230, 180 310, 280 310, 390 270, 400 210, 320 140, 215 141, 150 170, 100 200))');

-- Load docks data
INSERT INTO docks ( geom, good )
 VALUES
       ('LINESTRING (170 290, 205 272)',true),
       ('LINESTRING (120 215, 176 197)',true),
       ('LINESTRING (290 260, 340 250)',false),
       ('LINESTRING (350 300, 400 320)',false),
       ('LINESTRING (370 230, 420 240)',false),
       ('LINESTRING (370 180, 390 160)',false);
       
-- How many good docks?       
SELECT docks.*
FROM docks JOIN lakes ON ST_Intersects(docks.geom, lakes.geom)
WHERE ST_Relate(docks.geom, lakes.geom, '1FF00F212');
-- Answer: our two good docks

-- Add an L-shaped dock.
INSERT INTO docks ( geom, good )
  VALUES ('LINESTRING (140 230, 150 250, 210 230)',true);
  
-- How many good docks now?  
SELECT docks.*
FROM docks JOIN lakes ON ST_Intersects(docks.geom, lakes.geom)
WHERE ST_Relate(docks.geom, lakes.geom, '1*F00F212');
-- Answer: our (now) three good docks
 
 
--
-- Data Quality testing 
--

-- Test nyc_census_blocks for overlaps
SELECT a.gid, b.gid
FROM nyc_census_blocks a, nyc_census_blocks b
WHERE ST_Intersects(a.geom, b.geom)
AND ST_Relate(a.geom, b.geom, '2********')
AND a.gid != b.gid
LIMIT 10;
-- Answer: 10, There's some funny business
 
-- Test nyc_streets for noding
SELECT a.gid, b.gid
FROM nyc_streets a, nyc_streets b
WHERE ST_Intersects(a.geom, b.geom)
  AND NOT ST_Relate(a.geom, b.geom, '****0****')
  AND a.gid != b.gid
LIMIT 10;
-- Answer: This happens, so the data is not end-noded.


------------------------------------------------------------------------
-- SECTION 24: Clustering on indexes
--

-- Cluster the blocks based on their spatial index
CLUSTER nyc_census_blocks USING nyc_census_blocks_geom_gist;

-- Make a geohash index
CREATE INDEX nyc_census_blocks_geohash ON nyc_census_blocks (ST_GeoHash(ST_Transform(geom,4326)));

-- Cluster the blocks based on their geohash
CLUSTER nyc_census_blocks USING nyc_census_blocks_geohash;

------------------------------------------------------------------------
-- SECTION 25: History tracking
--

-- Build a history table
CREATE TABLE nyc_streets_history (
  hid SERIAL PRIMARY KEY,
  gid INTEGER,
  id FLOAT8,
  name VARCHAR(200),
  oneway VARCHAR(10),
  type VARCHAR(50),
  geom GEOMETRY(MultiLinestring,26918),
  created TIMESTAMP,
  created_by VARCHAR(32),
  deleted TIMESTAMP,
  deleted_by VARCHAR(32)
  );
  
-- Populate history table with existing data
INSERT INTO nyc_streets_history
      (gid, id, name, oneway, type, geom, created, created_by)
      SELECT gid, id, name, oneway, type, geom, now(), current_user
        FROM nyc_streets;
        
-- Insert trigger function 
CREATE OR REPLACE FUNCTION nyc_streets_insert() RETURNS trigger AS
$$
  BEGIN
    INSERT INTO nyc_streets_history
      (gid, id, name, oneway, type, geom, created, created_by)
    VALUES
      (NEW.gid, NEW.id, NEW.name, NEW.oneway, NEW.type, NEW.geom,
       current_timestamp, current_user);
    RETURN NEW;
  END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER nyc_streets_insert_trigger
AFTER INSERT ON nyc_streets
    FOR EACH ROW EXECUTE PROCEDURE nyc_streets_insert();
    
-- Delete trigger function
CREATE OR REPLACE FUNCTION nyc_streets_delete() RETURNS trigger AS
$$
  BEGIN
    UPDATE nyc_streets_history
      SET deleted = current_timestamp, deleted_by = current_user
      WHERE deleted IS NULL and gid = OLD.gid;
    RETURN NULL;
  END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER nyc_streets_delete_trigger
AFTER DELETE ON nyc_streets
    FOR EACH ROW EXECUTE PROCEDURE nyc_streets_delete();
    
-- Update trigger function
CREATE OR REPLACE FUNCTION nyc_streets_update() RETURNS trigger AS
$$
  BEGIN

    UPDATE nyc_streets_history
      SET deleted = current_timestamp, deleted_by = current_user
      WHERE deleted IS NULL and gid = OLD.gid;

    INSERT INTO nyc_streets_history
      (gid, id, name, oneway, type, geom, created, created_by)
    VALUES
      (NEW.gid, NEW.id, NEW.name, NEW.oneway, NEW.type, NEW.geom,
       current_timestamp, current_user);

    RETURN NEW;

  END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER nyc_streets_update_trigger
AFTER UPDATE ON nyc_streets
    FOR EACH ROW EXECUTE PROCEDURE nyc_streets_update();
    
-- State of history one hour ago
-- Records must have been created at least an hour ago and
-- either be visible now (deleted is null) or deleted in the last hour
CREATE OR REPLACE VIEW nyc_streets_one_hour_ago AS
  SELECT * FROM nyc_streets_history
    WHERE created < (now() - '1hr'::interval)
    AND ( deleted IS NULL OR deleted > (now() - '1hr'::interval) );

-- State of history two minutes ago
-- Records must have been created at least an hour ago and
-- either be visible now (deleted is null) or deleted in the last hour
CREATE OR REPLACE VIEW nyc_streets_two_minutes_ago AS
  SELECT * FROM nyc_streets_history
    WHERE created < (now() - '1hr'::interval)
    AND ( deleted IS NULL OR deleted > (now() - '2min'::interval) );

-- View of changes made by 'postgres' user
CREATE OR REPLACE VIEW nyc_streets_postgres_edits AS
  SELECT * FROM nyc_streets_history
    WHERE created_by = 'postgres';


------------------------------------------------------------------------
-- SECTION 26: Tuning PostgreSQL for Spatial
--

-- Some parameters are run time!
SET maintenance_work_mem TO '128MB';
VACUUM ANALYZE;
SET maintenance_work_mem TO '16MB';


------------------------------------------------------------------------
-- SECTION 27: Security
--

-- A user account for the web app
CREATE USER app1;
-- Web app needs access to specific data tables
GRANT SELECT ON nyc_streets TO app1;

-- A generic role for access to PostGIS functionality
CREATE ROLE postgis_reader INHERIT;
-- Give that role to the web app
GRANT postgis_reader TO app1;

-- This works!
SELECT * FROM nyc_streets LIMIT 1;

-- This doesn't work!
SELECT ST_AsText(ST_Transform(geom, 4326))
  FROM nyc_streets LIMIT 1;

-- Need metadata table access  
GRANT SELECT ON geometry_columns TO postgis_reader;
GRANT SELECT ON geography_columns TO postgis_reader;
GRANT SELECT ON spatial_ref_sys TO postgis_reader;
  
-- This works now!
SELECT ST_AsText(ST_Transform(geom, 4326))
  FROM nyc_streets LIMIT 1;
  
  
-- Add insert/update/delete abilities to our web application
GRANT INSERT,UPDATE,DELETE ON nyc_streets TO app1;

-- Create the table without a geometry column
CREATE TABLE test (
  id INTEGER
);

-- Doesn't work!
-- Need writer role!

-- Make a postgis writer role
CREATE ROLE postgis_writer;

-- Start by giving it the postgis_reader powers
GRANT postgis_reader TO postgis_writer;

-- Add insert/update/delete powers for the PostGIS tables
GRANT INSERT,UPDATE,DELETE ON spatial_ref_sys TO postgis_writer;

-- Make app1 a PostGIS writer to see if it works!
GRANT postgis_writer TO app1;


------------------------------------------------------------------------
-- SECTION 28: Schemas
--

CREATE SCHEMA census;

-- Move table to schema
ALTER TABLE nyc_census_blocks SET SCHEMA census;

-- Reference with full path
SELECT * FROM census.nyc_census_blocks LIMIT 1;

-- Or add schema to path
SET search_path = census, public;

-- Or add path to user
ALTER USER postgres SET search_path = census, public;

-- User isolation
-- New user with basic privs
CREATE USER myuser WITH ROLE postgis_writer;
-- Schema for that user
CREATE SCHEMA myuser AUTHORIZATION myuser;

-- connect as 'myuser'
-- then,
show search_path;
-- show create table and other stuffs


------------------------------------------------------------------------
-- SECTION 29: Backup and restore
--



