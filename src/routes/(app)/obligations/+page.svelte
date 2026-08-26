<script>
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { api } from '$lib/api';
	import StatusBadge from '$lib/components/ui/StatusBadge.svelte';
	import DueChip from '$lib/components/ui/DueChip.svelte';
	import { formatMoney, formatDate } from '$lib/utils/format.js';
	import { sortRows, nextSort } from '$lib/utils/sort.js';

	let tab = 'bills';
	let bills = [];
	let templates = [];
	let entities = [];
	let properties = [];
	let loans = [];
	let loading = true;
	let error = '';

	let search = '';
	let status = 'all';
	let entityId = '';
	let groupByProperty = false;

	let loanSearch = '';
	let utilitySearch = '';
	let loanSortKey = '';
	let loanSortDir = 'asc';
	let utilitySortKey = '';
	let utilitySortDir = 'asc';

	let tplSortKey = '';
	let tplSortDir = 'asc';

	const STATUSES = [
		{ value: 'all', label: 'All statuses' },
		{ value: 'open', label: 'Open' },
		{ value: 'overdue', label: 'Overdue' },
		{ value: 'canceled', label: 'Canceled' }
	];

	$: propertyMap = Object.fromEntries(properties.map((p) => [p.id, p]));
	$: loanMap = Object.fromEntries(loans.map((l) => [l.id, l]));

	// --- Bills: exclude paid, split by category ---
	$: activeBills = bills.filter((b) => b.status !== 'paid');
	$: displayBills =
		status === 'overdue'
			? activeBills.filter((b) => b.is_overdue && b.status === 'open')
			: activeBills;
	$: loanBills = displayBills.filter((b) => b.category === 'loan_payment');
	$: utilityBills = displayBills.filter((b) => b.category !== 'loan_payment');

	$: visibleLoanBills = loanBills.filter((b) =>
		b.name.toLowerCase().includes(loanSearch.trim().toLowerCase())
	);
	$: visibleUtilityBills = utilityBills.filter((b) =>
		b.name.toLowerCase().includes(utilitySearch.trim().toLowerCase())
	);

	$: loanColumns = [
		{ key: 'name', label: 'Bill', format: 'text', value: (b) => b.name },
		{
			key: 'lender',
			label: 'Lender',
			format: 'text',
			value: (b) => loanMap[b.loan_id]?.lender
		},
		{
			key: 'entity',
			label: 'Entity',
			format: 'text',
			value: (b) => loanMap[b.loan_id]?.ownership_entity_name
		},
		{
			key: 'property',
			label: 'Property',
			format: 'text',
			value: (b) => propertyMap[loanMap[b.loan_id]?.property_id]?.address1
		},
		{ key: 'due', label: 'Due', format: 'date', value: (b) => b.next_due_date },
		{ key: 'amount', label: 'Amount', format: 'money', value: (b) => b.est_amount ?? b.amount },
		{
			key: 'status',
			label: 'Status',
			format: 'text',
			value: (b) => (b.is_overdue ? 'overdue' : b.status)
		}
	];
	$: loanSortCol = loanColumns.find((c) => c.key === loanSortKey) ?? null;
	$: sortedLoanBills = sortRows(visibleLoanBills, loanSortCol, loanSortDir, loanSortCol?.value);

	$: utilityColumns = [
		{ key: 'name', label: 'Name', format: 'text', value: (b) => b.name },
		{ key: 'entity', label: 'Entity', format: 'text', value: (b) => b.ownership_entity_name },
		{
			key: 'property',
			label: 'Property',
			format: 'text',
			value: (b) => propertyMap[b.property_id]?.address1 ?? b.property_name
		},
		{ key: 'tenant', label: 'Tenant', format: 'text', value: (b) => b.tenant_name },
		{ key: 'category', label: 'Category', format: 'text', value: (b) => b.category },
		{ key: 'due', label: 'Due', format: 'date', value: (b) => b.next_due_date },
		{ key: 'amount', label: 'Amount', format: 'money', value: (b) => b.est_amount ?? b.amount },
		{
			key: 'status',
			label: 'Status',
			format: 'text',
			value: (b) => (b.is_overdue ? 'overdue' : b.status)
		}
	];
	$: utilitySortCol = utilityColumns.find((c) => c.key === utilitySortKey) ?? null;
	$: sortedUtilityBills = sortRows(
		visibleUtilityBills,
		utilitySortCol,
		utilitySortDir,
		utilitySortCol?.value
	);

	// --- Templates ---
	$: visibleTemplates = templates.filter((o) =>
		o.name.toLowerCase().includes(search.trim().toLowerCase())
	);

	$: tplColumns = [
		{ key: 'name', label: 'Name', format: 'text', value: (t) => t.name },
		{ key: 'entity', label: 'Entity', format: 'text', value: (t) => t.ownership_entity_name },
		{ key: 'property', label: 'Property', format: 'text', value: (t) => t.property_name },
		{ key: 'category', label: 'Category', format: 'text', value: (t) => t.category },
		{ key: 'frequency', label: 'Frequency', format: 'text', value: (t) => t.frequency },
		{ key: 'due', label: 'Next due', format: 'date', value: (t) => t.next_due_date },
		{ key: 'amount', label: 'Amount', format: 'money', value: (t) => t.amount },
		{ key: 'status', label: 'Status', format: 'text', value: (t) => t.status }
	];

	$: tplSortCol = tplColumns.find((c) => c.key === tplSortKey) ?? null;
	$: tplSorted = sortRows(visibleTemplates, tplSortCol, tplSortDir, tplSortCol?.value);

	$: tplDisplayRows = (() => {
		if (!groupByProperty) return tplSorted.map((t) => ({ kind: 'row', t }));
		const map = new Map();
		for (const t of tplSorted) {
			const key = t.property_name ?? '—';
			if (!map.has(key)) map.set(key, []);
			map.get(key).push(t);
		}
		const rows = [];
		for (const [name, group] of [...map.entries()].sort((a, b) =>
			a[0].localeCompare(b[0], undefined, { numeric: true })
		)) {
			rows.push({ kind: 'group', name, count: group.length });
			for (const t of group) rows.push({ kind: 'row', t });
		}
		return rows;
	})();

	function isDerived(ob) {
		return ob.est_amount != null && Number(ob.est_amount) !== Number(ob.amount);
	}

	function toggleLoanSort(key) {
		({ loanSortKey, loanSortDir } = nextSort(key, loanSortKey, loanSortDir));
	}
	function toggleUtilitySort(key) {
		({ utilitySortKey, utilitySortDir } = nextSort(key, utilitySortKey, utilitySortDir));
	}
	function toggleTpl(key) {
		({ tplSortKey, tplSortDir } = nextSort(key, tplSortKey, tplSortDir));
	}

	onMount(load);

	async function load() {
		loading = true;
		error = '';
		try {
			const [b, t, e, p, l] = await Promise.all([
				loadBills(),
				api.getTemplates(),
				api.getOwnershipEntities(),
				api.getProperties(),
				api.getLoans()
			]);
			bills = b;
			templates = t;
			entities = e;
			properties = p;
			loans = l;
		} catch (e2) {
			error = e2.message;
		} finally {
			loading = false;
		}
	}

	async function loadBills() {
		const opts = {
			ownershipEntityId: entityId || undefined
		};
		if (status === 'all' || status === 'overdue') {
			return api.getBills(opts);
		}
		return api.getBills({ ...opts, status });
	}

	async function reload() {
		loading = true;
		error = '';
		try {
			bills = await loadBills();
		} catch (e2) {
			error = e2.message;
		} finally {
			loading = false;
		}
	}
</script>

<div class="page-header">
	<div>
		<h1>Obligations</h1>
		<p class="subtitle">
			Templates define recurring bills; bills are the concrete due / paid invoices.
		</p>
	</div>
	<div class="actions">
		<a class="btn" href={`${base}/obligations/new?kind=template`}>+ New template</a>
		<a class="btn btn-primary" href={`${base}/obligations/new?kind=bill`}>+ New bill</a>
	</div>
</div>

<div class="tabs">
	<button class:active={tab === 'bills'} onclick={() => (tab = 'bills')}>
		Bills <span class="count">{activeBills.length}</span>
	</button>
	<button class:active={tab === 'templates'} onclick={() => (tab = 'templates')}>
		Templates <span class="count">{templates.length}</span>
	</button>
</div>

{#if !loading}
	<div class="filters">
		{#if tab === 'bills'}
			<select class="select" bind:value={status} onchange={reload}>
				{#each STATUSES as s}<option value={s.value}>{s.label}</option>{/each}
			</select>
			<select class="select" bind:value={entityId} onchange={reload}>
				<option value="">All entities</option>
				{#each entities as e}<option value={e.id}>{e.name}</option>{/each}
			</select>
		{:else}
			<input class="input search" placeholder="Search by name…" bind:value={search} />
			<label class="group-toggle">
				<input type="checkbox" bind:checked={groupByProperty} />
				Group by property
			</label>
		{/if}
	</div>
{/if}

{#if error}<p class="error-text">{error}</p>{/if}

{#if loading}
	<p class="empty">Loading…</p>
{:else if tab === 'bills'}
	{#if activeBills.length === 0}
		<p class="empty">No bills yet.</p>
	{:else}
		<!-- Loan Payments -->
		<div class="bill-section">
			<div class="section-header">
				<h2>Loan Payments</h2>
				<input
					class="input section-search"
					placeholder="Search loans…"
					bind:value={loanSearch}
				/>
			</div>
			{#if sortedLoanBills.length === 0}
				<p class="empty">No loan payments.</p>
			{:else}
				<div class="table-scroll">
					<table>
						<thead>
							<tr>
								{#each loanColumns as col (col.key)}
									<th
										class:sortable={true}
										class:sorted={loanSortKey === col.key}
										onclick={() => toggleLoanSort(col.key)}
									>{col.label}{#if loanSortKey === col.key}<span class="sort-ind">{loanSortDir === 'asc' ? '▲' : '▼'}</span>{/if}</th>
								{/each}
							</tr>
						</thead>
						<tbody>
							{#each sortedLoanBills as ob (ob.id)}
								<tr>
									<td>
										<a href={`${base}/obligations/${ob.id}`}>{ob.name}</a>
									</td>
									<td>{loanMap[ob.loan_id]?.lender ?? '—'}</td>
									<td>{loanMap[ob.loan_id]?.ownership_entity_name ?? '—'}</td>
									<td>{propertyMap[loanMap[ob.loan_id]?.property_id]?.address1 ?? '—'}</td>
									<td><DueChip dueDate={ob.next_due_date} /></td>
									<td class="num">{formatMoney(ob.est_amount ?? ob.amount)}</td>
									<td><StatusBadge status={ob.is_overdue ? 'overdue' : ob.status} /></td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>

		<!-- Utility Bills -->
		<div class="bill-section">
			<div class="section-header">
				<h2>Utility Bills</h2>
				<input
					class="input section-search"
					placeholder="Search utilities…"
					bind:value={utilitySearch}
				/>
			</div>
			{#if sortedUtilityBills.length === 0}
				<p class="empty">No utility bills.</p>
			{:else}
				<div class="table-scroll">
					<table>
						<thead>
							<tr>
								{#each utilityColumns as col (col.key)}
									<th
										class:sortable={true}
										class:sorted={utilitySortKey === col.key}
										onclick={() => toggleUtilitySort(col.key)}
									>{col.label}{#if utilitySortKey === col.key}<span class="sort-ind">{utilitySortDir === 'asc' ? '▲' : '▼'}</span>{/if}</th>
								{/each}
							</tr>
						</thead>
						<tbody>
							{#each sortedUtilityBills as ob (ob.id)}
								<tr>
									<td>
										<a href={`${base}/obligations/${ob.id}`}>{ob.name}</a>
									</td>
									<td>{ob.ownership_entity_name ?? '—'}</td>
									<td>{propertyMap[ob.property_id]?.address1 ?? ob.property_name ?? '—'}</td>
									<td>{ob.tenant_name ?? '—'}</td>
									<td>{ob.category}</td>
									<td><DueChip dueDate={ob.next_due_date} /></td>
									<td class="num">
										{formatMoney(ob.est_amount ?? ob.amount)}
										{#if isDerived(ob)}<span class="est" title="Estimated: average of the last 3 bills">est</span>{/if}
									</td>
									<td><StatusBadge status={ob.is_overdue ? 'overdue' : ob.status} /></td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	{/if}
{:else}
	{#if templates.length === 0}
		<p class="empty">No templates yet. Create one to start generating bills.</p>
	{:else}
		<div class="table-wrap">
			<table>
				<thead>
					<tr>
						{#each tplColumns as col (col.key)}
							<th
								class:sortable={true}
								class:sorted={tplSortKey === col.key}
								onclick={() => toggleTpl(col.key)}
							>{col.label}{#if tplSortKey === col.key}<span class="sort-ind">{tplSortDir === 'asc' ? '▲' : '▼'}</span>{/if}</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each tplDisplayRows as r (r.kind === 'group' ? `g:${r.name}` : `r:${r.t.id}`)}
						{#if r.kind === 'group'}
							<tr class="group-row">
								<td colspan={tplColumns.length}>
									<span class="group-title">{r.name}</span>
									<span class="group-count">{r.count} {r.count === 1 ? 'template' : 'templates'}</span>
								</td>
							</tr>
						{:else}
							<tr>
								<td><a href={`${base}/obligations/${r.t.id}`}>{r.t.name}</a></td>
								<td>{r.t.ownership_entity_name ?? '—'}</td>
								<td>{r.t.property_name ?? '—'}</td>
								<td>{r.t.category}</td>
								<td>{r.t.frequency.replace('_', ' ')}</td>
								<td>{formatDate(r.t.next_due_date)}</td>
								<td class="num">{formatMoney(r.t.amount)}</td>
								<td>{r.t.status}</td>
							</tr>
						{/if}
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
{/if}

<style>
	.actions {
		display: flex;
		gap: 0.5rem;
	}
	.tabs {
		display: flex;
		gap: 0.25rem;
		margin-bottom: 1rem;
		border-bottom: 1px solid var(--border);
	}
	.tabs button {
		background: none;
		border: none;
		border-bottom: 2px solid transparent;
		padding: 0.5rem 0.9rem;
		font-weight: 600;
		color: var(--text-muted);
		cursor: pointer;
	}
	.tabs button.active {
		color: var(--text);
		border-bottom-color: var(--primary);
	}
	.count {
		font-size: 11px;
		color: var(--text-muted);
		margin-left: 0.25rem;
	}
	.filters {
		display: flex;
		flex-wrap: wrap;
		gap: 0.6rem;
		margin-bottom: 1rem;
	}
	.search {
		flex: 1;
		min-width: 180px;
		max-width: 320px;
	}
	.filters .select {
		width: auto;
	}
	.group-toggle {
		display: inline-flex;
		align-items: center;
		gap: 0.4rem;
		font-size: 13px;
		color: var(--text);
		cursor: pointer;
		user-select: none;
		white-space: nowrap;
		padding: 0.4rem 0.6rem;
	}
	th.sortable {
		cursor: pointer;
		user-select: none;
		white-space: nowrap;
	}
	th.sortable:hover {
		background: #eef2f6;
	}
	th.sorted {
		color: var(--text);
	}
	.sort-ind {
		font-size: 10px;
		margin-left: 0.3rem;
	}
	.group-row > td {
		background: #eef2f6;
		font-size: 12px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.03em;
		color: var(--text-muted);
		padding: 0.35rem 0.75rem;
	}
	.group-title {
		color: var(--text);
	}
	.group-count {
		margin-left: 0.5rem;
		font-weight: 500;
	}
	.bill-section {
		margin-bottom: 1.5rem;
	}
	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		margin-bottom: 0.5rem;
	}
	.section-header h2 {
		margin: 0;
		font-size: 1rem;
	}
	.section-search {
		max-width: 260px;
	}
	.table-scroll {
		max-height: 460px;
		overflow-y: auto;
		border: 1px solid var(--border);
		border-radius: var(--radius);
	}
	.table-scroll table {
		margin: 0;
	}
	.est {
		font-size: 11px;
		color: var(--text-muted);
		margin-left: 0.25rem;
		text-transform: uppercase;
	}
</style>
