<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { api } from '$lib/api';
	import StatusBadge from '$lib/components/ui/StatusBadge.svelte';
	import Breadcrumb from '$lib/components/ui/Breadcrumb.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import BillbackForm from '$lib/components/billback/BillbackForm.svelte';
	import SettleBillbackModal from '$lib/components/billback/SettleBillbackModal.svelte';
	import PaymentTable from '$lib/components/payments/PaymentTable.svelte';
	import DocumentsPanel from '$lib/components/obligation/DocumentsPanel.svelte';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	let billback = null;
	let allocations = [];
	let payments = [];
	let loading = true;
	let error = '';

	let editing = false;
	let settling = false;
	let saving = false;
	let pendingDelete = false;

	onMount(load);

	async function load() {
		loading = true;
		error = '';
		try {
			const id = $page.params.id;
			const [bb, allocs, pays] = await Promise.all([
				api.getBillbackById(id),
				api.getBillbackAllocations(id),
				api.getPayments({ billbackId: id })
			]);
			billback = bb;
			allocations = allocs;
			payments = pays;
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	async function saveEdit(payload) {
		saving = true;
		error = '';
		try {
			await api.deleteBillback(billback.id);
			await api.createBillback({ ...payload, id: billback.id });
			editing = false;
			await load();
		} catch (e) {
			error = e.message;
		} finally {
			saving = false;
		}
	}

	async function confirmSettle(payload) {
		saving = true;
		error = '';
		try {
			await api.createPayment({ billbackId: billback.id, ...payload });
			settling = false;
			await load();
		} catch (e) {
			error = e.message;
		} finally {
			saving = false;
		}
	}

	async function confirmDelete() {
		try {
			await api.deleteBillback(billback.id);
			goto(`${base}/billbacks`);
		} catch (e) {
			error = e.message;
		}
	}

	function propertyDisplay() {
		if (!billback) return '—';
		return billback.property_name && billback.property_address1
			? `${billback.property_name} - ${billback.property_address1}`
			: (billback.property_name ?? '—');
	}
</script>

<Breadcrumb
	items={[
		{ label: 'Billbacks', href: `${base}/billbacks` },
		{ label: billback?.description ?? billback?.responsible_party_display ?? 'Details' }
	]}
/>

{#if loading}
	<p class="empty">Loading…</p>
{:else if error}
	<p class="error-text">{error}</p>
{:else if billback}
	<div class="page-header">
		<div>
			<div class="title-row">
				<h1>{billback.description ?? billback.responsible_party_display ?? 'Billback'}</h1>
				<StatusBadge status={billback.status} />
			</div>
			<p class="subtitle">
				{formatMoney(billback.amount)} · issued {formatDate(billback.issued_date)}
				{#if billback.due_date} · due {formatDate(billback.due_date)}{/if}
			</p>
		</div>
		<div class="actions">
			{#if billback.is_outstanding}
				<button class="btn btn-primary" onclick={() => (settling = true)}>Record payment</button>
			{/if}
			<button class="btn" onclick={() => (editing = !editing)}>{editing ? 'Close edit' : 'Edit'}</button>
			<button class="btn btn-danger" onclick={() => (pendingDelete = true)}>Delete</button>
		</div>
	</div>

	{#if editing}
		<div class="card edit-card">
			<BillbackForm
				initial={billback}
				busy={saving}
				onSubmit={saveEdit}
				onCancel={() => (editing = false)}
			/>
		</div>
	{/if}

	<div class="card facts">
		<div class="fact"><span>Responsible Party</span><b>{billback.responsible_party_display ?? '—'}</b></div>
		<div class="fact"><span>Paid By</span><b>{billback.from_entity_name ?? '—'}</b></div>
		{#if billback.to_entity_name}
			<div class="fact"><span>Owes To</span><b>{billback.to_entity_name}</b></div>
		{/if}
		<div class="fact"><span>Property</span><b>{propertyDisplay()}</b></div>
		{#if billback.vendor_name}
			<div class="fact"><span>Vendor</span><b>{billback.vendor_name}</b></div>
		{/if}
		{#if billback.obligation_name}
			<div class="fact"><span>Obligation</span><b>{billback.obligation_name}</b></div>
		{/if}
		<div class="fact">
			<span>Paid Amount</span>
			<b>{formatMoney(billback.paid_amount ?? billback.amount)}</b>
		</div>
		{#if billback.markup_percent}
			<div class="fact"><span>Markup</span><b>{billback.markup_percent}%</b></div>
		{/if}
		<div class="fact"><span>Total Amount</span><b>{formatMoney(billback.amount)}</b></div>
		<div class="fact"><span>Balance</span><b>{formatMoney(billback.balance)}</b></div>
		<div class="fact"><span>Status</span><b><StatusBadge status={billback.status} /></b></div>
		<div class="fact"><span>Issued</span><b>{formatDate(billback.issued_date)}</b></div>
		{#if billback.due_date}
			<div class="fact"><span>Due</span><b>{formatDate(billback.due_date)}</b></div>
		{/if}
		{#if billback.check_number}
			<div class="fact"><span>Check #</span><b>{billback.check_number}</b></div>
		{/if}
		<div class="fact"><span>Responsibility Type</span><b>{billback.responsibility_type ?? '—'}</b></div>
		{#if billback.notes}
			<div class="fact wide"><span>Notes</span><b>{billback.notes}</b></div>
		{/if}
	</div>

	{#if allocations.length > 0}
		<div class="card">
			<h2>Allocations</h2>
			<div class="table-wrap">
				<table>
					<thead>
						<tr>
							<th>Party</th>
							<th>Type</th>
							<th class="num">Amount</th>
						</tr>
					</thead>
					<tbody>
						{#each allocations as a (a.id)}
							<tr>
								<td>{a.responsible_type === 'tenant' ? 'Tenant' : 'Landlord'}</td>
								<td>{a.allocation_type}</td>
								<td class="num">{formatMoney(a.amount)}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	{/if}

	<div class="card">
		<h2>Payment history</h2>
		<PaymentTable payments={payments} showObligation={false} />
	</div>

	<div class="card">
		<DocumentsPanel entityType="billback" entityId={billback.id} />
	</div>
{/if}

{#if settling}
	<SettleBillbackModal billback={billback} onClose={() => (settling = false)} onSettled={confirmSettle} />
{/if}

{#if pendingDelete}
	<ConfirmDialog
		title="Delete billback?"
		message={`Permanently delete this billback (${billback.responsible_party_display ?? 'Unassigned'}, ${formatMoney(billback.amount)}). This cannot be undone.`}
		confirmLabel="Delete"
		onConfirm={confirmDelete}
		onCancel={() => (pendingDelete = false)}
	/>
{/if}

<style>
	.title-row {
		display: flex;
		align-items: center;
		gap: 0.6rem;
	}
	.subtitle {
		margin: 0.25rem 0 0;
	}
	.actions {
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
		justify-content: flex-end;
	}
	.edit-card {
		margin-bottom: 1.25rem;
	}
	.facts {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
		gap: 0.75rem 1.5rem;
		margin-bottom: 1.25rem;
	}
	.fact {
		display: grid;
		gap: 0.15rem;
	}
	.fact span {
		font-size: 12px;
		color: var(--text-muted);
	}
	.fact b {
		font-weight: 600;
	}
	.fact.wide {
		grid-column: 1 / -1;
	}
	.card + .card {
		margin-top: 1.25rem;
	}
</style>
