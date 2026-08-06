<script>
	import { downloadCSV } from '$lib/utils/csv.js';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	// columns: [{ key, label, format: 'text'|'money'|'date' }]
	export let columns = [];
	export let rows = [];
	export let filename = 'report.csv';
	export let empty = 'Nothing to show.';
	export let loading = false;
	export let error = '';
	export let rowHref = null; // (row) => url | null — makes the first column a link
	export let rowKey = (row) => row.id ?? row.key;

	function cell(row, col) {
		const v = row[col.key];
		if (v === null || v === undefined || v === '') return '—';
		if (col.format === 'money') return formatMoney(v);
		if (col.format === 'date') return formatDate(v);
		return String(v).replace(/_/g, ' ');
	}
</script>

<div class="report">
	<div class="report-head">
		<h2>{filename.replace(/\.csv$/, '').replace(/[-_]/g, ' ')}</h2>
		<button class="btn" onclick={() => downloadCSV(filename, columns, rows)} disabled={rows.length === 0}>
			Export CSV
		</button>
	</div>

	{#if error}<p class="error-text">{error}</p>{/if}
	{#if loading}
		<p class="empty">Loading…</p>
	{:else if rows.length === 0}
		<p class="empty">{empty}</p>
	{:else}
		<div class="table-wrap">
			<table>
				<thead>
					<tr>
						{#each columns as col (col.key)}<th>{col.label}</th>{/each}
					</tr>
				</thead>
				<tbody>
					{#each rows as row, i (rowKey(row) ?? i)}
						<tr>
							{#each columns as col, ci (col.key)}
								<td class:num={col.format === 'money'}>
									{#if ci === 0 && rowHref && rowHref(row)}
										<a href={rowHref(row)}>{cell(row, col)}</a>
									{:else}
										{cell(row, col)}
									{/if}
								</td>
							{/each}
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<style>
	.report-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
		margin-bottom: 0.75rem;
	}
	.report-head h2 {
		margin: 0;
	}
	.num {
		text-align: right;
	}
	td a {
		color: var(--primary);
	}
</style>
