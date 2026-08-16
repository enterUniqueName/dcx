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
	import BillForm from '$lib/components/obligation/BillForm.svelte';
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
	let showGenerate = false;
	let saving = false;
	let pendingDelete = null;

	$: isBill = obligation?.kind === 'bill';
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
			// The id may be a template or a bill; fetch both, keep the match.
			const [ob, pays, ents] = await Promise.all([
				fetchObligation(id),
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

	async function fetchObligation(id) {
		const settled = await Promise.allSettled([api.getBill(id), api.getTemplate(id)]);
		const hit = settled.find((s) => s.status === 'fulfilled');
		if (!hit) throw new Error('Obligation not found');
		return hit.value;
	}

	async function toggleReceived() {
		try {
			await (obligation.received
				? api.markBillUnreceived(obligation.id)
				: api.markBillReceived(obligation.id));
			await load();
		} catch (e) {
			error = e.message;
		}
	}

	async function confirmPay(payload) {
		saving = true;
		error = '';
		try {
			await api.payBill(obligation.id, payload);
			showPay = false;
			await load();
		} catch (e) {
			error = e.message;
		} finally {
			saving = false;
		}
	}

	async function confirmGenerate() {
		saving = true;
		error = '';
		try {
			const created = await api.generateBills();
			showGenerate = false;
			if (created > 0) await load();
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
			await (isBill
				? api.updateBill(obligation.id, payload)
				: api.updateTemplate(obligation.id, payload));
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
			await (isBill
				? api.cancelBill(obligation.id)
				: api.cancelTemplate(obligation.id));
			pendingDelete = null;
			await load();
		} catch (e) {
			error = e.message;
		}
	}

	async function confirmDelete() {
		try {
			await (isBill
				? api.deleteBill(obligation.id)
				: api.deleteTemplate(obligation.id));
			goto(`${base}/obligations`);
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
				<span class="kind-chip">{isBill ? 'Bill' : 'Template'}</span>
			</div>
			<p class="subtitle">
				{obligation.category.replace('_', ' ')}
				{#if isBill}
					· due <DueChip dueDate={obligation.next_due_date} />
				{:else}
					· next due {formatDate(obligation.next_due_date)}
				{/if}
				{#if obligation.received} · received {formatDate(obligation.received_date)}{/if}
			</p>
		</div>
		<div class="actions">
			{#if isBill}
				{#if obligation.status === 'open'}
					<button class="btn" onclick={toggleReceived}>
						{obligation.received ? 'Mark not received' : 'Mark received'}
					</button>
					<button class="btn btn-primary" onclick={() => (showPay = true)}>Mark paid</button>
				{/if}
				<button class="btn" onclick={() => (editing = !editing)}>{editing ? 'Close edit' : 'Edit'}</button>
				{#if obligation.status === 'open'}
					<button class="btn btn-danger" onclick={() => (pendingDelete = 'cancel')}>Cancel bill</button>
				{:else}
					<button class="btn btn-danger" onclick={() => (pendingDelete = 'delete')}>Delete</button>
				{/if}
			{:else}
				<button class="btn" onclick={() => (showGenerate = true)}>Generate bills</button>
				<button class="btn" onclick={() => (editing = !editing)}>{editing ? 'Close edit' : 'Edit'}</button>
				{#if obligation.status === 'open'}
					<button class="btn btn-danger" onclick={() => (pendingDelete = 'cancel')}>Cancel template</button>
				{:else}
					<button class="btn btn-danger" onclick={() => (pendingDelete = 'delete')}>Delete</button>
				{/if}
			{/if}
		</div>
	</div>

	{#if editing}
		<div class="card edit-card">
			{#if isBill}
				<BillForm
					initial={obligation}
					busy={saving}
					onSubmit={saveEdit}
					onCancel={() => (editing = false)}
				/>
			{:else}
				<ObligationForm
					initial={obligation}
					busy={saving}
					onSubmit={saveEdit}
					onCancel={() => (editing = false)}
				/>
			{/if}
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
		{#if isBill}
			<div class="fact">
				<span>Paid</span>
				<b>{obligation.paid_amount != null ? formatMoney(obligation.paid_amount) : '—'}</b>
			</div>
			{#if obligation.paid_date}
				<div class="fact"><span>Paid date</span><b>{formatDate(obligation.paid_date)}</b></div>
				<div class="fact"><span>Method</span><b>{obligation.method ?? '—'}</b></div>
				<div class="fact"><span>Reference</span><b>{obligation.reference ?? '—'}</b></div>
			{/if}
		{:else}
			<div class="fact">
				<span>Frequency</span>
				<b>
					{obligation.frequency.replace('_', ' ')}
					{#if obligation.interval_days} · {obligation.interval_days} days after previous bill{/if}
				</b>
			</div>
		{/if}
		{#if obligation.portal_url}
			<div class="fact"><span>Portal</span><b><a href={obligation.portal_url} target="_blank" rel="noopener">Open portal</a></b></div>
		{/if}
		{#if obligation.notes}<div class="fact wide"><span>Notes</span><b>{obligation.notes}</b></div>{/if}
	</div>

	{#if isBill}
		<div class="card">
			<h2>Payment history</h2>
			<PaymentTable payments={payments} />
			{#if obligation.status === 'paid'}
				<p class="hint">
					Payments are recorded on the bill itself. Delete this bill to remove its payment record.
				</p>
			{/if}
		</div>
	{/if}

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

{#if showGenerate}
	<ConfirmDialog
		title="Generate bills?"
		message="Create every missing bill for this template (and all other open templates) up to 6 months out. Already-generated bills are kept."
		confirmLabel="Generate bills"
		onConfirm={confirmGenerate}
		onCancel={() => (showGenerate = false)}
	/>
{/if}

{#if pendingDelete === 'cancel'}
	<ConfirmDialog
		title={isBill ? 'Cancel bill?' : 'Cancel template?'}
		message={isBill
			? 'This marks the bill canceled. It will not appear in overdue or upcoming lists.'
			: 'This stops generating bills from this template. Existing bills are kept.'}
		confirmLabel={isBill ? 'Cancel bill' : 'Cancel template'}
		onConfirm={confirmCancel}
		onCancel={() => (pendingDelete = null)}
	/>
{:else if pendingDelete === 'delete'}
	<ConfirmDialog
		title={isBill ? 'Delete bill?' : 'Delete template?'}
		message={isBill
			? 'This permanently removes the bill and its payment record.'
			: 'This permanently removes the template and any bills generated from it.'}
		onConfirm={confirmDelete}
		onCancel={() => (pendingDelete = null)}
	/>
{/if}

<style>
	.title-row {
		display: flex;
		align-items: center;
		gap: 0.6rem;
	}
	.kind-chip {
		font-size: 11px;
		font-weight: 600;
		text-transform: uppercase;
		color: var(--primary);
		border: 1px solid var(--border);
		border-radius: 4px;
		padding: 0.1rem 0.4rem;
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
