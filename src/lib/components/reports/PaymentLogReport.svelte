<script>
	import { onMount } from 'svelte';
	import ReportTable from './ReportTable.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'paid_date', label: 'Paid date', format: 'date' },
		{ key: 'kind', label: 'Kind' },
		{ key: 'funding_entity_name', label: 'Funded by' },
		{ key: 'obligation_entity_name', label: 'Entity' },
		{ key: 'obligation_name', label: 'Obligation' },
		{ key: 'method', label: 'Method' },
		{ key: 'reference', label: 'Reference' },
		{ key: 'amount', label: 'Amount', format: 'money' }
	];

	let rows = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			const data = await api.getPaymentLog();
			rows = data.map((p) => ({
				...p,
				kind: p.billback_id ? 'Billback' : 'Obligation',
				obligation_name: p.obligation_name ?? (p.billback_id ? 'Billback settlement' : '—')
			}));
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});
</script>

<ReportTable
	filename="payment-log.csv"
	{columns}
	{rows}
	{loading}
	{error}
	empty="No payments recorded."
	rowHref={(row) => (row.obligation_id ? `/obligations/${row.obligation_id}` : null)}
/>
