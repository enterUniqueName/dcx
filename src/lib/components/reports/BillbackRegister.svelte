<script>
	import { onMount } from 'svelte';
	import ReportTable from './ReportTable.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'responsible_party_display', label: 'Responsible party' },
		{ key: 'issued_date', label: 'Date', format: 'date' },
		{ key: 'description', label: 'Memo / reason' },
		{ key: 'from_entity_name', label: 'Paid by' },
		{ key: 'amount', label: 'Amount', format: 'money' },
		{ key: 'amount_paid', label: 'Paid', format: 'money' },
		{ key: 'balance', label: 'Balance', format: 'money' },
		{ key: 'status', label: 'Status' }
	];

	let rows = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			rows = await api.getBillbacks();
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});
</script>

<ReportTable filename="billback-register.csv" {columns} {rows} {loading} {error} empty="No billbacks." />
