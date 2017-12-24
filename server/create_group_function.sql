-- Create the group and add the creator as a member"
CREATE OR REPLACE FUNCTION create_group_proxichat(g_id text, group_name text, group_password text, group_creator text, create_date text, public boolean, coords text, users_groups_id text)
RETURNS VOID AS $$
DECLARE
  created_date timestamptz := cast(create_date as timestamptz);
BEGIN
  -- Insert into groups table
  INSERT INTO groups (id, title, password, created_by, date_created, is_public, location, coordinates) VALUES (g_id, group_name, group_password, group_creator, created_date, public, ST_GeogFromText('SRID=4326;POINT(' || coords || ')'), coords);

  -- Insert into users_groups table
  INSERT INTO users_groups (id, username, group_id) VALUES (users_groups_id, group_creator, g_id);
END;
$$ LANGUAGE plpgsql;
