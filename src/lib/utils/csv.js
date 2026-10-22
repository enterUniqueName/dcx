// Download rows as a CSV file. A column can provide exportValue(row) for custom output.
export function downloadCSV(filename, columns, rows) {
	const header = columns.map((c) => c.label).join(',');
	const lines = rows.map((row) =>
		columns
			.map((c) => {
				const v = c.exportValue ? c.exportValue(row) : row[c.key];
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

// Capture a report section as it appears in the browser.
export async function downloadPNG(filename, element) {
	if (!element) throw new Error('There is no report to export.');
	await document.fonts?.ready;
	const { default: html2canvas } = await import('html2canvas');
	const tableWidth = element.querySelector('table')?.scrollWidth ?? 0;
	const width = Math.ceil(Math.max(element.scrollWidth, tableWidth));
	const height = Math.ceil(element.scrollHeight);
	const scale = Math.min(2, 16000 / width, 16000 / height);
	const canvas = await html2canvas(element, {
		backgroundColor: '#ffffff',
		scale,
		useCORS: true,
		width,
		height,
		windowWidth: width,
		onclone: (documentClone) => {
			const report = documentClone.querySelector('[data-png-report]');
			if (!report) return;
			report.style.width = `${width}px`;
			const tableWrap = report.querySelector('.table-wrap');
			if (tableWrap) tableWrap.style.overflow = 'visible';
		}
	});

	const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
	if (!blob) throw new Error('The report image could not be created.');
	downloadBlob(filename, blob);
}

function downloadBlob(filename, blob) {
	const url = URL.createObjectURL(blob);
	const link = document.createElement('a');
	link.href = url;
	link.download = filename;
	link.click();
	URL.revokeObjectURL(url);
}
