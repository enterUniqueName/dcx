<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { api } from '$lib/api';
	import StatusBadge from '$lib/components/ui/StatusBadge.svelte';
	import Breadcrumb from '$lib/components/ui/Breadcrumb.svelte';
	import DueChip from '$lib/components/ui/DueChip.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import ObligationForm from '$lib/components/obligation/ObligationForm.svelte';
	import PayObligationModal from '$lib/components/obligation/PayObligationModal.svelte';
	import DocumentsPanel from '$lib/components/obligation/DocumentsPanel.svelte';
	import PaymentTable from '$lib/components/payments/PaymentTable.svelte';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	let obligation = null;
	let payments = [];
	let entities = [];
	let loading = true;
	let error = '';

	let editing = false;
	let showPay = false;
	let saving = false;
	let pendingDelete = null;
	let pendingPaymentDelete = null;

	$: isDerived =
		obligation &&
		obligation.est_amount != null &&
		Number(obligation.est_amount) !== Number(obligation.amount);

	onMount(load);

	async function load() {
		loading = true;
		error = '';
		try {
			const id = $page.params.id;
			const [ob, pays, ents] = await Promise.all([
				api.getObligation(id),
				api.getPayments({ obligationId: id }),
				api.getOwnershipEntities()
			]);
			obligation = ob;
			payments = pays;
			entities = ents;
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	async function toggleReceived() {
		try {
			await (obligation.received
				? api.markObligationUnreceived(obligation.id)
				: api.markObligationReceived(obligation.id));
			await load();
		} catch (e) {
			error = e.message;
		}
	}

	async function confirmPay(payload) {
		saving = true;
		error = '';
		try {
			await api.markObligationPaid(obligation.id, payload);
			showPay = false;
			await load();
		} catch (e) {
			error = e.message;
		} finally {
			saving = false;
		}
	}

	async function saveEdit(payload) {
		saving = true;
		error = '';
		try {
			await api.updateObligation(obligation.id, payload);
			editing = false;
			await load();
		} catch (e) {
			error = e.message;
		} finally {
			saving = false;
		}
	}

	async function confirmCancel() {
		try {
			await api.cancelObligation(obligation.id);
			pendingDelete = null;
			await load();
		} catch (e) {
			error = e.message;
		}
	}

	async function confirmDelete() {
		try {
			await api.deleteObligation(obligation.id);
			goto(`${base}/obligations`);
		} catch (e) {
			error = e.message;
		}
	}

	async function confirmPaymentDelete() {
		try {
			await api.deletePayment(pendingPaymentDelete.id);
			pendingPaymentDelete = null;
			await load();
		} catch (e) {
			error = e.message;
		}
	}
</script>

<Breadcrumb
	items={[
		{ label: 'Obligations', href: `${base}/obligations` },
		{ label: obligation?.name ?? 'Details' }
	]}
/>

{#if loading}
	<p class="empty">Loading…</p>
{:else if error}
	<p class="error-text">{error}</p>
{:else if obligation}
	<div class="page-header">
		<div>
			<div class="title-row">
				<h1>{obligation.name}</h1>
				<StatusBadge status={obligation.is_overdue ? 'overdue' : obligation.status} />
			</div>
			<p class="subtitle">
				{obligation.category.replace('_', ' ')} · due <DueChip dueDate={obligation.next_due_date} />
				{#if obligation.received} · received {formatDate(obligation.received_date)}{/if}
			</p>
		</div>
		<div class="actions">
			{#if obligation.status === 'open'}
				<button class="btn" onclick={toggleReceived}>
					{obligation.received ? 'Mark not received' : 'Mark received'}
				</button>
				<button class="btn btn-primary" onclick={() => (showPay = true)}>Mark paid</button>
				<button class="btn" onclick={() => (editing = !editing)}>{editing ? 'Close edit' : 'Edit'}</button>
				<button class="btn btn-danger" onclick={() => (pendingDelete = 'cancel')}>Cancel obligation</button>
			{:else}
				<button class="btn" onclick={() => (editing = !editing)}>{editing ? 'Close edit' : 'Edit'}</button>
				<button class="btn btn-danger" onclick={() => (pendingDelete = 'delete')}>Delete</button>
			{/if}
		</div>
	</div>

	{#if editing}
		<div class="card edit-card">
			<ObligationForm
				initial={obligation}
				busy={saving}
				onSubmit={saveEdit}
				onCancel={() => (editing = false)}
			/>
		</div>
	{/if}

	<div class="card facts">
		<div class="fact"><span>Entity</span><b>{obligation.ownership_entity_name ?? '—'}</b></div>
		<div class="fact"><span>Property</span><b>{obligation.property_name ?? '—'}</b></div>
		<div class="fact"><span>Tenant</span><b>{obligation.tenant_name ?? '—'}</b></div>
		<div class="fact"><span>Vendor</span><b>{obligation.vendor_name ?? '—'}</b></div>
		<div class="fact"><span>Loan</span><b>{obligation.loan_name ?? '—'}</b></div>
		<div class="fact">
			<span>Amount</span>
			<b>{formatMoney(obligation.est_amount ?? obligation.amount)}</b>
			{#if isDerived}<span>Estimated · average of the last 3 bills</span>{/if}
		</div>
		<div class="fact">
			<span>Frequency</span>
			<b>
				{obligation.frequency.replace('_', ' ')}
				{#if obligation.interval_days} · {obligation.interval_days} days after previous bill{/if}
			</b>
		</div>
		<div class="fact"><span>Billing period</span><b>{formatDate(obligation.billing_start)} → {formatDate(obligation.billing_end)}</b></div>
		<div class="fact"><span>Portal</span><b>{#if obligation.portal_url}<a href={obligation.portal_url} target="_blank" rel="noopener">Open portal</a>{:else}—{/if}</b></div>
		{#if obligation.notes}<div class="fact wide"><span>Notes</span><b>{obligation.notes}</b></div>{/if}
	</div>

	<div class="card">
		<h2>Payment history</h2>
		<PaymentTable payments={payments} showDelete={true} onDelete={(p) => (pendingPaymentDelete = p)} />
	</div>

	<div class="card">
		<DocumentsPanel entityType="obligation" entityId={obligation.id} />
	</div>
{/if}

{#if showPay}
	<PayObligationModal
		obligation={obligation}
		entities={entities}
		busy={saving}
		onConfirm={confirmPay}
		onCancel={() => (showPay = false)}
	/>
{/if}

{#if pendingDelete === 'cancel'}
	<ConfirmDialog
		title="Cancel obligation?"
		message="This stops tracking the obligation. It will not appear in overdue or upcoming lists."
		confirmLabel="Cancel obligation"
		onConfirm={confirmCancel}
		onCancel={() => (pendingDelete = null)}
	/>
{:else if pendingDelete === 'delete'}
	<ConfirmDialog
		title="Delete obligation?"
		message="This permanently removes the obligation and its payments."
		onConfirm={confirmDelete}
		onCancel={() => (pendingDelete = null)}
	/>
{/if}

{#if pendingPaymentDelete}
	<ConfirmDialog
		message={`Delete payment of ${formatMoney(pendingPaymentDelete.amount)} from ${formatDate(pendingPaymentDelete.paid_date)}? This does not undo the obligation's next due date.`}
		onConfirm={confirmPaymentDelete}
		onCancel={() => (pendingPaymentDelete = null)}
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
