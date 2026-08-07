<script>
	import Modal from '../ui/Modal.svelte';
	import { toISODate, formatMoney } from '$lib/utils/format.js';

	export let obligation = null;
	export let entities = [];
	export let busy = false;
	export let onConfirm = null;
	export let onCancel = null;

	const METHODS = ['bank', 'check', 'autopay', 'credit card', 'other'];

	let amount = '';
	let paidDate = toISODate(new Date());
	let fundingEntityId = '';
	let method = 'bank';
	let reference = '';
	let notes = '';
	let error = '';

	$: estDerived =
		obligation &&
		obligation.est_amount != null &&
		Number(obligation.est_amount) !== Number(obligation.amount);

	$: {
		if (obligation) {
			amount = String(obligation.est_amount ?? obligation.amount ?? '');
			fundingEntityId = obligation.ownership_entity_id ?? '';
		}
	}

	function submit() {
		const value = Number(amount);
		if (!amount || Number.isNaN(value) || value <= 0) {
			error = 'Enter a payment amount greater than zero.';
			return;
		}
		if (!paidDate) {
			error = 'Enter a payment date.';
			return;
		}
		error = '';
		onConfirm?.({
			amount: value,
			paidDate,
			fundingEntityId: fundingEntityId || null,
			method: method || null,
			reference: reference.trim() || null,
			notes: notes.trim() || null
		});
	}
</script>

<Modal title="Mark as paid" onClose={onCancel}>
	{#if obligation}
		<p class="ob-name">
			{obligation.name}
			<span class="muted">· {formatMoney(obligation.est_amount ?? obligation.amount)}</span>
		</p>
		{#if estDerived}
			<p class="hint">Amount prefilled from the average of the last 3 bills. Adjust to the actual bill.</p>
		{/if}

		<div class="field-row">
			<div class="field">
				<label for="pay-amount">Amount</label>
				<input id="pay-amount" class="input" type="number" min="0" step="0.01" bind:value={amount} />
			</div>
			<div class="field">
				<label for="pay-date">Paid date</label>
				<input id="pay-date" class="input" type="date" bind:value={paidDate} />
			</div>
		</div>

		<div class="field">
			<label for="pay-entity">Paid by (funding entity)</label>
			<select id="pay-entity" class="select" bind:value={fundingEntityId}>
				<option value="">—</option>
				{#each entities as e}<option value={e.id}>{e.name}</option>{/each}
			</select>
			<p class="hint">Used to answer "what did one entity pay on behalf of another?"</p>
		</div>

		<div class="field-row">
			<div class="field">
				<label for="pay-method">Method</label>
				<select id="pay-method" class="select" bind:value={method}>
					{#each METHODS as m}<option value={m}>{m}</option>{/each}
				</select>
			</div>
			<div class="field">
				<label for="pay-ref">Reference (check #, confirmation)</label>
				<input id="pay-ref" class="input" bind:value={reference} />
			</div>
		</div>

		<div class="field">
			<label for="pay-notes">Notes</label>
			<textarea id="pay-notes" class="textarea" rows="2" bind:value={notes}></textarea>
		</div>

		{#if error}<p class="error-text">{error}</p>{/if}

		<div class="row">
			<button class="btn" onclick={onCancel} disabled={busy}>Cancel</button>
			<button class="btn btn-primary" onclick={submit} disabled={busy}>
				{busy ? 'Recording…' : 'Record payment'}
			</button>
		</div>
	{/if}
</Modal>

<style>
	.ob-name {
		font-weight: 600;
		margin: 0 0 1rem;
	}
	.muted {
		color: var(--text-muted);
		font-weight: 400;
	}
	.hint {
		font-size: 12px;
		color: var(--text-muted);
		margin: 0.25rem 0 0;
	}
	.row {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
		margin-top: 0.5rem;
	}
</style>
