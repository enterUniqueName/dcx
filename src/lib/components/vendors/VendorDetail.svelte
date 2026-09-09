<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { formatMoney, formatDate } from '$lib/utils/format.js';
	import DocumentsPanel from '../obligation/DocumentsPanel.svelte';

	export let row = null;

	let obligations = [];
	let billbacks = [];
	let loading = true;
	let error = '';

	$: totalBilled = obligations.reduce((sum, o) => sum + (o.est_amount ?? o.amount ?? 0), 0);
	$: totalOutstanding = billbacks.reduce((sum, b) => sum + (b.balance ?? 0), 0);

	onMount(async () => {
		try {
			[obligations, billbacks] = await Promise.all([
				api.getVendorObligations(row.id),
				api.getVendorBillbacks(row.id)
			]);
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});
</script>

<div class="detail">
	{#if error}
		<p class="error-text">{error}</p>
	{:else if loading}
		<p class="empty">Loading…</p>
	{:else}
		<div class="grid">
			<div class="section">
				<h3>Linked Obligations</h3>
				{#if obligations.length === 0}
					<p class="muted">No linked obligations</p>
				{:else}
					<ul>
						{#each obligations as o (o.id)}
							<li>
								<b>{o.name}</b>
								<span>
									{o.category.replace('_', ' ')}
									{o.property_name ? ` · ${o.property_name}` : ''}
									· due {formatDate(o.next_due_date)} · {formatMoney(o.est_amount ?? o.amount)}
									· {o.status}
								</span>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<div class="section">
				<h3>Linked Billbacks</h3>
				{#if billbacks.length === 0}
					<p class="muted">No linked billbacks</p>
				{:else}
					<ul>
						{#each billbacks as b (b.id)}
							<li>
								<b>{b.description}</b>
								<span>
									{b.responsible_party_display ?? '—'} ·
									{formatMoney(b.amount)} · {formatMoney(b.balance)} left · {b.status}
								</span>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<div class="section">
				<h3>Summary</h3>
				<ul>
					<li>
						<b>Total Billed</b>
						<span>{formatMoney(totalBilled)}</span>
					</li>
					<li>
						<b>Total Outstanding</b>
						<span>{formatMoney(totalOutstanding)}</span>
					</li>
				</ul>
			</div>

			<div class="section">
				<DocumentsPanel entityType="vendor" entityId={row.id} />
			</div>
		</div>
	{/if}
</div>

<style>
	.detail {
		padding: 0.9rem 1.25rem 1.1rem;
	}
	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
		gap: 0 2rem;
	}
	.section {
		min-width: 0;
	}
	.section h3 {
		font-size: 12px;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--text-muted);
		margin: 0 0 0.4rem;
	}
	ul {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		gap: 0.45rem;
	}
	li {
		display: grid;
		gap: 0.1rem;
	}
	li b {
		font-size: 13px;
		font-weight: 600;
	}
	li span {
		font-size: 12px;
		color: var(--text-muted);
	}
	.muted {
		color: var(--text-muted);
		font-size: 13px;
		margin: 0;
	}
</style>
