<script>
	import Modal from '../ui/Modal.svelte';
	import { toISODate, formatDate } from '$lib/utils/format.js';

	export let entities = [];
	export let properties = [];
	export let busy = false;
	export let onConfirm = null;
	export let onCancel = null;

	const CATEGORIES = [
		{ value: '', label: 'All categories' },
		{ value: 'water', label: 'Water' },
		{ value: 'electric', label: 'Electric' },
		{ value: 'tax', label: 'Tax' },
		{ value: 'insurance', label: 'Insurance' },
		{ value: 'loan_payment', label: 'Loan payments' },
		{ value: 'maintenance', label: 'Maintenance' },
		{ value: 'service', label: 'Service' },
		{ value: 'reimbursement', label: 'Reimbursement' },
		{ value: 'other', label: 'Other' }
	];
	const RANGES = [30, 60, 90];

	let ownershipEntityId = '';
	let propertyId = '';
	let category = '';
	let days = 60;

	$: availableProperties = properties.filter(
		(property) => !ownershipEntityId || property.ownership_entity_id === ownershipEntityId
	);
	$: targetDate = rangeTarget(days);

	function changeEntity() {
		propertyId = '';
	}

	function submit() {
		onConfirm?.({
			ownershipEntityId: ownershipEntityId || null,
			propertyId: propertyId || null,
			category: category || null,
			targetDate
		});
	}

	function rangeTarget(range) {
		const target = new Date();
		target.setDate(target.getDate() + Number(range));
		return toISODate(target);
	}
</script>

<Modal title="Generate bills" onClose={busy ? null : onCancel}>
	<p class="intro">
		Create missing bills from open recurring templates. Existing bills with the same template and due
		date will be skipped.
	</p>

	<div class="field">
		<label for="generate-entity">Entity</label>
		<select id="generate-entity" class="select" bind:value={ownershipEntityId} onchange={changeEntity}>
			<option value="">All entities</option>
			{#each entities as entity (entity.id)}
				<option value={entity.id}>{entity.name}</option>
			{/each}
		</select>
	</div>

	<div class="field">
		<label for="generate-property">Property</label>
		<select id="generate-property" class="select" bind:value={propertyId}>
			<option value="">All properties</option>
			{#each availableProperties as property (property.id)}
				<option value={property.id}>{property.name}</option>
			{/each}
		</select>
	</div>

	<div class="field-row">
		<div class="field">
			<label for="generate-category">Category</label>
			<select id="generate-category" class="select" bind:value={category}>
				{#each CATEGORIES as option (option.value)}
					<option value={option.value}>{option.label}</option>
				{/each}
			</select>
		</div>
		<div class="field">
			<label for="generate-range">Generate through</label>
			<select id="generate-range" class="select" bind:value={days}>
				{#each RANGES as range (range)}
					<option value={range}>Next {range} days</option>
				{/each}
			</select>
			<p class="hint">Through {formatDate(targetDate)}, inclusive.</p>
		</div>
	</div>

	<div class="actions">
		<button class="btn" type="button" onclick={onCancel} disabled={busy}>Cancel</button>
		<button class="btn btn-primary" type="button" onclick={submit} disabled={busy}>
			{busy ? 'Generating…' : 'Generate bills'}
		</button>
	</div>
</Modal>

<style>
	.intro {
		margin: 0 0 1rem;
		color: var(--text-muted);
		font-size: 13px;
	}
	.hint {
		font-size: 12px;
		color: var(--text-muted);
		margin: 0.25rem 0 0;
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
		margin-top: 0.5rem;
	}
</style>
