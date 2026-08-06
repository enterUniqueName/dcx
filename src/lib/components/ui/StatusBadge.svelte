<script>
	export let status = '';
</script>

{#if status === 'open'}
	<span class="badge badge-open">Open</span>
{:else if status === 'paid'}
	<span class="badge badge-paid">Paid</span>
{:else if status === 'canceled'}
	<span class="badge badge-canceled">Canceled</span>
{:else if status === 'overdue'}
	<span class="badge badge-overdue">Overdue</span>
{:else if status === 'outstanding'}
	<span class="badge badge-outstanding">Outstanding</span>
{:else if status === 'partially_paid'}
	<span class="badge badge-partially_paid">Partially paid</span>
{:else if status === 'waived'}
	<span class="badge badge-waived">Waived</span>
{:else}
	<span class="badge">{status}</span>
{/if}
