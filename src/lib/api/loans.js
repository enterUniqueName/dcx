// Loans.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getLoans() {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('v_loans').select('*').eq('organization_id', orgId).order('nickname')
	);
}

export async function createLoan(data) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('loans').insert({ organization_id: orgId, ...data }).select()
	);
}

export async function updateLoan(id, patch) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('loans')
			.update(patch)
			.eq('organization_id', orgId)
			.eq('id', id)
			.select()
	);
}

export async function deleteLoan(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('loans').delete().eq('organization_id', orgId).eq('id', id)
	);
}
