// Tenants. Writes fan out across three tables: the tenant row itself, its
// lease (1:1), and the current rent period (rent_schedule). The list read
// model is v_tenants, which already joins property + lease + current rent.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getTenants() {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('v_tenants').select('*').eq('organization_id', orgId).order('name')
	);
}

export async function getTenant(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_tenants')
			.select('*')
			.eq('organization_id', orgId)
			.eq('id', id)
			.single()
	);
}

export async function getTenantRentHistory(tenantId) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('rent_schedule')
			.select('*')
			.eq('organization_id', orgId)
			.eq('tenant_id', tenantId)
			.order('period_start')
	);
}

function todayIso() {
	return new Date().toISOString().slice(0, 10);
}

// Split the form payload into per-table buckets.
function split(data) {
	const tenant = {};
	let lease = null;
	let rent = null;
	for (const [k, v] of Object.entries(data)) {
		if (k === 'lease_url' || k === 'lease_start' || k === 'lease_end' || k === 'lease_notes') {
			if (!lease) lease = {};
			lease[k === 'lease_url' ? 'url' : k === 'lease_notes' ? 'notes' : k] = v;
		} else if (k === 'monthly_rent' || k === 'rent_notes') {
			if (!rent) rent = {};
			rent[k === 'monthly_rent' ? 'amount' : 'notes'] = v;
		} else {
			tenant[k] = v;
		}
	}
	return { tenant, lease, rent };
}

function leaseHasContent(lease) {
	return lease && (lease.url || lease.lease_start || lease.lease_end || lease.notes);
}

async function saveLease(orgId, tenantId, lease) {
	if (!leaseHasContent(lease)) return;
	const existing = unwrap(
		await supabase
			.from('leases')
			.select('id')
			.eq('organization_id', orgId)
			.eq('tenant_id', tenantId)
			.maybeSingle()
	);
	if (existing) {
		await supabase.from('leases').update(lease).eq('id', existing.id);
	} else {
		await supabase.from('leases').insert({ organization_id: orgId, tenant_id: tenantId, ...lease });
	}
}

async function saveCurrentRent(orgId, tenantId, rent) {
	if (!rent || rent.amount === null || rent.amount === undefined || rent.amount === '') return;
	const existing = unwrap(
		await supabase
			.from('rent_schedule')
			.select('id')
			.eq('organization_id', orgId)
			.eq('tenant_id', tenantId)
			.is('period_end', null)
			.maybeSingle()
	);
	if (existing) {
		await supabase
			.from('rent_schedule')
			.update({ amount: rent.amount, ...(rent.notes ? { notes: rent.notes } : {}) })
			.eq('id', existing.id);
	} else {
		await supabase
			.from('rent_schedule')
			.insert({
				organization_id: orgId,
				tenant_id: tenantId,
				period_start: todayIso(),
				amount: rent.amount,
				...(rent.notes ? { notes: rent.notes } : {})
			});
	}
}

export async function createTenant(data) {
	const orgId = getOrgId();
	const { tenant, lease, rent } = split(data);
	const rows = unwrap(
		await supabase.from('tenants').insert({ organization_id: orgId, ...tenant }).select()
	);
	const created = Array.isArray(rows) ? rows[0] : rows;
	await saveLease(orgId, created.id, lease);
	await saveCurrentRent(orgId, created.id, rent);
	return created;
}

export async function updateTenant(id, patch) {
	const orgId = getOrgId();
	const { tenant, lease, rent } = split(patch);
	await unwrap(
		await supabase
			.from('tenants')
			.update(tenant)
			.eq('organization_id', orgId)
			.eq('id', id)
			.select()
	);
	await saveLease(orgId, id, lease);
	await saveCurrentRent(orgId, id, rent);
	return unwrap(
		await supabase.from('v_tenants').select('*').eq('organization_id', orgId).eq('id', id).single()
	);
}

export async function deleteTenant(id) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('tenants').delete().eq('organization_id', orgId).eq('id', id)
	);
}
