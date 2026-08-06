<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { toISODate } from '$lib/utils/format.js';

	export let initial = null;
	export let busy = false;
	export let onSubmit = null;
	export let onCancel = null;

	const CATEGORIES = [
		'utility',
		'tax',
		'insurance',
		'loan_payment',
		'maintenance',
		'service',
		'reimbursement',
		'other'
	];
	const FREQUENCIES = ['one_time', 'monthly', 'quarterly', 'semi_annual', 'annual', 'custom'];

	let entities = [];
	let properties = [];
	let vendors = [];
	let loans = [];
	let tenants = [];
	let loadError = '';

	let form = {
		name: '',
		description: '',
		category: 'utility',
		ownership_entity_id: '',
		property_id: '',
		vendor_id: '',
		loan_id: '',
		tenant_id: '',
		amount: '',
		frequency: 'monthly',
		interval_months: '1',
		due_day: '',
		next_due_date: toISODate(new Date()),
		billing_start: '',
		billing_end: '',
		received: false,
		portal_url: '',
		notes: ''
	};

	$: entityProperties = properties.filter(
		(p) => !form.ownership_entity_id || p.ownership_entity_id === form.ownership_entity_id
	);

	onMount(async () => {
		if (initial) {
			form = {
				name: initial.name ?? '',
				description: initial.description ?? '',
				category: initial.category ?? 'utility',
				ownership_entity_id: initial.ownership_entity_id ?? '',
				property_id: initial.property_id ?? '',
				vendor_id: initial.vendor_id ?? '',
				loan_id: initial.loan_id ?? '',
				tenant_id: initial.tenant_id ?? '',
				amount: initial.amount ?? '',
				frequency: initial.frequency ?? 'monthly',
				interval_months: initial.interval_months ?? '1',
				due_day: initial.due_day ?? '',
				next_due_date: initial.next_due_date ?? toISODate(new Date()),
				billing_start: initial.billing_start ?? '',
				billing_end: initial.billing_end ?? '',
				received: initial.received ?? false,
				portal_url: initial.portal_url ?? '',
				notes: initial.notes ?? ''
			};
		}

		try {
			const [e, p, v, l, t] = await Promise.all([
				api.getOwnershipEntities(),
				api.getProperties(),
				api.getVendors(),
				api.getLoans(),
				api.getTenants()
			]);
			entities = e;
			properties = p;
			vendors = v;
			loans = l;
			tenants = t;
		} catch (e) {
			loadError = e.message;
		}
	});

	function num(value) {
		return value === '' || value === null || value === undefined ? null : Number(value);
	}

	function submit() {
		const payload = {
			name: form.name.trim(),
			description: form.description.trim() || null,
			category: form.category,
			ownership_entity_id: form.ownership_entity_id || null,
			property_id: form.property_id || null,
			vendor_id: form.vendor_id || null,
			loan_id: form.loan_id || null,
			tenant_id: form.tenant_id || null,
			amount: num(form.amount),
			frequency: form.frequency,
			interval_months: form.frequency === 'custom' ? num(form.interval_months) : null,
			due_day: form.due_day === '' ? null : num(form.due_day),
			next_due_date: form.next_due_date,
			billing_start: form.billing_start || null,
			billing_end: form.billing_end || null,
			received: form.received,
			portal_url: form.portal_url.trim() || null,
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
			alert('Next due date is required.');
			return;
		}
		if (payload.frequency === 'custom' && (payload.interval_months === null || payload.interval_months < 1)) {
			alert('Custom frequency needs a positive interval in months.');
			return;
		}

		onSubmit?.(payload);
	}
</script>

{#if loadError}
	<p class="error-text">{loadError}</p>
{:else}
	<div class="field">
		<label for="ob-name">Name</label>
		<input id="ob-name" class="input" bind:value={form.name} placeholder="e.g. Water — 112 Riverbend Rd" />
	</div>

	<div class="field-row">
		<div class="field">
			<label for="ob-category">Category</label>
			<select id="ob-category" class="select" bind:value={form.category}>
				{#each CATEGORIES as c}<option value={c}>{c.replace('_', ' ')}</option>{/each}
			</select>
		</div>
		<div class="field">
			<label for="ob-amount">Amount</label>
			<input id="ob-amount" class="input" type="number" min="0" step="0.01" bind:value={form.amount} placeholder="0.00" />
		</div>
	</div>

	<div class="field-row">
		<div class="field">
			<label for="ob-frequency">Frequency</label>
			<select id="ob-frequency" class="select" bind:value={form.frequency}>
				{#each FREQUENCIES as f}<option value={f}>{f.replace('_', ' ')}</option>{/each}
			</select>
		</div>
		{#if form.frequency === 'custom'}
			<div class="field">
				<label for="ob-interval">Every N months</label>
				<input id="ob-interval" class="input" type="number" min="1" bind:value={form.interval_months} />
			</div>
		{:else}
			<div class="field">
				<label for="ob-dueday">Day of month (optional)</label>
				<input id="ob-dueday" class="input" type="number" min="1" max="31" bind:value={form.due_day} placeholder="1–31" />
			</div>
		{/if}
	</div>

	<div class="field">
		<label for="ob-duedate">Next due date</label>
		<input id="ob-duedate" class="input" type="date" bind:value={form.next_due_date} />
	</div>

	<div class="field-row">
		<div class="field">
			<label for="ob-entity">Ownership entity</label>
			<select id="ob-entity" class="select" bind:value={form.ownership_entity_id}>
				<option value="">—</option>
				{#each entities as e}<option value={e.id}>{e.name}</option>{/each}
			</select>
		</div>
		<div class="field">
			<label for="ob-property">Property</label>
			<select id="ob-property" class="select" bind:value={form.property_id}>
				<option value="">—</option>
				{#each entityProperties as p}<option value={p.id}>{p.name}</option>{/each}
			</select>
		</div>
	</div>

	<div class="field-row">
		<div class="field">
			<label for="ob-vendor">Vendor</label>
			<select id="ob-vendor" class="select" bind:value={form.vendor_id}>
				<option value="">—</option>
				{#each vendors as v}<option value={v.id}>{v.name}</option>{/each}
			</select>
		</div>
		<div class="field">
			<label for="ob-loan">Loan</label>
			<select id="ob-loan" class="select" bind:value={form.loan_id}>
				<option value="">—</option>
				{#each loans as l}<option value={l.id}>{l.lender} — {l.loan_number ?? ''}</option>{/each}
			</select>
		</div>
	</div>

	<div class="field-row">
		<div class="field">
			<label for="ob-bstart">Billing start (optional)</label>
			<input id="ob-bstart" class="input" type="date" bind:value={form.billing_start} />
		</div>
		<div class="field">
			<label for="ob-bend">Billing end (optional)</label>
			<input id="ob-bend" class="input" type="date" bind:value={form.billing_end} />
		</div>
	</div>

	<div class="field">
		<label for="ob-portal">Portal / invoice URL (optional)</label>
		<input id="ob-portal" class="input" type="url" bind:value={form.portal_url} placeholder="https://…" />
	</div>

	<div class="field">
		<label for="ob-notes">Notes</label>
		<textarea id="ob-notes" class="textarea" rows="3" bind:value={form.notes}></textarea>
	</div>

	<label class="check">
		<input type="checkbox" bind:checked={form.received} />
		Bill/invoice has been received
	</label>

	<div class="row">
		<button class="btn" onclick={onCancel} disabled={busy}>Cancel</button>
		<button class="btn btn-primary" onclick={submit} disabled={busy}>
			{busy ? 'Saving…' : 'Save obligation'}
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
