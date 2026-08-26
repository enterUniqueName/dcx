<script>
	import { onMount } from 'svelte';
	import Modal from '$lib/components/ui/Modal.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import StatusBadge from '$lib/components/ui/StatusBadge.svelte';
	import BillbackForm from '$lib/components/billback/BillbackForm.svelte';
	import SettleBillbackModal from '$lib/components/billback/SettleBillbackModal.svelte';
	import { api } from '$lib/api';
	import { base } from '$app/paths';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	let rows = [];
	let loading = true;
	let error = '';
	let showCreate = false;
	let saving = false;
	let settling = null;
	let pendingDelete = null;
	let hidePaid = false;

	onMount(load);

	async function load() {
		loading = true;
		error = '';
		try {
			rows = await api.getBillbacks();
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	$: visible = rows.filter((b) => !hidePaid || b.status !== 'paid');

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
		<p class="subtitle">Reimburse a paid cost to the responsible tenant or ownership entity.</p>
	</div>
	<button class="btn btn-primary" onclick={() => (showCreate = true)}>+ New billback</button>
</div>

<div class="filters">
	<label class="check">
		<input type="checkbox" bind:checked={hidePaid} />
		Hide paid items
	</label>
</div>

{#if error}<p class="error-text">{error}</p>{/if}

{#if loading}
	<p class="empty">Loading…</p>
{:else if visible.length === 0}
	<p class="empty">No billbacks yet.</p>
{:else}
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>Responsible party</th>
					<th>Date</th>
					<th>Memo / reason</th>
					<th>Paid by</th>
					<th class="num">Amount</th>
					<th class="num">Paid</th>
					<th class="num">Balance</th>
					<th>Status</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				{#each visible as b (b.id)}
					<tr>
						<td><a href={`${base}/billbacks/${b.id}`}>{b.responsible_party_display ?? '—'}</a></td>
						<td>{formatDate(b.issued_date)}</td>
						<td>
							{b.description ?? '—'}
							{#if b.check_number || b.vendor_name}
								<span class="sub">
									{#if b.vendor_name}{b.vendor_name}{/if}{#if b.check_number && b.vendor_name} · {/if}{#if b.check_number}check {b.check_number}{/if}
								</span>
							{/if}
						</td>
						<td>{b.from_entity_name}</td>
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
	<Modal title="New billback" wide onClose={() => (showCreate = false)}>
		<BillbackForm busy={saving} onSubmit={createBillback} onCancel={() => (showCreate = false)} />
	</Modal>
{/if}

{#if settling}
	<SettleBillbackModal billback={settling} onClose={() => (settling = null)} onSettled={settle} />
{/if}

{#if pendingDelete}
	<ConfirmDialog
		message={`Delete this billback (${pendingDelete.responsible_party_display ?? 'Unassigned'} owes ${pendingDelete.from_entity_name}, ${formatMoney(pendingDelete.amount)})? This cannot be undone.`}
		onConfirm={confirmDelete}
		onCancel={() => (pendingDelete = null)}
	/>
{/if}

<style>
	.filters {
		margin-bottom: 0.75rem;
	}
	.check {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		font-size: 13px;
	}
	.sub {
		display: block;
		font-size: 12px;
		color: var(--text-muted);
	}
</style>


