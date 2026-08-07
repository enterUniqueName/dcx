<script>
	import { onMount } from 'svelte';
	import Modal from '../ui/Modal.svelte';
	import ConfirmDialog from '../ui/ConfirmDialog.svelte';
	import CrudForm from './CrudForm.svelte';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	// Config-driven CRUD list page.
	//   title, description      page chrome
	//   columns                 [{ key, label, format: 'text'|'money'|'date'|'yesno' }]
	//   fields                  form field defs (see CrudForm)
	//   defaults                values for new records
	//   load/create/update/remove  async api functions
	//   loadReferences          optional async () => { sourceKey: [{id, name}] }
	export let title = '';
	export let description = '';
	export let columns = [];
	export let fields = [];
	export let defaults = {};
	export let load = null;
	export let create = null;
	export let update = null;
	export let remove = null;
	export let loadReferences = null;

	let rows = [];
	let references = {};
	let loading = true;
	let error = '';
	let search = '';
	let showForm = false;
	let editing = null;
	let saving = false;
	let pendingDelete = null;

	onMount(loadData);

	async function loadData() {
		loading = true;
		error = '';
		try {
			rows = await load();
			if (loadReferences) references = await loadReferences();
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	function openCreate() {
		editing = null;
		showForm = true;
	}

	function openEdit(row) {
		editing = row;
		showForm = true;
	}

	async function submit(payload) {
		saving = true;
		error = '';
		try {
			if (editing) await update(editing.id, payload);
			else await create(payload);
			showForm = false;
			await loadData();
		} catch (e) {
			error = e.message;
		} finally {
			saving = false;
		}
	}

	async function confirmDelete() {
		try {
			await remove(pendingDelete.id);
			pendingDelete = null;
			await loadData();
		} catch (e) {
			error = e.message;
		}
	}

	$: filtered = rows.filter((row) => {
		const q = search.trim().toLowerCase();
		if (!q) return true;
		return columns.some((c) => String(row[c.key] ?? '').toLowerCase().includes(q));
	});

	function cell(row, col) {
		const v = row[col.key];
		if (v === null || v === undefined || v === '') return '—';
		if (col.format === 'money') return formatMoney(v);
		if (col.format === 'date') return formatDate(v);
		if (col.format === 'yesno') return v ? 'Yes' : 'No';
		return String(v).replace(/_/g, ' ');
	}
</script>

<div class="page-header">
	<div>
		<h1>{title}</h1>
		{#if description}<p class="subtitle">{description}</p>{/if}
	</div>
	<button class="btn btn-primary" onclick={openCreate}>+ New</button>
</div>

<div class="filters">
	<input class="input search" placeholder="Search…" bind:value={search} />
</div>

{#if error}<p class="error-text">{error}</p>{/if}

{#if loading}
	<p class="empty">Loading…</p>
{:else if filtered.length === 0}
	<p class="empty">Nothing here yet.</p>
{:else}
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					{#each columns as col (col.key)}<th>{col.label}</th>{/each}
					<th></th>
				</tr>
			</thead>
			<tbody>
				{#each filtered as row (row.id)}
					<tr>
						{#each columns as col (col.key)}
							<td class:num={col.format === 'money'}>{cell(row, col)}</td>
						{/each}
						<td class="row-actions">
							<button class="btn btn-small" onclick={() => openEdit(row)}>Edit</button>
							<button class="btn btn-small btn-danger" onclick={() => (pendingDelete = row)}>Delete</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

{#if showForm}
	<Modal title={editing ? `Edit ${title.toLowerCase()}` : `New ${title.toLowerCase()}`} onClose={() => (showForm = false)}>
		<CrudForm
			fields={fields}
			references={references}
			initial={editing}
			defaults={defaults}
			busy={saving}
			onSubmit={submit}
			onCancel={() => (showForm = false)}
		/>
	</Modal>
{/if}

{#if pendingDelete}
	<ConfirmDialog
		message={`Delete "${pendingDelete.name ?? pendingDelete.lender ?? pendingDelete.id}"? This cannot be undone.`}
		onConfirm={confirmDelete}
		onCancel={() => (pendingDelete = null)}
	/>
{/if}
