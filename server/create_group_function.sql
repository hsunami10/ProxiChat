-- Create the group and add the creator as a member"
CREATE OR REPLACE FUNCTION create_group_proxichat(g_id text, group_name text, group_password text, group_description text, group_creator text, public boolean, coords text, users_groups_id text)
RETURNS SETOF groups AS $BODY$
BEGIN
  -- Insert into groups table
  INSERT INTO groups (id, title, password, description, created_by, is_public, location, coordinates) VALUES (g_id, group_name, group_password, group_description, group_creator, public, ST_GeogFromText('SRID=4326;POINT(' || coords || ')'), coords);

  -- Insert into users_groups table
  INSERT INTO users_groups (id, username, group_id) VALUES (users_groups_id, group_creator, g_id);

  -- Return inserted group with select query
  RETURN query SELECT * FROM groups WHERE id = g_id;
END;
$BODY$ LANGUAGE plpgsql;
