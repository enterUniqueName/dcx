<script>
	import CrudPage from '$lib/components/crud/CrudPage.svelte';
	import { api } from '$lib/api';

	const columns = [
		{ key: 'lender', label: 'Lender' },
		{ key: 'loan_number', label: 'Loan #' },
		{ key: 'ownership_entity_name', label: 'Entity' },
		{ key: 'property_name', label: 'Property' },
		{ key: 'monthly_payment', label: 'Monthly payment', format: 'money' },
		{ key: 'current_balance', label: 'Balance', format: 'money' },
		{ key: 'status', label: 'Status' }
	];

	const fields = [
		{ key: 'lender', label: 'Lender', type: 'text', required: true },
		{ key: 'loan_number', label: 'Loan number', type: 'text' },
		{ key: 'ownership_entity_id', label: 'Ownership entity', type: 'select', source: 'entities' },
		{ key: 'property_id', label: 'Property', type: 'select', source: 'properties' },
		{ key: 'original_amount', label: 'Original amount', type: 'number', min: 0, step: 0.01 },
		{ key: 'current_balance', label: 'Current balance', type: 'number', min: 0, step: 0.01 },
		{ key: 'interest_rate', label: 'Interest rate', type: 'number', step: 0.001 },
		{ key: 'origination_date', label: 'Origination date', type: 'date' },
		{ key: 'maturity_date', label: 'Maturity date', type: 'date' },
		{
			key: 'payment_frequency',
			label: 'Payment frequency',
			type: 'select',
			options: [
				{ value: 'monthly', label: 'Monthly' },
				{ value: 'quarterly', label: 'Quarterly' },
				{ value: 'semi_annual', label: 'Semi-annual' },
				{ value: 'annual', label: 'Annual' },
				{ value: 'balloon', label: 'Balloon' }
			]
		},
		{ key: 'monthly_payment', label: 'Monthly payment', type: 'number', min: 0, step: 0.01 },
		{
			key: 'status',
			label: 'Status',
			type: 'select',
			options: [
				{ value: 'active', label: 'Active' },
				{ value: 'paid_off', label: 'Paid off' },
				{ value: 'inactive', label: 'Inactive' }
			]
		},
		{ key: 'notes', label: 'Notes', type: 'textarea' }
	];

	const defaults = { payment_frequency: 'monthly', status: 'active' };
</script>

<CrudPage
	title="Loans"
	description="Mortgages and other financing obligations."
	{columns}
	{fields}
	{defaults}
	load={api.getLoans}
	create={api.createLoan}
	update={api.updateLoan}
	remove={api.deleteLoan}
	loadReferences={async () => ({
		entities: await api.getOwnershipEntities(),
		properties: await api.getProperties()
	})}
/>
