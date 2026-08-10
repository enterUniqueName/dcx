<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { api } from '$lib/api';
	import { authReady, orgsReady, user, organizations, activeOrganizationId, activeOrgRole } from '$lib/api/context.js';

	// Highlight the current section: exact match for the dashboard, prefix
	// match elsewhere so detail pages (e.g. /obligations/[id]) keep their
	// parent nav item highlighted.
	$: isActive = (href) => {
		if (href === `${base}/`) return $page.url.pathname === `${base}/`;
		return $page.url.pathname.startsWith(href);
	};

	// Admin-only nav (organizations) is hidden from everyone else.
	$: isAdmin = ['owner', 'admin'].includes($activeOrgRole);

	const links = [
		{ href: `${base}/`, label: 'Dashboard' },
		{ href: `${base}/obligations`, label: 'Obligations' },
		{ href: `${base}/payments`, label: 'Payments' },
		{ href: `${base}/billbacks`, label: 'Billbacks' },
		{ href: `${base}/documents`, label: 'Documents' },
		{ href: `${base}/reports`, label: 'Reports' },
		{ href: `${base}/entities`, label: 'Entities', section: 'Admin' },
		{ href: `${base}/properties`, label: 'Properties' },
		{ href: `${base}/tenants`, label: 'Tenants' },
		{ href: `${base}/vendors`, label: 'Vendors' },
		{ href: `${base}/loans`, label: 'Loans' },
		{ href: `${base}/organizations`, label: 'Organizations', adminOnly: true },
		{ href: `${base}/settings`, label: 'Settings' }
	];

	$: visibleLinks = links.filter((l) => !l.adminOnly || isAdmin);

	let newName = '';
	let newSlug = '';
	let creating = false;
	let createError = '';

	async function createOrg() {
		creating = true;
		createError = '';
		try {
			await api.createOrganization(newName, newSlug);
			await api.refreshOrganizations();
		} catch (e) {
			createError = e.message;
		} finally {
			creating = false;
		}
	}

	async function onSignOut() {
		await api.signOut();
		goto(`${base}/auth/login`);
	}

	onMount(async () => {
		await api.initAuth();
		if (!$user) {
			goto(`${base}/auth/login`);
			return;
		}
		await api.refreshOrganizations();
	});
</script>

{#if !$authReady || !$orgsReady}
	<p class="center">Loading…</p>
{:else if !$user}
	<p class="center">Signing you in…</p>
{:else if $organizations.length === 0}
	<div class="no-access">
		<h1>No organization access yet</h1>
		<p>
			Create your own organization, or ask an administrator to add you and then refresh.
		</p>
		<form class="create-org" onsubmit={(e) => { e.preventDefault(); createOrg(); }}>
			<input class="input" placeholder="Organization name (e.g. DCX)" bind:value={newName} required />
			<input class="input" placeholder="Slug (e.g. dcx)" bind:value={newSlug} required />
			<button class="btn btn-primary" disabled={creating}>
				{creating ? 'Creating…' : 'Create organization'}
			</button>
		</form>
		{#if createError}<p class="error-text">{createError}</p>{/if}
		<button class="btn" onclick={() => location.reload()}>Refresh</button>
	</div>
{:else}
	<div class="app">
		<aside class="sidebar">
			<div class="brand">dcx</div>
			<nav>
				{#each visibleLinks as link (link.href)}
					{#if link.section}<span class="nav-section">{link.section}</span>{/if}
					<a href={link.href} class:active={isActive(link.href)}>{link.label}</a>
				{/each}
			</nav>
		</aside>
		<main class="content">
			<header class="topbar">
				<select
					class="select org-switcher"
					value={$activeOrganizationId ?? ''}
					onchange={(e) => api.setActiveOrganization(e.target.value)}
				>
					{#each $organizations as org (org.id)}
						<option value={org.id}>{org.name}</option>
					{/each}
				</select>
				<span class="user">{ $user.email }</span>
				<button class="btn" onclick={onSignOut}>Sign out</button>
			</header>
			<slot />
		</main>
	</div>
{/if}

<style>
	.center {
		text-align: center;
		padding: 4rem 1rem;
		color: var(--text-muted);
	}
	.no-access {
		max-width: 480px;
		margin: 6rem auto;
		text-align: center;
		padding: 1.5rem;
	}
	.no-access h1 {
		margin: 0 0 0.5rem;
	}
	.no-access p {
		color: var(--text-muted);
		margin: 0 0 1.25rem;
	}
	.create-org {
		display: grid;
		gap: 0.6rem;
		margin-bottom: 1rem;
	}
	.app {
		display: flex;
		min-height: 100vh;
	}
	.sidebar {
		width: 210px;
		flex-shrink: 0;
		padding: 1rem;
		background: var(--surface);
		border-right: 1px solid var(--border);
	}
	.brand {
		font-weight: 800;
		font-size: 1.15rem;
		margin-bottom: 1.25rem;
	}
	nav {
		display: grid;
		gap: 0.15rem;
	}
	nav a {
		display: block;
		padding: 0.4rem 0.6rem;
		border-radius: var(--radius);
		color: var(--text);
	}
	nav a:hover {
		background: #f3f4f6;
		text-decoration: none;
	}
	nav a.active {
		background: #eff6ff;
		color: var(--primary);
		font-weight: 600;
	}
	.nav-section {
		margin-top: 0.9rem;
		padding: 0 0.6rem;
		font-size: 11px;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--text-muted);
	}
	.content {
		flex: 1;
		min-width: 0;
		padding: 1.25rem 1.5rem 3rem;
	}
	.topbar {
		display: flex;
		align-items: center;
		gap: 0.85rem;
		justify-content: flex-end;
		margin-bottom: 1.5rem;
	}
	.org-switcher {
		width: auto;
		max-width: 280px;
	}
	.user {
		color: var(--text-muted);
		font-size: 13px;
	}
</style>
