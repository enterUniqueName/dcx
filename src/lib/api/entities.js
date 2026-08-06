// Ownership entities.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getOwnershipEntities() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('ownership_entities')
			.select('*')
			.eq('organization_id', orgId)
			.order('name')
	);
}

export async function getOwnershipEntity(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('ownership_entities')
			.select('*')
			.eq('organization_id', orgId)
			.eq('id', id)
			.single()
	);
}

export async function createOwnershipEntity(data) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('ownership_entities').insert({ organization_id: orgId, ...data }).select()
	);
}

export async function updateOwnershipEntity(id, patch) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('ownership_entities')
			.update(patch)
			.eq('organization_id', orgId)
			.eq('id', id)
			.select()
	);
}

export async function deleteOwnershipEntity(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('ownership_entities')
			.delete()
			.eq('organization_id', orgId)
			.eq('id', id)
	);
}
