# Our Space - a private digital space

npm install @supabase/supabase-js @supabase/ssr

NEXT_PUBLIC_SUPABASE_URL=YOUR-SUPABASE-URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=YOUR-SUPABASE-PUBLISHABLE-KEY

## Database setup

Before using the couple-space flow, run
`supabase/migrations/202608300001_private_couple_spaces.sql` in the Supabase
Dashboard SQL Editor for the project configured in `.env.local`. It creates the
required tables, RLS policies, and the `create_couple_space` / `join_couple_space`
database functions.
