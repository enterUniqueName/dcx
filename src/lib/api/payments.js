// Payments.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getPayments({ obligationId } = {}) {
	const orgId = getOrgId();
	let query = supabase
		.from('v_payments')
		.select('*')
		.eq('organization_id', orgId)
		.order('paid_date', { ascending: false });
	if (obligationId) query = query.eq('obligation_id', obligationId);
	return unwrap(await query);
}

export async function getPaymentLog({ from, to, crossEntity } = {}) {
	const orgId = getOrgId();
	let query = supabase
		.from('v_payments')
		.select('*')
		.eq('organization_id', orgId)
		.order('paid_date', { ascending: false });
	if (from) query = query.gte('paid_date', from);
	if (to) query = query.lte('paid_date', to);
	if (crossEntity) query = query.eq('is_cross_entity', true);
	return unwrap(await query);
}

export async function deletePayment(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('payments').delete().eq('organization_id', orgId).eq('id', id)
	);
}

// Settle (or partially settle) a billback. The refresh_billback_status trigger
// keeps the billback's status in sync with its payments.
export async function createPayment({ billbackId, amount, paidDate, method, reference, notes }) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('payments')
			.insert({
				organization_id: orgId,
				billback_id: billbackId,
				amount,
				paid_date: paidDate,
				method: method ?? null,
				reference: reference ?? null,
				notes: notes ?? null
			})
			.select()
	);
}
