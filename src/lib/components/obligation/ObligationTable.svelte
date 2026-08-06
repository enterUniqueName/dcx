<script>
	import StatusBadge from '../ui/StatusBadge.svelte';
	import DueChip from '../ui/DueChip.svelte';
	import { formatMoney } from '$lib/utils/format.js';

	export let obligations = [];
	export let showReceived = false;
	export let showStatus = true;
</script>

{#if obligations.length === 0}
	<p class="empty">Nothing here.</p>
{:else}
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>Name</th>
					<th>Entity</th>
					<th>Property</th>
					<th>Category</th>
					<th>Due</th>
					<th class="num">Amount</th>
					{#if showReceived}<th>Received</th>{/if}
					{#if showStatus}<th>Status</th>{/if}
				</tr>
			</thead>
			<tbody>
				{#each obligations as ob (ob.id)}
					<tr>
						<td>
							<a href="/obligations/{ob.id}">{ob.name}</a>
						</td>
						<td>{ob.ownership_entity_name ?? '—'}</td>
						<td>{ob.property_name ?? '—'}</td>
						<td>{ob.category}</td>
						<td><DueChip dueDate={ob.next_due_date} /></td>
						<td class="num">{formatMoney(ob.amount)}</td>
						{#if showReceived}<td>{ob.received ? 'Yes' : 'No'}</td>{/if}
						{#if showStatus}<td><StatusBadge status={ob.is_overdue ? 'overdue' : ob.status} /></td>{/if}
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

<style>
	.num {
		text-align: right;
	}
</style>
