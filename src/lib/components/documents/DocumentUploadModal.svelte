<script>
	import Modal from '../ui/Modal.svelte';

	// types: [{ value, label, load }] — load() returns entity rows for the select.
	export let types = [];
	export let onClose = null;
	export let onUploaded = null;

	let type = '';
	let entityId = '';
	let entities = [];
	let file = null;
	let busy = false;
	let error = '';

	async function onTypeChange() {
		entityId = '';
		entities = [];
		error = '';
		const def = types.find((t) => t.value === type);
		if (!def) return;
		try {
			entities = await def.load();
		} catch (e) {
			error = e.message;
		}
	}

	function onFile(event) {
		file = event.target.files?.[0] ?? null;
	}

	async function submit() {
		if (!type || !entityId) {
			error = 'Choose an entity to attach to.';
			return;
		}
		if (!file) {
			error = 'Choose a file to upload.';
			return;
		}
		busy = true;
		error = '';
		try {
			await onUploaded(type, entityId, file);
		} catch (e) {
			error = e.message;
		} finally {
			busy = false;
		}
	}
</script>

<Modal title="Attach a document" onClose={onClose}>
	<div class="form-grid">
		<div class="field">
			<label for="doc-type">Entity type *</label>
			<select id="doc-type" class="select" bind:value={type} onchange={onTypeChange}>
				<option value="">—</option>
				{#each types as t (t.value)}
					<option value={t.value}>{t.label}</option>
				{/each}
			</select>
		</div>
		<div class="field">
			<label for="doc-entity">Entity *</label>
			<select id="doc-entity" class="select" bind:value={entityId} disabled={!type}>
				<option value="">—</option>
				{#each entities as e (e.id)}
					<option value={e.id}>{e.name ?? e.lender ?? e.description ?? '(unnamed)'}</option>
				{/each}
			</select>
		</div>
	</div>

	<div class="field">
		<label for="doc-file">File *</label>
		<input id="doc-file" class="input" type="file" onchange={onFile} disabled={busy} />
	</div>

	{#if error}<p class="error-text">{error}</p>{/if}

	<div class="row">
		<button class="btn" onclick={onClose} disabled={busy}>Cancel</button>
		<button class="btn btn-primary" onclick={submit} disabled={busy}>
			{busy ? 'Uploading…' : 'Upload'}
		</button>
	</div>
</Modal>

<style>
	.form-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0 1rem;
	}
	.field {
		margin-bottom: 0.85rem;
	}
	.row {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
		margin-top: 0.5rem;
	}
</style>
