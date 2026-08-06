<script>
	import { onMount } from 'svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import DocumentUploadModal from '$lib/components/documents/DocumentUploadModal.svelte';
	import { api } from '$lib/api';
	import { formatDate, formatSize } from '$lib/utils/format.js';

	const ENTITY_TYPES = [
		{ value: 'obligation', label: 'Obligation', load: () => api.getObligations() },
		{ value: 'property', label: 'Property', load: () => api.getProperties() },
		{ value: 'ownership_entity', label: 'Ownership entity', load: () => api.getOwnershipEntities() },
		{ value: 'loan', label: 'Loan', load: () => api.getLoans() },
		{ value: 'tenant', label: 'Tenant', load: () => api.getTenants() },
		{ value: 'vendor', label: 'Vendor', load: () => api.getVendors() },
		{ value: 'billback', label: 'Billback', load: () => api.getBillbacks() }
	];

	function typeLabel(value) {
		return ENTITY_TYPES.find((t) => t.value === value)?.label ?? value;
	}

	let rows = [];
	let loading = true;
	let error = '';
	let filterType = '';
	let filterEntityId = '';
	let entitiesForType = [];
	let search = '';
	let showUpload = false;
	let pendingDelete = null;

	onMount(load);

	async function load() {
		loading = true;
		error = '';
		try {
			rows = await api.getDocuments();
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	async function onTypeChange() {
		filterEntityId = '';
		entitiesForType = [];
		const def = ENTITY_TYPES.find((t) => t.value === filterType);
		if (!def) return;
		try {
			entitiesForType = await def.load();
		} catch (e) {
			error = e.message;
		}
	}

	async function uploaded(type, entityId, file) {
		await api.uploadDocument(type, entityId, file);
		showUpload = false;
		await load();
	}

	async function openDoc(doc) {
		try {
			const url = await api.getDocumentUrl(doc.id);
			window.open(url, '_blank');
		} catch (e) {
			error = e.message;
		}
	}

	async function confirmDelete() {
		try {
			await api.deleteDocument(pendingDelete.id);
			pendingDelete = null;
			await load();
		} catch (e) {
			error = e.message;
		}
	}

	$: visible = rows.filter((doc) => {
		if (filterType && doc.entity_type !== filterType) return false;
		if (filterEntityId && doc.entity_id !== filterEntityId) return false;
		const q = search.trim().toLowerCase();
		if (q && !String(doc.file_name ?? '').toLowerCase().includes(q)) return false;
		return true;
	});
</script>

<div class="page-header">
	<div>
		<h1>Documents</h1>
		<p class="subtitle">Files attached to obligations, properties, and more.</p>
	</div>
	<button class="btn btn-primary" onclick={() => (showUpload = true)}>+ Attach file</button>
</div>

<div class="filters">
	<select class="select" bind:value={filterType} onchange={onTypeChange}>
		<option value="">All types</option>
		{#each ENTITY_TYPES as t (t.value)}
			<option value={t.value}>{t.label}</option>
		{/each}
	</select>
	<select class="select" bind:value={filterEntityId} disabled={!filterType}>
		<option value="">All {filterType ? typeLabel(filterType).toLowerCase() : 'entities'}</option>
		{#each entitiesForType as e (e.id)}
			<option value={e.id}>{e.name ?? e.lender ?? e.description ?? '(unnamed)'}</option>
		{/each}
	</select>
	<input class="input search" placeholder="Search file names…" bind:value={search} />
</div>

{#if error}<p class="error-text">{error}</p>{/if}

{#if loading}
	<p class="empty">Loading…</p>
{:else if visible.length === 0}
	<p class="empty">No documents found.</p>
{:else}
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>File</th>
					<th>Entity</th>
					<th>Type</th>
					<th class="num">Size</th>
					<th>Uploaded</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				{#each visible as doc (doc.id)}
					<tr>
						<td>
							<button class="link-btn" onclick={() => openDoc(doc)} title={doc.file_name}>
								{doc.file_name}
							</button>
						</td>
						<td>{doc.entity_name ?? '—'}</td>
						<td>{typeLabel(doc.entity_type)}</td>
						<td class="num">{formatSize(doc.size_bytes)}</td>
						<td>{formatDate(doc.created_at)}</td>
						<td class="row-actions">
							<button class="btn btn-small" onclick={() => openDoc(doc)}>Open</button>
							<button class="btn btn-small btn-danger" onclick={() => (pendingDelete = doc)}>Delete</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

{#if showUpload}
	<DocumentUploadModal types={ENTITY_TYPES} onClose={() => (showUpload = false)} onUploaded={uploaded} />
{/if}

{#if pendingDelete}
	<ConfirmDialog
		message={`Delete "${pendingDelete.file_name}"? This removes the file from storage.`}
		onConfirm={confirmDelete}
		onCancel={() => (pendingDelete = null)}
	/>
{/if}

<style>
	.subtitle {
		color: var(--text-muted);
		margin-top: 0;
	}
	.filters {
		display: flex;
		gap: 0.6rem;
		margin-bottom: 1rem;
		flex-wrap: wrap;
	}
	.filters .select {
		min-width: 180px;
	}
	.search {
		max-width: 260px;
	}
	.num {
		text-align: right;
	}
	.row-actions {
		text-align: right;
		white-space: nowrap;
	}
	.link-btn {
		border: none;
		background: none;
		padding: 0;
		color: var(--primary);
		cursor: pointer;
		font: inherit;
		text-align: left;
	}
	.link-btn:hover {
		text-decoration: underline;
	}
	.btn-small {
		padding: 0.2rem 0.5rem;
		font-size: 12px;
	}
</style>
