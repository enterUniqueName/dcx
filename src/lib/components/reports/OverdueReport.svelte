<script>
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import ReportTable from './ReportTable.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'name', label: 'Obligation' },
		{ key: 'ownership_entity_name', label: 'Entity' },
		{ key: 'property_name', label: 'Property' },
		{ key: 'category', label: 'Category' },
		{ key: 'next_due_date', label: 'Due', format: 'date' },
		{ key: 'est_amount', label: 'Amount', format: 'money' }
	];

	let rows = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			rows = await api.getOverdueObligations();
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});
</script>

<ReportTable
	filename="overdue-obligations.csv"
	{columns}
	{rows}
	{loading}
	{error}
	empty="No overdue obligations."
	rowHref={(row) => `${base}/obligations/${row.id}`}
/>
