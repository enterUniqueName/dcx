<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import ObligationTable from '$lib/components/obligation/ObligationTable.svelte';
	import StatusBadge from '$lib/components/ui/StatusBadge.svelte';
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

	$: upcomingTotal = snapshot?.upcoming.reduce((s, o) => s + Number(o.amount), 0) ?? 0;
	$: overdueTotal = snapshot?.overdue.reduce((s, o) => s + Number(o.amount), 0) ?? 0;
	$: receivedTotal = snapshot?.received.reduce((s, o) => s + Number(o.amount), 0) ?? 0;
</script>

<h1>Dashboard</h1>
<p class="subtitle">What requires attention today.</p>

{#if error}<p class="error-text">{error}</p>{/if}

{#if snapshot}
	<div class="kpi-grid">
		<div class="card kpi">
			<span class="kpi-label">Due this week</span>
			<span class="kpi-value">{snapshot.upcoming.length}</span>
			<span class="kpi-sub">{formatMoney(upcomingTotal)}</span>
		</div>
		<div class="card kpi">
			<span class="kpi-label">Overdue</span>
			<span class="kpi-value">{snapshot.overdue.length}</span>
			<span class="kpi-sub">{formatMoney(overdueTotal)}</span>
		</div>
		<div class="card kpi">
			<span class="kpi-label">Received, not paid</span>
			<span class="kpi-value">{snapshot.received.length}</span>
			<span class="kpi-sub">{formatMoney(receivedTotal)}</span>
		</div>
		<div class="card kpi">
			<span class="kpi-label">Outstanding billbacks</span>
			<span class="kpi-value">{snapshot.billbacks.length}</span>
			<span class="kpi-sub">{formatMoney(snapshot.billbackTotal)}</span>
		</div>
		<div class="card kpi">
			<span class="kpi-label">Cash needed this month</span>
			<span class="kpi-value">{formatMoney(snapshot.cashThisMonth)}</span>
			<span class="kpi-sub">across entities</span>
		</div>
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
								<th>From</th>
								<th>To</th>
								<th>Due</th>
								<th class="num">Balance</th>
								<th>Status</th>
							</tr>
						</thead>
						<tbody>
							{#each snapshot.billbacks as b (b.id)}
								<tr>
									<td>{b.from_entity_name}</td>
									<td>{b.to_entity_name}</td>
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
	.subtitle {
		color: var(--text-muted);
		margin-top: 0;
	}
	.kpi-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
		gap: 1rem;
		margin-bottom: 1.25rem;
	}
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
	.grid-2 {
		margin-bottom: 1.25rem;
	}
	.card-total {
		font-size: 13px;
		font-weight: 600;
		color: var(--text-muted);
		float: right;
	}
	.num {
		text-align: right;
	}
</style>
