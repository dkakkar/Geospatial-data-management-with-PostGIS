
-- SECTION 1: Download and copy tutorial dataset
--

Download data from : https://github.com/dkakkar/Geospatial-data-management-with-PostGIS/tree/master/data


ssh to ubuntu server and :

Cd /home
sudo mkdir data
sudo chown ubuntu:ubuntu data

Go to your local folder where data is downloaded and type the following in command line:

scp -r -i ~/.ssh/test-postgis.pem data ubuntu@ec2-34-228-245-75.compute-1.amazonaws.com:/home

----------------------------------------------------------------
-- SECTION 2: Install gdal-bin and Load data
--

Go to Ubuntu server and run:

sudo add-apt-repository ppa:ubuntugis/ppa && sudo apt-get update
sudo apt-get install gdal-bin
Ogrinfo

Load data:

NYC neighborhoods:

ogr2ogr -nlt PROMOTE_TO_MULTI -overwrite -f "PostgreSQL" PG:"host=localhost user=dkakkar dbname=gisdata password=******" "/home/data/nyc_neighborhoods.shp" "nyc_neighborhoods"

NYC census blocks:

ogr2ogr -nlt PROMOTE_TO_MULTI -overwrite -f "PostgreSQL" PG:"host=localhost user=dkakkar dbname=gisdata password=******" "/home/data/nyc_census_blocks.shp" "nyc_census_blocks"

NYC streets:

ogr2ogr -nlt PROMOTE_TO_MULTI -overwrite -f "PostgreSQL" PG:"host=localhost user=dkakkar dbname=gisdata password=******" "/home/data/nyc_streets.shp" "nyc_streets"

NYC subway stations:

ogr2ogr -nlt PROMOTE_TO_MULTI -overwrite -f "PostgreSQL" PG:"host=localhost user=dkakkar dbname=gisdata password=******" "/home/data/nyc_subway_stations.shp" "nyc_subway_stations"


Connect to database:
psql -h localhost -U dkakkar gisdata

List tables:
 \d

List columns of table: 
 \d+ <tablename>


------------------------------------------------------------------------
-- SECTION 3: Simple SQL --
--

-- What are the names of the neighborhoods?
SELECT name FROM nyc_neighborhoods;

-- What are the names of all the neighborhoods in Brooklyn?
SELECT name FROM nyc_neighborhoods WHERE boroname = 'Brooklyn';

-- What is the number of letters in the names of all the 
-- neighborhoods in Brooklyn?
SELECT char_length(name) FROM nyc_neighborhoods WHERE boroname = 'Brooklyn';

-- What is the average number of letters and standard 
-- deviation of number of letters in the names of all the 
-- neighborhoods in Brooklyn?
SELECT avg(char_length(name)), stddev(char_length(name))FROM nyc_neighborhoods WHERE boroname = 'Brooklyn';

------------------------------------------------------------------------

-- SECTION 4: Geometry Exercises
--

-- What is the area of the 'West Village' neighborhood?
SELECT ST_Area(wkb_geometry)FROM nyc_neighborhoods WHERE name = 'West Village';

-- What is the geometry type of 'Pelham St'? The length?
SELECT ST_GeometryType(wkb_geometry), ST_Length(wkb_geometry)
FROM nyc_streets WHERE name = 'Pelham St';

-- What is the GML representation of ‘Broad St’ subway station?
SELECT ST_AsGML(wkb_geometry)FROM nyc_subway_stations WHERE name = 'Broad St';

-- How many census blocks in New York City have a hole in them? 
SELECT Count(*)FROM nyc_census_blocks WHERE ST_NumInteriorRings(ST_GeometryN(wkb_geometry,1)) > 0;


-- What is the area of Manhattan in acres? 
SELECT Sum(ST_Area(wkb_geometry)) / 4047 FROM nyc_neighborhoods
WHERE boroname = 'Manhattan';
-- or
SELECT Sum(ST_Area(wkb_geometry)) / 4047 FROM nyc_census_blocks
WHERE boroname = 'Manhattan';

------------------------------------------------------------------------
-- SECTION 5: Spatial Relationships
--

-- What is the geometry representation of Broad St station?
SELECT wkb_geometry FROM nyc_subway_stations
WHERE name = 'Broad St';

-- Use that geometry representation to query back to get the name!
SELECT name FROM nyc_subway_stations WHERE ST_Equals(wkb_geometry, '0101000020266900000EEBD4CF27CF2141BC17D69516315141');

-- What neighborhood is that geometry in?
SELECT name, ST_AsText(wkb_geometry) FROM nyc_subway_stations 
WHERE name = 'Broad St';               

SELECT name, boroname FROM nyc_neighborhoods WHERE ST_Intersects(wkb_geometry, ST_GeomFromText('POINT(583571 4506714)',26918));

-- What is the distance between two geometries?
SELECT ST_Distance(ST_GeometryFromText('POINT(0 5)'),ST_GeometryFromText('LINESTRING(-2 2, 2 2)'));

-- What streets are near the Broad Street station?
SELECT name FROM nyc_streets WHERE ST_DWithin(
        wkb_geometry,
        ST_GeomFromText('POINT(583571 4506714)',26918),
        10
      );


------------------------------------------------------------------------
-- SECTION 6: Spatial Joins
--

-- What neighborhood is the 'Broad St' station in?
SELECT
  subways.name AS subway_name,
  neighborhoods.name AS neighborhood_name,
  neighborhoods.boroname AS borough
FROM nyc_neighborhoods AS neighborhoods
JOIN nyc_subway_stations AS subways
ON ST_Contains(neighborhoods.wkb_geometry, subways.wkb_geometry)
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
ON ST_Intersects(neighborhoods.wkb_geometry, census.wkb_geometry)
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
ON ST_DWithin(census.wkb_geometry, subways.wkb_geometry, 200)
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
ON ST_DWithin(census.wkb_geometry, subways.wkb_geometry, 200)
JOIN subway_lines AS lines
ON strpos(subways.routes, lines.route) > 0
GROUP BY lines.route
ORDER BY black_pct DESC;

------------------------------------------------------------------------
-- SECTION 7: Spatial Indexing
--


-- Add the index back
CREATE INDEX nyc_census_blocks_geom_gist ON nyc_census_blocks USING GIST (wkb_geometry);

-- Try the query(watch the timer)
SELECT blocks.blkid
FROM nyc_census_blocks blocks
JOIN nyc_subway_stations subways
ON ST_Contains(blocks.wkb_geometry, subways.wkb_geometry)
WHERE subways.name = 'Broad St';

-- Drop a spatial index
DROP INDEX nyc_census_blocks_geom_gist;

-- Try a query without the spatial index (watch the timer)
SELECT blocks.blkid
FROM nyc_census_blocks blocks
JOIN nyc_subway_stations subways
ON ST_Contains(blocks.wkb_geometry, subways.wkb_geometry)
WHERE subways.name = 'Broad St';



------------------------------------------------------------------------
-- SECTION 8: Projecting Data
--

-- What is the SRID of our data?
SELECT ST_SRID(wkb_geometry) FROM nyc_streets LIMIT 1;

-- What does SRID of 26918 mean?
SELECT proj4text FROM spatial_ref_sys WHERE srid = 26918;

-- What does the SRID of 4326 mean (in street)?
SELECT srtext FROM spatial_ref_sys WHERE srid = 4326;

-- What is the 4326 coordinate of Broad St station?
SELECT ST_AsText(ST_Transform(wkb_geometry,4326))
FROM nyc_subway_stations
WHERE name = 'Broad St';

-- What are the table-level SRID values for our geometries?
SELECT f_table_name AS name, srid
FROM geometry_columns;

------------------------------------------------------------------------
-- SECTION 9: Geography
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


------------------------------------------------------------------------
-- SECTION 10: Geometry Construction Exercises
--

-- How many census blocks don’t contain their own centroid?
SELECT Count(*) 
FROM nyc_census_blocks 
WHERE NOT ST_Contains(wkb_geometry, ST_Centroid(wkb_geometry));

-- What is the area of a one unit buffer around the origin? 
-- How different is it from what you would expect? Why?
SELECT ST_Area(ST_Buffer('POINT(0 0)', 1));
SELECT pi(), ST_Area(ST_Buffer('POINT(0 0)', 1, 100));

------------------------------------------------------------------------
-- SECTION 11: Validity
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
SELECT name, boroname, ST_IsValidReason(wkb_geometry)
FROM nyc_neighborhoods
WHERE NOT ST_IsValid(wkb_geometry);


------------------------------------------------------------------------
-- SECTION 12: Equality
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
-- SECTION 13: Connecting to QGIS


Go to : /etc/postgresql/9.6/main/ 

Edit pg_hba.conf to have the following lines:

#Database administrative login by unix domain socket
local   all             postgres                                md5
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    all             all             0.0.0.0/0               trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128               md5

Add the following lines to postgresql.conf:

listen_addresses = '*'

Open QGIS and connect to PostGIS database as below:

1. Click on PostGIS
2. Create a New PostGIS connection:
Name: Postgres
Host: ec2-52-206-154-125.compute-1.amazonaws.com (Public DNS of your EC2)
Database: gisdata
SSL mode: disable
Username: dkakkar (Your username)
Password: ******* (Your password)

 
Make Sure port 5432 is open in the Security Group of your EC2.

 
        

            
