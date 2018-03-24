-- Update user location and return group chats that are in the radius
CREATE OR REPLACE FUNCTION update_location_proxichat(u_id text, u_coord text, u_rad integer)
RETURNS SETOF groups AS $BODY$
DECLARE
	g_id text;
	r record;
	user_id text := cast(u_id as text);
	user_coord text := cast(u_coord as text);
	user_radius double precision := cast(u_rad as double precision);
	user_location geography(POINT,4326) := ST_GeogFromText('SRID=4326;POINT(' || user_coord || ')');
BEGIN
	-- First update the user's location
	UPDATE users SET location = user_location, coordinates = user_coord, radius = user_radius WHERE username = user_id;

	-- Iterate through all group IDs that the user is NOT in
  -- Order by distance from the user's current location
	FOR g_id IN (SELECT group_id FROM users_groups WHERE username <> user_id ORDER BY (SELECT ST_Distance(user_location, (SELECT location FROM groups WHERE id = group_id))))
	LOOP
		FOR r IN (SELECT * FROM groups WHERE id = g_id)
		LOOP
			IF (SELECT ST_Distance(
				user_location,
				(SELECT location FROM groups WHERE id = g_id))) <= user_radius THEN
				RETURN NEXT r;
			END IF;
		END LOOP;
	END LOOP;

	RETURN;
END;
$BODY$ LANGUAGE plpgsql;
