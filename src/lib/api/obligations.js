// Obligations — the core module.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

function obligationQuery() {
	const orgId = getOrgId();
	return supabase.from('v_obligations').select('*').eq('organization_id', orgId);
}

export async function getObligations({ status, category, ownershipEntityId, from, to } = {}) {
	let query = obligationQuery();
	if (status) query = query.eq('status', status);
	if (category) query = query.eq('category', category);
	if (ownershipEntityId) query = query.eq('ownership_entity_id', ownershipEntityId);
	if (from) query = query.gte('next_due_date', from);
	if (to) query = query.lte('next_due_date', to);
	return unwrap(await query.order('next_due_date'));
}

export async function getObligation(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('id', id)
			.single()
	);
}

// Open obligations due within a window (default: today through +7 days).
export async function getUpcomingObligations({ from, to } = {}) {
	const today = new Date();
	const fromDate = from ?? toISODate(today);
	const toDate = to ?? toISODate(new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000));

	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('status', 'open')
			.gte('next_due_date', fromDate)
			.lte('next_due_date', toDate)
			.order('next_due_date')
	);
}

// Open obligations with a due date before today.
export async function getOverdueObligations() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('status', 'open')
			.lt('next_due_date', toISODate(new Date()))
			.order('next_due_date')
	);
}

// Bills/invoices received but not yet paid.
export async function getReceivedObligations() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_obligations')
			.select('*')
			.eq('organization_id', orgId)
			.eq('status', 'open')
			.eq('received', true)
			.order('next_due_date')
	);
}

export async function createObligation(data) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('obligations').insert({ organization_id: orgId, ...data }).select()
	);
}

export async function updateObligation(id, patch) {
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

export async function markObligationReceived(id) {
	return updateObligation(id, { received: true, received_date: toISODate(new Date()) });
}

export async function markObligationUnreceived(id) {
	return updateObligation(id, { received: false, received_date: null });
}

export async function cancelObligation(id) {
	return updateObligation(id, { status: 'canceled' });
}

// Atomic: insert payment + advance next_due_date (RPC, security definer).
export async function markObligationPaid(
	id,
	{ amount, paidDate, fundingEntityId, method, reference, notes } = {}
) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.rpc('pay_obligation', {
			p_obligation_id: id,
			p_amount: amount,
			p_paid_date: paidDate,
			p_ownership_entity_id: fundingEntityId ?? null,
			p_method: method ?? null,
			p_reference: reference ?? null,
			p_notes: notes ?? null
		})
	);
}

export async function deleteObligation(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('obligations').delete().eq('organization_id', orgId).eq('id', id)
	);
}

function toISODate(date) {
	return date.toISOString().slice(0, 10);
}
