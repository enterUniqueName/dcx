<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import PaymentTable from '$lib/components/payments/PaymentTable.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	let payments = [];
	let loading = true;
	let error = '';
	let from = '';
	let to = '';
	let crossEntityOnly = false;
	let pendingDelete = null;

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

	async function confirmDelete() {
		try {
			await api.deletePayment(pendingDelete.id);
			pendingDelete = null;
			await reload();
		} catch (e) {
			error = e.message;
		}
	}
</script>

<div class="page-header">
	<div>
		<h1>Payments</h1>
		<p class="subtitle">Everything that has been paid, across all entities.</p>
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
	<PaymentTable payments={payments} showDelete={true} onDelete={(p) => (pendingDelete = p)} />
{/if}

{#if pendingDelete}
	<ConfirmDialog
		message={`Delete payment of ${formatMoney(pendingDelete.amount)} from ${formatDate(pendingDelete.paid_date)}?`}
		onConfirm={confirmDelete}
		onCancel={() => (pendingDelete = null)}
	/>
{/if}

<style>
	.subtitle {
		color: var(--text-muted);
		margin: 0;
	}
	.filters {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}
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
