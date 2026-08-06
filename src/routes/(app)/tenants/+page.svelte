<script>
	import CrudPage from '$lib/components/crud/CrudPage.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'name', label: 'Name' },
		{ key: 'property_name', label: 'Property' },
		{ key: 'email', label: 'Email' },
		{ key: 'phone', label: 'Phone' },
		{ key: 'status', label: 'Status' }
	];

	const fields = [
		{ key: 'name', label: 'Name', type: 'text', required: true },
		{ key: 'property_id', label: 'Property', type: 'select', source: 'properties' },
		{ key: 'email', label: 'Email', type: 'text' },
		{ key: 'phone', label: 'Phone', type: 'text' },
		{
			key: 'status',
			label: 'Status',
			type: 'select',
			options: [
				{ value: 'active', label: 'Active' },
				{ value: 'former', label: 'Former' },
				{ value: 'prospective', label: 'Prospective' }
			]
		},
		{ key: 'move_in_date', label: 'Move-in date', type: 'date' },
		{ key: 'notes', label: 'Notes', type: 'textarea' }
	];

	const defaults = { status: 'active' };
</script>

<CrudPage
	title="Tenants"
	description="Current, former, and prospective tenants."
	{columns}
	{fields}
	{defaults}
	load={api.getTenants}
	create={api.createTenant}
	update={api.updateTenant}
	remove={api.deleteTenant}
	loadReferences={async () => ({ properties: await api.getProperties() })}
/>
