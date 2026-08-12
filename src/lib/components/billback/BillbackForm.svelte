<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { formatMoney, toISODate } from '$lib/utils/format.js';

	export let busy = false;
	export let onSubmit = null;
	export let onCancel = null;

	let entities = [];
	let properties = [];
	let vendors = [];
	let tenants = [];
	let loadError = '';

	let form = {
		paidDate: toISODate(new Date()),
		paidAmount: '',
		checkNumber: '',
		vendorName: '',
		memo: '',
		propertyId: '',
		fromEntityId: '',
		markupPercent: '',
		responsibility: 'tenant',
		tenantId: '',
		landlordId: '',
		splitMode: 'amount',
		splitRows: [
			{ responsibleType: 'tenant', tenantId: '', entityId: '', amount: '', percent: '' },
			{ responsibleType: 'ownership_entity', tenantId: '', entityId: '', amount: '', percent: '' }
		],
		notes: ''
	};

	$: paid = Number(form.paidAmount) || 0;
	$: markup = Number(form.markupPercent) || 0;
	$: total = Math.round(paid * (1 + markup / 100) * 100) / 100;

	onMount(async () => {
		try {
			[entities, properties, tenants, vendors] = await Promise.all([
				api.getOwnershipEntities(),
				api.getProperties(),
				api.getTenants(),
				api.getVendors()
			]);
		} catch (e) {
			loadError = e.message;
		}
	});

	function round2(n) {
		return Math.round(n * 100) / 100;
	}

	function rowPercent(row) {
		if (form.splitMode === 'amount') return total > 0 ? round2((Number(row.amount) || 0) / total * 100) : 0;
		return Number(row.percent) || 0;
	}

	function rowAmount(row) {
		if (form.splitMode === 'percent') return round2(total * ((Number(row.percent) || 0) / 100));
		return Number(row.amount) || 0;
	}

	function setSplitMode(mode) {
		form.splitMode = mode;
		if (mode === 'percent') {
			form.splitRows.forEach((r) => {
				if ((r.percent === '' || r.percent === null) && total > 0) r.percent = round2((Number(r.amount) || 0) / total * 100);
			});
		} else {
			form.splitRows.forEach((r) => {
				if ((r.amount === '' || r.amount === null) && total > 0) r.amount = round2(total * ((Number(r.percent) || 0) / 100));
			});
		}
	}

	function addRow() {
		form.splitRows = [
			...form.splitRows,
			{ responsibleType: 'tenant', tenantId: '', entityId: '', amount: '', percent: '' }
		];
	}

	function removeRow(i) {
		if (form.splitRows.length > 1) form.splitRows = form.splitRows.filter((_, idx) => idx !== i);
	}

	async function submit() {
		const issues = [];
		if (!form.paidDate) issues.push('Date paid is required.');
		if (!(paid > 0)) issues.push('Paid amount must be greater than zero.');
		if (!form.fromEntityId) issues.push('Paid by (ownership entity) is required.');
		if (form.responsibility === 'tenant' && !form.tenantId) issues.push('Choose the tenant responsible for the billback.');
		if (form.responsibility === 'ownership_entity' && !form.landlordId) issues.push('Choose the ownership entity responsible for the billback.');
		if (form.responsibility === 'split') {
			const active = form.splitRows.filter((r) => r.tenantId || r.entityId);
			if (active.length === 0) issues.push('Add at least one responsible party.');
			if (form.splitMode === 'amount') {
				const sum = round2(active.reduce((s, r) => s + (Number(r.amount) || 0), 0));
				if (Math.abs(sum - total) > 0.01) issues.push(`Split amounts sum to ${formatMoney(sum)} but the billback total is ${formatMoney(total)}.`);
			} else {
				const sumPct = round2(active.reduce((s, r) => s + (Number(r.percent) || 0), 0));
				if (Math.abs(sumPct - 100) > 0.5) issues.push(`Split percentages sum to ${sumPct}% (should be 100%).`);
			}
		}
		if (issues.length) {
			alert(issues.join('\n'));
			return;
		}

		try {
			const vendorId = await api.findOrCreateVendor(form.vendorName);
			const base = {
				from_ownership_entity_id: form.fromEntityId,
				to_ownership_entity_id: form.responsibility === 'ownership_entity' ? form.landlordId : null,
				description: form.memo.trim() || null,
				amount: total,
				paid_amount: paid,
				markup_percent: markup,
				check_number: form.checkNumber.trim() || null,
				vendor_id: vendorId,
				property_id: form.propertyId || null,
				responsibility_type: form.responsibility,
				issued_date: form.paidDate,
				notes: form.notes.trim() || null
			};

			let allocations;
			if (form.responsibility === 'tenant') {
				allocations = [{ responsible_type: 'tenant', tenant_id: form.tenantId, allocation_type: 'amount', amount: total }];
			} else if (form.responsibility === 'ownership_entity') {
				allocations = [{ responsible_type: 'ownership_entity', ownership_entity_id: form.landlordId, allocation_type: 'amount', amount: total }];
			} else {
				allocations = form.splitRows
					.filter((r) => r.tenantId || r.entityId)
					.map((r) => ({
						responsible_type: r.responsibleType,
						tenant_id: r.responsibleType === 'tenant' ? r.tenantId : null,
						ownership_entity_id: r.responsibleType === 'ownership_entity' ? r.entityId : null,
						allocation_type: form.splitMode,
						percentage: form.splitMode === 'percent' ? Number(r.percent) || 0 : null,
						amount: rowAmount(r)
					}));
			}

			onSubmit?.({ ...base, allocations });
		} catch (e) {
			alert(`Could not save vendor: ${e.message}`);
		}
	}
</script>

{#if loadError}
	<p class="error-text">{loadError}</p>
{:else}
	<div class="field-row">
		<div class="field">
			<label for="bb-paid-date">Date paid *</label>
			<input id="bb-paid-date" class="input" type="date" bind:value={form.paidDate} />
		</div>
		<div class="field">
			<label for="bb-paid-amount">Paid amount *</label>
			<input
				id="bb-paid-amount"
				class="input"
				type="number"
				min="0.01"
				step="0.01"
				bind:value={form.paidAmount}
				placeholder="0.00"
			/>
		</div>
	</div>

	<div class="field-row">
		<div class="field">
			<label for="bb-check">Check # / reference</label>
			<input id="bb-check" class="input" bind:value={form.checkNumber} placeholder="e.g. 10234" />
		</div>
		<div class="field">
			<label for="bb-vendor">Vendor (payee)</label>
			<input id="bb-vendor" class="input" list="vendor-options" bind:value={form.vendorName} placeholder="Type a name or pick one…" />
			<datalist id="vendor-options">
				{#each vendors as v}<option value={v.name}></option>{/each}
			</datalist>
			<p class="hint">Typing a new name creates the vendor automatically.</p>
		</div>
	</div>

	<div class="field">
		<label for="bb-memo">Memo / reason *</label>
		<input id="bb-memo" class="input" bind:value={form.memo} placeholder="e.g. Roof repair at 58 9th St" />
	</div>

	<div class="field-row">
		<div class="field">
			<label for="bb-from">Paid by (ownership entity) *</label>
			<select id="bb-from" class="select" bind:value={form.fromEntityId}>
				<option value="">—</option>
				{#each entities as e}<option value={e.id}>{e.name}</option>{/each}
			</select>
		</div>
		<div class="field">
			<label for="bb-property">Property</label>
			<select id="bb-property" class="select" bind:value={form.propertyId}>
				<option value="">—</option>
				{#each properties as p}<option value={p.id}>{p.name}</option>{/each}
			</select>
		</div>
	</div>

	<div class="field-row">
		<div class="field">
			<label for="bb-markup">Price adjustment / markup %</label>
			<input id="bb-markup" class="input" type="number" min="0" step="0.01" bind:value={form.markupPercent} placeholder="0" />
			<p class="hint">Amount to bill back = paid × (1 + markup%).</p>
		</div>
		<div class="field">
			<div class="field-label">Amount to bill back</div>
			<div class="readonly-total">{formatMoney(total)}</div>
		</div>
	</div>

	<fieldset class="responsibility">
		<legend>Who owes the billback?</legend>
		<div class="field-row">
			<label class="check">
				<input type="radio" name="responsibility" bind:group={form.responsibility} value="tenant" />
				Tenant
			</label>
			<label class="check">
				<input type="radio" name="responsibility" bind:group={form.responsibility} value="ownership_entity" />
				Landlord (ownership entity)
			</label>
			<label class="check">
				<input type="radio" name="responsibility" bind:group={form.responsibility} value="split" />
				Split
			</label>
		</div>

		{#if form.responsibility === 'tenant'}
			<div class="field">
				<label for="bb-tenant">Tenant responsible</label>
				<select id="bb-tenant" class="select" bind:value={form.tenantId}>
					<option value="">—</option>
					{#each tenants as t}<option value={t.id}>{t.name}{t.property_name ? ` (${t.property_name})` : ''}</option>{/each}
				</select>
			</div>
		{:else if form.responsibility === 'ownership_entity'}
			<div class="field">
				<label for="bb-landlord">Landlord (ownership entity) responsible</label>
				<select id="bb-landlord" class="select" bind:value={form.landlordId}>
					<option value="">—</option>
					{#each entities as e}<option value={e.id}>{e.name}</option>{/each}
				</select>
			</div>
		{:else}
			<div class="split-mode">
				<label class="check">
					<input type="checkbox" checked={form.splitMode === 'percent'} onclick={() => setSplitMode(form.splitMode === 'percent' ? 'amount' : 'percent')} />
					Adjust percentages instead of amounts
				</label>
			</div>
			<div class="split-head">
				<span>Party</span>
				<span>Enter {form.splitMode === 'amount' ? 'amount' : 'percent'}</span>
				<span>{form.splitMode === 'amount' ? '% of total' : 'Amount'}</span>
				<span></span>
			</div>
			{#each form.splitRows as row, i (i)}
				<div class="split-row">
					<select class="select" bind:value={row.responsibleType}>
						<option value="tenant">Tenant</option>
						<option value="ownership_entity">Landlord</option>
					</select>
					{#if row.responsibleType === 'tenant'}
						<select class="select" bind:value={row.tenantId}>
							<option value="">—</option>
							{#each tenants as t}<option value={t.id}>{t.name}{t.property_name ? ` (${t.property_name})` : ''}</option>{/each}
						</select>
					{:else}
						<select class="select" bind:value={row.entityId}>
							<option value="">—</option>
							{#each entities as e}<option value={e.id}>{e.name}</option>{/each}
						</select>
					{/if}
					{#if form.splitMode === 'amount'}
						<input class="input" type="number" min="0" step="0.01" bind:value={row.amount} placeholder="0.00" />
						<span class="computed">{rowPercent(row)}%</span>
					{:else}
						<input class="input" type="number" min="0" max="100" step="0.01" bind:value={row.percent} placeholder="0" />
						<span class="computed">{formatMoney(rowAmount(row))}</span>
					{/if}
					<button class="btn btn-small" type="button" onclick={() => removeRow(i)} disabled={form.splitRows.length <= 1}>
						Remove
					</button>
				</div>
			{/each}
			<button class="btn btn-small" type="button" onclick={addRow}>+ Add responsible party</button>
		{/if}
	</fieldset>

	<div class="field">
		<label for="bb-notes">Notes</label>
		<textarea id="bb-notes" class="textarea" rows="3" bind:value={form.notes}></textarea>
	</div>

	<div class="row">
		<button class="btn" onclick={onCancel} disabled={busy}>Cancel</button>
		<button class="btn btn-primary" onclick={submit} disabled={busy}>
			{busy ? 'Saving…' : 'Create billback'}
		</button>
	</div>
{/if}

<style>
	.responsibility {
		border: 1px solid var(--border);
		border-radius: var(--radius);
		padding: 0.75rem 0.9rem;
		margin: 0 0 1rem;
	}
	.responsibility legend {
		padding: 0 0.4rem;
		font-size: 13px;
		color: var(--text-muted);
	}
	.readonly-total {
		padding: 0.55rem 0.75rem;
		background: var(--surface-muted, rgba(0, 0, 0, 0.04));
		border: 1px solid var(--border);
		border-radius: var(--radius);
		font-variant-numeric: tabular-nums;
	}
	.field-label {
		display: block;
		font-size: 13px;
		font-weight: 600;
		margin-bottom: 0.3rem;
	}
	.split-mode {
		margin-bottom: 0.5rem;
	}
	.split-head {
		display: grid;
		grid-template-columns: 130px 1fr 90px 70px;
		gap: 0.5rem;
		padding: 0.25rem 0;
		font-size: 12px;
		color: var(--text-muted);
	}
	.split-row {
		display: grid;
		grid-template-columns: 130px 1fr 110px 90px 70px;
		gap: 0.5rem;
		align-items: center;
		margin-bottom: 0.5rem;
	}
	.split-row .computed {
		text-align: right;
		font-variant-numeric: tabular-nums;
		color: var(--text-muted);
		font-size: 13px;
	}
	.row {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
		margin-top: 0.5rem;
	}
	.check {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		font-size: 13px;
	}
	.hint {
		font-size: 12px;
		color: var(--text-muted);
		margin: 0.25rem 0 0;
	}
</style>
