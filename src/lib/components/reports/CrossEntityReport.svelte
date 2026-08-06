<script>
	import { onMount } from 'svelte';
	import ReportTable from './ReportTable.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'paid_date', label: 'Paid date', format: 'date' },
		{ key: 'funding_entity_name', label: 'Funded by' },
		{ key: 'obligation_entity_name', label: 'Obligation entity' },
		{ key: 'obligation_name', label: 'Obligation' },
		{ key: 'amount', label: 'Amount', format: 'money' }
	];

	let rows = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			rows = await api.getCrossEntityPayments();
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});
</script>

<ReportTable
	filename="cross-entity-payments.csv"
	{columns}
	{rows}
	{loading}
	{error}
	empty="No cross-entity payments."
	rowHref={(row) => (row.obligation_id ? `/obligations/${row.obligation_id}` : null)}
/>
