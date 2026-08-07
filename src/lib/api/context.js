// Internal: session + active-organization state. Never imported outside src/lib/api.
import { writable, get } from 'svelte/store';
import { supabase, unwrap } from './client.js';

const STORAGE_KEY = 'dcx.active_org';

let storedActiveOrg = null;
try {
	storedActiveOrg = localStorage.getItem(STORAGE_KEY);
} catch {
	// localStorage unavailable (non-browser); ignore.
}

export const authReady = writable(false);
export const orgsReady = writable(false);
export const session = writable(null);
export const user = writable(null);
export const organizations = writable([]);
export const activeOrganizationId = writable(storedActiveOrg);

function applySession(sess) {
	session.set(sess);
	user.set(sess?.user ?? null);
	authReady.set(true);
}

// Restore the Supabase session (persisted by supabase-js) and subscribe to
// future auth changes. Call once from the root layout.
export async function initAuth() {
	const { data } = await supabase.auth.getSession();
	applySession(data.session);

	supabase.auth.onAuthStateChange((_event, next) => {
		applySession(next);
	});

	return data.session;
}

export async function signOut() {
	await supabase.auth.signOut();
}

export async function signIn(email, password) {
	const { data, error } = await supabase.auth.signInWithPassword({ email, password });
	if (error) throw new Error(error.message);
	return data.session;
}

export async function signUp(email, password) {
	const { data, error } = await supabase.auth.signUp({ email, password });
	if (error) throw new Error(error.message);
	return data;
}

// Load the caller's organizations and pick the active one:
// explicit choice > profile default > first org. Returns the org list.
export async function refreshOrganizations() {
	const currentUser = get(user);
	if (!currentUser) return [];

	const data = unwrap(
		await supabase.from('organizations').select('*').order('name')
	);
	organizations.set(data);

	let defaultOrgId = null;
	try {
		const profile = unwrap(
			await supabase
				.from('profiles')
				.select('default_organization_id')
				.eq('id', currentUser.id)
				.single()
		);
		defaultOrgId = profile?.default_organization_id ?? null;
	} catch {
		// No profile yet; fall through.
	}

	let active = get(activeOrganizationId);
	if (!active || !data.some((o) => o.id === active)) {
		active = defaultOrgId ?? data[0]?.id ?? null;
		activeOrganizationId.set(active);
		try {
			localStorage.setItem(STORAGE_KEY, active ?? '');
		} catch {
			// ignore
		}
	}

	orgsReady.set(true);

	return data;
}

export function setActiveOrganization(id) {
	activeOrganizationId.set(id);
	try {
		localStorage.setItem(STORAGE_KEY, id ?? '');
	} catch {
		// ignore
	}
}

// The organization every api.* call is scoped to. Falls back to the first
// loaded organization so pages don't race refreshOrganizations().
export function getOrgId() {
	let id = get(activeOrganizationId);
	if (!id) {
		id = get(organizations)[0]?.id ?? null;
		if (id) setActiveOrganization(id);
	}
	if (!id) throw new Error('No active organization selected.');
	return id;
}
