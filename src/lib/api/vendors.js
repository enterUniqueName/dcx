// Vendors.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getVendors() {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('vendors').select('*').eq('organization_id', orgId).order('name')
	);
}

export async function createVendor(data) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('vendors').insert({ organization_id: orgId, ...data }).select()
	);
}

export async function updateVendor(id, patch) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('vendors')
			.update(patch)
			.eq('organization_id', orgId)
			.eq('id', id)
			.select()
	);
}

export async function deleteVendor(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('vendors').delete().eq('organization_id', orgId).eq('id', id)
	);
}

// Resolve a typed vendor name to its id, creating the vendor row if needed.
// Returns null for an empty name.
export async function findOrCreateVendor(name) {
	const trimmed = (name ?? '').trim();
	if (!trimmed) return null;
	const orgId = getOrgId();
	const existing = unwrap(
		await supabase
			.from('vendors')
			.select('id')
			.eq('organization_id', orgId)
			.ilike('name', trimmed)
			.order('created_at', { ascending: true })
			.limit(1)
	);
	if (Array.isArray(existing) && existing.length > 0) return existing[0].id;
	const rows = unwrap(
		await supabase
			.from('vendors')
			.insert({ organization_id: orgId, name: trimmed })
			.select('id')
	);
	const created = Array.isArray(rows) ? rows[0] : rows;
	return created.id;
}
