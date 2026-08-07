-- seed.sql — idempotent baseline for the DCX organization.
--
-- Data sources (exported 2026-08-03, imported into this file):
--   * ownership entities CSV            -> 7 real entities
--   * properties CSV                    -> 16 real properties (name = address, nickname = short name)
--   * loans CSV                         -> 13 real loans (monthly payment = interest + principal)
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
insert into ownership_entities (id, organization_id, name, entity_type, status) values
  ('21000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'JenCal LLC', 'llc', 'active'),
  ('21000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', 'Fritts Price LLC', 'llc', 'active'),
  ('21000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '901 5th St LLC', 'llc', 'active'),
  ('21000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', 'Casa Nueva LLC', 'llc', 'active'),
  ('21000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', 'Calfee & Barney LLC', 'llc', 'active'),
  ('21000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', 'PLB LLC', 'llc', 'active'),
  ('21000000-0000-4000-8000-000000000007', '11000000-0000-4000-8000-000000000001', 'Daryl W Calfee', 'individual', 'active')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Properties (16 real — from properties CSV; name = address, nickname = short name)
-- ---------------------------------------------------------------------------
insert into properties (id, organization_id, ownership_entity_id, name, nickname, address1, city, state, zip, property_type, unit_count, status, notes) values
  ('31000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000002', '2307 Bedford Ave', 'Palmera House', '2307 Bedford Ave', 'Lynchburg', 'VA', '24503', 'residential', 1, 'active', 'Annual real estate tax 4200 (from property import)'),
  ('31000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '2599 Fort Ave', 'Tacos2/Stadium District', '2599 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 1, 'active', 'Annual real estate tax 328.02 (from property import)'),
  ('31000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '309 Hancock St', '309 Hancock', '309 Hancock St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', null),
  ('31000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '1915 Thomson Dr', 'Teachable Moments', '1915 Thomson Dr', 'Lynchburg', 'VA', '24501', 'commercial', 1, 'active', 'Annual real estate tax 1365 (from property import)'),
  ('31000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '313 Hancock St', '313 Hancock', '313 Hancock St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', null),
  ('31000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '305 6th St', 'Motor Co', '305 6th St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', 'Annual real estate tax 1586.76 (from property import)'),
  ('31000000-0000-4000-8000-000000000007', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000003', '901 Fifth St', '901 5th | Cutting Room', '901 Fifth St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', 'Annual real estate tax 651.84 (from property import)'),
  ('31000000-0000-4000-8000-000000000008', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '58 9th St', 'SuperRad', '58 9th St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', 'Annual real estate tax 1035.3 (from property import)'),
  ('31000000-0000-4000-8000-000000000009', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '2300 Bedford Ave', 'PLB Shop/Marshroots', '2300 Bedford Ave', 'Lynchburg', 'VA', '24503', 'commercial', 0, 'active', null),
  ('31000000-0000-4000-8000-000000000010', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '2309 Bedford Ave', 'Tacos#1 | Old Pizza Hut', '2309 Bedford Ave', 'Lynchburg', 'VA', '24503', 'commercial', 1, 'active', 'Annual real estate tax 550.2 (from property import)'),
  ('31000000-0000-4000-8000-000000000011', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '2603 Fort Ave', 'Best Catch', '2603 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 0, 'active', 'Annual real estate tax 768.81 (from property import)'),
  ('31000000-0000-4000-8000-000000000012', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '2597 Fort Ave', 'Tacos #2 Trailer | Storage Building', '2597 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 0, 'active', 'Annual real estate tax 144.9 (from property import)'),
  ('31000000-0000-4000-8000-000000000013', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '309 6th St', 'Parking Lot', '309 6th St', 'Lynchburg', 'VA', '24504', 'commercial', 0, 'active', 'Annual real estate tax 235.83 (from property import)'),
  ('31000000-0000-4000-8000-000000000014', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000005', '5900 Fort Ave', 'Carpet Shop', '5900 Fort Ave', 'Lynchburg', 'VA', '24502', 'commercial', 0, 'active', 'Annual real estate tax 1227.24 (from property import)'),
  ('31000000-0000-4000-8000-000000000015', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000004', '2999 Fort Ave', 'Bee Line', '2999 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 0, 'active', 'Annual real estate tax 304.29 (from property import)'),
  ('31000000-0000-4000-8000-000000000016', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000004', '2995 Fort Ave', 'Casa Nueva', '2995 Fort Ave', 'Lynchburg', 'VA', '24501', 'commercial', 1, 'active', 'Annual real estate tax 326.55 (from property import)')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Loans (13 real — from loans CSV; nickname kept in notes, payment = interest + principal)
-- ---------------------------------------------------------------------------
insert into loans (id, organization_id, ownership_entity_id, property_id, lender, loan_number, monthly_payment, payment_frequency, status, notes) values
  ('41000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000004', 'Freedom First', '0007406434220002', 459.9, 'monthly', 'active', 'nickname: Bus. Term R/E 360 | Thomson #2'),
  ('41000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000012', 'Pinnacle', '90865277', 2879.17, 'monthly', 'active', 'nickname: 2597/99 Fort'),
  ('41000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000003', 'Pinnacle', '90870210', 1710.94, 'monthly', 'active', 'nickname: 309 Hancock'),
  ('41000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000005', 'Pinnacle', '90870211', 1664.06, 'monthly', 'active', 'nickname: 313 Hancock'),
  ('41000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000007', null, 'Pinnacle', '20231236720', 20959.62, 'monthly', 'active', 'nickname: LOC DC'),
  ('41000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', null, 'Pinnacle', '90850703', 1376.33, 'monthly', 'active', 'nickname: LOC JenCal'),
  ('41000000-0000-4000-8000-000000000007', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000006', 'Pinnacle', '90610425', 12345, 'monthly', 'active', 'nickname: 305 6th | Motor Co'),
  ('41000000-0000-4000-8000-000000000008', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', null, 'Pinnacle', '90840959', 1700.47, 'monthly', 'active', 'nickname: LOC PLB'),
  ('41000000-0000-4000-8000-000000000009', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000003', '31000000-0000-4000-8000-000000000007', 'Freedom First', '0007406742200001', 6342.04, 'monthly', 'active', 'nickname: LOC 901 5th'),
  ('41000000-0000-4000-8000-000000000010', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', null, 'Freedom First', '0007406912240001', 5022.57, 'monthly', 'active', 'nickname: LOC R/E 360'),
  ('41000000-0000-4000-8000-000000000011', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000009', 'Freedom First', '0007406283140001', 1224.29, 'monthly', 'active', 'nickname: Business Term 2300 Bedford'),
  ('41000000-0000-4000-8000-000000000012', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', null, 'Freedom First', '0007406434220001', 3236.68, 'monthly', 'active', 'nickname: 1915 Thomson #1'),
  ('41000000-0000-4000-8000-000000000013', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000008', 'Freedom First', '0007406492990001', 6091.41, 'monthly', 'active', 'nickname: LOC 58 9th')
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
-- Annual real-estate-tax obligations (derived from the real property tax amounts)
-- ---------------------------------------------------------------------------
insert into obligations (id, organization_id, ownership_entity_id, property_id, name, description, category, amount, frequency, due_day, next_due_date, status, notes) values
  ('71000000-0000-4000-8000-000000000014', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000002', '31000000-0000-4000-8000-000000000001', 'Palmera House — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 4200, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000015', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000002', 'Tacos2/Stadium District — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 328.02, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000016', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000004', 'Teachable Moments — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 1365, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000017', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000006', 'Motor Co — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 1586.76, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000018', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000003', '31000000-0000-4000-8000-000000000007', '901 5th | Cutting Room — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 651.84, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000019', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000008', 'SuperRad — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 1035.3, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000020', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000010', 'Tacos#1 | Old Pizza Hut — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 550.2, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000021', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000011', 'Best Catch — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 768.81, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000022', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000012', 'Tacos #2 Trailer | Storage Building — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 144.9, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000023', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000013', 'Parking Lot — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 235.83, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000024', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000005', '31000000-0000-4000-8000-000000000014', 'Carpet Shop — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 1227.24, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000025', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000004', '31000000-0000-4000-8000-000000000015', 'Bee Line — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 304.29, 'annual', 5, '2026-12-05', 'open', null),
  ('71000000-0000-4000-8000-000000000026', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000004', '31000000-0000-4000-8000-000000000016', 'Casa Nueva — Real Estate Tax', 'Annual real estate tax (from property import)', 'tax', 326.55, 'annual', 5, '2026-12-05', 'open', null)
on conflict (id) do nothing;


-- ---------------------------------------------------------------------------
-- [DEMO] Vendors — replace with real vendors
-- ---------------------------------------------------------------------------
insert into vendors (id, organization_id, name, category, email, phone, active) values
  ('61000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '[DEMO] Apex Commercial Insurance', 'insurance', 'billing@demo-apex.example', '555-0101', true),
  ('61000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '[DEMO] Rockland Power & Light', 'utility', 'accounts@demo-rockland.example', '555-0102', true),
  ('61000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '[DEMO] City Water & Sewer', 'utility', 'water@demo-city.example', '555-0103', true),
  ('61000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '[DEMO] Hearthside HVAC', 'maintenance', 'service@demo-hearthside.example', '555-0104', true),
  ('61000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '[DEMO] GreenScape Landscaping', 'maintenance', 'info@demo-greenscape.example', '555-0105', true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- [DEMO] Tenants — replace with real tenants
-- ---------------------------------------------------------------------------
insert into tenants (id, organization_id, property_id, name, email, phone, status, move_in_date) values
  ('51000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000003', '[DEMO] The Rivera Family', 'demo.rivera@example.com', '555-0201', 'active', '2025-06-01'),
  ('51000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000006', '[DEMO] Maria''s Cafe', 'demo.marias@example.com', '555-0202', 'active', '2024-03-15'),
  ('51000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000005', '[DEMO] Bluebird Boutique', 'demo.bluebird@example.com', '555-0203', 'active', '2025-09-01'),
  ('51000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000016', '[DEMO] Patel Family', 'demo.patel@example.com', '555-0204', 'active', '2024-11-01'),
  ('51000000-0000-4000-8000-000000000005', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000002', '[DEMO] Copper Kettle Diner', 'demo.copper@example.com', '555-0205', 'active', '2023-07-01'),
  ('51000000-0000-4000-8000-000000000006', '11000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000014', '[DEMO] Elm Street Gym', 'demo.elm@example.com', '555-0206', 'active', '2025-01-15')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- [DEMO] Recurring obligations — replace with real bills
-- ---------------------------------------------------------------------------
insert into obligations (id, organization_id, ownership_entity_id, property_id, vendor_id, name, description, category, amount, frequency, interval_months, due_day, weekday, nth_occurrence, next_due_date, status, notes) values
  ('71000000-0000-4000-8000-000000000027', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000003', '61000000-0000-4000-8000-000000000002', '[DEMO] Electric — 309 Hancock', 'Monthly electric service (dummy)', 'utility', 180.00, 'monthly', 1, 20, null, null, '2026-08-20', 'open', null),
  ('71000000-0000-4000-8000-000000000028', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000006', '61000000-0000-4000-8000-000000000003', '[DEMO] Water & Sewer — Motor Co', 'Monthly water/sewer due the 2nd-to-last Wednesday', 'utility', 95.00, 'monthly', 1, null, 3, -2, '2026-08-19', 'open', null),
  ('71000000-0000-4000-8000-000000000029', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000002', '61000000-0000-4000-8000-000000000004', '[DEMO] HVAC Maintenance — Tacos2', 'Monthly HVAC maintenance (dummy)', 'maintenance', 120.00, 'monthly', 1, 25, null, null, '2026-08-25', 'open', null),
  ('71000000-0000-4000-8000-000000000030', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000006', '31000000-0000-4000-8000-000000000004', '61000000-0000-4000-8000-000000000001', '[DEMO] Liability Insurance — Teachable Moments', 'Annual liability policy (dummy)', 'insurance', 2400.00, 'annual', null, 15, null, null, '2026-10-15', 'open', null)
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
--   delete from tenants  where name like '[DEMO]%';
--   delete from vendors  where name like '[DEMO]%';
-- ---------------------------------------------------------------------------
