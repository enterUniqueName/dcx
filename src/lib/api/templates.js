// Templates — recurring obligation definitions (the basis rows). Each active
// template is materialized into concrete bills by generate_bills().
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

function templateQuery() {
	const orgId = getOrgId();
	return supabase
		.from('v_obligations')
		.select('*')
		.eq('organization_id', orgId)
		.eq('kind', 'template');
}

export async function getTemplates({ status, category, ownershipEntityId } = {}) {
	let query = templateQuery();
	if (status) query = query.eq('status', status);
	if (category) query = query.eq('category', category);
	if (ownershipEntityId) query = query.eq('ownership_entity_id', ownershipEntityId);
	return unwrap(await query.order('next_due_date'));
}

export async function getTemplate(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('kind', 'template')
			.eq('id', id)
			.single()
	);
}

export async function createTemplate(data) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('obligations')
			.insert({ organization_id: orgId, kind: 'template', ...data })
			.select()
	);
}

export async function updateTemplate(id, patch) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('obligations')
			.update(patch)
			.eq('organization_id', orgId)
			.eq('id', id)
			.select()
	);
}

export async function cancelTemplate(id) {
	return updateTemplate(id, { status: 'canceled' });
}

export async function deleteTemplate(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('obligations').delete().eq('organization_id', orgId).eq('id', id)
	);
}

// Materialize missing bills for every open template, from each template's last
// generated due date forward to p_targetDate (default: today + 180 days).
// Returns the number of bills created.
export async function generateBills({ targetDate } = {}) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.rpc('generate_bills', {
			p_organization_id: orgId,
			p_target_date: targetDate ?? null
		})
	);
}
