<script>
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { api } from '$lib/api';
	import ObligationForm from '$lib/components/obligation/ObligationForm.svelte';

	let saving = false;
	let error = '';

	async function save(payload) {
		saving = true;
		error = '';
		try {
			const [created] = await api.createObligation(payload);
			goto(`${base}/obligations/${created.id}`);
		} catch (e) {
			error = e.message;
			saving = false;
		}
	}
</script>

<div class="page-header">
	<div>
		<h1>New obligation</h1>
		<p class="subtitle">Track a bill, utility, tax, insurance premium, loan payment, or work order.</p>
	</div>
</div>

<div class="card">
	{#if error}<p class="error-text">{error}</p>{/if}
	<ObligationForm busy={saving} onSubmit={save} 	onCancel={() => goto(`${base}/obligations`)} />
</div>

