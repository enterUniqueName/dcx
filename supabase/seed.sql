-- seed.sql — idempotent baseline for the DCX organization.
--
-- Data sources (exported 2026-08-03, imported into this file):
--   * ownership entities CSV            -> 7 real entities
--   * properties CSV                    -> 16 real properties (name = address, nickname = short name)
--   * loans CSV                         -> 13 real loans (monthly payment = interest + principal; nickname from notes)
-- Derived (from the real data above, not dummy):
--   * 13 recurring loan-payment obligations  (one per loan)
--   * 13 annual real-estate-tax obligations  (one per property that listed a tax amount)
-- Dummy baseline data (NOT real) is prefixed "[DEMO]" throughout and can be
-- removed with the DELETE statements in the final section of this file.
--
-- All dates are computed relative to 2026-08-05 (the import date). The app
-- computes "overdue"/"due soon" from current_date at runtime, so these dates
-- will drift as time passes — refresh them when convenient.
--
-- Provisioning the first human user (run AFTER signing up in the app):
--
--     insert into org_members (organization_id, user_id, role)
--     select org.id, auth_user.id, 'owner'
--     from organizations org
--     cross join auth.users auth_user
--     where org.slug = 'dcx' and auth_user.email = 'davesteele.tend@gmail.com'
--     on conflict do nothing;
--
-- Re-runnable: every id is fixed and every insert is "on conflict do nothing",
-- and the old demo seed (Demo Client Group) is removed first.
--
-- Ownership-entity assignment for properties/loans is a best-effort guess
-- (nickname hints + sensible defaults). Verify entity -> property ownership.
--
-- ---------------------------------------------------------------------------
-- Remove rows created by the earlier demo seed (Demo Client Group). This
-- cascades to every demo entity, property, loan, obligation, payment, etc.
-- ---------------------------------------------------------------------------
delete from organizations where id = '10000000-0000-4000-8000-000000000001';

-- ---------------------------------------------------------------------------
-- Organization
-- ---------------------------------------------------------------------------
insert into organizations (id, name, slug) values
  ('11000000-0000-4000-8000-000000000001', 'DCX', 'dcx')
on conflict (id) do nothing;

insert into organization_settings (organization_id) values
  ('11000000-0000-4000-8000-000000000001')
on conflict (organization_id) do nothing;

-- ---------------------------------------------------------------------------
-- Ownership entities (7 real — from entities CSV)
-- ---------------------------------------------------------------------------
insert into ownership_entities (id, organization_id, name, entity_type) values
  ('21000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'JenCal LLC', 'llc'),
  ('21000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', 'Fritts Price LLC', 'llc'),
  ('21000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '901 5th St LLC', 'llc'),
  ('21000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', 'Casa Nueva LLC', 'llc'),
  ('21000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', 'Calfee & Barney LLC', 'llc'),
  ('21000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', 'PLB LLC', 'llc'),
  ('21000000-0000-4000-8000-000000000007', '11000000-0000-4000-8000-000000000001', 'Daryl W Calfee', 'individual')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Properties (16 real — from properties CSV; name = address, nickname = short name)
-- ---------------------------------------------------------------------------
insert into properties (id, organization_id, ownership_entity_id, name, nickname, address1, city, state, zip, property_type, unit_count, status, annual_tax, notes) values
  ('31000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000002', '2307 Bedford Ave', 'Palmera House', '2307 Bedford Ave', 'Lynchburg', 'VA', '24503', 'residential', 1, 'active', 4200.00, null),
  ('31000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '2599 Fort Ave', 'Tacos2/Stadium District', '2599 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 1, 'active', 328.02, null),
  ('31000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '309 Hancock St', '309 Hancock', '309 Hancock St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', null, null),
  ('31000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '1915 Thomson Dr', 'Teachable Moments', '1915 Thomson Dr', 'Lynchburg', 'VA', '24501', 'commercial', 1, 'active', 1365.00, null),
  ('31000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '313 Hancock St', '313 Hancock', '313 Hancock St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', null, null),
  ('31000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '305 6th St', 'Motor Co', '305 6th St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', 1586.76, null),
  ('31000000-0000-4000-8000-000000000007', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000003', '901 Fifth St', '901 5th | Cutting Room', '901 Fifth St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', 651.84, null),
  ('31000000-0000-4000-8000-000000000008', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '58 9th St', 'SuperRad', '58 9th St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', 1035.30, null),
  ('31000000-0000-4000-8000-000000000009', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '2300 Bedford Ave', 'PLB Shop/Marshroots', '2300 Bedford Ave', 'Lynchburg', 'VA', '24503', 'commercial', 0, 'active', null, null),
  ('31000000-0000-4000-8000-000000000010', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '2309 Bedford Ave', 'Tacos#1 | Old Pizza Hut', '2309 Bedford Ave', 'Lynchburg', 'VA', '24503', 'commercial', 1, 'active', 550.20, null),
  ('31000000-0000-4000-8000-000000000011', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '2603 Fort Ave', 'Best Catch', '2603 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 0, 'active', 768.81, null),
  ('31000000-0000-4000-8000-000000000012', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '2597 Fort Ave', 'Tacos #2 Trailer | Storage Building', '2597 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 0, 'active', 144.90, null),
  ('31000000-0000-4000-8000-000000000013', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '309 6th St', 'Parking Lot', '309 6th St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', 235.83, null),
  ('31000000-0000-4000-8000-000000000014', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000005', '5900 Fort Ave', 'Carpet Shop', '5900 Fort Ave', 'Lynchburg', 'VA', '24502', 'commercial', 0, 'active', 1227.24, null),
  ('31000000-0000-4000-8000-000000000015', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000004', '2999 Fort Ave', 'Bee Line', '2999 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 0, 'active', 304.29, null),
  ('31000000-0000-4000-8000-000000000016', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000004', '2995 Fort Ave', 'Casa Nueva', '2995 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 1, 'active', 326.55, null)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Loans (13 real — from loans CSV; nickname = display name, payment = interest + principal)
-- ---------------------------------------------------------------------------
insert into loans (id, organization_id, ownership_entity_id, property_id, lender, loan_number, nickname, monthly_payment, payment_frequency, status) values
  ('41000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000004', 'Freedom First', '0007406434220002', 'Bus. Term R/E 360 | Thomson #2', 459.9, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000012', 'Pinnacle', '90865277', '2597/99 Fort', 2879.17, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000003', 'Pinnacle', '90870210', '309 Hancock', 1710.94, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000005', 'Pinnacle', '90870211', '313 Hancock', 1664.06, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000007', null, 'Pinnacle', '20231236720', 'LOC DC', 20959.62, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', null, 'Pinnacle', '90850703', 'LOC JenCal', 1376.33, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000007', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000006', 'Pinnacle', '90610425', '305 6th | Motor Co', 12345, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000008', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', null, 'Pinnacle', '90840959', 'LOC PLB', 1700.47, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000009', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000003', '31000000-0000-4000-8000-000000000007', 'Freedom First', '0007406742200001', 'LOC 901 5th', 6342.04, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000010', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', null, 'Freedom First', '0007406912240001', 'LOC R/E 360', 5022.57, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000011', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000009', 'Freedom First', '0007406283140001', 'Business Term 2300 Bedford', 1224.29, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000012', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', null, 'Freedom First', '0007406434220001', '1915 Thomson #1', 3236.68, 'monthly', 'active'),
  ('41000000-0000-4000-8000-000000000013', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000008', 'Freedom First', '0007406492990001', 'LOC 58 9th', 6091.41, 'monthly', 'active')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Recurring loan-payment obligations (derived from the real loan records)
-- ---------------------------------------------------------------------------
insert into obligations (id, organization_id, ownership_entity_id, property_id, loan_id, name, description, category, amount, frequency, interval_months, due_day, next_due_date, status, notes) values
  ('71000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000004', '41000000-0000-4000-8000-000000000001', 'Bus. Term R/E 360 | Thomson #2', 'Monthly loan payment (derived from loan records)', 'loan_payment', 459.9, 'monthly', 1, 15, '2026-08-15', 'open', null),
  ('71000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000012', '41000000-0000-4000-8000-000000000002', '2597/99 Fort', 'Monthly loan payment (derived from loan records)', 'loan_payment', 2879.17, 'monthly', 1, 22, '2026-08-22', 'open', null),
  ('71000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000003', '41000000-0000-4000-8000-000000000003', '309 Hancock', 'Monthly loan payment (derived from loan records)', 'loan_payment', 1710.94, 'monthly', 1, 22, '2026-08-22', 'open', null),
  ('71000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000005', '41000000-0000-4000-8000-000000000004', '313 Hancock', 'Monthly loan payment (derived from loan records)', 'loan_payment', 1664.06, 'monthly', 1, 22, '2026-08-22', 'open', null),
  ('71000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000007', null, '41000000-0000-4000-8000-000000000005', 'LOC DC', 'Monthly loan payment (derived from loan records)', 'loan_payment', 20959.62, 'monthly', 1, 28, '2026-08-28', 'open', null),
  ('71000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', null, '41000000-0000-4000-8000-000000000006', 'LOC JenCal', 'Monthly loan payment (derived from loan records)', 'loan_payment', 1376.33, 'monthly', 1, 30, '2026-08-30', 'open', null),
  ('71000000-0000-4000-8000-000000000007', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000006', '41000000-0000-4000-8000-000000000007', '305 6th | Motor Co', 'Monthly loan payment (derived from loan records)', 'loan_payment', 12345, 'monthly', 1, 15, '2026-08-15', 'open', null),
  ('71000000-0000-4000-8000-000000000008', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', null, '41000000-0000-4000-8000-000000000008', 'LOC PLB', 'Monthly loan payment (derived from loan records)', 'loan_payment', 1700.47, 'monthly', 1, 26, '2026-08-26', 'open', null),
  ('71000000-0000-4000-8000-000000000009', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000003', '31000000-0000-4000-8000-000000000007', '41000000-0000-4000-8000-000000000009', 'LOC 901 5th', 'Monthly loan payment (derived from loan records)', 'loan_payment', 6342.04, 'monthly', 1, 15, '2026-08-15', 'open', null),
  ('71000000-0000-4000-8000-000000000010', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', null, '41000000-0000-4000-8000-000000000010', 'LOC R/E 360', 'Monthly loan payment (derived from loan records)', 'loan_payment', 5022.57, 'monthly', 1, 1, '2026-09-01', 'open', null),
  ('71000000-0000-4000-8000-000000000011', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000009', '41000000-0000-4000-8000-000000000011', 'Business Term 2300 Bedford', 'Monthly loan payment (derived from loan records)', 'loan_payment', 1224.29, 'monthly', 1, 15, '2026-08-15', 'open', null),
  ('71000000-0000-4000-8000-000000000012', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', null, '41000000-0000-4000-8000-000000000012', '1915 Thomson #1', 'Monthly loan payment (derived from loan records)', 'loan_payment', 3236.68, 'monthly', 1, 1, '2026-09-01', 'open', null),
  ('71000000-0000-4000-8000-000000000013', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000008', '41000000-0000-4000-8000-000000000013', 'LOC 58 9th', 'Monthly loan payment (derived from loan records)', 'loan_payment', 6091.41, 'monthly', 1, 1, '2026-09-01', 'open', null)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Quarterly real-estate-tax obligations (derived from the real property tax
-- amounts; Lynchburg bills in quarterly installments due Nov 15, Jan 15,
-- Mar 15, May 15)
-- ---------------------------------------------------------------------------
insert into obligations (id, organization_id, ownership_entity_id, property_id, name, description, category, amount, frequency, installment_months, due_day, next_due_date, status, notes) values
  ('71000000-0000-4000-8000-000000000014', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000002', '31000000-0000-4000-8000-000000000001', 'Palmera House — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 1050, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000015', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000002', 'Tacos2/Stadium District — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 82.01, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000016', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000004', 'Teachable Moments — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 341.25, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000017', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000006', 'Motor Co — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 396.69, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000018', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000003', '31000000-0000-4000-8000-000000000007', '901 5th | Cutting Room — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 162.96, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000019', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000008', 'SuperRad — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 258.83, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000020', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000010', 'Tacos#1 | Old Pizza Hut — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 137.55, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000021', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000011', 'Best Catch — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 192.2, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000022', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000012', 'Tacos #2 Trailer | Storage Building — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 36.23, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000023', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000013', 'Parking Lot — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 58.96, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000024', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000005', '31000000-0000-4000-8000-000000000014', 'Carpet Shop — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 306.81, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000025', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000004', '31000000-0000-4000-8000-000000000015', 'Bee Line — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 76.07, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null),
  ('71000000-0000-4000-8000-000000000026', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000004', '31000000-0000-4000-8000-000000000016', 'Casa Nueva — Real Estate Tax', 'Quarterly real estate tax installment (from property import)', 'tax', 81.64, 'quarterly', '{1,3,5,11}', 15, '2026-11-15', 'open', null)
on conflict (id) do nothing;


-- ---------------------------------------------------------------------------
-- [DEMO] Vendors — replace with real vendors
-- ---------------------------------------------------------------------------
insert into vendors (id, organization_id, name, category, email, phone, active) values
  ('61000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '[DEMO] Apex Commercial Insurance', 'insurance', 'billing@demo-apex.example', '555-0101', true),
  ('61000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '[DEMO] Rockland Power & Light', 'electric', 'accounts@demo-rockland.example', '555-0102', true),
  ('61000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '[DEMO] City Water & Sewer', 'water', 'water@demo-city.example', '555-0103', true),
  ('61000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '[DEMO] Hearthside HVAC', 'maintenance', 'service@demo-hearthside.example', '555-0104', true),
  ('61000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '[DEMO] GreenScape Landscaping', 'maintenance', 'info@demo-greenscape.example', '555-0105', true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- [DEMO] Tenants — replace with real tenants. Responsibility flags record who
-- is contractually on the hook per the lease. Defaults: landlord pays
-- water/HVAC/CAM; tenant pays electric/internet. Exceptions shown: ownership
-- pays Rivera's electric; Maria's Cafe pays its own water; Elm Street Gym
-- pays CAM.
-- ---------------------------------------------------------------------------
insert into tenants (id, organization_id, property_id, name, email, phone, status, responsible_water, responsible_electric, responsible_internet, responsible_hvac, responsible_cam) values
  ('51000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000003', '[DEMO] The Rivera Family', 'demo.rivera@example.com', '555-0201', 'active', false, false, true, false, false),
  ('51000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000006', '[DEMO] Maria''s Cafe', 'demo.marias@example.com', '555-0202', 'active', true, true, true, false, false),
  ('51000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000005', '[DEMO] Bluebird Boutique', 'demo.bluebird@example.com', '555-0203', 'active', false, true, true, false, false),
  ('51000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000016', '[DEMO] Patel Family', 'demo.patel@example.com', '555-0204', 'active', false, true, true, false, false),
  ('51000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000002', '[DEMO] Copper Kettle Diner', 'demo.copper@example.com', '555-0205', 'active', false, true, true, false, false),
  ('51000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000014', '[DEMO] Elm Street Gym', 'demo.elm@example.com', '555-0206', 'active', false, true, true, false, true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- [DEMO] Leases — Google Drive link + term, one per tenant (replace with real)
-- ---------------------------------------------------------------------------
insert into leases (id, organization_id, tenant_id, url, lease_start, lease_end, notes) values
  ('52000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000001', 'https://drive.google.com/file/d/DEMO-RIVERA-LEASE/view', '2025-06-01', '2026-05-31', '[DEMO] lease document'),
  ('52000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000002', 'https://drive.google.com/file/d/DEMO-MARIAS-LEASE/view', '2024-03-15', '2025-03-14', '[DEMO] lease document'),
  ('52000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000003', 'https://drive.google.com/file/d/DEMO-BLUEBIRD-LEASE/view', '2025-09-01', '2026-08-31', '[DEMO] lease document'),
  ('52000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000004', 'https://drive.google.com/file/d/DEMO-PATEL-LEASE/view', '2024-11-01', '2025-10-31', '[DEMO] lease document'),
  ('52000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000005', 'https://drive.google.com/file/d/DEMO-COPPER-LEASE/view', '2023-07-01', '2026-06-30', '[DEMO] lease document'),
  ('52000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000006', 'https://drive.google.com/file/d/DEMO-ELM-LEASE/view', '2025-01-15', '2026-01-14', '[DEMO] lease document')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- [DEMO] Rent schedule — period_end null = current period. Rivera has an intro
-- rate (first 3 months) then base rent, then a CPI bump at renewal; Copper
-- Kettle has a CPI bump too. Replace with real lease terms.
-- ---------------------------------------------------------------------------
insert into rent_schedule (id, organization_id, tenant_id, period_start, period_end, amount, cpi_percent, notes) values
  ('53000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000001', '2025-06-01', '2025-08-31', 1500.00, null, '[DEMO] intro rate — first 3 months'),
  ('53000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000001', '2025-09-01', '2026-05-31', 1700.00, null, '[DEMO] base rent'),
  ('53000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000001', '2026-06-01', null, 1742.50, 2.500, '[DEMO] CPI applied at renewal'),
  ('53000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000002', '2024-04-01', null, 13000.00, null, null),
  ('53000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000003', '2025-09-01', null, 1600.00, null, null),
  ('53000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000004', '2024-11-01', '2025-03-31', 2200.00, null, '[DEMO] intro rate — first 5 months'),
  ('53000000-0000-4000-8000-000000000007', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000004', '2025-04-01', null, 2400.00, null, null),
  ('53000000-0000-4000-8000-000000000008', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000005', '2023-07-01', '2026-06-30', 1850.00, null, null),
  ('53000000-0000-4000-8000-000000000009', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000005', '2026-07-01', null, 1905.50, 3.000, '[DEMO] CPI applied'),
  ('53000000-0000-4000-8000-000000000010', '11000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000006', '2025-01-15', null, 3200.00, null, null)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- [DEMO] Recurring obligations — replace with real bills
-- ---------------------------------------------------------------------------
-- Ownership pays Rivera's electric bill on their behalf, so the obligation is
-- linked to the tenant as well as the property for visibility.
insert into obligations (id, organization_id, ownership_entity_id, property_id, vendor_id, tenant_id, name, description, category, amount, frequency, interval_months, due_day, weekday, nth_occurrence, next_due_date, status, variable_amount, notes) values
  ('71000000-0000-4000-8000-000000000027', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000003', '61000000-0000-4000-8000-000000000002', '51000000-0000-4000-8000-000000000001', '[DEMO] Electric — 309 Hancock', 'Monthly electric service (dummy)', 'electric', 180.00, 'monthly', 1, 20, null, null, '2026-08-20', 'open', true, null),
  ('71000000-0000-4000-8000-000000000028', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000006', '61000000-0000-4000-8000-000000000003', null, '[DEMO] Water & Sewer — Motor Co', 'Monthly water/sewer due the 2nd-to-last Wednesday', 'water', 95.00, 'monthly', 1, null, 3, -2, '2026-08-19', 'open', true, null),
  ('71000000-0000-4000-8000-000000000029', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000004', null, '[DEMO] HVAC Maintenance — Tacos2', 'Monthly HVAC maintenance (dummy)', 'maintenance', 120.00, 'monthly', 1, 25, null, null, '2026-08-25', 'open', false, null),
  ('71000000-0000-4000-8000-000000000030', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000004', '61000000-0000-4000-8000-000000000001', null, '[DEMO] Liability Insurance — Teachable Moments', 'Annual liability policy (dummy)', 'insurance', 2400.00, 'annual', null, 15, null, null, '2026-10-15', 'open', false, null)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- [DEMO] Billbacks — replace with real cross-entity reimbursements
-- ---------------------------------------------------------------------------
insert into billbacks (id, organization_id, from_ownership_entity_id, to_ownership_entity_id, description, amount, status, issued_date, due_date, notes) values
  ('81000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '21000000-0000-4000-8000-000000000001', '[DEMO] Reimburse roofing deposit at 58 9th St (PLB paid for JenCal)', 1500.00, 'outstanding', '2026-07-20', '2026-08-20', null),
  ('81000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '21000000-0000-4000-8000-000000000004', '[DEMO] Shared snow removal (PLB paid for Casa Nueva)', 400.00, 'outstanding', '2026-07-25', '2026-09-01', null)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- [DEMO] Payments — a little history so the log is not empty. Payment 3 is a
-- cross-entity example: JenCal funded PLB's water bill.
-- ---------------------------------------------------------------------------
insert into payments (id, organization_id, obligation_id, ownership_entity_id, billback_id, amount, paid_date, method, reference, notes) values
  ('91000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000027', '21000000-0000-4000-8000-000000000006', null, 180.00, '2026-07-20', 'Check', 'DEMO-001', null),
  ('91000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000029', '21000000-0000-4000-8000-000000000006', null, 120.00, '2026-06-25', 'Check', 'DEMO-002', null),
  ('91000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000028', '21000000-0000-4000-8000-000000000001', null, 95.00, '2026-07-12', 'ACH', 'DEMO-003', 'Cross-entity example: JenCal funded PLB water bill')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Replace the [DEMO] rows with real data, then remove the demo rows:
--
--   delete from payments  where reference like 'DEMO-%';
--   delete from billbacks where description like '[DEMO]%';
--   delete from obligations where name like '[DEMO]%';
--   delete from rent_schedule where tenant_id in (select id from tenants where name like '[DEMO]%');
--   delete from leases where tenant_id in (select id from tenants where name like '[DEMO]%');
--   delete from tenants  where name like '[DEMO]%';
--   delete from vendors  where name like '[DEMO]%';
-- ---------------------------------------------------------------------------
