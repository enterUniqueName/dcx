<script>
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { api } from '$lib/api';
	import { formatMoney } from '$lib/utils/format.js';
	import ReportTable from './ReportTable.svelte';

	const CATEGORIES = [
		{ id: 'water', label: 'Water' },
		{ id: 'electric', label: 'Electric' },
		{ id: 'tax', label: 'Tax' },
		{ id: 'insurance', label: 'Insurance' },
		{ id: 'loan_payment', label: 'Loan payments' },
		{ id: 'maintenance', label: 'Maintenance' },
		{ id: 'service', label: 'Service' },
		{ id: 'reimbursement', label: 'Reimbursement' },
		{ id: 'other', label: 'Other' }
	];

	const columns = [
		{ key: 'name', label: 'Obligation', sortable: true },
		{ key: 'property_name', label: 'Property', sortable: true },
		{ key: 'category', label: 'Category', sortable: true },
		{ key: 'loan_name', label: 'Lender', sortable: true },
		{ key: 'loan_account', label: 'Loan Account' },
		{
			key: 'next_due_date',
			label: 'Due',
			format: 'date',
			sortable: true,
			alert: (row) => row.is_overdue
		},
		{
			key: 'amount',
			label: 'Amount',
			format: 'money',
			sortable: true,
			alert: (row) => row.is_overdue
		},
		{ key: 'is_overdue', label: 'Overdue', format: 'yesno', sortable: true }
	];

	const exportColumns = [
		{ key: 'ownership_entity_name', label: 'Ownership Entity' },
		{ key: 'property_name', label: 'Property Name' },
		{ key: 'property_address1', label: 'Address' },
		{ key: 'name', label: 'Name' },
		{ key: 'description', label: 'Description' },
		{ key: 'category', label: 'Category' },
		{ key: 'loan_name', label: 'Lender' },
		{ key: 'loan_account', label: 'Loan Account' },
		{ key: 'amount', label: 'Amount', exportValue: (row) => formatMoney(row.amount) },
		{ key: 'next_due_date', label: 'Next Due Date' },
		{ key: 'is_overdue', label: 'Is Overdue', exportValue: (row) => row.is_overdue ? 'TRUE' : 'FALSE' }
	];

	let entities = [];
	let properties = [];
	let ownershipEntityId = '';
	let selectedPropertyIds = [];
	let selectedCategories = CATEGORIES.map((category) => category.id);
	let includeOverdue = false;
	let selectedResultCategories = [];
	let rows = [];
	let loadingOptions = true;
	let running = false;
	let error = '';
	let hasRun = false;

	$: entityProperties = properties.filter(
		(property) => property.ownership_entity_id === ownershipEntityId
	);
	$: resultCategories = [...new Set(rows.map((row) => row.category))].sort();
	$: visibleRows = rows.filter((row) => selectedResultCategories.includes(row.category));
	$: resultFilterOptions = resultCategories.map((category) => ({
			value: category,
			label: category.replace(/_/g, ' ')
		}));
	$: resultTotal = visibleRows.reduce((sum, row) => sum + Number(row.amount || 0), 0);
	onMount(async () => {
		try {
			[entities, properties] = await Promise.all([
				api.getOwnershipEntities(),
				api.getProperties()
			]);
		} catch (e) {
			error = e.message;
		} finally {
			loadingOptions = false;
		}
	});

	function selectEntity() {
		selectedPropertyIds = properties
			.filter((property) => property.ownership_entity_id === ownershipEntityId)
			.map((property) => property.id);
		rows = [];
		selectedResultCategories = [];
		hasRun = false;
		error = '';
	}

	function toggleProperties() {
		selectedPropertyIds =
			selectedPropertyIds.length === entityProperties.length
				? []
				: entityProperties.map((property) => property.id);
	}

	function toggleCategories() {
		selectedCategories =
			selectedCategories.length === CATEGORIES.length
				? []
				: CATEGORIES.map((category) => category.id);
	}

	async function runReport() {
		running = true;
		error = '';
		selectedResultCategories = [];
		try {
			const result = await api.getObligationReport({
				ownershipEntityId,
				propertyIds: selectedPropertyIds,
				categories: selectedCategories,
				includeOverdue
			});
			rows = result;
			selectedResultCategories = [...new Set(result.map((row) => row.category))].sort();
			hasRun = true;
		} catch (e) {
			error = e.message;
			rows = [];
			hasRun = true;
		} finally {
			running = false;
		}
	}

	function toggleResultCategory(category, checked) {
		selectedResultCategories = checked
			? [...selectedResultCategories, category]
			: selectedResultCategories.filter((value) => value !== category);
	}
</script>

<form class="criteria card" onsubmit={(event) => { event.preventDefault(); runReport(); }}>
	<div class="criteria-head">
		<div>
			<h2>Obligation report</h2>
			<p>Choose an entity, its properties, and the bill categories to include.</p>
		</div>
		<button
			class="btn btn-primary"
			type="submit"
			disabled={loadingOptions || running || !ownershipEntityId || selectedPropertyIds.length === 0 || selectedCategories.length === 0}
		>
			{running ? 'Running…' : 'Run report'}
		</button>
	</div>

	<div class="field entity-field">
		<label for="report-entity">Entity</label>
		<select
			id="report-entity"
			class="select"
			bind:value={ownershipEntityId}
			onchange={selectEntity}
			disabled={loadingOptions}
		>
			<option value="">Select an entity</option>
			{#each entities as entity (entity.id)}
				<option value={entity.id}>{entity.name}</option>
			{/each}
		</select>
	</div>

	<div class="option-grid">
		<fieldset>
			<div class="legend-row">
				<legend>Properties</legend>
				{#if entityProperties.length > 0}
					<button class="link-btn" type="button" onclick={toggleProperties}>
						{selectedPropertyIds.length === entityProperties.length ? 'Clear all' : 'Select all'}
					</button>
				{/if}
			</div>
			{#if !ownershipEntityId}
				<p class="option-note">Select an entity first.</p>
			{:else if entityProperties.length === 0}
				<p class="option-note">This entity has no properties.</p>
			{:else}
				<div class="checks">
					{#each entityProperties as property (property.id)}
						<label><input type="checkbox" bind:group={selectedPropertyIds} value={property.id} /> {property.name}</label>
					{/each}
				</div>
			{/if}
		</fieldset>

		<fieldset>
			<div class="legend-row">
				<legend>Bill categories</legend>
				<button class="link-btn" type="button" onclick={toggleCategories}>
					{selectedCategories.length === CATEGORIES.length ? 'Clear all' : 'Select all'}
				</button>
			</div>
			<div class="checks categories">
				{#each CATEGORIES as category (category.id)}
					<label><input type="checkbox" bind:group={selectedCategories} value={category.id} /> {category.label}</label>
				{/each}
			</div>
		</fieldset>
	</div>

	<label class="overdue-option">
		<input type="checkbox" bind:checked={includeOverdue} />
		Include overdue unpaid bills
	</label>
</form>

{#if error && !hasRun}<p class="error-text">{error}</p>{/if}

{#if hasRun || running}
	<ReportTable
		filename="obligation-report.csv"
		title="Obligation Report"
		total={formatMoney(resultTotal)}
		filterLabel="Categories"
		filterOptions={rows.length > 0 ? resultFilterOptions : []}
		filterValues={selectedResultCategories}
		filterMultiple={true}
		onFilterChange={toggleResultCategory}
		exportMenu={true}
		{columns}
		{exportColumns}
		rows={visibleRows}
		loading={running}
		{error}
		defaultSortKey="next_due_date"
		defaultSortDir="asc"
		empty="No open bills match these criteria."
		rowHref={(row) => `${base}/obligations/${row.id}`}
	/>
{:else}
	<p class="empty prompt">Select report criteria and run the report.</p>
{/if}

<style>
	.criteria {
		margin-bottom: 1.25rem;
	}
	.criteria-head {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: 1rem;
		margin-bottom: 1rem;
	}
	.criteria-head h2,
	.criteria-head p {
		margin: 0;
	}
	.criteria-head p,
	.option-note {
		color: var(--text-muted);
		font-size: 13px;
	}
	.entity-field {
		max-width: 420px;
	}
	.option-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}
	fieldset {
		border: 1px solid var(--border);
		border-radius: var(--radius);
		padding: 0.75rem;
		min-width: 0;
	}
	.legend-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.75rem;
		margin-bottom: 0.6rem;
	}
	legend {
		font-size: 12px;
		font-weight: 600;
		color: var(--text-muted);
		padding: 0;
	}
	.checks {
		display: grid;
		gap: 0.45rem;
		max-height: 190px;
		overflow-y: auto;
	}
	.checks.categories {
		grid-template-columns: repeat(2, minmax(0, 1fr));
	}
	.checks label,
	.overdue-option {
		font-size: 13px;
	}
	.overdue-option {
		display: inline-flex;
		align-items: center;
		gap: 0.35rem;
		margin-top: 0.9rem;
	}
	.option-note {
		margin: 0;
	}
	.prompt {
		border: 1px dashed var(--border);
		border-radius: var(--radius);
	}
	@media (max-width: 700px) {
		.criteria-head {
			align-items: stretch;
			flex-direction: column;
		}
		.criteria-head .btn {
			justify-content: center;
		}
		.option-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
