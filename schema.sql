CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS users(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL DEFAULT '',
 email text UNIQUE NOT NULL,
 password_hash text NOT NULL,
 phone text NOT NULL DEFAULT '',
 role text NOT NULL DEFAULT 'user' CHECK(role IN ('user','admin')),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS properties(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 title text NOT NULL,
 city text NOT NULL,
 neighborhood text NOT NULL DEFAULT '',
 type text NOT NULL DEFAULT 'فروش',
 price text NOT NULL DEFAULT '',
 area text NOT NULL DEFAULT '',
 phone text NOT NULL DEFAULT '',
 description text NOT NULL DEFAULT '',
 images jsonb NOT NULL DEFAULT '[]'::jsonb,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS properties_status_idx ON properties(status);
CREATE INDEX IF NOT EXISTS properties_city_idx ON properties(city);
CREATE INDEX IF NOT EXISTS properties_created_idx ON properties(created_at DESC);

CREATE TABLE IF NOT EXISTS favorites(
 user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,property_id)
);
CREATE INDEX IF NOT EXISTS favorites_user_idx ON favorites(user_id,created_at DESC);
