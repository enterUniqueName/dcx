// Download rows as a CSV file. Raw values are used (no currency/date display formatting).
export function downloadCSV(filename, columns, rows) {
	const header = columns.map((c) => c.label).join(',');
	const lines = rows.map((row) =>
		columns
			.map((c) => {
				const v = row[c.key];
				const s = v === null || v === undefined ? '' : String(v);
				return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
			})
			.join(',')
	);
	const csv = [header, ...lines].join('\n');
	const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
	const url = URL.createObjectURL(blob);
	const a = document.createElement('a');
	a.href = url;
	a.download = filename;
	a.click();
	URL.revokeObjectURL(url);
}
