<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	export let row = null;

	let properties = [];
	let loans = [];
	let obligations = [];
	let billbacks = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			[properties, loans, obligations, billbacks] = await Promise.all([
				api.getEntityProperties(row.id),
				api.getEntityLoans(row.id),
				api.getEntityObligations(row.id),
				api.getEntityBillbacks(row.id)
			]);
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});

	function propertyLabel(p) {
		return p.nickname ? `${p.nickname} — ${p.name}` : p.name;
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
				<h3>Properties</h3>
				{#if properties.length === 0}
					<p class="muted">No properties</p>
				{:else}
					<ul>
						{#each properties as p (p.id)}
							<li>
								<b>{propertyLabel(p)}</b>
								<span>
									{p.city ?? '—'}, {p.state ?? '—'} · {p.property_type.replace('_', ' ')} ·
									{p.unit_count ?? 0} units · {p.status}
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
									{formatMoney(l.monthly_payment ?? 0)}/mo · {l.status}
								</span>
							</li>
						{/each}
					</ul>
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
									{o.property_name ? ` · ${o.property_name}` : ''}
									{o.vendor_name ? ` · ${o.vendor_name}` : ''}
									· due {formatDate(o.next_due_date)} · {formatMoney(o.est_amount ?? o.amount)}
								</span>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			<div class="section">
				<h3>Billbacks owed</h3>
				{#if billbacks.length === 0}
					<p class="muted">None outstanding</p>
				{:else}
					<ul>
						{#each billbacks as b (b.id)}
							<li>
								<b>{b.description}</b>
								<span>
									{b.responsible_party_display ?? b.to_entity_name ?? '—'} owes {b.from_entity_name ?? '—'} · due {formatDate(b.due_date)} ·
									{formatMoney(b.balance)} left
								</span>
							</li>
						{/each}
					</ul>
				{/if}
			</div>

			{#if row.notes}
				<div class="section notes">
					<h3>Notes</h3>
					<p class="muted">{row.notes}</p>
				</div>
			{/if}
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
	.notes {
		grid-column: 1 / -1;
	}
</style>
