// Internal: shared Supabase client. Never imported outside src/lib/api.
import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
	throw new Error('VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be set. Copy .env.example to .env.');
}

export const supabase = createClient(url, anonKey);

// Friendly copy for SQLSTATE error codes that are safe to show users.
const SQLSTATE_FRIENDLY = {
	'23505': 'A record with these same details already exists.',
	'23503': 'This record is still referenced by another record, so it cannot be changed or deleted.',
	'23514': 'This entry doesn\'t follow the business rules for that field. Please review it and try again.',
	'23502': 'A required value is missing. Please fill in all required fields.',
	'22P02': 'One of the values entered isn\'t in the expected format.',
	'42501': 'You don\'t have permission to do that in this organization.',
	'42P01': 'The app couldn\'t find the data it needs. This looks like a configuration problem.',
	'42703': 'The app is looking for a field that doesn\'t exist. This looks like a configuration problem.',
	'57014': 'That request took too long and was cancelled. Please try again.',
	'40001': 'Your change conflicted with another update and was rolled back. Please try again.'
};

// Specific, human-readable messages for named constraints we know about.
const CONSTRAINT_FRIENDLY = {
	billbacks_check:
		'The paying entity and the responsible entity must be different. If one entity paid its own expense, there\'s nothing to bill back.',
	obligations_series_due_uq:
		'A bill already exists for this template and due date. Delete or edit the existing bill first.',
	organizations_slug_key: 'An organization with this short name already exists.',
	org_members_organization_id_user_id_key: 'This user is already a member of the organization.',
	documents_storage_path_key: 'A document with the same name was already attached.',
	leases_tenant_id_key: 'This tenant already has a lease on file. Edit the existing lease instead of adding another.',
	entity_access_pkey: 'This user already has access to that entity.'
};

// Translate a Supabase/Postgres error into something a user can act on.
// Errors we don't recognize (RPC "raise exception", auth, storage/network)
// are passed through unchanged — those messages are already user-facing.
export function friendlyError(error) {
	const raw = error?.message ?? 'Something went wrong.';

	try {
		const name = constraintName(raw);
		if (name) {
			const mapped = CONSTRAINT_FRIENDLY[name];
			if (mapped) {
				console.warn('dcx constraint error:', name, '—', raw);
				return mapped;
			}
		}
		const mapped = SQLSTATE_FRIENDLY[error?.code];
		if (mapped) {
			console.warn('dcx db error:', error?.code, '—', raw);
			return mapped;
		}
	} catch {
		// Never let translation itself break error handling.
	}

	return raw;
}

// Extract a constraint name from a Postgres message like:
//   new row for relation "billbacks" violates check constraint "billbacks_check"
function constraintName(message) {
	const m = /constraint "([^"]+)"/.exec(message);
	return m ? m[1] : null;
}

// Unwrap a Supabase response; throw on error so callers get one code path.
export function unwrap({ data, error }) {
	if (error) throw new Error(friendlyError(error));
	return data;
}