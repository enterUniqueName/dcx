<script>
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import { api } from '$lib/api';
	import ObligationForm from '$lib/components/obligation/ObligationForm.svelte';
	import BillForm from '$lib/components/obligation/BillForm.svelte';

	$: kind = $page.url.searchParams.get('kind') === 'bill' ? 'bill' : 'template';

	let saving = false;
	let error = '';

	async function saveTemplate(payload) {
		saving = true;
		error = '';
		try {
			const [created] = await api.createTemplate(payload);
			goto(`${base}/obligations/${created.id}`);
		} catch (e) {
			error = e.message;
			saving = false;
		}
	}

	async function saveBill(payload) {
		saving = true;
		error = '';
		try {
			const [created] = await api.createBill(payload);
			goto(`${base}/obligations/${created.id}`);
		} catch (e) {
			error = e.message;
			saving = false;
		}
	}
</script>

<div class="page-header">
	<div>
		<h1>New {kind === 'bill' ? 'bill' : 'template'}</h1>
		<p class="subtitle">
			{#if kind === 'bill'}
				Record a single concrete bill (one-off invoice, or a generated bill's overrides).
			{:else}
				Define a recurring obligation; bills are generated from it on its schedule.
			{/if}
		</p>
	</div>
</div>

<div class="card">
	{#if error}<p class="error-text">{error}</p>{/if}
	{#if kind === 'bill'}
		<BillForm busy={saving} onSubmit={saveBill} onCancel={() => goto(`${base}/obligations`)} />
	{:else}
		<ObligationForm busy={saving} onSubmit={saveTemplate} onCancel={() => goto(`${base}/obligations`)} />
	{/if}
</div>
