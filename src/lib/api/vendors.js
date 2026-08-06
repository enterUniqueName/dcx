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
