<script>
	import { onMount } from 'svelte';
	import Modal from '$lib/components/ui/Modal.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import StatusBadge from '$lib/components/ui/StatusBadge.svelte';
	import CrudForm from '$lib/components/crud/CrudForm.svelte';
	import SettleBillbackModal from '$lib/components/billback/SettleBillbackModal.svelte';
	import { api } from '$lib/api';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	let rows = [];
	let entities = [];
	let loading = true;
	let error = '';
	let showCreate = false;
	let saving = false;
	let settling = null;
	let pendingDelete = null;

	onMount(load);

	async function load() {
		loading = true;
		error = '';
		try {
			[rows, entities] = await Promise.all([api.getBillbacks(), api.getOwnershipEntities()]);
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	const fields = [
		{ key: 'from_ownership_entity_id', label: 'From entity', type: 'select', source: 'entities', required: true },
		{ key: 'to_ownership_entity_id', label: 'To entity', type: 'select', source: 'entities', required: true },
		{ key: 'description', label: 'Description', type: 'text' },
		{ key: 'amount', label: 'Amount', type: 'number', min: 0.01, step: 0.01, required: true },
		{ key: 'issued_date', label: 'Issued date', type: 'date' },
		{ key: 'due_date', label: 'Due date', type: 'date' },
		{ key: 'notes', label: 'Notes', type: 'textarea' }
	];

	const defaults = { issued_date: new Date().toISOString().slice(0, 10) };

	async function createBillback(payload) {
		saving = true;
		error = '';
		try {
			await api.createBillback(payload);
			showCreate = false;
			await load();
		} catch (e) {
			error = e.message;
		} finally {
			saving = false;
		}
	}

	async function settle(payload) {
		await api.createPayment({ billbackId: settling.id, ...payload });
		settling = null;
		await load();
	}

	async function confirmDelete() {
		try {
			await api.deleteBillback(pendingDelete.id);
			pendingDelete = null;
			await load();
		} catch (e) {
			error = e.message;
		}
	}
</script>

<div class="page-header">
	<div>
		<h1>Billbacks</h1>
		<p class="subtitle">Reimbursements between ownership entities.</p>
	</div>
	<button class="btn btn-primary" onclick={() => (showCreate = true)}>+ New billback</button>
</div>

{#if error}<p class="error-text">{error}</p>{/if}

{#if loading}
	<p class="empty">Loading…</p>
{:else if rows.length === 0}
	<p class="empty">No billbacks yet.</p>
{:else}
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>From</th>
					<th>To</th>
					<th>Description</th>
					<th>Due</th>
					<th class="num">Amount</th>
					<th class="num">Paid</th>
					<th class="num">Balance</th>
					<th>Status</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				{#each rows as b (b.id)}
					<tr>
						<td>{b.from_entity_name}</td>
						<td>{b.to_entity_name}</td>
						<td>{b.description ?? '—'}</td>
						<td>{formatDate(b.due_date)}</td>
						<td class="num">{formatMoney(b.amount)}</td>
						<td class="num">{formatMoney(b.amount_paid)}</td>
						<td class="num">{formatMoney(b.balance)}</td>
						<td><StatusBadge status={b.status} /></td>
						<td class="row-actions">
							{#if b.is_outstanding}
								<button class="btn btn-small" onclick={() => (settling = b)}>Record payment</button>
							{/if}
							<button class="btn btn-small btn-danger" onclick={() => (pendingDelete = b)}>Delete</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

{#if showCreate}
	<Modal title="New billback" onClose={() => (showCreate = false)}>
		<CrudForm
			fields={fields}
			references={{ entities }}
			defaults={defaults}
			busy={saving}
			onSubmit={createBillback}
			onCancel={() => (showCreate = false)}
		/>
	</Modal>
{/if}

{#if settling}
	<SettleBillbackModal billback={settling} onClose={() => (settling = null)} onSettled={settle} />
{/if}

{#if pendingDelete}
	<ConfirmDialog
		message={`Delete this billback (${pendingDelete.from_entity_name} → ${pendingDelete.to_entity_name}, ${formatMoney(pendingDelete.amount)})? This cannot be undone.`}
		onConfirm={confirmDelete}
		onCancel={() => (pendingDelete = null)}
	/>
{/if}

<style>
	.subtitle {
		color: var(--text-muted);
		margin-top: 0;
	}
	.num {
		text-align: right;
	}
	.row-actions {
		text-align: right;
		white-space: nowrap;
	}
	.btn-small {
		padding: 0.2rem 0.5rem;
		font-size: 12px;
	}
</style>
