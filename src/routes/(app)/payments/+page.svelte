<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import PaymentTable from '$lib/components/payments/PaymentTable.svelte';
	import { formatDate } from '$lib/utils/format.js';

	let payments = [];
	let loading = true;
	let error = '';
	let from = '';
	let to = '';
	let crossEntityOnly = false;

	onMount(reload);

	async function reload() {
		loading = true;
		error = '';
		try {
			payments = await api.getPaymentLog({
				from: from || undefined,
				to: to || undefined,
				crossEntity: crossEntityOnly || undefined
			});
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}
</script>

<div class="page-header">
	<div>
		<h1>Payments</h1>
		<p class="subtitle">Everything that has been paid — bill payments and billback settlements — across all entities.</p>
	</div>
</div>

<div class="filters">
	<div class="filter">
		<label for="from">From</label>
		<input id="from" class="input" type="date" bind:value={from} />
	</div>
	<div class="filter">
		<label for="to">To</label>
		<input id="to" class="input" type="date" bind:value={to} />
	</div>
	<label class="check">
		<input type="checkbox" bind:checked={crossEntityOnly} />
		Cross-entity only (one entity paid for another)
	</label>
	<button class="btn btn-primary" onclick={reload}>Apply</button>
</div>

{#if error}<p class="error-text">{error}</p>{/if}

{#if loading}
	<p class="empty">Loading…</p>
{:else}
	<PaymentTable payments={payments} />
{/if}

<style>
	.filter {
		display: grid;
		gap: 0.25rem;
	}
	.filter label {
		font-size: 12px;
		color: var(--text-muted);
		font-weight: 600;
	}
	.check {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		font-size: 13px;
		padding-bottom: 0.45rem;
	}
</style>
