<script>
	import { onMount } from 'svelte';
	import Modal from '../ui/Modal.svelte';
	import ConfirmDialog from '../ui/ConfirmDialog.svelte';
	import CrudForm from './CrudForm.svelte';
	import { formatMoney, formatDate } from '$lib/utils/format.js';
	import { sortRows, nextSort } from '$lib/utils/sort.js';

	// Config-driven CRUD list page.
	//   title, description      page chrome
	//   columns                 [{ key, label, format: 'text'|'money'|'date'|'yesno', signed }]
	//   fields                  form field defs (see CrudForm)
	//   defaults                values for new records
	//   load/create/update/remove  async api functions
	//   loadReferences          optional async () => { sourceKey: [{id, name}] }
	//   detail                  optional Svelte component rendered in an
	//                           expandable row; receives { row }
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
	export let detail = null;
	export let stickyFirst = false;

	let rows = [];
	let references = {};
	let loading = true;
	let error = '';
	let search = '';
	let showForm = false;
	let editing = null;
	let saving = false;
	let pendingDelete = null;
	let expanded = new Set();
	let sortKey = '';
	let sortDir = 'asc';

	function sort(col) {
		({ sortKey, sortDir } = nextSort(col.key, sortKey, sortDir));
	}

	function toggleExpanded(id) {
		expanded = new Set(
			expanded.has(id) ? [...expanded].filter((x) => x !== id) : [...expanded, id]
		);
	}

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

	$: filtered = (() => {
		const q = search.trim().toLowerCase();
		const list = q
			? rows.filter((row) =>
					columns.some((c) => String(row[c.key] ?? '').toLowerCase().includes(q))
				)
			: [...rows];
		if (sortKey) {
			const col = columns.find((c) => c.key === sortKey);
			if (col) return sortRows(list, col, sortDir);
		}
		return list;
	})();

	function cell(row, col) {
		const v = row[col.key];
		if (v === null || v === undefined || v === '') return '—';
		if (col.format === 'money') return formatMoney(v);
		if (col.format === 'date') return formatDate(v);
		if (col.format === 'yesno') return v ? 'Yes' : 'No';
		if (col.format === 'percent') return `${Number(v)}%`;
		return String(v).replace(/_/g, ' ');
	}

	function cellClass(col, row) {
		if (col.signed) {
			const n = Number(row[col.key] ?? 0);
			return n < 0 ? 'num neg' : 'num pos';
		}
		return col.format === 'money' ? 'num' : '';
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
					{#if detail}<th class="chev-cell"></th>{/if}
					{#each columns as col, i (col.key)}
						<th
							class:sticky={stickyFirst && i === 0}
							class:sortable={true}
							class:sorted={sortKey === col.key}
							onclick={() => sort(col)}
						>{col.label}{#if sortKey === col.key}<span class="sort-ind">{sortDir === 'asc' ? '▲' : '▼'}</span>{/if}</th>
					{/each}
					<th></th>
				</tr>
			</thead>
			<tbody>
				{#each filtered as row (row.id)}
					<tr
						class:expanded-row={expanded.has(row.id)}
						class:clickable={detail}
						onclick={detail ? () => toggleExpanded(row.id) : undefined}
					>
						{#if detail}
							<td class="chev-cell">
								<span class="chev" class:open={expanded.has(row.id)}>▸</span>
							</td>
						{/if}
						{#each columns as col, i (col.key)}
							<td
								class={cellClass(col, row)}
								class:sticky={stickyFirst && i === 0}
							>{cell(row, col)}</td>
						{/each}
						<td class="row-actions">
							<button
								class="btn btn-small"
								onclick={(e) => {
									e.stopPropagation();
									openEdit(row);
								}}
							>Edit</button>
							<button
								class="btn btn-small btn-danger"
								onclick={(e) => {
									e.stopPropagation();
									pendingDelete = row;
								}}
							>Delete</button>
						</td>
					</tr>
					{#if detail && expanded.has(row.id)}
						<tr class="detail-row">
							<td colspan={columns.length + 2}>
								<svelte:component this={detail} row={row} />
							</td>
						</tr>
					{/if}
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

<style>
	th.sortable {
		cursor: pointer;
		user-select: none;
		white-space: nowrap;
	}
	th.sortable:hover {
		background: #eef2f6;
	}
	th.sticky.sortable:hover {
		background: #eef2f6;
	}
	th.sorted {
		color: var(--text);
	}
	.sort-ind {
		font-size: 10px;
		margin-left: 0.3rem;
	}
	.chev-cell {
		width: 2rem;
		padding: 0 0 0 0.6rem;
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
	tr.clickable {
		cursor: pointer;
	}
	tr.expanded-row,
	tr.expanded-row:hover {
		background: #eff6ff;
	}
	th.sticky,
	td.sticky {
		position: sticky;
		left: 0;
		z-index: 2;
		background: var(--surface);
		box-shadow: inset -1px 0 0 var(--border);
	}
	th.sticky {
		z-index: 3;
		background: #f9fafb;
	}
	tbody tr:hover td.sticky {
		background: #f9fafb;
	}
	tr.expanded-row td.sticky,
	tr.expanded-row:hover td.sticky {
		background: #eff6ff;
	}
	.detail-row > td {
		background: #f9fafb;
		padding: 0;
		white-space: normal;
		overflow-wrap: anywhere;
	}
	.pos {
		color: var(--ok);
	}
	.neg {
		color: var(--danger);
		font-weight: 600;
	}
</style>
