<script>
	import CrudPage from '$lib/components/crud/CrudPage.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'name', label: 'Name' },
		{ key: 'category', label: 'Category' },
		{ key: 'email', label: 'Email' },
		{ key: 'phone', label: 'Phone' },
		{ key: 'payment_terms', label: 'Terms' },
		{ key: 'active', label: 'Active', format: 'yesno' }
	];

	const fields = [
		{ key: 'name', label: 'Name', type: 'text', required: true },
		{
			key: 'category',
			label: 'Category',
			type: 'select',
			options: [
				{ value: 'water', label: 'Water' },
				{ value: 'electric', label: 'Electric' },
				{ value: 'tax', label: 'Tax' },
				{ value: 'insurance', label: 'Insurance' },
				{ value: 'maintenance', label: 'Maintenance' },
				{ value: 'contractor', label: 'Contractor' },
				{ value: 'other', label: 'Other' }
			]
		},
		{ key: 'email', label: 'Email', type: 'text' },
		{ key: 'phone', label: 'Phone', type: 'text' },
		{ key: 'website', label: 'Website', type: 'text' },
		{ key: 'payment_terms', label: 'Payment terms', type: 'text', placeholder: 'Net 30' },
		{ key: 'active', label: 'Active vendor', type: 'checkbox' },
		{ key: 'notes', label: 'Notes', type: 'textarea' }
	];

	const defaults = { category: 'water', active: true };
</script>

<CrudPage
	title="Vendors"
	description="Utilities, contractors, and service providers."
	{columns}
	{fields}
	{defaults}
	load={api.getVendors}
	create={api.createVendor}
	update={api.updateVendor}
	remove={api.deleteVendor}
	stickyFirst
/>
