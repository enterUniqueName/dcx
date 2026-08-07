<script>
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { api } from '$lib/api';
	import ObligationTable from '$lib/components/obligation/ObligationTable.svelte';

	let obligations = [];
	let entities = [];
	let loading = true;
	let error = '';

	let search = '';
	let status = 'all';
	let category = '';
	let entityId = '';

	const STATUSES = [
		{ value: 'all', label: 'All statuses' },
		{ value: 'open', label: 'Open' },
		{ value: 'overdue', label: 'Overdue' },
		{ value: 'paid', label: 'Paid' },
		{ value: 'canceled', label: 'Canceled' }
	];
	const CATEGORIES = [
		'water',
		'electric',
		'tax',
		'insurance',
		'loan_payment',
		'maintenance',
		'service',
		'reimbursement',
		'other'
	];

	$: query = { search, status, category, entityId };

	$: filtered = obligations.filter((o) =>
		o.name.toLowerCase().includes(search.trim().toLowerCase())
	);

	onMount(async () => {
		try {
			[obligations, entities] = await Promise.all([
				loadObligations(),
				api.getOwnershipEntities()
			]);
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});

	async function loadObligations() {
		const opts = {
			category: query.category || undefined,
			ownershipEntityId: query.entityId || undefined
		};
		if (query.status === 'all' || query.status === 'overdue') {
			// fetch broad set; overdue is derived (displayed via is_overdue)
			return api.getObligations(opts);
		}
		return api.getObligations({ ...opts, status: query.status });
	}

	async function reload() {
		loading = true;
		error = '';
		try {
			obligations = await loadObligations();
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}
</script>

<div class="page-header">
	<div>
		<h1>Obligations</h1>
		<p class="subtitle">Bills, utilities, taxes, insurance, loan payments, and work orders.</p>
	</div>
	<a class="btn btn-primary" href={`${base}/obligations/new`}>+ New obligation</a>
</div>

<div class="filters">
	<input
		class="input search"
		placeholder="Search by name…"
		bind:value={search}
	/>
	<select class="select" bind:value={status} onchange={reload}>
		{#each STATUSES as s}<option value={s.value}>{s.label}</option>{/each}
	</select>
	<select class="select" bind:value={category} onchange={reload}>
		<option value="">All categories</option>
		{#each CATEGORIES as c}<option value={c}>{c.replace('_', ' ')}</option>{/each}
	</select>
	<select class="select" bind:value={entityId} onchange={reload}>
		<option value="">All entities</option>
		{#each entities as e}<option value={e.id}>{e.name}</option>{/each}
	</select>
</div>

{#if error}<p class="error-text">{error}</p>{/if}

{#if loading}
	<p class="empty">Loading…</p>
{:else}
	{#if status === 'overdue'}
		<ObligationTable
			obligations={filtered.filter((o) => o.is_overdue && o.status === 'open')}
			showReceived={true}
		/>
	{:else}
		<ObligationTable obligations={filtered} showReceived={true} />
	{/if}
{/if}

<style>
	.filters {
		display: flex;
		flex-wrap: wrap;
		gap: 0.6rem;
		margin-bottom: 1rem;
	}
	.search {
		flex: 1;
		min-width: 180px;
	}
	.filters .select {
		width: auto;
	}
</style>
