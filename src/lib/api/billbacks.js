// Billbacks (reimbursements between ownership entities).
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getBillbacks({ status } = {}) {
	const orgId = getOrgId();
	let query = supabase
		.from('v_billbacks')
		.select('*')
		.eq('organization_id', orgId)
		.order('issued_date', { ascending: false });
	if (status) query = query.eq('status', status);
	return unwrap(await query);
}

// Billbacks that still need money to come in.
export async function getOutstandingBillbacks() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_billbacks')
			.select('*')
			.eq('organization_id', orgId)
			.or(`and(status.eq.outstanding,balance.gt.0),and(status.eq.partially_paid,balance.gt.0)`)
			.order('due_date')
	);
}

export async function createBillback(data) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('billbacks').insert({ organization_id: orgId, ...data }).select()
	);
}

export async function deleteBillback(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('billbacks').delete().eq('organization_id', orgId).eq('id', id)
	);
}
