// Bills — concrete instances of a recurring template (kind='bill'), plus
// one-time bills with no series. Bills carry their own merged payment fields
// (paid_amount / paid_date / method / reference / funding_entity_id).
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';
import { toISODate } from '../utils/format.js';

function billQuery() {
	const orgId = getOrgId();
	return supabase
		.from('v_obligations')
		.select('*')
		.eq('organization_id', orgId)
		.eq('kind', 'bill');
}

export async function getBills({ status, category, ownershipEntityId, from, to } = {}) {
	let query = billQuery();
	if (status) query = query.eq('status', status);
	if (category) query = query.eq('category', category);
	if (ownershipEntityId) query = query.eq('ownership_entity_id', ownershipEntityId);
	if (from) query = query.gte('next_due_date', from);
	if (to) query = query.lte('next_due_date', to);
	return unwrap(await query.order('next_due_date'));
}

export async function getBill(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('kind', 'bill')
			.eq('id', id)
			.single()
	);
}

// Open bills due within a window (default: today through +7 days).
export async function getUpcomingBills({ from, to } = {}) {
	const today = new Date();
	const fromDate = from ?? toISODate(today);
	const toDate = to ?? toISODate(new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000));

	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('kind', 'bill')
			.eq('status', 'open')
			.gte('next_due_date', fromDate)
			.lte('next_due_date', toDate)
			.order('next_due_date')
	);
}

// Open bills with a due date before today.
export async function getOverdueBills() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('kind', 'bill')
			.eq('status', 'open')
			.lt('next_due_date', toISODate(new Date()))
			.order('next_due_date')
	);
}

// Bills/invoices received but not yet paid.
export async function getReceivedBills() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('kind', 'bill')
			.eq('status', 'open')
			.eq('received', true)
			.order('next_due_date')
	);
}

export async function createBill(data) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('obligations')
			.insert({ organization_id: orgId, kind: 'bill', ...data })
			.select()
	);
}

export async function updateBill(id, patch) {
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

export async function markBillReceived(id) {
	return updateBill(id, { received: true, received_date: toISODate(new Date()) });
}

export async function markBillUnreceived(id) {
	return updateBill(id, { received: false, received_date: null });
}

export async function cancelBill(id) {
	return updateBill(id, { status: 'canceled' });
}

export async function deleteBill(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('obligations').delete().eq('organization_id', orgId).eq('id', id)
	);
}

// Pay (or partially pay) an open bill. The payment is merged into the bill
// row; partial payments keep the bill open until paid_amount >= amount.
export async function payBill(
	id,
	{ amount, paidDate, fundingEntityId, method, reference, notes } = {}
) {
	return unwrap(
		await supabase.rpc('pay_bill', {
			p_bill_id: id,
			p_amount: amount,
			p_paid_date: paidDate,
			p_funding_entity_id: fundingEntityId ?? null,
			p_method: method ?? null,
			p_reference: reference ?? null,
			p_notes: notes ?? null
		})
	);
}
