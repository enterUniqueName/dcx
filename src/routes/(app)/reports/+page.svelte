<script>
	import CashForecast from '$lib/components/reports/CashForecast.svelte';
	import OverdueReport from '$lib/components/reports/OverdueReport.svelte';
	import PaymentLogReport from '$lib/components/reports/PaymentLogReport.svelte';
	import BillbackRegister from '$lib/components/reports/BillbackRegister.svelte';
	import CrossEntityReport from '$lib/components/reports/CrossEntityReport.svelte';

	const TABS = [
		{ id: 'forecast', label: 'Cash forecast' },
		{ id: 'overdue', label: 'Overdue' },
		{ id: 'payments', label: 'Payment log' },
		{ id: 'billbacks', label: 'Billbacks' },
		{ id: 'cross', label: 'Cross-entity' }
	];

	let active = 'forecast';
</script>

<h1>Reports</h1>
<p class="subtitle">Operational numbers, exportable to CSV.</p>

<div class="tabs">
	{#each TABS as tab (tab.id)}
		<button class="tab" class:active={tab.id === active} onclick={() => (active = tab.id)}>
			{tab.label}
		</button>
	{/each}
</div>

<div hidden={active !== 'forecast'}><CashForecast /></div>
<div hidden={active !== 'overdue'}><OverdueReport /></div>
<div hidden={active !== 'payments'}><PaymentLogReport /></div>
<div hidden={active !== 'billbacks'}><BillbackRegister /></div>
<div hidden={active !== 'cross'}><CrossEntityReport /></div>

<style>
	.tabs {
		display: flex;
		gap: 0.4rem;
		flex-wrap: wrap;
		margin-bottom: 1.25rem;
	}
	.tab {
		border: 1px solid var(--border);
		background: var(--surface);
		color: var(--text-muted);
		padding: 0.4rem 0.85rem;
		border-radius: 999px;
		cursor: pointer;
		font-size: 13px;
	}
	.tab:hover {
		border-color: var(--primary);
	}
	.tab.active {
		background: var(--primary);
		border-color: var(--primary);
		color: #fff;
	}
</style>
