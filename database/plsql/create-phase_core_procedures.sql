drop procedure if exists add_street;
DELIMITER $$
create procedure add_street(
	in in_streetName VARCHAR(45), in in_streetDirection VARCHAR(45), in in_beginLatitude decimal(6,3), 
	in in_beginLongitude  decimal(6,3), in in_endLatitude  decimal(6,3), in in_endLongitude  decimal(6,3))

begin
	declare uuid varchar(36);
	SET uuid = (select UUID());
	INSERT INTO Street
		(streetID, streetName, streetDirection, beginLatitude, beginLongitude, endLatitude, endLongitude)
	VALUES
		(uuid, in_streetName, in_streetDirection, in_beginLatitude, in_beginLongitude,
		in_endLatitude, in_endLongitude);
	select * from Street where streetID = uuid;

end$$
DELIMITER ;


/* Procedure to add intersection
*/
drop procedure if exists add_intersection;
DELIMITER $$
create procedure add_intersection(IN lat decimal(6,3), IN lon decimal(6,3))
begin
	declare uuid varchar(36);
    SET uuid = (select uuid());
	insert into Intersection values (uuid, lat, lon);
    select * from Intersection where intersectionID = uuid;
END$$
DELIMITER ;


/*
	Procedure to add intersectionStreet
*/
drop procedure if exists add_intersectionStreet;
DELIMITER $$
CREATE PROCEDURE add_intersectionStreet(IN intersectionID VARCHAR(36), IN streetID VARCHAR(36), streetPM DECIMAL(6, 3))
begin
	DECLARE uuid VARCHAR(36);
	SET uuid = (SELECT UUID());
	INSERT INTO IntersectionStreet
		(intersectionStreetID, intersectionID, streetID, streetPostmile)
	VALUES
		(uuid, intersectionID, streetID, streetPM);
	SELECT * FROM IntersectionStreet WHERE intersectionStreetID = uuid;
END$$
DELIMITER ;

/*
	Procedure to add intersection with intersectionstreet
*/
DROP PROCEDURE IF EXISTS add_intersection_w_IS;
DELIMITER $$
CREATE PROCEDURE add_intersection_w_IS(IN lat DECIMAL(6, 3), IN lon DECIMAL(6, 3), IN sID VARCHAR(36), sPM DECIMAL(6, 3))
BEGIN
	DECLARE uuid VARCHAR(36);
    DECLARE is_uuid VARCHAR(36);
    SET uuid = (SELECT uuid());
	INSERT INTO Intersection VALUES (uuid, lat, lon);
    SELECT * FROM Intersection WHERE intersectionID = uuid;

	SET is_uuid = (SELECT uuid());
	INSERT INTO IntersectionStreet VALUES(is_uuid, uuid, sID, sPM);
	SELECT * FROM IntersectionStreet WHERE intersectionStreetID = is_uuid;
END $$
DELIMITER ;

/* Procedure to add a phase
*/
drop procedure if exists add_phase;
DELIMITER $$
create procedure add_phase(in in_phaseTypeID varchar(36), in in_intersectionID varchar(36))
begin
	declare uuid varchar(36);
    set uuid = (select UUID());
	INSERT INTO Phase
		(phaseID, phaseTypeID, intersectionID)
	VALUES
		(uuid, in_phaseTypeID, in_intersectionID);

    select * from Phase where phaseID = uuid;
end$$
DELIMITER ;

/*
	Adds nodes to the node table
*/
drop procedure if exists add_node;
DELIMITER $$
create procedure add_node(
IN in_nodeDescription VARCHAR(100), IN in_intersectionID varchar(36), IN in_ipaddress varchar(15), IN in_isalive boolean)
begin
	declare uuid varchar(36);
    SET uuid = (select uuid());
	insert into Node(NodeID, nodeDescription, intersectionID, ipAddress, isAlive) values(uuid, in_nodeDescription, in_intersectionID, in_ipaddress, in_isalive);
    select * from Node where NodeID = uuid;
END$$
DELIMITER ;


 /*
	This will update or insert a light.
    To update a light pass in_id, to insert pass null to in_id
*/
drop procedure if exists add_light;
DELIMITER $$
create procedure add_light(IN in_node_id varchar(36), IN in_light_phase int, IN in_light_rowID int, IN in_state varchar(100))
begin
	declare temp_id varchar(36);
    set temp_id = (select UUID());
	insert into Light(lightID, nodeID, lightPhase, lightRowID, state) values (temp_id, in_node_id, in_light_phase, in_light_rowID, in_state);
	-- can also do a Trigger before insert but this makes it so only update_light does it.
-- 	WITH light_update AS (
-- 		select id, ROW_NUMBER() OVER (PARTITION BY node_id) as new_row_num
-- 		FROM light
-- 		WHERE node_id = IN_NODE_ID
-- 	)update light set light_id = (select light_update.new_row_num from light_update where light.id = light_update.id) WHERE node_id = IN_NODE_ID AND light.id = temp_id;
    select * from Light where lightID = temp_id;
END$$
DELIMITER ;

drop procedure if exists get_phase_stream;
DELIMITER $$
create procedure get_phase_stream(IN in_intersection_in varchar(36))
begin
with colors as (
select *, 
case  
	WHEN state = 'RED' then 1
    ELSE 0
END as reds,
case  
	WHEN state = 'GREEN' then 1
    ELSE 0
END as greens,
case  
	WHEN state = 'YELLOW' then 1
    ELSE 0
END as yellows
from Phase_vw where intersectionID = in_intersection_in
order by phaseRowId
), color_str as(
select 
	lpad(CONV(group_concat(colors.reds order by phaseRowId desc SEPARATOR ''), 2, 16), 2, '0') red_str,
	lpad(CONV(group_concat(colors.greens order by phaseRowId desc SEPARATOR ''), 2, 16), 2, '0') green_str,
    lpad(CONV(group_concat(colors.yellows order by phaseRowId desc SEPARATOR ''), 2, 16), 2, '0') yellow_str
from colors
), cnt_str as(
	select lpad(CONV(count(*), 10, 16), 2, '0') num_of_phases from Phase where intersectionID = in_intersection_in
), phase_str as (
select group_concat(concat(lpad(CONV(Phase.phaseRowId, 10, 16), 2, '0'), ':', '00:00:00:00:00:00:00:00:00:00:00:00') SEPARATOR ':') phase_str from Phase where intersectionID = in_intersection_in order by phaseRowId
)
select CONCAT('CD:', cnt_str.num_of_phases, ':', phase_str.phase_str, ':',
			  color_str.red_str, ':', color_str.yellow_str, ':', color_str.green_str, ':',
              '00:00:00:00:00:00:00:00:00') `data.data` from color_str, cnt_str, phase_str;
end$$
DELIMITER ;


call get_phase_stream('2e9b931f-a26c-11ec-ab9b-023e4cce1fdd');


select Light.* from Light natural join Node where intersectionID = 'e1e6fa41-a171-11ec-ab9b-023e4cce1fdd' order by lightPhase;

select * from Phase_vw where intersectionID = 'e1e6fa41-a171-11ec-ab9b-023e4cce1fdd';

select conv('F4', 16, 2);
select * from Intersection;

/*
	Updates a node, pass null to location, ipaddress or isalive to keep the original value
*/
DROP PROCEDURE IF EXISTS patch_node;
DELIMITER $$
create procedure patch_node(IN in_node_id varchar(36), 
							IN in_description VARCHAR(100), 
                            IN in_intersectionID VARCHAR(36), 
                            IN in_ipaddress varchar(15), 
                            IN in_isalive boolean)
begin
	if in_description is not null then
		update node set nodeDescription = in_description where nodeID = in_node_id;
	end if;
	if in_intersectionID is not null then
		update node set intersectionID = in_intersectionID WHERE nodeID = in_node_id;
	end if;
	if in_ipaddress is not null then
		update node set ipaddress = in_ipaddress where nodeID = in_node_id;
	end if;
	if in_isalive is not null then
		update node set isalive = in_isalive where nodeID = in_node_id;
	end if;
    select * from node where nodeID = in_node_id;
END $$
DELIMITER ;

/*
	Removes the node and it's children lights
*/
DROP PROCEDURE IF EXISTS remove_node;
DELIMITER $$
create procedure remove_node(IN in_node_id varchar(36))
begin
	delete from light where nodeID = in_node_id;
    delete from node where nodeID = in_node_id;
END$$
DELIMITER ;

/*
	This will update or insert a light.
    To update a light pass in_id, to insert pass null to in_id
*/
DROP PROCEDURE IF EXISTS update_light;
DELIMITER $$
create procedure update_light(IN in_id VARCHAR(36), 
								IN in_node_id VARCHAR(36), 
                                IN in_light_phase int, 
                                IN in_light_rowID INT,
                                IN in_state varchar(100))
begin
	declare temp_id VARCHAR(36);
	IF in_id is null then
		insert into light(nodeID, lightPhase, lightRowID, state) values ( in_node_id, in_light_phase, in_light_rowID, in_state);
        -- can also do a Trigger before insert but this makes it so only update_light does it.
        set temp_id = last_insert_id();
        WITH light_update AS (
			select lightID, ROW_NUMBER() OVER (PARTITION BY nodeID) as new_row_num
			FROM light
			WHERE nodeID = IN_NODE_ID
		) update light set lightID = (select light_update.new_row_num from light_update where light.lightID = light_update.lightID) WHERE nodeID = IN_NODE_ID AND light.lightID = temp_id;
	else
		update light set
			lightPhase = in_light_phase,
            state = in_state
		WHERE
			nodeID = in_node_id
			and lightID = in_id;
	END IF;
    select * from light where lightID = temp_id;
END$$
DELIMITER ;

/*
 This will update or insert a light.
	 To update a light pass in_id, to insert pass null to in_id
*/
drop procedure if exists add_light;
DELIMITER $$
create procedure add_light(IN in_node_id varchar(36), IN in_light_phase int, IN in_state varchar(100))
begin
 declare temp_id varchar(36);
	 set temp_id = (select UUID());
 insert into Light(lightID, nodeID, lightPhase, state) values (temp_id, in_node_id, in_light_phase, in_state);
 -- can also do a Trigger before insert but this makes it so only update_light does it.
-- 	WITH light_update AS (
-- 		select id, ROW_NUMBER() OVER (PARTITION BY node_id) as new_row_num
-- 		FROM light
-- 		WHERE node_id = IN_NODE_ID
-- 	)update light set light_id = (select light_update.new_row_num from light_update where light.id = light_update.id) WHERE node_id = IN_NODE_ID AND light.id = temp_id;
	 select * from Light where lightID = temp_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS patch_light;
DELIMITER $$
create procedure patch_light(IN in_id int, IN in_light_phase int, IN in_state varchar(100))
begin
	IF in_node_id IS NOT NULL THEN
		UPDATE Light SET nodeID = in_node_id WHERE lightID = in_id;
	END IF;
	if in_light_phase is not null then
		update Light set lightPhase = in_light_phase where lightID = in_id;
	end if;
    IF in_light_rowID IS NOT NULL THEN
		UPDATE Light set lightRowID = in_light_rowID WHERE lightID = in_id;
	END IF;
	if in_state is not null then
		update Light set state = in_state where lightID = in_id;
	end if;
    select * from light where lightID = in_id;
END $$
DELIMITER ;

 /*
	This will update a nodes phase status. eg. phase 3 is RED.
*/
DROP PROCEDURE IF EXISTS update_phase_status;
DELIMITER $$
create procedure update_phase_status(IN in_id VARCHAR(36), IN in_node_id varchar(36), IN in_phase int, IN in_state varchar(100))
begin
	update light set state = in_state 
    where nodeID = in_node_id 
    and lightPhase = in_phase
    AND lightID = in_id;
end$$
DELIMITER ;

DROP PROCEDURE IF EXISTS get_node_state_id;
DELIMITER $$
create procedure get_node_state_id(IN in_node_id VARCHAR(36), OUT out_ret varchar(64))

begin
	declare ret varchar(64);
    declare temp varchar(4);
    declare done int default false;
    declare c_binchunks cursor for
		select lpad(bin(lf.lightStateRefID), 4, '0') as nibble
        from Light as l, lightStateRef as lf
        where
			l.state = lf.state
            and l.node_id = in_node_id
		order by l.lightID;
    declare continue handler for not found set done = true;
    open c_binchunks;

    set ret = "";

    getString: LOOP
		FETCH c_binchunks INTO temp;
        IF done = true then
			leave getString;
        END IF;
        set ret = concat(ret, temp);
	END LOOP getString;

    close c_binchunks;
    set out_ret = ret;
    select in_node_id node_id,  ret;
END$$
DELIMITER ;


DROP PROCEDURE IF EXISTS has_image;
DELIMITER $$
create procedure has_image(IN IN_NODE_ID int)
begin
	declare temp_state_id varchar(64);
	call get_node_state_id(in_node_id, temp_state_id);
    select exists (select image_key from node_image where node_id = IN_NODE_ID and image_key = temp_state_id) as reg, temp_state_id as node_state; -- registered
end$$
DELIMITER ;


DROP PROCEDURE IF EXISTS update_node_image;
DELIMITER $$
create procedure update_node_image(in in_node_id int)
begin
	declare temp_state_id varchar(64);
    call get_node_state_id(in_node_id, temp_state_id);
    INSERT INTO node_image(image_key, node_id) VALUES (temp_state_id, in_node_id);
end$$
DELIMITER ;


DROP PROCEDURE IF EXISTS get_image_url;
DELIMITER $$
create procedure GET_IMAGE_URL(in in_node_id int)
begin
	declare temp_state_id varchar(64);
	call get_node_state_id(in_node_id, temp_state_id);
	select CONCAT(in_node_id, '_', temp_state_id, '.png') as fileName;
end $$
DELIMITER ;

/*
	Procedure to get a stream for a given intersection
*/
drop procedure if exists get_phase_stream;
DELIMITER $$
create procedure get_phase_stream(IN in_intersection_in varchar(36))
begin
with colors as (
select *,
case
	WHEN state = 'RED' then 1
    ELSE 0
END as reds,
case
	WHEN state = 'GREEN' then 1
    ELSE 0
END as greens,
case
	WHEN state = 'YELLOW' then 1
    ELSE 0
END as yellows
from Phase_vw where intersectionID = in_intersection_in
order by phaseRowId
), color_str as(
select
	lpad(CONV(group_concat(colors.reds order by phaseRowId desc SEPARATOR ''), 2, 16), 2, '0') red_str,
	lpad(CONV(group_concat(colors.greens order by phaseRowId desc SEPARATOR ''), 2, 16), 2, '0') green_str,
    lpad(CONV(group_concat(colors.yellows order by phaseRowId desc SEPARATOR ''), 2, 16), 2, '0') yellow_str
from colors
), cnt_str as(
	select lpad(CONV(count(*), 10, 16), 2, '0') num_of_phases from Phase where intersectionID = in_intersection_in
), phase_str as (
select group_concat(concat(lpad(CONV(Phase.phaseRowId, 10, 16), 2, '0'), ':', '00:00:00:00:00:00:00:00:00:00:00:00') SEPARATOR ':') phase_str from Phase where intersectionID = in_intersection_in order by phaseRowId
)
select CONCAT('CD:', cnt_str.num_of_phases, ':', phase_str.phase_str, ':',
			  color_str.red_str, ':', color_str.yellow_str, ':', color_str.green_str, ':',
              '00:00:00:00:00:00:00:00:00') `data.data` from color_str, cnt_str, phase_str;
end$$
DELIMITER ;

drop procedure if exists save_image;
DELIMITER $$
create procedure save_image(in p_nodeID varchar(36))
begin
	declare img varchar(100);
	SET img = (select concat(p_nodeID,'_', 
				group_concat(state, lightPhase order by lightRowID desc SEPARATOR '')) 
				from Light where nodeID = p_nodeID);
    insert into ImageFileName values (DEFAULT, img);
end$$
DELIMITER ;

drop procedure if exists  get_image;
DELIMITER $$
create procedure get_image(in p_nodeID varchar(36))
begin
	declare v_img varchar(100);
    declare v_fileName varchar(100);
    SET v_img = (select concat(p_nodeID,'_', 
				group_concat(state, lightPhase order by lightRowID desc SEPARATOR '')) 
				from Light where nodeID = p_nodeID);
    SET v_fileName = (select img from ImageFileName where img = v_img);
    if v_fileName is null then
		select 'NOT_REGISTERED', concat(v_img, '.png') as img;
    ELSE
		select 'REGISTERED', concat(v_img, '.png') as img;
    end if;
end$$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_imagefilename;
DELIMITER $$
CREATE PROCEDURE delete_imagefilename(IN id VARCHAR(36))
BEGIN
	UPDATE ImageFileName SET isDeleted = 1 WHERE imageFileNameID = id;
    SELECT * FROM ImageFileName WHERE imageFileNameID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_intersection;
DELIMITER $$
CREATE PROCEDURE delete_intersection(IN id VARCHAR(36))
BEGIN
	UPDATE Intersection SET isDeleted = 1 WHERE intersectionID = id;
    SELECT * FROM Intersection WHERE intersectionID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_intersection_andFK;
DELIMITER $$
CREATE PROCEDURE delete_intersection_andFK(IN id VARCHAR(36))
BEGIN
	UPDATE Intersection SET isDeleted = 1 WHERE intersectionID = id;
    SELECT * FROM Intersection WHERE intersectionID = id;
    
    UPDATE IntersectionStreet SET isDeleted = 1 WHERE intersectionID = id;
    SELECT * FROM IntersectionStreet WHERE intersectionID = id;
    
    UPDATE Node SET isDeleted = 1 WHERE intersectionID = id;
    SELECT * FROM Node WHERE nodeID = id;
    
    UPDATE Phase SET isDeleted = 1 WHERE intersectionID = id;
    SELECT * FROM Phase WHERE intersectionID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_intersectionstreet;
DELIMITER $$
CREATE PROCEDURE delete_intersectionstreet(IN id VARCHAR(36))
BEGIN
	UPDATE IntersectionStreet SET isDeleted = 1 WHERE intersectionStreetID = id;
    SELECT * FROM IntersectionStreet WHERE intersectionStreetID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_street;
DELIMITER $$
CREATE PROCEDURE delete_street(IN id VARCHAR(36))
BEGIN
	UPDATE Street SET isDeleted = 1 WHERE streetID = id;
    SELECT * FROM Street WHERE streetID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_street_andFK;
DELIMITER $$
CREATE PROCEDURE delete_street_andFK(IN id VARCHAR(36))
BEGIN
	UPDATE Street SET isDeleted = 1 WHERE streetID = id;
    SELECT * FROM Street WHERE streetID = id;
    
    UPDATE IntersectionStreet SET isDeleted = 1 WHERE streetID = id; 
    SELECT * FROM IntersectionStreet WHERE streetID = id;
    
    UPDATE Intersection SET isDeleted = 1 WHERE intersectionID IN 
		(SELECT intersectionID FROM IntersectionStreet WHERE streetID = id);
	SELECT * FROM Intersection WHERE intersectionID IN 
		(SELECT intersectionID FROM IntersectionStreet WHERE streetID = id);
        
	UPDATE Phase SET isDeleted = 1 WHERE intersectionID IN
		(SELECT intersectionID FROM IntersectionStreet WHERE streetID = id);
	SELECT * FROM Phase WHERE intersectionID IN 
		(SELECT intersectionID FROM IntersectionStreet WHERE streetID = id);
    UPDATE Node SET isDeleted = 1 WHERE intersectionID IN
		(SELECT intersectionID FROM IntersectionStreet WHERE streetID = id);
	SELECT * FROM Node WHERE intersectionID IN
		(SELECT intersectionID FROM IntersectionStreet WHERE streetID = id);
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_light;
DELIMITER $$
CREATE PROCEDURE delete_light(IN id VARCHAR(36))
BEGIN
	UPDATE Light SET isDeleted = 1 WHERE lightID = id;
    SELECT * FROM Light WHERE lightID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_lightstateref;
DELIMITER $$
CREATE PROCEDURE delete_lightstateref(IN id VARCHAR(36))
BEGIN
	UPDATE LightStateRef SET isDeleted = 1 WHERE lightStateRefID = id;
    SELECT * FROM LightStateRef WHERE lightStateRefID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_node;
DELIMITER $$
CREATE PROCEDURE delete_node(IN id VARCHAR(36))
BEGIN
	UPDATE Node SET isDeleted = 1 WHERE nodeID = id;
    SELECT * FROM Node WHERE nodeID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_phase;
DELIMITER $$
CREATE PROCEDURE delete_phase(IN id VARCHAR(36))
BEGIN
	UPDATE Phase SET isDeleted = 1 WHERE phaseID = id;
    SELECT * FROM Phase WHERE phaseID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS delete_phasetype;
DELIMITER $$
CREATE PROCEDURE delete_phasetype(IN id VARCHAR(36))
BEGIN
	UPDATE PhaseType SET isDeleted = 1 WHERE phaseTypeID = id;
    SELECT * FROM PhaseType WHERE phaesTypeID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS is_imagefilename_deleted;
DELIMITER $$
CREATE PROCEDURE is_imagefilename_deleted(IN id VARCHAR(36))
BEGIN
	SELECT isDeleted FROM ImageFileName WHERE imageFileNameID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS is_intersection_deleted;
DELIMITER $$
CREATE PROCEDURE is_intersection_deleted(IN id VARCHAR(36))
BEGIN
	SELECT isDeleted FROM Intersection WHERE intersectionID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS is_intersectionstreet_deleted;
DELIMITER $$
CREATE PROCEDURE is_intersectionstreet_deleted(IN id VARCHAR(36))
BEGIN
	SELECT isDeleted FROM IntersectionStreet WHERE intersectionStreetID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS is_light_deleted;
DELIMITER $$
CREATE PROCEDURE is_light_deleted(IN id VARCHAR(36))
BEGIN
	SELECT isDeleted FROM Light WHERE lightID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS is_lightstateref_deleted;
DELIMITER $$
CREATE PROCEDURE is_lightstateref_deleted(IN id VARCHAR(36))
BEGIN
	SELECT isDeleted FROM LightStateRef WHERE lightStateRefID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS is_node_deleted;
DELIMITER $$
CREATE PROCEDURE is_node_deleted(IN id VARCHAR(36))
BEGIN
	SELECT isDeleted FROM Node WHERE nodeID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS is_phase_deleted;
DELIMITER $$
CREATE PROCEDURE is_phase_deleted(IN id VARCHAR(36))
BEGIN
	SELECT isDeleted FROM Phase WHERE phaseID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS is_phasetype_deleted;
DELIMITER $$
CREATE PROCEDURE is_phasetype_deleted(IN id VARCHAR(36))
BEGIN
	SELECT isDeleted FROM PhaseType WHERE phaseTypeID = id;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS is_street_deleted;
DELIMITER $$
CREATE PROCEDURE is_street_deleted(IN id VARCHAR(36))
BEGIN
	SELECT isDeleted FROM Street WHERE streetID = id;
END $$
DELIMITER ;