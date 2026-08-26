<script>
	import StatusBadge from '../ui/StatusBadge.svelte';
	import DueChip from '../ui/DueChip.svelte';
	import { base } from '$app/paths';
	import { formatMoney } from '$lib/utils/format.js';
	import { sortRows, nextSort } from '$lib/utils/sort.js';

	export let obligations = [];
	export let showReceived = false;
	export let showStatus = true;
	export let groupByProperty = false;

	let sortKey = '';
	let sortDir = 'asc';

	$: columns = [
		{ key: 'name', label: 'Name', format: 'text', value: (o) => o.name },
		{ key: 'entity', label: 'Entity', format: 'text', value: (o) => o.ownership_entity_name },
		{ key: 'property', label: 'Property', format: 'text', value: (o) => o.property_name && o.property_address1 ? `${o.property_name} - ${o.property_address1}` : (o.property_name ?? '—') },
		{ key: 'lender', label: 'Lender', format: 'text', value: (o) => o.loan_name ?? '—' },
		{ key: 'category', label: 'Category', format: 'text', value: (o) => o.category },
		{ key: 'due', label: 'Due', format: 'date', value: (o) => o.next_due_date },
		{ key: 'amount', label: 'Amount', format: 'money', value: (o) => o.est_amount ?? o.amount },
		...(showReceived
			? [{ key: 'received', label: 'Received', format: 'yesno', value: (o) => o.received }]
			: []),
		...(showStatus
			? [
					{
						key: 'status',
						label: 'Status',
						format: 'text',
						value: (o) => (o.is_overdue ? 'overdue' : o.status)
					}
				]
			: [])
	];

	$: sortCol = columns.find((c) => c.key === sortKey) ?? null;
	$: sorted = sortRows(obligations, sortCol, sortDir, sortCol?.value);

	$: displayRows = (() => {
		if (!groupByProperty) return sorted.map((ob) => ({ kind: 'row', ob }));
		const map = new Map();
		for (const ob of sorted) {
			const key = ob.property_name ?? '—';
			if (!map.has(key)) map.set(key, []);
			map.get(key).push(ob);
		}
		const rows = [];
		for (const [name, group] of [...map.entries()].sort((a, b) =>
			a[0].localeCompare(b[0], undefined, { numeric: true })
		)) {
			rows.push({ kind: 'group', name, count: group.length });
			for (const ob of group) rows.push({ kind: 'row', ob });
		}
		return rows;
	})();

	function toggle(key) {
		({ sortKey, sortDir } = nextSort(key, sortKey, sortDir));
	}

	function isDerived(ob) {
		return ob.est_amount != null && Number(ob.est_amount) !== Number(ob.amount);
	}
</script>

{#if obligations.length === 0}
	<p class="empty">Nothing here.</p>
{:else}
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					{#each columns as col (col.key)}
						<th
							class:sortable={true}
							class:sorted={sortKey === col.key}
							onclick={() => toggle(col.key)}
						>{col.label}{#if sortKey === col.key}<span class="sort-ind">{sortDir === 'asc' ? '▲' : '▼'}</span>{/if}</th>
					{/each}
				</tr>
			</thead>
			<tbody>
				{#each displayRows as r (r.kind === 'group' ? `g:${r.name}` : `r:${r.ob.id}`)}
					{#if r.kind === 'group'}
						<tr class="group-row">
							<td colspan={columns.length}>
								<span class="group-title">{r.name}</span>
								<span class="group-count">{r.count} {r.count === 1 ? 'item' : 'items'}</span>
							</td>
						</tr>
					{:else}
						<tr>
							<td>
								<a href={`${base}/obligations/${r.ob.id}`}>{r.ob.name}</a>
							</td>
							<td>{r.ob.ownership_entity_name ?? '—'}</td>
							<td>{r.ob.property_name && r.ob.property_address1 ? `${r.ob.property_name} - ${r.ob.property_address1}` : (r.ob.property_name ?? '—')}</td>
							<td>{r.ob.loan_name ?? '—'}</td>
							<td>{r.ob.category}</td>
							<td><DueChip dueDate={r.ob.next_due_date} /></td>
							<td class="num">
								{formatMoney(r.ob.est_amount ?? r.ob.amount)}
								{#if isDerived(r.ob)}<span class="est" title="Estimated: average of the last 3 bills">est</span>{/if}
							</td>
							{#if showReceived}<td>{r.ob.received ? 'Yes' : 'No'}</td>{/if}
							{#if showStatus}<td><StatusBadge status={r.ob.is_overdue ? 'overdue' : r.ob.status} /></td>{/if}
						</tr>
					{/if}
				{/each}
			</tbody>
		</table>
	</div>
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
	.est {
		font-size: 11px;
		color: var(--text-muted);
		margin-left: 0.25rem;
		text-transform: uppercase;
	}
</style>
