<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api';
	import { formatMoney, formatDate } from '$lib/utils/format.js';

	export let row = null;

	const FLAGS = [
		{ key: 'responsible_water', label: 'Water' },
		{ key: 'responsible_electric', label: 'Electric' },
		{ key: 'responsible_internet', label: 'Internet' },
		{ key: 'responsible_hvac', label: 'HVAC' },
		{ key: 'responsible_cam', label: 'CAM' }
	];

	let rentRows = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			rentRows = await api.getTenantRentHistory(row.id);
		} catch (e) {
			error = e.message;
		} finally {
			loading = false;
		}
	});
</script>

<div class="detail">
	<div class="grid">
		<div class="section">
			<h3>Rent history</h3>
			{#if error}
				<p class="error-text">{error}</p>
			{:else if loading}
				<p class="muted">Loading…</p>
			{:else if rentRows.length === 0}
				<p class="muted">No rent schedule set</p>
			{:else}
				<ul>
					{#each rentRows as r (r.id)}
						<li class="rent-row">
							<span class="period">
								{formatDate(r.period_start)} →
								{r.period_end ? formatDate(r.period_end) : 'now'}
							</span>
							<b>{formatMoney(r.amount)}</b>
							{#if r.cpi_percent}<span class="chip-cpi">+{r.cpi_percent}% CPI</span>{/if}
							{#if r.notes}<span class="muted">{r.notes}</span>{/if}
						</li>
					{/each}
				</ul>
			{/if}
		</div>

		<div class="section">
			<h3>Utilities & services</h3>
			<div class="flags">
				{#each FLAGS as f (f.key)}
					<span class="flag" class:tenant-pays={row[f.key]}>
						{f.label}: {row[f.key] ? 'Tenant pays' : 'Landlord pays'}
					</span>
				{/each}
			</div>

			<h3 class="spaced">Lease</h3>
			<p class="muted">
				{#if row.lease_start}
					{formatDate(row.lease_start)} → {row.lease_end ? formatDate(row.lease_end) : 'open-ended'}
				{:else}
					No term recorded
				{/if}
			</p>
			{#if row.lease_url}
				<a class="lease-link" href={row.lease_url} target="_blank" rel="noopener">Open lease →</a>
			{/if}
			{#if row.lease_notes}<p class="muted lease-notes">{row.lease_notes}</p>{/if}
			{#if row.notes}<p class="muted lease-notes">{row.notes}</p>{/if}
		</div>
	</div>
</div>

<style>
	.detail {
		padding: 0.9rem 1.25rem 1.1rem;
	}
	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
		gap: 0 2rem;
	}
	.section {
		min-width: 0;
	}
	.section h3 {
		font-size: 12px;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--text-muted);
		margin: 0 0 0.4rem;
	}
	h3.spaced {
		margin-top: 1rem;
	}
	ul {
		list-style: none;
		margin: 0;
		padding: 0;
		display: grid;
		gap: 0.5rem;
	}
	.rent-row {
		display: grid;
		grid-template-columns: auto 1fr auto auto;
		align-items: center;
		gap: 0.5rem;
	}
	.rent-row .period {
		font-size: 12px;
		color: var(--text-muted);
	}
	.rent-row b {
		font-size: 13px;
		font-weight: 600;
	}
	.chip-cpi {
		display: inline-block;
		padding: 0.05rem 0.45rem;
		border-radius: 999px;
		font-size: 11px;
		font-weight: 500;
		background: #fefce8;
		color: #ca8a04;
	}
	.flags {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
	}
	.flag {
		display: inline-block;
		padding: 0.2rem 0.55rem;
		border-radius: 999px;
		font-size: 12px;
		font-weight: 500;
		background: #eff6ff;
		color: var(--primary);
	}
	.flag.tenant-pays {
		background: #fff7ed;
		color: var(--warn);
	}
	.muted {
		color: var(--text-muted);
		font-size: 13px;
		margin: 0;
	}
	.lease-notes {
		margin-top: 0.4rem;
	}
	.lease-link {
		font-size: 13px;
		font-weight: 600;
	}
</style>
