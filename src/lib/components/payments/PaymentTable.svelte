<script>
	import { base } from '$app/paths';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	export let payments = [];
	export let showObligation = true;
	export let showDelete = false;
	export let onDelete = null;

	$: crossEntity = (p) =>
		p.is_cross_entity && p.funding_entity_name && p.obligation_entity_name;
</script>

{#if payments.length === 0}
	<p class="empty">No payments recorded.</p>
{:else}
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>Date</th>
					{#if showObligation}<th>Obligation</th>{/if}
					<th>Paid by</th>
					<th>On behalf of</th>
					<th>Method</th>
					<th>Reference</th>
					<th class="num">Amount</th>
					{#if showDelete}<th></th>{/if}
				</tr>
			</thead>
			<tbody>
				{#each payments as p (p.id)}
					<tr>
						<td>{formatDate(p.paid_date)}</td>
						{#if showObligation}
							<td>
								{#if p.obligation_name}
									<a href={`${base}/obligations/${p.obligation_id}`}>{p.obligation_name}</a>
								{:else}
									<span class="muted">Billback settlement</span>
								{/if}
							</td>
						{/if}
						<td>{p.funding_entity_name ?? '—'}</td>
						<td>
							{#if crossEntity(p)}
								<span class="cross" title="Paid on behalf of another entity">{p.obligation_entity_name}</span>
							{:else}
								—
							{/if}
						</td>
						<td>{p.method ?? '—'}</td>
						<td>{p.reference ?? '—'}</td>
						<td class="num">{formatMoney(p.amount)}</td>
						{#if showDelete}
							<td>
								<button class="btn btn-small btn-danger" onclick={() => onDelete?.(p)}>Delete</button>
							</td>
						{/if}
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

<style>
	.muted {
		color: var(--text-muted);
	}
	.cross {
		color: var(--warn);
	}
</style>
