// Shared table sorting helpers.
// Columns look like { key, label, format } where format is one of
// 'text' | 'money' | 'percent' | 'date' | 'yesno'. Pass an optional
// `value(row)` accessor to sort on a derived / coalesced field.
// Null, empty and unparseable values always sort last, regardless of direction.

export function sortValue(v, format) {
	if (v === null || v === undefined || v === '') return null;
	if (format === 'money' || format === 'percent' || format === 'yesno') return Number(v);
	if (format === 'date') {
		const t = new Date(v).getTime();
		return Number.isNaN(t) ? null : t;
	}
	return String(v).toLowerCase();
}

export function compareRows(a, b, col, value) {
	const get = value ?? ((row) => row[col.key]);
	const av = sortValue(get(a), col.format);
	const bv = sortValue(get(b), col.format);
	if (av === null && bv === null) return 0;
	if (av === null) return 1;
	if (bv === null) return -1;
	if (typeof av === 'number' && typeof bv === 'number') return av - bv;
	return av.localeCompare(bv, undefined, { numeric: true });
}

export function sortRows(rows, col, dir, value) {
	const list = [...rows];
	if (!col) return list;
	const d = dir === 'asc' ? 1 : -1;
	list.sort((a, b) => compareRows(a, b, col, value) * d);
	return list;
}

export function nextSort(colKey, sortKey, sortDir) {
	if (sortKey === colKey) return { key: colKey, dir: sortDir === 'asc' ? 'desc' : 'asc' };
	return { key: colKey, dir: 'asc' };
}
