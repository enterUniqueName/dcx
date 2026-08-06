<script>
	export let title;
	export let description = 'Under construction.';
</script>

<div class="page-header">
	<h1>{title}</h1>
</div>
<div class="card">
	<p class="muted">{description}</p>
</div>

<style>
	.muted {
		color: var(--text-muted);
		margin: 0;
	}
</style>
