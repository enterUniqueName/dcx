<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { formatMoney, formatDate } from '$lib/utils/format.js';
	import DocumentsPanel from '../obligation/DocumentsPanel.svelte';

	export let row = null;

	let tenants = [];
	let obligations = [];
	let loans = [];
	let loading = true;
	let error = '';

	$: costBreakdown = buildCostBreakdown(obligations);

	onMount(async () => {
		try {
			const allTenants = await api.getTenants();
			tenants = allTenants.filter((t) => t.property_id === row.id);
			[obligations, loans] = await Promise.all([
				api.getPropertyObligations(row.id),
				api.getPropertyLoans(row.id)
			]);
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});

	function buildCostBreakdown(obs) {
		const map = new Map();
		for (const o of obs) {
			const cat = (o.category ?? 'Other').replace('_', ' ');
			map.set(cat, (map.get(cat) ?? 0) + (o.est_amount ?? 0));
		}
		return [...map.entries()].map(([category, amount]) => ({ category, amount }));
	}
</script>

<div class="detail">
	{#if error}
		<p class="error-text">{error}</p>
	{:else if loading}
		<p class="empty">Loading…</p>
	{:else}
		<div class="grid">
			<div class="section">
				<h3>Tenant</h3>
				{#if tenants.length === 0}
					<p class="muted">No active tenant</p>
				{:else}
					<ul>
						{#each tenants as t (t.id)}
							<li>
								<b>{t.name}</b>
								<span>
									{formatMoney(t.monthly_rent ?? 0)}/mo ·
									{t.lease_start ?? '—'} – {t.lease_end ?? '—'} ·
									{t.status ?? '—'}
								</span>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<div class="section">
				<h3>Monthly Costs</h3>
				{#if costBreakdown.length === 0}
					<p class="muted">No costs</p>
				{:else}
					<ul>
						{#each costBreakdown as c}
							<li>
								<b>{c.category}</b>
								<span>{formatMoney(c.amount)}/mo</span>
							</li>
						{/each}
					</ul>
					<p class="muted total">
						Total: {formatMoney(costBreakdown.reduce((sum, c) => sum + c.amount, 0))}/mo
					</p>
				{/if}
			</div>

			<div class="section">
				<h3>Obligations</h3>
				{#if obligations.length === 0}
					<p class="muted">No open obligations</p>
				{:else}
					<ul>
						{#each obligations as o (o.id)}
							<li>
								<b>{o.name}</b>
								<span>
									{o.category.replace('_', ' ')}
									{o.vendor_name ? ` · ${o.vendor_name}` : ''}
									· due {formatDate(o.next_due_date)} · {formatMoney(o.est_amount ?? o.amount)}
								</span>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<div class="section">
				<h3>Loans</h3>
				{#if loans.length === 0}
					<p class="muted">No loans</p>
				{:else}
					<ul>
						{#each loans as l (l.id)}
							<li>
								<b>{l.nickname || l.lender}</b>
								<span>
									{l.lender}{l.loan_number ? ` · #${l.loan_number}` : ''} ·
									{formatMoney(l.monthly_payment ?? 0)}/mo · {formatMoney(l.current_balance ?? 0)} · {l.status}
								</span>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<div class="section">
				<DocumentsPanel entityType="property" entityId={row.id} />
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
	.total {
		margin-top: 0.5rem;
		font-weight: 600;
	}
</style>
