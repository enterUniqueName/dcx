// Properties.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getProperties() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_properties')
			.select('*')
			.eq('organization_id', orgId)
			.order('name')
	);
}

export async function getProperty(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_properties')
			.select('*')
			.eq('organization_id', orgId)
			.eq('id', id)
			.single()
	);
}

export async function createProperty(data) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('properties').insert({ organization_id: orgId, ...data }).select()
	);
}

export async function updateProperty(id, patch) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('properties')
			.update(patch)
			.eq('organization_id', orgId)
			.eq('id', id)
			.select()
	);
}

export async function deleteProperty(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('properties')
			.delete()
			.eq('organization_id', orgId)
			.eq('id', id)
	);
}
