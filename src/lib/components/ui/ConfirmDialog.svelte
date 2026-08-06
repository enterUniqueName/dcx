<script>
	export let title = 'Confirm';
	export let message = 'Are you sure?';
	export let confirmLabel = 'Delete';
	export let busy = false;
	export let onConfirm = null;
	export let onCancel = null;
</script>

<div class="root">
	<button class="backdrop" type="button" aria-label="Close" onclick={onCancel}></button>
	<div class="dialog" role="dialog" aria-modal="true" aria-label={title}>
		<h2>{title}</h2>
		<p>{message}</p>
		<div class="row">
			<button class="btn" type="button" onclick={onCancel} disabled={busy}>Cancel</button>
			<button class="btn btn-danger" type="button" onclick={onConfirm} disabled={busy}>
				{busy ? 'Working…' : confirmLabel}
			</button>
		</div>
	</div>
</div>

<style>
	.root {
		position: fixed;
		inset: 0;
		z-index: 60;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}
	.backdrop {
		position: absolute;
		inset: 0;
		border: none;
		padding: 0;
		background: rgba(17, 24, 39, 0.5);
		cursor: pointer;
	}
	.dialog {
		position: relative;
		width: 100%;
		max-width: 400px;
		background: var(--surface);
		border-radius: var(--radius);
		padding: 1.25rem;
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
	}
	.dialog h2 {
		margin: 0 0 0.5rem;
	}
	.dialog p {
		color: var(--text);
		margin: 0 0 1rem;
	}
	.row {
		display: flex;
		justify-content: flex-end;
		gap: 0.6rem;
	}
</style>
