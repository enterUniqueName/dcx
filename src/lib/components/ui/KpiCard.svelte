<script>
	export let label = '';
	export let value = '';
	export let sub = '';
</script>

<div class="card kpi">
	<span class="kpi-label">{label}</span>
	<span class="kpi-value">{value}</span>
	{#if sub}<span class="kpi-sub">{sub}</span>{/if}
</div>

<style>
	.kpi {
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
	}
	.kpi-label {
		font-size: 12px;
		color: var(--text-muted);
	}
	.kpi-value {
		font-size: 1.5rem;
		font-weight: 700;
	}
	.kpi-sub {
		font-size: 12px;
		color: var(--text-muted);
	}
</style>
