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
	const { allocations, ...billback } = data;
	const rows = unwrap(
		await supabase.from('billbacks').insert({ organization_id: orgId, ...billback }).select()
	);
	const created = Array.isArray(rows) ? rows[0] : rows;
	if (allocations?.length) {
		const rowsAlloc = allocations.map((a) => ({
			organization_id: orgId,
			billback_id: created.id,
			responsible_type: a.responsible_type,
			tenant_id: a.tenant_id || null,
			ownership_entity_id: a.ownership_entity_id || null,
			allocation_type: a.allocation_type,
			percentage: a.allocation_type === 'percent' ? a.percentage : null,
			amount: a.amount
		}));
		await supabase.from('billback_allocations').insert(rowsAlloc);
	}
	return created;
}

export async function getBillbackAllocations(billbackId) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('billback_allocations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('billback_id', billbackId)
	);
}

export async function deleteBillback(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('billbacks').delete().eq('organization_id', orgId).eq('id', id)
	);
}
