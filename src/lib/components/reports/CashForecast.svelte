<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { downloadCSV } from '$lib/utils/csv.js';
	import { formatMoney } from '$lib/utils/format.js';

	const columns = [
		{ key: 'ownership_entity_name', label: 'Entity' },
		{ key: 'obligations_amount', label: 'Obligations' },
		{ key: 'billbacks_amount', label: 'Billbacks' },
		{ key: 'total', label: 'Total' }
	];

	let rows = [];
	let months = [];
	let month = '';
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			rows = await api.getCashNeeded();
			months = [...new Set(rows.map((r) => r.month))].sort();
			const cur = new Date();
			const prefix = `${cur.getFullYear()}-${String(cur.getMonth() + 1).padStart(2, '0')}`;
			month = months.find((m) => m.startsWith(prefix)) ?? months[0] ?? '';
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});

	$: monthRows = month ? rows.filter((r) => r.month === month) : [];
	$: maxTotal = Math.max(1, ...monthRows.map((r) => Number(r.total)));
	$: grandTotal = monthRows.reduce((s, r) => s + Number(r.total), 0);

	function monthLabel(m) {
		return new Date(`${m}T00:00:00`).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
	}

	function pct(row) {
		return Math.round((Number(row.total) / maxTotal) * 100);
	}
</script>

<div class="report">
	<div class="report-head">
		<h2>Cash forecast</h2>
		<div class="head-actions">
			<select class="select" bind:value={month}>
				{#each months as m (m)}
					<option value={m}>{monthLabel(m)}</option>
				{/each}
			</select>
			<button class="btn" onclick={() => downloadCSV('cash-forecast.csv', columns, monthRows)} disabled={monthRows.length === 0}>
				Export CSV
			</button>
		</div>
	</div>

	{#if error}<p class="error-text">{error}</p>{/if}
	{#if loading}
		<p class="empty">Loading…</p>
	{:else if monthRows.length === 0}
		<p class="empty">No cash needed in the forecast window.</p>
	{:else}
		<p class="forecast-total">Total needed: {formatMoney(grandTotal)}</p>
		<div class="table-wrap">
			<table>
				<thead>
					<tr>
						<th>Entity</th>
						<th class="num">Obligations</th>
						<th class="num">Billbacks</th>
						<th class="num">Total</th>
						<th>Share</th>
					</tr>
				</thead>
				<tbody>
					{#each monthRows as row (row.ownership_entity_id)}
						<tr>
							<td>{row.ownership_entity_name}</td>
							<td class="num">{formatMoney(row.obligations_amount)}</td>
							<td class="num">{formatMoney(row.billbacks_amount)}</td>
							<td class="num">{formatMoney(row.total)}</td>
							<td>
								<div class="bar" title={formatMoney(row.total)}>
									<div class="bar-fill" style="width: {pct(row)}%"></div>
								</div>
							</td>
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
	.head-actions {
		display: flex;
		gap: 0.6rem;
	}
	.forecast-total {
		color: var(--text-muted);
		margin-top: 0;
	}
	.num {
		text-align: right;
	}
	.bar {
		background: var(--border);
		border-radius: 4px;
		height: 10px;
		min-width: 120px;
		overflow: hidden;
	}
	.bar-fill {
		height: 100%;
		background: var(--primary);
		border-radius: 4px;
	}
</style>
