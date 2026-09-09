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

export async function getPropertyObligations(propertyId) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('id, name, category, amount, est_amount, next_due_date, status, vendor_name')
			.eq('organization_id', orgId)
			.eq('property_id', propertyId)
			.eq('kind', 'bill')
			.eq('status', 'open')
			.order('next_due_date')
	);
}

export async function getPropertyLoans(propertyId) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_loans')
			.select('id, lender, loan_number, nickname, current_balance, monthly_payment, status')
			.eq('organization_id', orgId)
			.eq('property_id', propertyId)
			.order('lender')
	);
}
