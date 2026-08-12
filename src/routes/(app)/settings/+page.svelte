<script>
	import PagePlaceholder from '$lib/components/ui/PagePlaceholder.svelte';
</script>

<!--
	Placeholder — hidden from navigation (no sidebar link), kept as the future
	home for organization defaults and account preferences.

	Ideas we've discussed for this page when it gets built:

	- My profile:
	  * display name (profiles.display_name — already surfaced in org rosters
	    via v_org_members, but not editable in the UI yet)
	  * default organization (profiles.default_organization_id — already used
	    by the org-switcher in api/context.js)
	  * signed-in email (read-only)

	- Organization (owner/admin only):
	  * organization name (editable; slug should stay read-only — it's unique
	    and renaming it would break links/org switching)
	  * default_currency from organization_settings — note the column exists
	    (default 'USD') but is NOT wired anywhere yet: formatMoney in
	    src/lib/utils/format.js hardcodes '$'. Include this only when/if
	    currency-aware formatting is implemented, or it will silently no-op.

	Membership management (roster, invites, roles) and entity-scoped partner
	access intentionally live on the Organizations page instead of here.

	RLS note: when building, guard edits to organization_settings/profiles with
	the owner/admin checks used elsewhere (can_write_org / org_members_detail
	pattern from 000013/000014) so viewers can't change them.
-->

<PagePlaceholder title="Settings" description="Organization settings and defaults." />
