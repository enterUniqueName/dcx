<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { toISODate } from '$lib/utils/format.js';

	export let initial = null;
	export let busy = false;
	export let onSubmit = null;
	export let onCancel = null;

	const CATEGORIES = [
		'water',
		'electric',
		'tax',
		'insurance',
		'loan_payment',
		'maintenance',
		'service',
		'reimbursement',
		'other'
	];

	let entities = [];
	let properties = [];
	let loadError = '';

	let form = {
		name: '',
		category: 'water',
		amount: '',
		ownership_entity_id: '',
		property_id: '',
		next_due_date: toISODate(new Date()),
		received: false,
		notes: ''
	};

	$: entityProperties = properties.filter(
		(p) => !form.ownership_entity_id || p.ownership_entity_id === form.ownership_entity_id
	);

	onMount(async () => {
		if (initial) {
			form = {
				name: initial.name ?? '',
				category: initial.category ?? 'water',
				amount: initial.amount ?? '',
				ownership_entity_id: initial.ownership_entity_id ?? '',
				property_id: initial.property_id ?? '',
				next_due_date: initial.next_due_date ?? toISODate(new Date()),
				received: initial.received ?? false,
				notes: initial.notes ?? ''
			};
		}
		try {
			const [e, p] = await Promise.all([api.getOwnershipEntities(), api.getProperties()]);
			entities = e;
			properties = p;
		} catch (e2) {
			loadError = e2.message;
		}
	});

	function submit() {
		const payload = {
			name: form.name.trim(),
			category: form.category,
			amount: form.amount === '' ? null : Number(form.amount),
			ownership_entity_id: form.ownership_entity_id || null,
			property_id: form.property_id || null,
			next_due_date: form.next_due_date,
			received: form.received,
			notes: form.notes.trim() || null
		};

		if (!payload.name) {
			alert('Name is required.');
			return;
		}
		if (payload.amount === null || payload.amount < 0) {
			alert('Amount must be 0 or greater.');
			return;
		}
		if (!payload.next_due_date) {
			alert('Due date is required.');
			return;
		}
		onSubmit?.(payload);
	}
</script>

{#if loadError}
	<p class="error-text">{loadError}</p>
{:else}
	<div class="field">
		<label for="b-name">Name</label>
		<input id="b-name" class="input" bind:value={form.name} placeholder="e.g. Water — March 2026" />
	</div>

	<div class="field-row">
		<div class="field">
			<label for="b-category">Category</label>
			<select id="b-category" class="select" bind:value={form.category}>
				{#each CATEGORIES as c}<option value={c}>{c.replace('_', ' ')}</option>{/each}
			</select>
		</div>
		<div class="field">
			<label for="b-amount">Amount</label>
			<input id="b-amount" class="input" type="number" min="0" step="0.01" bind:value={form.amount} placeholder="0.00" />
		</div>
	</div>

	<div class="field">
		<label for="b-duedate">Due date</label>
		<input id="b-duedate" class="input" type="date" bind:value={form.next_due_date} />
	</div>

	<div class="field-row">
		<div class="field">
			<label for="b-entity">Ownership entity</label>
			<select id="b-entity" class="select" bind:value={form.ownership_entity_id}>
				<option value="">—</option>
				{#each entities as e}<option value={e.id}>{e.name}</option>{/each}
			</select>
		</div>
		<div class="field">
			<label for="b-property">Property</label>
			<select id="b-property" class="select" bind:value={form.property_id}>
				<option value="">—</option>
				{#each entityProperties as p}<option value={p.id}>{p.name}</option>{/each}
			</select>
		</div>
	</div>

	<div class="field">
		<label for="b-notes">Notes</label>
		<textarea id="b-notes" class="textarea" rows="3" bind:value={form.notes}></textarea>
	</div>

	<label class="check">
		<input type="checkbox" bind:checked={form.received} />
		Bill/invoice has been received
	</label>

	<div class="row">
		<button class="btn" onclick={onCancel} disabled={busy}>Cancel</button>
		<button class="btn btn-primary" onclick={submit} disabled={busy}>
			{busy ? 'Saving…' : 'Save bill'}
		</button>
	</div>
{/if}

<style>
	.row {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
		margin-top: 0.5rem;
	}
	.check {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 13px;
		margin-bottom: 1rem;
	}
</style>
