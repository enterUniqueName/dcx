<script>
	import { daysFromNow, formatDate } from '$lib/utils/format.js';

	export let dueDate;

	$: days = daysFromNow(dueDate);
</script>

{#if days === null}
	<span class="muted">{formatDate(dueDate)}</span>
{:else if days < 0}
	<span class="chip-due-overdue" title={formatDate(dueDate)}>{Math.abs(days)}d overdue</span>
{:else if days === 0}
	<span class="chip-due-soon" title={formatDate(dueDate)}>due today</span>
{:else if days <= 7}
	<span class="chip-due-soon" title={formatDate(dueDate)}>in {days}d</span>
{:else}
	<span class="muted">{formatDate(dueDate)}</span>
{/if}
