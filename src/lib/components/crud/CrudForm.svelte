<script>
	import { onMount } from 'svelte';

	// fields: [{ key, label, type, required, options|source, min, step, placeholder }]
	// references: { sourceKey: [{ id, name }] }
	export let fields = [];
	export let references = {};
	export let initial = null;
	export let defaults = {};
	export let busy = false;
	export let onSubmit = null;
	export let onCancel = null;

	let values = {};
	let error = '';

	onMount(() => {
		values = {};
		if (initial) {
			for (const f of fields) values[f.key] = initial[f.key] ?? '';
		} else {
			for (const f of fields) {
				values[f.key] = f.type === 'checkbox' ? !!defaults[f.key] : (defaults[f.key] ?? '');
			}
		}
	});

	function selectOptions(field) {
		if (field.options) return field.options;
		if (field.source) return (references[field.source] ?? []).map((r) => ({ value: r.id, label: r.name }));
		return [];
	}

	function submit() {
		const payload = {};
		for (const f of fields) {
			const v = values[f.key];
			if (f.type === 'checkbox') {
				payload[f.key] = !!v;
			} else if (f.type === 'number') {
				payload[f.key] = v === '' || v === null || v === undefined ? null : Number(v);
			} else if (f.type === 'select') {
				payload[f.key] = v === '' ? null : v;
			} else if (f.type === 'date') {
				payload[f.key] = v || null;
			} else {
				payload[f.key] = typeof v === 'string' ? v.trim() || null : v;
			}
		}

		for (const f of fields) {
			if (f.required && (payload[f.key] === null || payload[f.key] === '')) {
				error = `${f.label} is required.`;
				return;
			}
		}

		error = '';
		onSubmit?.(payload);
	}
</script>

<div class="form-grid">
	{#each fields as f (f.key)}
		{#if f.type === 'checkbox'}
			<label class="check full" for={`crud-${f.key}`}>
				<input id={`crud-${f.key}`} type="checkbox" bind:checked={values[f.key]} />
				{f.label}
			</label>
		{:else}
			<div class="field" class:full={f.type === 'textarea'}>
				<label for={`crud-${f.key}`}>{f.label}{f.required ? ' *' : ''}</label>
				{#if f.type === 'select'}
					<select id={`crud-${f.key}`} class="select" bind:value={values[f.key]}>
						<option value="">—</option>
						{#each selectOptions(f) as o (o.value)}
							<option value={o.value}>{o.label}</option>
						{/each}
					</select>
				{:else if f.type === 'number'}
					<input
						id={`crud-${f.key}`}
						class="input"
						type="number"
						min={f.min}
						step={f.step}
						placeholder={f.placeholder}
						bind:value={values[f.key]}
					/>
				{:else if f.type === 'date'}
					<input id={`crud-${f.key}`} class="input" type="date" bind:value={values[f.key]} />
				{:else if f.type === 'textarea'}
					<textarea id={`crud-${f.key}`} class="textarea" rows="3" bind:value={values[f.key]}></textarea>
				{:else}
					<input
						id={`crud-${f.key}`}
						class="input"
						type="text"
						placeholder={f.placeholder}
						bind:value={values[f.key]}
					/>
				{/if}
			</div>
		{/if}
	{/each}
</div>

{#if error}<p class="error-text">{error}</p>{/if}

<div class="row">
	<button class="btn" onclick={onCancel} disabled={busy}>Cancel</button>
	<button class="btn btn-primary" onclick={submit} disabled={busy}>
		{busy ? 'Saving…' : 'Save'}
	</button>
</div>

<style>
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
	.check {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 13px;
		padding-top: 1.2rem;
	}
	.check.full {
		grid-column: 1 / -1;
	}
	.row {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
		margin-top: 0.5rem;
	}
</style>
