<script>
	import { onMount } from 'svelte';
	import Modal from '$lib/components/ui/Modal.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import { api } from '$lib/api';
	import { activeOrgRole, user } from '$lib/api/context.js';
	import { formatDate } from '$lib/utils/format.js';

	$: isAdmin = ['owner', 'admin'].includes($activeOrgRole);

	const roles = [
		{ value: 'owner', label: 'Owner' },
		{ value: 'admin', label: 'Admin' },
		{ value: 'member', label: 'Member' },
		{ value: 'viewer', label: 'Viewer' }
	];

	let orgs = [];
	let loading = true;
	let error = '';
	let expanded = new Set();
	let membersByOrg = {};
	let membersLoading = new Set();
	let invites = {};
	let inviteBusy = new Set();
	let pendingRemove = null;
	let removing = false;

	let accessByOrg = {};
	let entitiesByOrg = {};
	let accessLoading = new Set();
	let grantForms = {};
	let grantBusy = new Set();
	let pendingRevoke = null;
	let revoking = false;

	let showCreate = false;
	let newOrg = { name: '', slug: '' };
	let creating = false;
	let success = '';

	onMount(loadOrgs);

	async function loadOrgs() {
		loading = true;
		error = '';
		success = '';
		try {
			orgs = await api.getOrganizations();
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	function toggleExpanded(id) {
		expanded = new Set(
			expanded.has(id) ? [...expanded].filter((x) => x !== id) : [...expanded, id]
		);
		if (expanded.has(id)) {
			if (!invites[id]) invites[id] = { email: '', role: 'member' };
			if (!grantForms[id]) grantForms[id] = { email: '', entityId: '' };
			if (!membersByOrg[id]) loadMembers(id);
			if (!accessByOrg[id]) loadAccess(id);
			if (!entitiesByOrg[id]) loadEntities(id);
		}
	}

	async function loadMembers(orgId) {
		membersLoading = new Set([...membersLoading, orgId]);
		error = '';
		try {
			membersByOrg[orgId] = await api.getOrgMembersDetail(orgId);
			membersByOrg = { ...membersByOrg };
		} catch (e) {
			error = e.message;
		} finally {
			membersLoading = new Set([...membersLoading].filter((x) => x !== orgId));
		}
	}

	async function loadAccess(orgId) {
		accessLoading = new Set([...accessLoading, orgId]);
		error = '';
		try {
			accessByOrg[orgId] = await api.getEntityAccessDetail(orgId);
			accessByOrg = { ...accessByOrg };
		} catch (e) {
			error = e.message;
		} finally {
			accessLoading = new Set([...accessLoading].filter((x) => x !== orgId));
		}
	}

	async function loadEntities(orgId) {
		error = '';
		try {
			entitiesByOrg[orgId] = await api.getOrgEntities(orgId);
			entitiesByOrg = { ...entitiesByOrg };
		} catch (e) {
			error = e.message;
		}
	}

	async function doGrant(orgId) {
		const form = grantForms[orgId];
		if (!form?.email?.trim() || !form.entityId) return;
		grantBusy = new Set([...grantBusy, orgId]);
		error = '';
		success = '';
		try {
			await api.grantEntityAccess(orgId, form.email.trim(), form.entityId);
			grantForms[orgId] = { email: '', entityId: '' };
			grantForms = { ...grantForms };
			success = 'Access granted.';
			await loadAccess(orgId);
		} catch (e) {
			error = e.message;
		} finally {
			grantBusy = new Set([...grantBusy].filter((x) => x !== orgId));
		}
	}

	async function confirmRevoke() {
		const { orgId, grant } = pendingRevoke;
		revoking = true;
		error = '';
		success = '';
		try {
			await api.revokeEntityAccess(orgId, grant.user_id);
			pendingRevoke = null;
			success = 'Access revoked.';
			await loadAccess(orgId);
		} catch (e) {
			error = e.message;
		} finally {
			revoking = false;
		}
	}

	async function changeRole(orgId, member, role) {
		if (role === member.role) return;
		error = '';
		success = '';
		try {
			await api.updateMemberRole(orgId, member.user_id, role);
			await loadMembers(orgId);
		} catch (e) {
			error = e.message;
		}
	}

	async function doInvite(orgId) {
		const inv = invites[orgId];
		if (!inv?.email?.trim()) return;
		inviteBusy = new Set([...inviteBusy, orgId]);
		error = '';
		success = '';
		try {
			await api.inviteMember(orgId, inv.email.trim(), inv.role);
			invites[orgId] = { email: '', role: 'member' };
			invites = { ...invites };
			success = 'Invite sent.';
			await loadMembers(orgId);
		} catch (e) {
			error = e.message;
		} finally {
			inviteBusy = new Set([...inviteBusy].filter((x) => x !== orgId));
		}
	}

	async function confirmRemove() {
		const { orgId, member } = pendingRemove;
		removing = true;
		error = '';
		success = '';
		try {
			await api.removeMember(orgId, member.user_id);
			pendingRemove = null;
			await loadMembers(orgId);
		} catch (e) {
			error = e.message;
		} finally {
			removing = false;
		}
	}

	async function createOrg() {
		creating = true;
		error = '';
		success = '';
		try {
			await api.createOrganization(newOrg.name, newOrg.slug);
			showCreate = false;
			newOrg = { name: '', slug: '' };
			success = 'Organization created — switch to it in the top bar.';
			await api.refreshOrganizations();
			await loadOrgs();
		} catch (e) {
			error = e.message;
		} finally {
			creating = false;
		}
	}
</script>

{#if !isAdmin && $activeOrgRole === null}
	<p class="empty">Loading…</p>
{:else if !isAdmin}
	<div class="card">
		<p class="muted">This page is for organization administrators only.</p>
	</div>
{:else}
	<div class="page-header">
		<div>
			<h1>Organizations</h1>
			<p class="subtitle">Client organizations and their members.</p>
		</div>
		<button class="btn btn-primary" onclick={() => (showCreate = true)}>+ New organization</button>
	</div>

	{#if success}<p class="success-text">{success}</p>{/if}
	{#if error}<p class="error-text">{error}</p>{/if}

	{#if loading}
		<p class="empty">Loading…</p>
	{:else if orgs.length === 0}
		<p class="empty">No organizations yet.</p>
	{:else}
		<div class="orgs">
			{#each orgs as org (org.id)}
				<div class="org-card">
					<button class="org-head" onclick={() => toggleExpanded(org.id)}>
						<span class="chev" class:open={expanded.has(org.id)}>▸</span>
						<span class="org-name">{org.name}</span>
						<span class="slug">{org.slug}</span>
						<span class="created">Created {formatDate(org.created_at)}</span>
					</button>

					{#if expanded.has(org.id)}
						<div class="org-body">
							{#if membersLoading.has(org.id)}
								<p class="muted">Loading members…</p>
							{:else}
								{#if (membersByOrg[org.id] ?? []).length === 0}
									<p class="muted">No members.</p>
								{:else}
									<table>
										<thead>
											<tr>
												<th>Name</th>
												<th>Email</th>
												<th>Role</th>
												<th></th>
											</tr>
										</thead>
										<tbody>
											{#each membersByOrg[org.id] ?? [] as member (member.user_id)}
												<tr>
													<td>
														{member.display_name ?? '—'}{member.user_id === $user?.id
															? ' (you)'
															: ''}
													</td>
													<td>{member.email}</td>
													<td>
														<select
															class="select role-select"
															value={member.role}
															disabled={member.user_id === $user?.id}
															onchange={(e) => changeRole(org.id, member, e.target.value)}
														>
															{#each roles as r (r.value)}
																<option value={r.value}>{r.label}</option>
															{/each}
														</select>
													</td>
													<td class="row-actions">
														<button
															class="btn btn-small btn-danger"
															disabled={member.user_id === $user?.id}
															onclick={() => (pendingRemove = { orgId: org.id, org, member })}
														>Remove</button>
													</td>
												</tr>
											{/each}
										</tbody>
									</table>
								{/if}

								<form class="invite" onsubmit={(e) => { e.preventDefault(); doInvite(org.id); }}>
									<input
										class="input"
										type="email"
										placeholder="Email to invite"
										bind:value={invites[org.id].email}
										required
									/>
									<select class="select" bind:value={invites[org.id].role}>
										{#each roles as r (r.value)}
											<option value={r.value}>{r.label}</option>
										{/each}
									</select>
									<button
										class="btn"
										disabled={inviteBusy.has(org.id)}
									>{inviteBusy.has(org.id) ? 'Inviting…' : 'Invite'}</button>
								</form>
							{/if}

							<h4 class="section-title">Entity access</h4>
							{#if accessLoading.has(org.id)}
								<p class="muted">Loading access…</p>
							{:else}
								{#if (accessByOrg[org.id] ?? []).length === 0}
									<p class="muted">No entity grants.</p>
								{:else}
									<table>
										<thead>
											<tr>
												<th>Entity</th>
												<th>Name</th>
												<th>Email</th>
												<th>Role</th>
												<th></th>
											</tr>
										</thead>
										<tbody>
											{#each accessByOrg[org.id] ?? [] as grant (`${grant.user_id}-${grant.ownership_entity_id}`)}
												<tr>
													<td>{grant.entity_name}</td>
													<td>{grant.display_name ?? '—'}</td>
													<td>{grant.email}</td>
													<td>{grant.role}</td>
													<td class="row-actions">
														<button
															class="btn btn-small btn-danger"
															onclick={() => (pendingRevoke = { orgId: org.id, org, grant })}
														>Revoke</button>
													</td>
												</tr>
											{/each}
										</tbody>
									</table>
								{/if}

								<form class="invite" onsubmit={(e) => { e.preventDefault(); doGrant(org.id); }}>
									<input
										class="input"
										type="email"
										placeholder="Partner email"
										bind:value={grantForms[org.id].email}
										required
									/>
									<select
										class="select entity-select"
										bind:value={grantForms[org.id].entityId}
										required
									>
										<option value="" disabled>Select entity</option>
										{#each entitiesByOrg[org.id] ?? [] as e (e.id)}
											<option value={e.id}>{e.name}</option>
										{/each}
									</select>
									<button class="btn" disabled={grantBusy.has(org.id)}>
										{grantBusy.has(org.id) ? 'Granting…' : 'Grant access'}
									</button>
								</form>
							{/if}
						</div>
					{/if}
				</div>
			{/each}
		</div>
	{/if}

	{#if showCreate}
		<Modal title="New organization" onClose={() => (showCreate = false)}>
			<form onsubmit={(e) => { e.preventDefault(); createOrg(); }}>
				<div class="field">
					<label for="new-org-name">Organization name</label>
					<input
						class="input"
						id="new-org-name"
						placeholder="e.g. DCX"
						bind:value={newOrg.name}
						required
					/>
				</div>
				<div class="field">
					<label for="new-org-slug">Slug</label>
					<input class="input" id="new-org-slug" placeholder="e.g. dcx" bind:value={newOrg.slug} required />
				</div>
				<div class="form-actions">
					<button type="button" class="btn" onclick={() => (showCreate = false)}>Cancel</button>
					<button class="btn btn-primary" disabled={creating}>
						{creating ? 'Creating…' : 'Create'}
					</button>
				</div>
			</form>
		</Modal>
	{/if}

	{#if pendingRemove}
		<ConfirmDialog
			title="Remove member"
			message={`Remove ${pendingRemove.member.email} from ${pendingRemove.org.name}?`}
			confirmLabel="Remove"
			busy={removing}
			onConfirm={confirmRemove}
			onCancel={() => (pendingRemove = null)}
		/>
	{/if}

	{#if pendingRevoke}
		<ConfirmDialog
			title="Revoke entity access"
			message={`Revoke ${pendingRevoke.grant.email}'s access to ${pendingRevoke.grant.entity_name}? They will no longer be a member of ${pendingRevoke.org.name}.`}
			confirmLabel="Revoke"
			busy={revoking}
			onConfirm={confirmRevoke}
			onCancel={() => (pendingRevoke = null)}
		/>
	{/if}
{/if}

<style>
	.orgs {
		display: grid;
		gap: 0.75rem;
	}
	.org-card {
		border: 1px solid var(--border);
		border-radius: var(--radius);
		background: var(--surface);
		overflow: hidden;
	}
	.org-head {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		width: 100%;
		padding: 0.85rem 1rem;
		border: none;
		background: none;
		cursor: pointer;
		font: inherit;
		text-align: left;
	}
	.org-head:hover {
		background: #f9fafb;
	}
	.chev {
		display: inline-block;
		color: var(--text-muted);
		transition: transform 0.12s ease;
		font-size: 12px;
		line-height: 1;
	}
	.chev.open {
		transform: rotate(90deg);
	}
	.org-name {
		font-weight: 600;
	}
	.slug {
		color: var(--text-muted);
		font-size: 13px;
	}
	.created {
		margin-left: auto;
		color: var(--text-muted);
		font-size: 12px;
	}
	.org-body {
		padding: 0 1rem 1rem;
		border-top: 1px solid var(--border);
	}
	.org-body table {
		margin-top: 0.85rem;
	}
	.role-select {
		width: auto;
	}
	.section-title {
		margin-top: 1.25rem;
	}
	.entity-select {
		max-width: 260px;
	}
	.invite {
		display: flex;
		gap: 0.5rem;
		margin-top: 0.85rem;
	}
	.invite .input {
		max-width: 320px;
	}
	.form-actions {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
		margin-top: 0.5rem;
	}
</style>
