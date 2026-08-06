<script>
	export let title = '';
	export let onClose = null;
	export let wide = false;
</script>

<div class="root">
	<button class="backdrop" type="button" aria-label="Close" onclick={onClose}></button>
	<div class="modal" class:wide role="dialog" aria-modal="true" aria-label={title}>
		<div class="modal-head">
			<h2>{title}</h2>
			<button class="btn-close" type="button" onclick={onClose} aria-label="Close">&times;</button>
		</div>
		<div class="modal-body">
			<slot />
		</div>
	</div>
</div>

<style>
	.root {
		position: fixed;
		inset: 0;
		z-index: 50;
		display: flex;
		align-items: flex-start;
		justify-content: center;
		padding: 5vh 1rem;
	}
	.backdrop {
		position: absolute;
		inset: 0;
		border: none;
		padding: 0;
		background: rgba(17, 24, 39, 0.5);
		cursor: pointer;
	}
	.modal {
		position: relative;
		width: 100%;
		max-width: 520px;
		max-height: 85vh;
		overflow-y: auto;
		background: var(--surface);
		border-radius: var(--radius);
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
	}
	.modal.wide {
		max-width: 760px;
	}
	.modal-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem 1.25rem;
		border-bottom: 1px solid var(--border);
		position: sticky;
		top: 0;
		background: var(--surface);
	}
	.modal-head h2 {
		margin: 0;
	}
	.modal-body {
		padding: 1.25rem;
	}
	.btn-close {
		border: none;
		background: none;
		font-size: 1.4rem;
		line-height: 1;
		cursor: pointer;
		color: var(--text-muted);
	}
</style>
