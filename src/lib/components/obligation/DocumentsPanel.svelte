<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import ConfirmDialog from '../ui/ConfirmDialog.svelte';
	import { formatDate, formatSize } from '$lib/utils/format.js';

	export let entityType;
	export let entityId;

	let documents = [];
	let loading = true;
	let error = '';
	let uploading = false;
	let pendingDelete = null;

	onMount(load);

	async function load() {
		loading = true;
		try {
			documents = await api.getDocuments({ entityType, entityId });
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	async function onFile(event) {
		const file = event.target.files?.[0];
		if (!file) return;
		uploading = true;
		error = '';
		try {
			await api.uploadDocument(entityType, entityId, file);
			await load();
		} catch (e) {
			error = e.message;
		} finally {
			uploading = false;
			event.target.value = '';
		}
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
</script>

<div class="docs">
	<div class="docs-head">
		<h3>Documents</h3>
		<label class="btn">
			{uploading ? 'Uploading…' : 'Attach file'}
			<input type="file" hidden onchange={onFile} disabled={uploading} />
		</label>
	</div>

	{#if error}<p class="error-text">{error}</p>{/if}

	{#if loading}
		<p class="empty">Loading…</p>
	{:else if documents.length === 0}
		<p class="empty">No documents attached.</p>
	{:else}
		<ul class="doc-list">
			{#each documents as doc (doc.id)}
				<li>
					<button class="link-btn" type="button" onclick={() => openDoc(doc)} title={doc.file_name}>
						{doc.file_name}
					</button>
					<span class="meta">
						{formatSize(doc.size_bytes)} · {formatDate(doc.created_at)}
					</span>
					<button class="btn btn-small btn-danger" onclick={() => (pendingDelete = doc)}>Delete</button>
				</li>
			{/each}
		</ul>
	{/if}
</div>

{#if pendingDelete}
	<ConfirmDialog
		message={`Delete "${pendingDelete.file_name}"?`}
		onConfirm={confirmDelete}
		onCancel={() => (pendingDelete = null)}
	/>
{/if}

<style>
	.docs-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		margin-bottom: 0.5rem;
	}
	.docs-head h3 {
		margin: 0;
	}
	.doc-list {
		list-style: none;
		margin: 0;
		padding: 0;
	}
	.doc-list li {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		padding: 0.4rem 0;
		border-bottom: 1px solid var(--border);
	}
	.doc-list li:last-child {
		border-bottom: none;
	}
	.link-btn {
		flex: 1;
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		text-align: left;
		border: none;
		background: none;
		padding: 0;
		color: var(--primary);
		cursor: pointer;
		font: inherit;
	}
	.link-btn:hover {
		text-decoration: underline;
	}
	.meta {
		color: var(--text-muted);
		font-size: 12px;
		white-space: nowrap;
	}
	.btn-small {
		padding: 0.2rem 0.5rem;
		font-size: 12px;
	}
</style>
