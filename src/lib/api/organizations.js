// Organizations & membership.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getOrganizations() {
	return unwrap(await supabase.from('organizations').select('*').order('name'));
}

export async function getOrganizationSettings() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('organization_settings')
			.select('*')
			.eq('organization_id', orgId)
			.single()
	);
}

export async function getMembers() {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('v_org_members')
			.select('user_id, role, display_name')
			.eq('organization_id', orgId)
			.order('display_name')
	);
}

export async function addMember({ userId, role }) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('org_members').insert({ organization_id: orgId, user_id: userId, role })
	);
}

export async function updateMemberRole(userId, role) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('org_members')
			.update({ role })
			.eq('organization_id', orgId)
			.eq('user_id', userId)
	);
}

export async function removeMember(userId) {
	const orgId = getOrgId();
	return unwrap(
		await supabase
			.from('org_members')
			.delete()
			.eq('organization_id', orgId)
			.eq('user_id', userId)
	);
}

// Bootstrap a brand-new tenant with the caller as owner (RPC, security definer).
export async function createOrganization({ name, slug }) {
	return unwrap(await supabase.rpc('create_organization', { p_name: name, p_slug: slug }));
}
