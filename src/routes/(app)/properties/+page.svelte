<script>
	import CrudPage from '$lib/components/crud/CrudPage.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'name', label: 'Name' },
		{ key: 'address1', label: 'Address' },
		{ key: 'ownership_entity_name', label: 'Entity' },
		{ key: 'unit_count', label: 'Units' },
		{ key: 'annual_tax', label: 'Annual tax', format: 'money' },
		{ key: 'tax_next_amount', label: 'Next tax', format: 'money' },
		{ key: 'tax_next_due_date', label: 'Next tax due', format: 'date' },
		{ key: 'status', label: 'Status' }
	];

	const fields = [
		{ key: 'name', label: 'Name', type: 'text', required: true },
		{ key: 'ownership_entity_id', label: 'Ownership entity', type: 'select', source: 'entities' },
		{ key: 'address1', label: 'Address line 1', type: 'text' },
		{ key: 'address2', label: 'Address line 2', type: 'text' },
		{ key: 'city', label: 'City', type: 'text' },
		{ key: 'state', label: 'State', type: 'text' },
		{ key: 'zip', label: 'ZIP', type: 'text' },
		{
			key: 'property_type',
			label: 'Type',
			type: 'select',
			options: [
				{ value: 'multifamily', label: 'Multifamily' },
				{ value: 'residential', label: 'Residential' },
				{ value: 'commercial', label: 'Commercial' },
				{ value: 'mixed', label: 'Mixed use' },
				{ value: 'other', label: 'Other' }
			]
		},
		{ key: 'unit_count', label: 'Unit count', type: 'number', min: 0 },
		{ key: 'annual_tax', label: 'Annual real estate tax', type: 'number', min: 0, step: '0.01' },
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

	const defaults = { property_type: 'multifamily', unit_count: 1, status: 'active' };
</script>

<CrudPage
	title="Properties"
	description="Physical real estate owned by your entities."
	{columns}
	{fields}
	{defaults}
	load={api.getProperties}
	create={api.createProperty}
	update={api.updateProperty}
	remove={api.deleteProperty}
	loadReferences={async () => ({ entities: await api.getOwnershipEntities() })}
	stickyFirst
/>
