// Tenants.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getTenants() {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('v_tenants').select('*').eq('organization_id', orgId).order('name')
	);
}

export async function createTenant(data) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('tenants').insert({ organization_id: orgId, ...data }).select()
	);
}

export async function updateTenant(id, patch) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('tenants')
			.update(patch)
			.eq('organization_id', orgId)
			.eq('id', id)
			.select()
	);
}

export async function deleteTenant(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('tenants').delete().eq('organization_id', orgId).eq('id', id)
	);
}
