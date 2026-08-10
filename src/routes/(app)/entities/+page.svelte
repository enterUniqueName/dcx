<script>
	import CrudPage from '$lib/components/crud/CrudPage.svelte';
	import EntityDetail from '$lib/components/entities/EntityDetail.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'name', label: 'Name' },
		{ key: 'entity_type', label: 'Type' },
		{ key: 'property_count', label: 'Properties' },
		{ key: 'rent_monthly', label: 'Rent/mo', format: 'money' },
		{ key: 'loans_monthly', label: 'Loans/mo', format: 'money' },
		{ key: 'billbacks_owed', label: 'Billbacks', format: 'money' },
		{ key: 'net_monthly', label: 'Net/mo', format: 'money', signed: true }
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
		{ key: 'notes', label: 'Notes', type: 'textarea' }
	];

	const defaults = { entity_type: 'llc' };
</script>

<CrudPage
	title="Ownership Entities"
	description="The LLCs, LPs, and trusts that own assets. Expand a row for its properties, loans, and billbacks."
	{columns}
	{fields}
	{defaults}
	load={api.getOwnershipEntities}
	create={api.createOwnershipEntity}
	update={api.updateOwnershipEntity}
	remove={api.deleteOwnershipEntity}
	detail={EntityDetail}
/>
