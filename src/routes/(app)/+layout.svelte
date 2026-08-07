<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { api } from '$lib/api';
	import { authReady, user, organizations, activeOrganizationId } from '$lib/api/context.js';

	$: isActive = (href) => $page.url.pathname === href;

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

{#if !$authReady}
	<p class="center">Loading…</p>
{:else if !$user}
	<p class="center">Signing you in…</p>
{:else if $organizations.length === 0}
	<div class="no-access">
		<h1>No organization access yet</h1>
		<p>
			Your account isn't linked to an organization. Ask an administrator to add you, then refresh.
		</p>
	</div>
{:else}
	<div class="app">
		<aside class="sidebar">
			<div class="brand">dcx</div>
			<nav>
				<a href="/" class:active={isActive('/')}>Dashboard</a>
				<a href="/obligations" class:active={isActive('/obligations')}>Obligations</a>
				<a href="/payments" class:active={isActive('/payments')}>Payments</a>
				<a href="/billbacks" class:active={isActive('/billbacks')}>Billbacks</a>
				<a href="/documents" class:active={isActive('/documents')}>Documents</a>
				<a href="/reports" class:active={isActive('/reports')}>Reports</a>
				<span class="nav-section">Admin</span>
				<a href="/entities" class:active={isActive('/entities')}>Entities</a>
				<a href="/properties" class:active={isActive('/properties')}>Properties</a>
				<a href="/tenants" class:active={isActive('/tenants')}>Tenants</a>
				<a href="/vendors" class:active={isActive('/vendors')}>Vendors</a>
				<a href="/loans" class:active={isActive('/loans')}>Loans</a>
				<a href="/organizations" class:active={isActive('/organizations')}>Organizations</a>
				<a href="/settings" class:active={isActive('/settings')}>Settings</a>
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
