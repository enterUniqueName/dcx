<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { formatMoney, formatDate } from '$lib/utils/format.js';
	import DocumentsPanel from '../obligation/DocumentsPanel.svelte';

	export let row = null;

	let obligations = [];
	let payments = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			obligations = await api.getLoanObligations(row.id);

			const obligationIds = obligations.map((o) => o.id);
			const payArrays = await Promise.all(
				obligationIds.map((oid) => api.getPayments({ obligationId: oid }))
			);
			payments = payArrays.flat().sort((a, b) => (b.paid_date ?? '').localeCompare(a.paid_date ?? ''));
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
									{o.property_name ?? '—'} · due {formatDate(o.next_due_date)} ·
									{formatMoney(o.est_amount ?? o.amount)} · {o.status}
								</span>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<div class="section">
				<h3>Payment History</h3>
				{#if payments.length === 0}
					<p class="muted">No payments recorded</p>
				{:else}
					<ul>
						{#each payments as p (p.id)}
							<li>
								<b>{formatDate(p.paid_date)}</b>
								<span>
									{formatMoney(p.amount)}
									{p.method ? ` · ${p.method}` : ''}
									{p.reference ? ` · ${p.reference}` : ''}
								</span>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<div class="section">
				<DocumentsPanel entityType="loan" entityId={row.id} />
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
