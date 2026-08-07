<script>
	// items: [{ label: string, href?: string }] — the last item without an href
	// is the current page and rendered as plain text.
	export let items = [];
</script>

<nav class="breadcrumb" aria-label="Breadcrumb">
	{#each items as item, i (i)}
		{#if item.href}
			<a href={item.href}>{item.label}</a>
		{:else}
			<span class="current">{item.label}</span>
		{/if}
		{#if i < items.length - 1}<span class="sep" aria-hidden="true">/</span>{/if}
	{/each}
</nav>

<style>
	.breadcrumb {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.4rem;
		font-size: 13px;
		margin: 0 0 0.75rem;
	}
	.breadcrumb a {
		color: var(--primary);
		text-decoration: none;
	}
	.breadcrumb a:hover {
		text-decoration: underline;
	}
	.breadcrumb .sep {
		color: var(--text-muted);
	}
	.breadcrumb .current {
		color: var(--text-muted);
	}
</style>
