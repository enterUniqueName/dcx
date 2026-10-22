<script>
	import { tick } from 'svelte';
	import { downloadCSV, downloadPNG } from '$lib/utils/csv.js';
	import { formatMoney, formatDate } from '$lib/utils/format.js';
	import { sortRows, nextSort } from '$lib/utils/sort.js';

	// columns: [{ key, label, format: 'text'|'money'|'date' }]
	export let columns = [];
	export let exportColumns = null;
	export let rows = [];
	export let filename = 'report.csv';
	export let empty = 'Nothing to show.';
	export let loading = false;
	export let error = '';
	export let rowHref = null; // (row) => url | null — makes the first column a link
	export let rowKey = (row) => row.id ?? row.key;
	export let defaultSortKey = '';
	export let defaultSortDir = 'asc';
	export let title = '';
	export let total = '';
	export let filterLabel = '';
	export let filterOptions = [];
	export let filterValue = '';
	export let filterValues = [];
	export let filterMultiple = false;
	export let onFilterChange = null;
	export let exportMenu = false;

	let sortKey = defaultSortKey;
	let sortDir = defaultSortDir;
	let showExportMenu = false;
	let showFilterMenu = false;
	let exportError = '';
	let reportElement;

	$: sortCol = columns.find((col) => col.key === sortKey && col.sortable) ?? null;
	$: sortedRows = sortRows(rows, sortCol, sortDir, sortCol?.value);

	function cell(row, col) {
		const v = row[col.key];
		if (v === null || v === undefined || v === '') return '—';
		if (col.format === 'money') return formatMoney(v);
		if (col.format === 'date') return formatDate(v);
		return String(v).replace(/_/g, ' ');
	}

	function toggleSort(key) {
		const next = nextSort(key, sortKey, sortDir);
		sortKey = next.key;
		sortDir = next.dir;
	}

	function exportCSV() {
		showExportMenu = false;
		exportError = '';
		downloadCSV(filename, exportColumns ?? columns, sortedRows);
	}

	function toggleExportMenu() {
		showFilterMenu = false;
		showExportMenu = !showExportMenu;
	}

	function toggleFilterMenu() {
		showExportMenu = false;
		showFilterMenu = !showFilterMenu;
	}

	function filterSummary() {
		if (filterValues.length === filterOptions.length) return `All ${filterLabel.toLowerCase()}`;
		if (filterValues.length === 0) return `No ${filterLabel.toLowerCase()}`;
		return `${filterValues.length} of ${filterOptions.length} ${filterLabel.toLowerCase()}`;
	}

	async function exportPNG() {
		showExportMenu = false;
		exportError = '';
		try {
			await tick();
			await downloadPNG(filename.replace(/\.csv$/i, '.png'), reportElement);
		} catch (e) {
			exportError = e.message;
		}
	}
</script>

<div class="report" bind:this={reportElement} data-png-report>
	<div class="report-head">
		<div class="report-title">
			<h2>{title || filename.replace(/\.csv$/, '').replace(/[-_]/g, ' ')}</h2>
			{#if filterOptions.length > 0}
				<div class="report-filter">
					<label for="report-table-filter">{filterLabel || 'Filter'}</label>
					{#if filterMultiple}
						<div class="filter-menu-wrap">
							<button
								id="report-table-filter"
								class="btn filter-trigger"
								type="button"
								onclick={toggleFilterMenu}
								aria-expanded={showFilterMenu}
							>
								{filterSummary()}
							</button>
							{#if showFilterMenu}
								<div class="filter-menu">
									{#each filterOptions as option (option.value)}
										<label>
											<input
												type="checkbox"
												checked={filterValues.includes(option.value)}
												onchange={(event) => onFilterChange?.(option.value, event.currentTarget.checked)}
											/>
											{option.label}
										</label>
									{/each}
								</div>
							{/if}
						</div>
					{:else}
						<select
							id="report-table-filter"
							class="select"
							value={filterValue}
							onchange={(event) => onFilterChange?.(event.currentTarget.value)}
						>
							{#each filterOptions as option (option.value)}
								<option value={option.value}>{option.label}</option>
							{/each}
						</select>
					{/if}
				</div>
			{/if}
		</div>
		{#if total}<div class="report-total">{total}</div>{/if}
		<div class="export-wrap" data-html2canvas-ignore>
			{#if exportMenu}
				<button
					class="btn"
					onclick={toggleExportMenu}
					disabled={rows.length === 0}
					aria-expanded={showExportMenu}
				>
					Export
				</button>
				{#if showExportMenu}
					<div class="export-menu">
						<button type="button" onclick={exportCSV}>CSV</button>
						<button type="button" onclick={exportPNG}>PNG</button>
					</div>
				{/if}
			{:else}
				<button class="btn" onclick={exportCSV} disabled={rows.length === 0}>Export CSV</button>
			{/if}
		</div>
	</div>

	{#if exportError}<p class="error-text">{exportError}</p>{/if}
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
						{#each columns as col (col.key)}
							<th
								class:sortable={col.sortable}
								class:sorted={sortKey === col.key}
								onclick={col.sortable ? () => toggleSort(col.key) : undefined}
							>
								{col.label}{#if sortKey === col.key}<span class="sort-ind">{sortDir === 'asc' ? '▲' : '▼'}</span>{/if}
							</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each sortedRows as row, i (rowKey(row) ?? i)}
						<tr>
							{#each columns as col, ci (col.key)}
								<td
									class:num={col.format === 'money'}
									class:alert-cell={col.alert?.(row)}
								>
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
		display: grid;
		grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
		align-items: start;
		gap: 1rem;
		margin-bottom: 0.75rem;
	}
	.report-head h2 {
		margin: 0;
	}
	.report-title {
		display: grid;
		gap: 0.6rem;
		justify-items: start;
	}
	.report-filter {
		display: grid;
		gap: 0.25rem;
	}
	.report-filter label {
		font-size: 12px;
		font-weight: 600;
		color: var(--text-muted);
	}
	.report-filter .select {
		width: auto;
		min-width: 180px;
	}
	.filter-menu-wrap {
		position: relative;
	}
	.filter-trigger {
		min-width: 180px;
		justify-content: space-between;
	}
	.filter-menu {
		position: absolute;
		top: calc(100% + 0.25rem);
		left: 0;
		z-index: 6;
		display: grid;
		gap: 0.15rem;
		min-width: 210px;
		max-height: 240px;
		overflow-y: auto;
		padding: 0.4rem;
		background: var(--surface);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		box-shadow: 0 8px 20px rgba(17, 24, 39, 0.12);
	}
	.filter-menu label {
		display: flex;
		align-items: center;
		gap: 0.45rem;
		padding: 0.35rem 0.4rem;
		border-radius: 4px;
		font-size: 13px;
		font-weight: 400;
		color: var(--text);
		cursor: pointer;
		text-transform: capitalize;
	}
	.filter-menu label:hover {
		background: #f3f4f6;
	}
	.report-total {
		align-self: center;
		font-size: 1.35rem;
		font-weight: 700;
		white-space: nowrap;
	}
	.export-wrap {
		position: relative;
		justify-self: end;
	}
	.export-menu {
		position: absolute;
		top: calc(100% + 0.25rem);
		right: 0;
		z-index: 5;
		min-width: 110px;
		padding: 0.25rem;
		background: var(--surface);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		box-shadow: 0 8px 20px rgba(17, 24, 39, 0.12);
	}
	.export-menu button {
		display: block;
		width: 100%;
		padding: 0.45rem 0.6rem;
		border: 0;
		border-radius: 4px;
		background: transparent;
		color: var(--text);
		text-align: left;
		cursor: pointer;
	}
	.export-menu button:hover {
		background: #f3f4f6;
	}
	td a {
		color: var(--primary);
	}
	th.sortable {
		cursor: pointer;
		user-select: none;
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
	.alert-cell {
		color: var(--danger);
		font-weight: 700;
	}
	@media (max-width: 700px) {
		.report-head {
			grid-template-columns: 1fr auto;
		}
		.report-total {
			grid-column: 1 / -1;
			grid-row: 2;
			justify-self: center;
		}
	}
</style>
