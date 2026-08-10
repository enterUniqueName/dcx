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

// Full roster for the admin page (emails included). Admin-guarded server-side.
export async function getOrgMembersDetail(orgId) {
	return unwrap(await supabase.rpc('org_members_detail', { p_org: orgId }));
}

// Add someone to an org by email. Admin-guarded server-side.
export async function inviteMember(orgId, email, role) {
	return unwrap(
		await supabase.rpc('invite_member', { p_org: orgId, p_email: email, p_role: role })
	);
}

export async function addMember({ userId, role }) {
	const orgId = getOrgId();
	return unwrap(
		await supabase.from('org_members').insert({ organization_id: orgId, user_id: userId, role })
	);
}

export async function updateMemberRole(orgId, userId, role) {
	return unwrap(
		await supabase
			.from('org_members')
			.update({ role })
			.eq('organization_id', orgId)
			.eq('user_id', userId)
	);
}

export async function removeMember(orgId, userId) {
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

// Entities of a specific org (not the active one) for the entity-access form.
export async function getOrgEntities(orgId) {
	return unwrap(
		await supabase
			.from('v_entity_summary')
			.select('*')
			.eq('organization_id', orgId)
			.order('name')
	);
}

// Entity-scoped partner access (000014). Admin-guarded server-side.
export async function getEntityAccessDetail(orgId) {
	return unwrap(await supabase.rpc('entity_access_detail', { p_org: orgId }));
}

export async function grantEntityAccess(orgId, email, entityId) {
	return unwrap(
		await supabase.rpc('grant_entity_access', {
			p_org: orgId,
			p_email: email,
			p_entity: entityId
		})
	);
}

export async function revokeEntityAccess(orgId, userId) {
	return unwrap(await supabase.rpc('revoke_entity_access', { p_org: orgId, p_user: userId }));
}
