// Documents: metadata in Postgres, files in the private "documents" bucket.
import { supabase, unwrap } from './client.js';
import { getOrgId } from './context.js';

export async function getDocuments({ entityType, entityId } = {}) {
	const orgId = getOrgId();
	let query = supabase
		.from('v_documents')
		.select('*')
		.eq('organization_id', orgId)
		.order('created_at', { ascending: false });
	if (entityType) query = query.eq('entity_type', entityType);
	if (entityId) query = query.eq('entity_id', entityId);
	return unwrap(await query);
}

// Upload a file, attach a metadata row, return the document row.
export async function uploadDocument(entityType, entityId, file) {
	const orgId = getOrgId();
	const storagePath = `${orgId}/${entityType}/${entityId}/${crypto.randomUUID()}_${file.name}`;

	const upload = await supabase.storage.from('documents').upload(storagePath, file, {
		cacheControl: '3600',
		upsert: false
	});
	if (upload.error) throw new Error(upload.error.message);

	return unwrap(
		await supabase
			.from('documents')
			.insert({
				organization_id: orgId,
				entity_type: entityType,
				entity_id: entityId,
				file_name: file.name,
				mime_type: file.type || null,
				size_bytes: file.size,
				storage_path: storagePath
			})
			.select()
	);
}

export async function deleteDocument(id) {
	const orgId = getOrgId();
	const row = unwrap(
		await supabase
			.from('documents')
			.select('storage_path')
			.eq('organization_id', orgId)
			.eq('id', id)
			.single()
	);
	await supabase.storage.from('documents').remove([row.storage_path]);
	return unwrap(
		await supabase.from('documents').delete().eq('organization_id', orgId).eq('id', id)
	);
}

// Signed, time-limited URL for viewing a file.
export async function getDocumentUrl(id) {
	const orgId = getOrgId();
	const row = unwrap(
		await supabase
			.from('documents')
			.select('storage_path')
			.eq('organization_id', orgId)
			.eq('id', id)
			.single()
	);
	const { data, error } = await supabase.storage
		.from('documents')
		.createSignedUrl(row.storage_path, 300);
	if (error) throw new Error(error.message);
	return data.signedUrl;
}
