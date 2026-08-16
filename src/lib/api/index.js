// The single public data surface of the app.
// The UI imports { api } from '$lib/api' and nothing else.
import * as organizations from './organizations.js';
import * as entities from './entities.js';
import * as properties from './properties.js';
import * as tenants from './tenants.js';
import * as vendors from './vendors.js';
import * as loans from './loans.js';
import * as templates from './templates.js';
import * as bills from './bills.js';
import * as payments from './payments.js';
import * as billbacks from './billbacks.js';
import * as documents from './documents.js';
import * as reports from './reports.js';
import * as context from './context.js';

export const api = {
	...context,
	...organizations,
	...entities,
	...properties,
	...tenants,
	...vendors,
	...loans,
	...templates,
	...bills,
	...payments,
	...billbacks,
	...documents,
	...reports
};
