<script>
	import Modal from '../ui/Modal.svelte';
	import { formatMoney } from '$lib/utils/format.js';

	export let billback = null;
	export let onClose = null;
	export let onSettled = null;

	let amount = '';
	let paidDate = new Date().toISOString().slice(0, 10);
	let method = '';
	let reference = '';
	let notes = '';
	let saving = false;
	let error = '';

	async function submit() {
		const value = Number(amount);
		if (!value || value <= 0) {
			error = 'Enter an amount greater than zero.';
			return;
		}
		saving = true;
		error = '';
		try {
			await onSettled({ amount: value, paidDate, method, reference, notes });
		} catch (e) {
			error = e.message;
		} finally {
			saving = false;
		}
	}
</script>

<Modal title="Record billback payment" onClose={onClose}>
	<p class="context">
		{billback.responsible_party_display || billback.to_entity_name || 'Debtor'} owes {billback.from_entity_name} · balance {formatMoney(billback.balance)}
	</p>
	<div class="form-grid">
		<div class="field">
			<label for="bb-amount">Amount *</label>
			<input id="bb-amount" class="input" type="number" min="0.01" step="0.01" bind:value={amount} />
		</div>
		<div class="field">
			<label for="bb-date">Paid date *</label>
			<input id="bb-date" class="input" type="date" bind:value={paidDate} />
		</div>
		<div class="field">
			<label for="bb-method">Method</label>
			<input id="bb-method" class="input" type="text" placeholder="ACH, check…" bind:value={method} />
		</div>
		<div class="field">
			<label for="bb-ref">Reference</label>
			<input id="bb-ref" class="input" type="text" bind:value={reference} />
		</div>
		<div class="field full">
			<label for="bb-notes">Notes</label>
			<textarea id="bb-notes" class="textarea" rows="2" bind:value={notes}></textarea>
		</div>
	</div>

	{#if error}<p class="error-text">{error}</p>{/if}

	<div class="row">
		<button class="btn" onclick={onClose} disabled={saving}>Cancel</button>
		<button class="btn btn-primary" onclick={submit} disabled={saving}>
			{saving ? 'Saving…' : 'Record payment'}
		</button>
	</div>
</Modal>

<style>
	.context {
		color: var(--text-muted);
		margin-top: 0;
	}
	.form-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0 1rem;
	}
	.field {
		margin-bottom: 0.85rem;
	}
	.field.full {
		grid-column: 1 / -1;
	}
	.row {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
		margin-top: 0.5rem;
	}
</style>
