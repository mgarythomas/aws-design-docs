-- =============================================================================
-- Issuer reference data model: a listed company (or other issuer) on the exchange
--
-- Depends on : instrument_reference_model.sql, applied first. It provides the ref
--              domains, ref.governing_framework, ref.obligation_ref, core.instrument
--              and the core.enforce_bitemporal_append_only() trigger function.
-- Target     : PostgreSQL 14+
--
-- Layout
--   party.*   legal entity master: identity, names, identifiers, addresses, group
--             structure, service providers, people and officer appointments.
--             Reusable for any legal entity (auditors, registries, later participants).
--   issuer.*  the issuer role played by a legal entity: issuer attributes,
--             classification, admission status under a governing framework,
--             nominated exchange contacts and the link to issued instruments.
--
-- Modelling notes (grounded in the ASX Listing Rules, verify against the current text)
--   * Admission to the official list and removal from it are ENTITY level facts
--     (issuer.issuer_status). Quotation and suspension of securities are SECURITY
--     level facts and already live in core.listing_status. A trading halt is a
--     session state, not a status, and is not modelled here.
--   * Entities admitted to the official list fall into ASX Listing, ASX Debt Listing
--     or ASX Foreign Exempt Listing (ref.listing_category).
--   * An entity must always have a person responsible for communication with the
--     exchange (Listing Rule 12.6) and may nominate more than one. See
--     issuer.nominated_exchange_contact and the coverage view at the end.
--   * For a trust the directors, CEO and CFO that matter are those of the
--     responsible entity. Model that as party.entity_service_provider with role
--     RESPONSIBLE_ENTITY and hang officer appointments on the responsible entity.
--   * A stapled security can have more than one issuer, so issuer.instrument_issuer
--     allows several issuer links per instrument.
--
-- Conventions are the same as the instrument model: surrogate UUID keys, bitemporal
-- valid_range and recorded_range, append-only history, maker-checker approval.
--
-- Personal data: names, business email and phone of natural persons live only in
-- party.person, which is a normal mutable table so it can be corrected or erased.
-- Every history table refers to a person by person_id alone.
--
-- Seed values in ref.* are illustrative and must be aligned with the operator's own
-- vocabulary and the current rulebooks. GLEIF and ISO 20022 annotations at the end
-- are indicative and must be verified.
-- =============================================================================

create extension if not exists btree_gist;

create schema if not exists party;
create schema if not exists issuer;

-- -----------------------------------------------------------------------------
-- ref: vocabularies held as data
-- -----------------------------------------------------------------------------
create table ref.entity_identifier_scheme (
  scheme        text primary key,
  description   text not null,
  value_pattern text
);

create table ref.legal_form (
  legal_form_code text primary key,
  description     text not null,
  iso20275_code   text
);

create table ref.entity_registration_status (
  status_code text primary key,
  is_terminal boolean not null default false,
  description text not null
);

create table ref.entity_relationship_type (
  relationship_type text primary key,
  description       text not null
);

create table ref.entity_service_role (
  service_role text primary key,
  description  text not null
);

create table ref.officer_role_type (
  role_type   text primary key,
  description text not null
);

create table ref.classification_scheme (
  scheme      text primary key,
  description text not null
);

create table ref.listing_category (
  listing_category text primary key,
  description      text not null
);

create table ref.instrument_party_role (
  party_role  text primary key,
  description text not null
);

create table ref.issuer_status_code (
  governing_framework text not null references ref.governing_framework,
  status_code         text not null,
  is_terminal         boolean not null default false,
  description         text,
  primary key (governing_framework, status_code)
);

insert into ref.entity_identifier_scheme values
  ('LEI',      'ISO 17442 legal entity identifier',             '^[A-Z0-9]{18}[0-9]{2}$'),
  ('ABN',      'Australian Business Number',                    '^[0-9]{11}$'),
  ('ACN',      'Australian Company Number',                     '^[0-9]{9}$'),
  ('ARBN',     'Australian Registered Body Number',             '^[0-9]{9}$'),
  ('INTERNAL', 'Internal operator identifier',                  null);

insert into ref.legal_form values
  ('PUBLIC_COMPANY',            'Public company',                            null),
  ('PROPRIETARY_COMPANY',       'Proprietary company',                       null),
  ('FOREIGN_COMPANY',           'Company incorporated outside the jurisdiction', null),
  ('TRUST',                     'Trust',                                     null),
  ('MANAGED_INVESTMENT_SCHEME', 'Registered managed investment scheme',      null),
  ('PARTNERSHIP',               'Partnership',                               null),
  ('OTHER',                     'Other legal form',                          null);

insert into ref.entity_registration_status values
  ('ACTIVE',            false, 'Registered and active'),
  ('IN_ADMINISTRATION', false, 'Under administration'),
  ('IN_LIQUIDATION',    false, 'In liquidation'),
  ('DEREGISTERED',      true,  'Deregistered or dissolved');

insert into ref.entity_relationship_type values
  ('DIRECT_PARENT',   'Direct accounting consolidating parent'),
  ('ULTIMATE_PARENT', 'Ultimate accounting consolidating parent');

insert into ref.entity_service_role values
  ('AUDITOR',            'External auditor'),
  ('SHARE_REGISTRY',     'Securities registry'),
  ('RESPONSIBLE_ENTITY', 'Responsible entity of a trust or scheme'),
  ('TRUSTEE',            'Trustee or custodian');

insert into ref.officer_role_type values
  ('DIRECTOR',                'Director'),
  ('CHAIR',                   'Chair of the board'),
  ('CHIEF_EXECUTIVE',         'Chief executive officer'),
  ('CHIEF_FINANCIAL_OFFICER', 'Chief financial officer'),
  ('COMPANY_SECRETARY',       'Company secretary');

insert into ref.classification_scheme values
  ('GICS',   'Global Industry Classification Standard (licensed, codes are not seeded here)'),
  ('ANZSIC', 'Australian and New Zealand Standard Industrial Classification');

insert into ref.listing_category values
  ('ASX_LISTING',               'Standard listing under the Listing Rules'),
  ('ASX_DEBT_LISTING',          'Listing of debt securities only'),
  ('ASX_FOREIGN_EXEMPT_LISTING','Secondary listing of a foreign entity, exempt from most Listing Rules');

insert into ref.instrument_party_role values
  ('ISSUER',             'Issuer of the instrument'),
  ('RESPONSIBLE_ENTITY', 'Responsible entity of a scheme'),
  ('INVESTMENT_MANAGER', 'Investment manager'),
  ('TRUSTEE',            'Trustee');

insert into ref.issuer_status_code (governing_framework, status_code, is_terminal, description)
select f.governing_framework, s.code, s.terminal, s.descr
from ref.governing_framework f
cross join (values
  ('PROPOSED', false, 'Application received'),
  ('APPROVED', false, 'Approved but not yet admitted'),
  ('ADMITTED', false, 'Admitted'),
  ('REMOVED',  true,  'Removed')
) as s(code, terminal, descr)
where f.governing_framework in ('LISTING_RULES', 'AQUA_RULES');

-- -----------------------------------------------------------------------------
-- party: legal entity master
-- -----------------------------------------------------------------------------
create function party.check_identifier_pattern() returns trigger
language plpgsql as $$
declare
  v_pattern text;
begin
  select value_pattern into v_pattern from ref.entity_identifier_scheme where scheme = new.scheme;
  if v_pattern is not null and new.id_value !~ v_pattern then
    raise exception 'identifier % does not match the pattern for scheme %', new.id_value, new.scheme
      using errcode = '23514';
  end if;
  return new;
end $$;

create table party.legal_entity (
  entity_id  uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table party.legal_entity_version (
  entity_version_id   uuid primary key default gen_random_uuid(),
  entity_id           uuid not null references party.legal_entity,
  valid_range         daterange not null check (not isempty(valid_range)),
  recorded_range      tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  legal_form_code     text references ref.legal_form,
  jurisdiction        ref.country_code not null,
  incorporation_date  date,
  registration_status text not null references ref.entity_registration_status,
  ext                 jsonb not null default '{}'::jsonb check (jsonb_typeof(ext) = 'object'),
  source_system       text not null,
  recorded_by         text not null,
  approval_status     text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by         text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  constraint legal_entity_version_no_overlap
    exclude using gist (entity_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);
create index legal_entity_version_entity_idx on party.legal_entity_version (entity_id);

create table party.entity_name (
  entity_name_id  uuid primary key default gen_random_uuid(),
  entity_id       uuid not null references party.legal_entity,
  name_type       text not null check (name_type in ('LEGAL', 'TRADING', 'FORMER', 'SHORT')),
  name            text not null check (btrim(name) <> ''),
  valid_range     daterange not null check (not isempty(valid_range)),
  recorded_range  tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system   text not null,
  recorded_by     text not null,
  approval_status text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by     text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  -- one legal name and one short name at a time. Trading and former names can repeat.
  constraint entity_name_single_legal_and_short
    exclude using gist (entity_id with =, name_type with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED' and name_type in ('LEGAL', 'SHORT'))
);
create index entity_name_entity_idx on party.entity_name (entity_id);

create table party.entity_identifier (
  identifier_id  uuid primary key default gen_random_uuid(),
  entity_id      uuid not null references party.legal_entity,
  scheme         text not null references ref.entity_identifier_scheme,
  id_value       text not null,
  valid_range    daterange not null check (not isempty(valid_range)),
  recorded_range tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system  text not null,
  -- an identifier value belongs to at most one entity at any point in valid and recorded time
  constraint entity_identifier_no_overlap
    exclude using gist (scheme with =, id_value with =, valid_range with &&, recorded_range with &&)
);
create index entity_identifier_entity_idx on party.entity_identifier (entity_id);
create trigger entity_identifier_pattern
  before insert on party.entity_identifier
  for each row execute function party.check_identifier_pattern();

create table party.entity_address (
  address_id      uuid primary key default gen_random_uuid(),
  entity_id       uuid not null references party.legal_entity,
  address_type    text not null check (address_type in ('REGISTERED_OFFICE', 'PRINCIPAL_PLACE_OF_BUSINESS', 'POSTAL')),
  line_1          text not null,
  line_2          text,
  locality        text not null,
  region          text,
  postal_code     text,
  country         ref.country_code not null,
  valid_range     daterange not null check (not isempty(valid_range)),
  recorded_range  tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system   text not null,
  recorded_by     text not null,
  approval_status text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by     text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  constraint entity_address_one_per_type
    exclude using gist (entity_id with =, address_type with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);
create index entity_address_entity_idx on party.entity_address (entity_id);

-- Group structure, seen from the child. Joint ventures with several direct parents are not
-- representable, which matches the single consolidating parent used in LEI relationship data.
create table party.entity_relationship (
  relationship_id   uuid primary key default gen_random_uuid(),
  child_entity_id   uuid not null references party.legal_entity,
  parent_entity_id  uuid not null references party.legal_entity,
  relationship_type text not null references ref.entity_relationship_type,
  ownership_percent numeric(7, 4) check (ownership_percent between 0 and 100),
  valid_range       daterange not null check (not isempty(valid_range)),
  recorded_range    tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system     text not null,
  recorded_by       text not null,
  approval_status   text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by       text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  check (child_entity_id <> parent_entity_id),
  constraint entity_relationship_one_parent_per_type
    exclude using gist (child_entity_id with =, relationship_type with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);
create index entity_relationship_parent_idx on party.entity_relationship (parent_entity_id);

create table party.entity_service_provider (
  service_id         uuid primary key default gen_random_uuid(),
  client_entity_id   uuid not null references party.legal_entity,
  provider_entity_id uuid not null references party.legal_entity,
  service_role       text not null references ref.entity_service_role,
  valid_range        daterange not null check (not isempty(valid_range)),
  recorded_range     tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system      text not null,
  recorded_by        text not null,
  approval_status    text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by        text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  check (client_entity_id <> provider_entity_id),
  constraint entity_service_provider_no_overlap
    exclude using gist (client_entity_id with =, provider_entity_id with =, service_role with =,
                        valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);
create index entity_service_provider_provider_idx on party.entity_service_provider (provider_entity_id);

-- The only table that holds personal data. Mutable on purpose so it can be corrected or erased.
create table party.person (
  person_id      uuid primary key default gen_random_uuid(),
  full_name      text not null check (btrim(full_name) <> ''),
  business_email text,
  business_phone text,
  created_at     timestamptz not null default now()
);
comment on table party.person is
  'Personal data of natural persons. Keep the minimum needed. History tables reference person_id only so this table can be corrected or erased without touching append-only history.';

create table party.officer_appointment (
  appointment_id  uuid primary key default gen_random_uuid(),
  entity_id       uuid not null references party.legal_entity,
  person_id       uuid not null references party.person,
  role_type       text not null references ref.officer_role_type,
  valid_range     daterange not null check (not isempty(valid_range)),   -- appointment to cessation
  recorded_range  tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system   text not null,
  recorded_by     text not null,
  approval_status text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by     text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  constraint officer_appointment_no_overlap
    exclude using gist (entity_id with =, person_id with =, role_type with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);
create index officer_appointment_entity_idx on party.officer_appointment (entity_id);
create index officer_appointment_person_idx on party.officer_appointment (person_id);

-- -----------------------------------------------------------------------------
-- issuer: the issuer role and its relationship with the exchange
-- -----------------------------------------------------------------------------
create table issuer.issuer (
  issuer_id  uuid primary key default gen_random_uuid(),
  entity_id  uuid not null unique references party.legal_entity,
  created_at timestamptz not null default now()
);

create table issuer.issuer_version (
  issuer_version_id         uuid primary key default gen_random_uuid(),
  issuer_id                 uuid not null references issuer.issuer,
  valid_range               daterange not null check (not isempty(valid_range)),
  recorded_range            tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  reporting_currency        ref.currency_code,
  financial_year_end_month  smallint check (financial_year_end_month between 1 and 12),
  financial_year_end_day    smallint check (financial_year_end_day between 1 and 31),
  home_exchange_mic         ref.mic_code,          -- relevant to foreign exempt listings
  principal_activities      text,
  website_url               text check (website_url ~ '^https?://'),
  ext                       jsonb not null default '{}'::jsonb check (jsonb_typeof(ext) = 'object'),
  source_system             text not null,
  recorded_by               text not null,
  approval_status           text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by               text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  check ((financial_year_end_month is null) = (financial_year_end_day is null)),
  constraint issuer_version_no_overlap
    exclude using gist (issuer_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);
create index issuer_version_issuer_idx on issuer.issuer_version (issuer_id);

create table issuer.issuer_classification (
  classification_id uuid primary key default gen_random_uuid(),
  issuer_id         uuid not null references issuer.issuer,
  scheme            text not null references ref.classification_scheme,
  code              text not null,
  valid_range       daterange not null check (not isempty(valid_range)),
  recorded_range    tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system     text not null,
  constraint issuer_classification_one_per_scheme
    exclude using gist (issuer_id with =, scheme with =, valid_range with &&, recorded_range with &&)
);
create index issuer_classification_issuer_idx on issuer.issuer_classification (issuer_id);

-- Admission to, and removal from, the official list, per governing framework.
create table issuer.issuer_status (
  issuer_status_id    uuid primary key default gen_random_uuid(),
  issuer_id           uuid not null references issuer.issuer,
  governing_framework text not null,
  status_code         text not null,
  listing_category    text references ref.listing_category,
  reason              text,
  authority_ref_id    uuid references ref.obligation_ref,
  valid_range         daterange not null check (not isempty(valid_range)),
  recorded_range      tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system       text not null,
  recorded_by         text not null,
  approval_status     text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by         text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  -- listing categories belong to the Listing Rules only
  check (listing_category is null or governing_framework = 'LISTING_RULES'),
  foreign key (governing_framework, status_code)
    references ref.issuer_status_code (governing_framework, status_code),
  constraint issuer_status_one_per_framework
    exclude using gist (issuer_id with =, governing_framework with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);
create index issuer_status_issuer_idx on issuer.issuer_status (issuer_id);

-- The person or persons responsible for communication with the exchange. Not necessarily an officer.
create table issuer.nominated_exchange_contact (
  contact_id                   uuid primary key default gen_random_uuid(),
  issuer_id                    uuid not null references issuer.issuer,
  person_id                    uuid not null references party.person,
  is_primary                   boolean not null default false,
  compliance_course_completed_on date,
  valid_range                  daterange not null check (not isempty(valid_range)),
  recorded_range               tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system                text not null,
  recorded_by                  text not null,
  approval_status              text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by                  text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  constraint nominated_contact_no_overlap
    exclude using gist (issuer_id with =, person_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED'),
  constraint nominated_contact_one_primary
    exclude using gist (issuer_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED' and is_primary)
);
create index nominated_contact_issuer_idx on issuer.nominated_exchange_contact (issuer_id);

-- Which issuer(s) issued an instrument. Several links per instrument are allowed, for example
-- the entities behind a stapled security.
create table issuer.instrument_issuer (
  instrument_issuer_id uuid primary key default gen_random_uuid(),
  instrument_id        uuid not null references core.instrument,
  issuer_id            uuid not null references issuer.issuer,
  party_role           text not null references ref.instrument_party_role,
  valid_range          daterange not null check (not isempty(valid_range)),
  recorded_range       tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system        text not null,
  constraint instrument_issuer_no_overlap
    exclude using gist (instrument_id with =, issuer_id with =, party_role with =,
                        valid_range with &&, recorded_range with &&)
);
create index instrument_issuer_issuer_idx on issuer.instrument_issuer (issuer_id);
create index instrument_issuer_instrument_idx on issuer.instrument_issuer (instrument_id);

-- -----------------------------------------------------------------------------
-- Append-only enforcement on every versioned table
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'party.legal_entity_version', 'party.entity_name', 'party.entity_identifier', 'party.entity_address',
    'party.entity_relationship', 'party.entity_service_provider', 'party.officer_appointment',
    'issuer.issuer_version', 'issuer.issuer_classification', 'issuer.issuer_status',
    'issuer.nominated_exchange_contact', 'issuer.instrument_issuer'
  ] loop
    execute format(
      'create trigger %I before update or delete on %s for each row execute function core.enforce_bitemporal_append_only()',
      replace(t, '.', '_') || '_append_only', t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- Views for common compliance questions (all evaluated as at today and now)
-- -----------------------------------------------------------------------------
create view issuer.v_issuer_current as
select i.issuer_id, i.entity_id,
       n.name as legal_name,
       ev.registration_status,
       s.governing_framework, s.status_code, s.listing_category
from issuer.issuer i
left join party.entity_name n
  on n.entity_id = i.entity_id and n.name_type = 'LEGAL' and n.approval_status = 'APPROVED'
 and n.valid_range @> current_date and n.recorded_range @> now()
left join party.legal_entity_version ev
  on ev.entity_id = i.entity_id and ev.approval_status = 'APPROVED'
 and ev.valid_range @> current_date and ev.recorded_range @> now()
left join issuer.issuer_status s
  on s.issuer_id = i.issuer_id and s.approval_status = 'APPROVED'
 and s.valid_range @> current_date and s.recorded_range @> now();

-- Admitted issuers with no current nominated exchange contact. Filter on listing_category if the
-- requirement does not apply to some categories, for example foreign exempt listings.
create view issuer.v_admitted_issuers_without_nominated_contact as
select i.issuer_id, s.listing_category
from issuer.issuer i
join issuer.issuer_status s
  on s.issuer_id = i.issuer_id and s.governing_framework = 'LISTING_RULES' and s.status_code = 'ADMITTED'
 and s.approval_status = 'APPROVED' and s.valid_range @> current_date and s.recorded_range @> now()
where not exists (
  select 1 from issuer.nominated_exchange_contact c
  where c.issuer_id = i.issuer_id and c.approval_status = 'APPROVED'
    and c.valid_range @> current_date and c.recorded_range @> now());

-- Instruments whose ISO 20022 issuer LEI has no matching issuer link. Covers a missing link
-- and a link to an issuer with a different LEI.
create view issuer.v_instrument_issuer_lei_mismatch as
with cur as (
  select instrument_id, issuer_lei from core.instrument_as_of(current_date) where issuer_lei is not null
), linked as (
  select ii.instrument_id, ei.id_value as lei
  from issuer.instrument_issuer ii
  join issuer.issuer i on i.issuer_id = ii.issuer_id
  join party.entity_identifier ei
    on ei.entity_id = i.entity_id and ei.scheme = 'LEI'
   and ei.valid_range @> current_date and ei.recorded_range @> now()
  where ii.party_role = 'ISSUER' and ii.valid_range @> current_date and ii.recorded_range @> now()
)
select c.instrument_id, c.issuer_lei as instrument_lei
from cur c
where not exists (select 1 from linked l where l.instrument_id = c.instrument_id and l.lei = c.issuer_lei);

-- -----------------------------------------------------------------------------
-- Traceability (indicative GLEIF LEI-CDF and ISO 20022 paths, verify before relying on them)
-- -----------------------------------------------------------------------------
comment on column party.entity_name.name                          is 'LEI-CDF: Entity/LegalName (name_type LEGAL) and Entity/OtherEntityNames';
comment on column party.legal_entity_version.jurisdiction         is 'LEI-CDF: Entity/LegalJurisdiction';
comment on column party.legal_entity_version.legal_form_code      is 'LEI-CDF: Entity/LegalForm (ISO 20275 entity legal form)';
comment on column party.legal_entity_version.registration_status  is 'LEI-CDF: Entity/EntityStatus (mapped, values differ)';
comment on column party.entity_address.address_type               is 'LEI-CDF: Entity/LegalAddress and Entity/HeadquartersAddress';
comment on column party.entity_relationship.relationship_type     is 'LEI-CDF level 2: DIRECT_ and ULTIMATE_ACCOUNTING_CONSOLIDATION_PARENT';
comment on column party.entity_identifier.id_value                is 'iso20022Path (scheme LEI): Issr on the instrument, LEI-CDF: LEI';
