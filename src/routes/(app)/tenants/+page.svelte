<script>
	import CrudPage from '$lib/components/crud/CrudPage.svelte';
	import TenantDetail from '$lib/components/tenants/TenantDetail.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'name', label: 'Name' },
		{ key: 'property_name', label: 'Property' },
		{ key: 'email', label: 'Email' },
		{ key: 'phone', label: 'Phone' },
		{ key: 'monthly_rent', label: 'Rent/mo', format: 'money' },
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
		{ key: 'lease_url', label: 'Lease link (Drive URL)', type: 'text', placeholder: 'https://drive.google.com/…' },
		{ key: 'lease_start', label: 'Lease start', type: 'date' },
		{ key: 'lease_end', label: 'Lease end', type: 'date' },
		{ key: 'monthly_rent', label: 'Current monthly rent', type: 'number', min: 0, step: '0.01' },
		{
			key: 'responsible_water',
			label: 'Tenant pays water (else landlord)',
			type: 'checkbox'
		},
		{
			key: 'responsible_electric',
			label: 'Tenant pays electric (else landlord)',
			type: 'checkbox'
		},
		{
			key: 'responsible_internet',
			label: 'Tenant pays internet (else landlord)',
			type: 'checkbox'
		},
		{
			key: 'responsible_hvac',
			label: 'Tenant pays HVAC (else landlord)',
			type: 'checkbox'
		},
		{
			key: 'responsible_cam',
			label: 'Tenant pays CAM (else landlord)',
			type: 'checkbox'
		},
		{ key: 'lease_notes', label: 'Lease notes', type: 'textarea' },
		{ key: 'notes', label: 'Notes', type: 'textarea' }
	];

	const defaults = {
		status: 'active',
		responsible_water: false,
		responsible_electric: true,
		responsible_internet: true,
		responsible_hvac: false,
		responsible_cam: false
	};
</script>

<CrudPage
	title="Tenants"
	description="Current, former, and prospective tenants. Expand a row for rent history, lease, and who pays the utilities."
	{columns}
	{fields}
	{defaults}
	load={api.getTenants}
	create={api.createTenant}
	update={api.updateTenant}
	remove={api.deleteTenant}
	loadReferences={async () => ({ properties: await api.getProperties() })}
	detail={TenantDetail}
/>
