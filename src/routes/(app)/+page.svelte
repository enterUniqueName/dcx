<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { base } from '$app/paths';
	import ObligationTable from '$lib/components/obligation/ObligationTable.svelte';
	import StatusBadge from '$lib/components/ui/StatusBadge.svelte';
	import KpiCard from '$lib/components/ui/KpiCard.svelte';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	let snapshot = null;
	let error = '';

	onMount(async () => {
		try {
			snapshot = await api.getDashboardSnapshot();
		} catch (e) {
			error = e.message;
		}
	});

	// Use the estimated amount (avg of last 3 bills) where present, so totals
	// reflect variable water/electric bills rather than the configured amount.
	$: est = (o) => Number(o.est_amount ?? o.amount);
	$: upcomingTotal = snapshot?.upcoming.reduce((s, o) => s + est(o), 0) ?? 0;
	$: overdueTotal = snapshot?.overdue.reduce((s, o) => s + est(o), 0) ?? 0;
	$: receivedTotal = snapshot?.received.reduce((s, o) => s + est(o), 0) ?? 0;
</script>

<h1>Dashboard</h1>
<p class="subtitle">What requires attention today.</p>

{#if error}<p class="error-text">{error}</p>{/if}

{#if snapshot}
	<div class="kpi-grid">
		<KpiCard
			label="Due this week"
			value={snapshot.upcoming.length}
			sub={formatMoney(upcomingTotal)}
		/>
		<KpiCard
			label="Overdue"
			value={snapshot.overdue.length}
			sub={formatMoney(overdueTotal)}
		/>
		<KpiCard
			label="Outstanding billbacks"
			value={snapshot.billbacks.length}
			sub={formatMoney(snapshot.billbackTotal)}
		/>
		<KpiCard
			label="Cash needed this month"
			value={formatMoney(snapshot.cashThisMonth)}
			sub="across entities"
		/>
	</div>

	<div class="flex-stack">
		<div class="card">
			<h2>Due this week</h2>
			<ObligationTable obligations={snapshot.upcoming} showReceived={false} />
		</div>
	</div>

	<div class="flex-stack">
		<div class="card">
			<h2>Overdue</h2>
			<ObligationTable obligations={snapshot.overdue} showReceived={false} />
		</div>
	</div>

	<div class="flex-stack">
		<div class="card">
			<h2>Outstanding PLB billbacks</h2>
			{#if snapshot.billbacks.length === 0}
				<p class="empty">None outstanding.</p>
			{:else}
				<div class="table-wrap">
					<table>
						<thead>
							<tr>
								<th>Responsible Party</th>
								<th>Property</th>
								<th class="num">Balance</th>
								<th>Memo / Reason</th>
								<th>Date Paid</th>
								<th>Status</th>
							</tr>
						</thead>
						<tbody>
							{#each snapshot.billbacks as b (b.id)}
								<tr>
									<td><a href={`${base}/billbacks/${b.id}`}>{b.responsible_party_display ?? '—'}</a></td>
									<td>{b.property_name && b.property_address1 ? `${b.property_name} - ${b.property_address1}` : (b.property_name ?? '—')}</td>
									<td class="num">{formatMoney(b.balance)}</td>
									<td>{b.description ?? '—'}</td>
									<td>{formatDate(b.issued_date)}</td>
									<td><StatusBadge status={b.status} /></td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	</div>
{:else}
	<p class="empty">Loading…</p>
{/if}

<style>
	.kpi-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
		gap: 1rem;
		margin-bottom: 1.25rem;
	}
	.flex-stack {
		margin-bottom: 1.25rem;
	}
</style>
