// Internal: shared Supabase client. Never imported outside src/lib/api.
import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
	throw new Error('VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be set. Copy .env.example to .env.');
}

export const supabase = createClient(url, anonKey);

// Unwrap a Supabase response; throw on error so callers get one code path.
export function unwrap({ data, error }) {
	if (error) throw new Error(error.message);
	return data;
}
