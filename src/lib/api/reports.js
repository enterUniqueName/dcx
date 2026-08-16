// Reports: read-model aggregates behind the same facade.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';
import {
	getUpcomingBills,
	getOverdueBills,
	getReceivedBills
} from './bills.js';
import { getOutstandingBillbacks } from './billbacks.js';
import { toISODate } from '../utils/format.js';

// Cash each ownership entity needs for a given month (YYYY-MM).
export async function getCashNeeded(month) {
	const orgId = getOrgId();
	const rows = unwrap(
		await supabase
			.from('v_cash_needed')
			.select('*')
			.eq('organization_id', orgId)
			.order('month')
			.order('ownership_entity_name')
	);
	const prefix = month ?? null;
	return prefix ? rows.filter((r) => (r.month || '').startsWith(prefix)) : rows;
}

// "What did one entity pay on behalf of another?" (e.g. PLB).
export async function getCrossEntityPayments({ from, to } = {}) {
	const orgId = getOrgId();
	let query = supabase
		.from('v_cross_entity_payments')
		.select('*')
		.eq('organization_id', orgId)
		.order('paid_date', { ascending: false });
	if (from) query = query.gte('paid_date', from);
	if (to) query = query.lte('paid_date', to);
	return unwrap(await query);
}

// Everything the dashboard needs in one call.
export async function getDashboardSnapshot() {
	const [upcoming, overdue, received, billbacks, crossEntity, cash] = await Promise.all([
		getUpcomingBills(),
		getOverdueBills(),
		getReceivedBills(),
		getOutstandingBillbacks(),
		getCrossEntityPayments(monthRange()),
		getCashNeeded()
	]);

	const outstandingBillbacks = billbacks.filter((b) => b.balance > 0);
	const billbackTotal = outstandingBillbacks.reduce((sum, b) => sum + Number(b.balance), 0);
	const cashThisMonth = cash.reduce(
		(sum, row) => (isThisMonth(row.month) ? sum + Number(row.total) : sum),
		0
	);
	const crossEntityTotal = crossEntity.reduce((sum, p) => sum + Number(p.amount), 0);

	return {
		upcoming,
		overdue,
		received,
		billbacks: outstandingBillbacks,
		billbackTotal,
		cashThisMonth,
		crossEntity,
		crossEntityTotal
	};
}

function isThisMonth(isoDate) {
	const today = new Date();
	const prefix = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
	return (isoDate || '').startsWith(prefix);
}

// First and last day of the current month.
function monthRange() {
	const today = new Date();
	const from = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-01`;
	const next = new Date(today.getFullYear(), today.getMonth() + 1, 1);
	const to = toISODate(new Date(next.getTime() - 86400000));
	return { from, to };
}
