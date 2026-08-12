<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
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
			label="Received, not paid"
			value={snapshot.received.length}
			sub={formatMoney(receivedTotal)}
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

	<div class="grid-2">
		<div class="card">
			<h2>Due this week</h2>
			<ObligationTable obligations={snapshot.upcoming} showReceived={false} />
		</div>
		<div class="card">
			<h2>Overdue</h2>
			<ObligationTable obligations={snapshot.overdue} showReceived={false} />
		</div>
	</div>

	<div class="card">
		<h2>Received, not yet paid</h2>
		<ObligationTable obligations={snapshot.received} showReceived={true} />
	</div>

	<div class="grid-2">
		<div class="card">
			<h2>Outstanding billbacks</h2>
			{#if snapshot.billbacks.length === 0}
				<p class="empty">None outstanding.</p>
			{:else}
				<div class="table-wrap">
					<table>
						<thead>
							<tr>
								<th>Responsible</th>
								<th>From</th>
								<th>Due</th>
								<th class="num">Balance</th>
								<th>Status</th>
							</tr>
						</thead>
						<tbody>
							{#each snapshot.billbacks as b (b.id)}
								<tr>
									<td>{b.responsible_party_display ?? b.to_entity_name ?? '—'}</td>
									<td>{b.from_entity_name}</td>
									<td>{formatDate(b.due_date)}</td>
									<td class="num">{formatMoney(b.balance)}</td>
									<td><StatusBadge status={b.status} /></td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
		<div class="card">
			<h2>
				Cross-entity payments this month
				<span class="card-total">{formatMoney(snapshot.crossEntityTotal)}</span>
			</h2>
			{#if snapshot.crossEntity.length === 0}
				<p class="empty">None this period.</p>
			{:else}
				<div class="table-wrap">
					<table>
						<thead>
							<tr>
								<th>Date</th>
								<th>Paid by</th>
								<th>On behalf of</th>
								<th>Obligation</th>
								<th class="num">Amount</th>
							</tr>
						</thead>
						<tbody>
							{#each snapshot.crossEntity as p (p.id)}
								<tr>
									<td>{formatDate(p.paid_date)}</td>
									<td>{p.funding_entity_name}</td>
									<td>{p.obligation_entity_name}</td>
									<td>{p.obligation_name}</td>
									<td class="num">{formatMoney(p.amount)}</td>
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
	.grid-2 {
		margin-bottom: 1.25rem;
	}
	.card-total {
		font-size: 13px;
		font-weight: 600;
		color: var(--text-muted);
		float: right;
	}
</style>
