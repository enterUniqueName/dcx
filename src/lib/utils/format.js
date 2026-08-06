export function formatMoney(amount) {
	const n = Number(amount ?? 0);
	return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n);
}

export function formatDate(iso) {
	if (!iso) return '—';
	const date = new Date(iso.length === 10 ? `${iso}T00:00:00` : iso);
	return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

// Whole days from today (today = 0). Returns null for missing/parsing failure.
export function daysFromNow(iso) {
	if (!iso) return null;
	const today = new Date();
	today.setHours(0, 0, 0, 0);
	const target = new Date(iso.length === 10 ? `${iso}T00:00:00` : iso);
	if (Number.isNaN(target.getTime())) return null;
	return Math.round((target - today) / 86400000);
}

export function toISODate(date) {
	const d = date instanceof Date ? date : new Date(date);
	return d.toISOString().slice(0, 10);
}

export function monthKey(date) {
	const d = date instanceof Date ? date : new Date(date);
	return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

export function formatSize(bytes) {
	if (!bytes) return '—';
	const kb = bytes / 1024;
	return kb >= 1024 ? `${(kb / 1024).toFixed(1)} MB` : `${Math.round(kb)} KB`;
}
