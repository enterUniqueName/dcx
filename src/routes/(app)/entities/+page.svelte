<script>
	import CrudPage from '$lib/components/crud/CrudPage.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'name', label: 'Name' },
		{ key: 'entity_type', label: 'Type' },
		{ key: 'ein', label: 'EIN' },
		{ key: 'status', label: 'Status' }
	];

	const fields = [
		{ key: 'name', label: 'Name', type: 'text', required: true },
		{
			key: 'entity_type',
			label: 'Type',
			type: 'select',
			options: [
				{ value: 'llc', label: 'LLC' },
				{ value: 'lp', label: 'LP' },
				{ value: 'trust', label: 'Trust' },
				{ value: 'individual', label: 'Individual' },
				{ value: 'other', label: 'Other' }
			]
		},
		{ key: 'ein', label: 'EIN', type: 'text', placeholder: 'XX-XXXXXXX' },
		{
			key: 'status',
			label: 'Status',
			type: 'select',
			options: [
				{ value: 'active', label: 'Active' },
				{ value: 'inactive', label: 'Inactive' }
			]
		},
		{ key: 'notes', label: 'Notes', type: 'textarea' }
	];

	const defaults = { entity_type: 'llc', status: 'active' };
</script>

<CrudPage
	title="Ownership Entities"
	description="The LLCs, LPs, and trusts that own assets."
	{columns}
	{fields}
	{defaults}
	load={api.getOwnershipEntities}
	create={api.createOwnershipEntity}
	update={api.updateOwnershipEntity}
	remove={api.deleteOwnershipEntity}
/>
