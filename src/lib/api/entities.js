// Ownership entities.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getOwnershipEntities() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_entity_summary')
			.select('*')
			.eq('organization_id', orgId)
			.order('name')
	);
}

export async function getOwnershipEntity(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_entity_summary')
			.select('*')
			.eq('organization_id', orgId)
			.eq('id', id)
			.single()
	);
}

// Expansion details for a single entity.
export async function getEntityProperties(entityId) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_properties')
			.select('id, name, city, state, property_type, unit_count, status')
			.eq('organization_id', orgId)
			.eq('ownership_entity_id', entityId)
			.order('name')
	);
}

export async function getEntityLoans(entityId) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_loans')
			.select('id, lender, loan_number, nickname, original_amount, interest_rate, monthly_payment, status')
			.eq('organization_id', orgId)
			.eq('ownership_entity_id', entityId)
			.order('lender')
	);
}

export async function getEntityBillbacks(entityId) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_billbacks')
			.select('id, description, from_entity_name, amount, balance, due_date, status')
			.eq('organization_id', orgId)
			.eq('to_ownership_entity_id', entityId)
			.eq('is_outstanding', true)
			.order('due_date')
	);
}

// Open obligations for a single entity (upcoming first).
export async function getEntityObligations(entityId) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select(
				'id, name, category, amount, est_amount, next_due_date, status, property_name, vendor_name'
			)
			.eq('organization_id', orgId)
			.eq('ownership_entity_id', entityId)
			.eq('status', 'open')
			.order('next_due_date')
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
