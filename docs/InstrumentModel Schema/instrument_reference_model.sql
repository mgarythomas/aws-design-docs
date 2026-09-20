-- =============================================================================
-- Instrument reference data model
-- Context 1: instrument and terms   Context 2: basket and index composition
--
-- Target      : PostgreSQL 14+ (range types, exclusion constraints, partitioning)
-- Extensions  : btree_gist (needed for exclusion constraints that mix = and &&)
--
-- Conventions
--   * Surrogate UUID keys. Exchange codes, ISINs, option codes and the like are
--     identifiers (core.instrument_identifier), never keys.
--   * Bitemporal tables carry two ranges:
--       valid_range     daterange  when the fact applies in the world (upper bound exclusive)
--       recorded_range  tstzrange  when the operator held this version (open upper = current)
--     Valid time is date granularity. Intraday facts (for example trading halts)
--     need a tstzrange valid time and are out of scope here.
--   * Write protocol for bitemporal tables: never UPDATE attribute columns.
--       Correction or change = close the old row (set upper(recorded_range) = now())
--       and INSERT replacement row(s). A trigger enforces this.
--   * Maker-checker: rows start PENDING. Only APPROVED rows take part in the
--     no-overlap guarantees and in the as-of functions.
--   * Seed values in ref.* are illustrative placeholders. Align them with the
--     operator's own vocabulary and with the current rulebooks before use.
--   * ISO 20022 path annotations (see the end of this file) are indicative and
--     must be verified against the ISO 20022 repository.
-- =============================================================================

create extension if not exists btree_gist;

create schema if not exists ref;
create schema if not exists core;
create schema if not exists basket;

-- -----------------------------------------------------------------------------
-- Domains
-- -----------------------------------------------------------------------------
create domain ref.currency_code as text check (value ~ '^[A-Z]{3}$');          -- ISO 4217
create domain ref.country_code  as text check (value ~ '^[A-Z]{2}$');          -- ISO 3166-1 alpha-2
create domain ref.mic_code      as text check (value ~ '^[A-Z0-9]{4}$');        -- ISO 10383
create domain ref.lei_code      as text check (value ~ '^[A-Z0-9]{18}[0-9]{2}$'); -- ISO 17442
create domain ref.cfi_code      as text check (value ~ '^[A-Z]{6}$');           -- ISO 10962

-- -----------------------------------------------------------------------------
-- ref: rules and vocabularies held as data
-- -----------------------------------------------------------------------------
create table ref.obligation_ref (
  obligation_ref_id uuid primary key default gen_random_uuid(),
  rulebook          text not null,
  rule_number       text not null,
  rule_version      text not null,
  effective_range   daterange not null,
  description       text,
  source_url        text,
  unique (rulebook, rule_number, rule_version)
);
comment on table ref.obligation_ref is
  'Pointer to a specific version of a rule. Attributes, checks and status changes reference it for traceability.';

create table ref.governing_framework (
  governing_framework text primary key,
  description         text not null
);

create table ref.admission_tier (
  governing_framework text not null references ref.governing_framework,
  tier_code           text not null,
  description         text,
  primary key (governing_framework, tier_code)
);

create table ref.status_code (
  governing_framework text not null references ref.governing_framework,
  status_code         text not null,
  is_terminal         boolean not null default false,
  description         text,
  primary key (governing_framework, status_code)
);

create table ref.identifier_scheme (
  scheme        text primary key,
  description   text not null,
  value_pattern text          -- optional regular expression checked on insert
);

create table ref.eligibility_basis (
  eligibility_basis text primary key,
  description       text not null,
  obligation_ref_id uuid references ref.obligation_ref
);

-- Seeds (illustrative)
insert into ref.governing_framework values
  ('LISTING_RULES',         'Entities and securities admitted under the Listing Rules'),
  ('AQUA_RULES',            'Products quoted under the AQUA Rules (Schedule 10A of the Operating Rules)'),
  ('ASX24_OPERATING_RULES', 'Futures traded on the ASX 24 market'),
  ('ASX_MARKET_ETO',        'Exchange traded options on the ASX Market');

insert into ref.admission_tier values
  ('AQUA_RULES', 'TRADING_STATUS',      'Admitted to Trading Status'),
  ('AQUA_RULES', 'QUOTE_DISPLAY_BOARD', 'Admitted to the Quote Display Board'),
  ('AQUA_RULES', 'MFUND_SETTLEMENT',    'Admitted for settlement through the Managed Fund Settlement Service');

insert into ref.status_code (governing_framework, status_code, is_terminal, description)
select f.governing_framework, s.code, s.terminal, s.descr
from ref.governing_framework f
cross join (values
  ('PROPOSED',  false, 'Application or proposal received'),
  ('APPROVED',  false, 'Approved but not yet announced'),
  ('ANNOUNCED', false, 'Announced to participants'),
  ('IN_TEST',   false, 'Available in the external test environment'),
  ('LIVE',      false, 'Live and tradeable'),
  ('HALTED',    false, 'Trading halted'),
  ('SUSPENDED', false, 'Suspended'),
  ('REMOVED',   true,  'Removed or delisted')
) as s(code, terminal, descr);

insert into ref.status_code (governing_framework, status_code, is_terminal, description)
select f.governing_framework, s.code, true, s.descr
from ref.governing_framework f
cross join (values
  ('EXPIRED', 'Series expired'),
  ('SETTLED', 'Series expired and settled')
) as s(code, descr)
where f.governing_framework in ('ASX24_OPERATING_RULES', 'ASX_MARKET_ETO');

insert into ref.identifier_scheme values
  ('ISIN',             'ISO 6166 security identifier',                        '^[A-Z]{2}[A-Z0-9]{9}[0-9]$'),
  ('ASX_CODE',         'Exchange code for a security or ETF',                 null),
  ('ASX_OPTION_CODE',  'Exchange option series code (underlying code plus clearing code characters)', '^[A-Z0-9]{5,6}$'),
  ('DERIV_NATURAL_KEY','Composite key: MIC|product|expiry|type|strike',       null),
  ('FIGI',             'OpenFIGI identifier',                                 '^[A-Z0-9]{12}$'),
  ('UPI',              'ISO 4914 unique product identifier',                  null),
  ('INTERNAL',         'Internal operator identifier',                        null);

insert into ref.eligibility_basis values
  ('EXCHANGE_TRADED_SECURITY',  'Security traded on an eligible exchange',   null),
  ('DEPOSIT_PRODUCT',           'Deposit product',                           null),
  ('MONEY_MARKET_INSTRUMENT',   'Money market instrument',                   null),
  ('ELIGIBLE_DEBT_PORTFOLIO',   'Eligible debt portfolio',                   null),
  ('OTHER_APPROVED',            'Other underlying approved by the operator', null);

-- -----------------------------------------------------------------------------
-- core: guard functions
-- -----------------------------------------------------------------------------
-- Bitemporal rows are append-only: only the recorded_range upper bound may be
-- closed, and approval fields may change as the maker-checker step completes.
-- Do not attach this to a table with generated columns without excluding them below.
create function core.enforce_bitemporal_append_only() returns trigger
language plpgsql as $$
begin
  if tg_op = 'DELETE' then
    raise exception '% is append-only: rows cannot be deleted', tg_table_name
      using errcode = '55000';
  end if;
  if (to_jsonb(new) - array['recorded_range', 'approval_status', 'approved_by']::text[])
     is distinct from
     (to_jsonb(old) - array['recorded_range', 'approval_status', 'approved_by']::text[]) then
    raise exception '% is append-only: close the old row and insert a new one', tg_table_name
      using errcode = '55000';
  end if;
  if lower(new.recorded_range) is distinct from lower(old.recorded_range)
     or (not upper_inf(old.recorded_range) and new.recorded_range is distinct from old.recorded_range) then
    raise exception '% : only an open recorded_range may be closed', tg_table_name
      using errcode = '55000';
  end if;
  return new;
end $$;

create function core.check_identifier_pattern() returns trigger
language plpgsql as $$
declare
  v_pattern text;
begin
  select value_pattern into v_pattern from ref.identifier_scheme where scheme = new.scheme;
  if v_pattern is not null and new.id_value !~ v_pattern then
    raise exception 'identifier % does not match the pattern for scheme %', new.id_value, new.scheme
      using errcode = '23514';
  end if;
  return new;
end $$;

-- -----------------------------------------------------------------------------
-- core: identity tables
-- -----------------------------------------------------------------------------
create table core.instrument (
  instrument_id    uuid primary key default gen_random_uuid(),
  instrument_class text not null check (instrument_class in ('EQUITY', 'ETF', 'FUTURE', 'OPTION')),
  created_at       timestamptz not null default now(),
  unique (instrument_id, instrument_class)
);

create table core.reference_index (
  index_id    uuid primary key default gen_random_uuid(),
  index_code  text not null unique,
  name        text not null,
  administrator text,
  base_currency ref.currency_code,
  created_at  timestamptz not null default now()
);

create table core.reference_index_version (
  index_version_id         uuid primary key default gen_random_uuid(),
  index_id                 uuid not null references core.reference_index,
  valid_range              daterange not null check (not isempty(valid_range)),
  recorded_range           tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  level_publicly_available boolean,
  methodology_ref          text,
  methodology_version      text,
  governance_ref           text,
  source_system            text not null,
  recorded_by              text not null,
  approval_status          text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by              text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  constraint reference_index_version_no_overlap
    exclude using gist (index_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);

-- One typed pointer used by underliers, basket lines and identifier resolution.
-- Exactly one target column is set, so referential integrity is kept for every type.
create table core.typed_ref (
  typed_ref_id   uuid primary key default gen_random_uuid(),
  instrument_id  uuid references core.instrument,
  index_id       uuid references core.reference_index,
  basket_id      uuid,                       -- foreign key added once basket.basket exists
  cash_currency  ref.currency_code,
  commodity_code text,
  rate_code      text,
  ref_type       text generated always as (
    case
      when instrument_id  is not null then 'INSTRUMENT'
      when index_id       is not null then 'INDEX'
      when basket_id      is not null then 'BASKET'
      when cash_currency  is not null then 'CASH'
      when commodity_code is not null then 'COMMODITY'
      when rate_code      is not null then 'RATE'
    end) stored,
  constraint typed_ref_exactly_one_target
    check (num_nonnulls(instrument_id, index_id, basket_id, cash_currency, commodity_code, rate_code) = 1),
  unique (instrument_id),
  unique (index_id),
  unique (basket_id),
  unique (cash_currency),
  unique (commodity_code),
  unique (rate_code)
);

-- -----------------------------------------------------------------------------
-- core: instrument attributes and identifiers
-- -----------------------------------------------------------------------------
create table core.instrument_version (
  instrument_version_id uuid primary key default gen_random_uuid(),
  instrument_id         uuid not null references core.instrument,
  valid_range           daterange not null check (not isempty(valid_range)),
  recorded_range        tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  cfi_code              ref.cfi_code,
  fisn                  text check (char_length(fisn) <= 35),
  full_name             text not null,
  denomination_currency ref.currency_code not null,
  issuer_lei            ref.lei_code,
  governing_framework   text not null references ref.governing_framework,
  lifecycle_status      text not null check (lifecycle_status in ('PROPOSED', 'ACTIVE', 'EXPIRED', 'TERMINATED')),
  ext                   jsonb not null default '{}'::jsonb check (jsonb_typeof(ext) = 'object'),
  source_system         text not null,
  recorded_by           text not null,
  approval_status       text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by           text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  constraint instrument_version_no_overlap
    exclude using gist (instrument_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);
create index instrument_version_instrument_idx on core.instrument_version (instrument_id);

create table core.instrument_identifier (
  identifier_id  uuid primary key default gen_random_uuid(),
  instrument_id  uuid not null references core.instrument,
  scheme         text not null references ref.identifier_scheme,
  id_value       text not null,
  valid_range    daterange not null check (not isempty(valid_range)),
  recorded_range tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system  text not null,
  -- an identifier points to at most one instrument at any point in valid and recorded time
  constraint instrument_identifier_no_overlap
    exclude using gist (scheme with =, id_value with =, valid_range with &&, recorded_range with &&)
);
create index instrument_identifier_instrument_idx on core.instrument_identifier (instrument_id);
create trigger instrument_identifier_pattern
  before insert on core.instrument_identifier
  for each row execute function core.check_identifier_pattern();

-- -----------------------------------------------------------------------------
-- core: listing (venue presence) and status history
-- -----------------------------------------------------------------------------
create table core.listing (
  listing_id    uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references core.instrument,
  mic           ref.mic_code not null,
  created_at    timestamptz not null default now(),
  unique (instrument_id, mic)
);

create table core.listing_version (
  listing_version_id uuid primary key default gen_random_uuid(),
  listing_id         uuid not null references core.listing,
  valid_range        daterange not null check (not isempty(valid_range)),
  recorded_range     tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  local_symbol       text not null,
  trading_currency   ref.currency_code not null,
  tick_size_regime   text,
  lot_size           numeric(18, 4) check (lot_size > 0),
  source_system      text not null,
  constraint listing_version_no_overlap
    exclude using gist (listing_id with =, valid_range with &&, recorded_range with &&)
);

create table core.listing_status (
  listing_status_id   uuid primary key default gen_random_uuid(),
  listing_id          uuid not null references core.listing,
  governing_framework text not null,
  status_code         text not null,
  admission_tier      text,
  reason              text,
  authority_ref_id    uuid references ref.obligation_ref,
  valid_range         daterange not null check (not isempty(valid_range)),
  recorded_range      tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system       text not null,
  recorded_by         text not null,
  approval_status     text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by         text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  foreign key (governing_framework, status_code)
    references ref.status_code (governing_framework, status_code),
  foreign key (governing_framework, admission_tier)
    references ref.admission_tier (governing_framework, tier_code),   -- skipped when admission_tier is null
  constraint listing_status_no_overlap
    exclude using gist (listing_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);

-- -----------------------------------------------------------------------------
-- core: derivatives (product > series > instrument)
-- -----------------------------------------------------------------------------
create table core.derivative_product (
  product_id   uuid primary key default gen_random_uuid(),
  mic          ref.mic_code not null,
  product_code text not null,
  product_type text not null check (product_type in ('FUTURE', 'OPTION')),
  name         text not null,
  unique (mic, product_code, product_type)
);

-- Product-level defaults. A series or instrument can override through its own terms.
create table core.contract_specification_version (
  spec_version_id  uuid primary key default gen_random_uuid(),
  product_id       uuid not null references core.derivative_product,
  valid_range      daterange not null check (not isempty(valid_range)),
  recorded_range   tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  price_multiplier numeric(18, 6) not null check (price_multiplier > 0),
  delivery_type    text not null check (delivery_type in ('PHYS', 'CASH', 'OPTL')),
  exercise_style   text check (exercise_style in ('EURO', 'AMER', 'ASIA', 'BERM', 'OTHR')),
  expiry_cycle     text check (expiry_cycle in ('WEEKLY', 'MONTHLY', 'QUARTERLY', 'OTHER')),
  tick_size        numeric(18, 8) check (tick_size > 0),
  tick_value       numeric(18, 8) check (tick_value > 0),
  settlement_method text,
  source_system    text not null,
  recorded_by      text not null,
  approval_status  text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by      text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  constraint contract_specification_version_no_overlap
    exclude using gist (product_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);

create table core.derivative_series (
  series_id     uuid primary key default gen_random_uuid(),
  product_id    uuid not null references core.derivative_product,
  series_period text not null,          -- for example a contract month or a weekly label
  unique (product_id, series_period)
);

create table core.derivative_instrument (
  instrument_id    uuid primary key,
  instrument_class text not null check (instrument_class in ('FUTURE', 'OPTION')),
  series_id        uuid not null references core.derivative_series,
  foreign key (instrument_id, instrument_class)
    references core.instrument (instrument_id, instrument_class),
  unique (instrument_id, instrument_class)
);

create table core.derivative_terms_version (
  terms_version_id  uuid primary key default gen_random_uuid(),
  instrument_id     uuid not null,
  instrument_class  text not null check (instrument_class in ('FUTURE', 'OPTION')),
  valid_range       daterange not null check (not isempty(valid_range)),
  recorded_range    tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  expiry_date       date not null,
  price_multiplier  numeric(18, 6) not null check (price_multiplier > 0),
  delivery_type     text not null check (delivery_type in ('PHYS', 'CASH', 'OPTL')),
  option_type       text check (option_type in ('PUTO', 'CALL', 'OTHR')),
  exercise_style    text check (exercise_style in ('EURO', 'AMER', 'ASIA', 'BERM', 'OTHR')),
  strike_price      numeric(24, 8) check (strike_price >= 0),
  strike_currency   ref.currency_code,
  adjusted_flag     boolean not null default false,   -- terms changed by a corporate action
  non_standard_flag boolean not null default false,
  source_system     text not null,
  recorded_by       text not null,
  approval_status   text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by       text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  foreign key (instrument_id, instrument_class)
    references core.derivative_instrument (instrument_id, instrument_class),
  constraint derivative_terms_option_fields check (
       (instrument_class = 'OPTION' and option_type is not null and exercise_style is not null
                                    and strike_price is not null and strike_currency is not null)
    or (instrument_class = 'FUTURE' and option_type is null and exercise_style is null
                                    and strike_price is null and strike_currency is null)),
  constraint derivative_terms_version_no_overlap
    exclude using gist (instrument_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);

-- What a derivative is written on. Weighted, so it also covers multi-underlier products.
create table core.underlying_link (
  underlying_link_id uuid primary key default gen_random_uuid(),
  instrument_id      uuid not null references core.derivative_instrument (instrument_id),
  typed_ref_id       uuid not null references core.typed_ref,
  weight             numeric(12, 10) not null default 1 check (weight > 0),
  valid_range        daterange not null check (not isempty(valid_range)),
  recorded_range     tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  source_system      text not null,
  constraint underlying_link_no_overlap
    exclude using gist (instrument_id with =, typed_ref_id with =, valid_range with &&, recorded_range with &&)
);

create function core.forbid_self_underlying() returns trigger
language plpgsql as $$
begin
  if exists (select 1 from core.typed_ref t
             where t.typed_ref_id = new.typed_ref_id and t.instrument_id = new.instrument_id) then
    raise exception 'a derivative cannot be its own underlying' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger underlying_link_no_self
  before insert on core.underlying_link
  for each row execute function core.forbid_self_underlying();

-- -----------------------------------------------------------------------------
-- core: ETF subtype
-- -----------------------------------------------------------------------------
create table core.etf (
  instrument_id    uuid primary key,
  instrument_class text not null default 'ETF' check (instrument_class = 'ETF'),
  foreign key (instrument_id, instrument_class)
    references core.instrument (instrument_id, instrument_class)
);

create table core.etf_version (
  etf_version_id     uuid primary key default gen_random_uuid(),
  instrument_id      uuid not null references core.etf,
  valid_range        daterange not null check (not isempty(valid_range)),
  recorded_range     tstzrange not null default tstzrange(now(), null, '[)') check (not isempty(recorded_range)),
  -- The AQUA rules also cover managed funds and structured products. All three are
  -- held under class ETF until the instrument class list is widened.
  aqua_product_type  text not null default 'ETF_SECURITY'
                     check (aqua_product_type in ('ETF_SECURITY', 'MANAGED_FUND', 'STRUCTURED_PRODUCT')),
  replication_method text check (replication_method in ('PHYSICAL', 'SYNTHETIC')),
  ter_percent        numeric(7, 4) check (ter_percent >= 0),
  distribution_policy text check (distribution_policy in ('ACCUMULATING', 'DISTRIBUTING')),
  creation_unit_size numeric(18, 4) check (creation_unit_size > 0),
  leverage_factor    numeric(6, 2),          -- negative values denote inverse products
  currency_hedged    boolean,
  domicile           ref.country_code,
  benchmark_index_id uuid references core.reference_index,
  uses_otc_derivatives boolean,
  source_system      text not null,
  recorded_by        text not null,
  approval_status    text not null default 'PENDING' check (approval_status in ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by        text,
  check (approval_status <> 'APPROVED' or approved_by is not null),
  constraint etf_version_no_overlap
    exclude using gist (instrument_id with =, valid_range with &&, recorded_range with &&)
    where (approval_status = 'APPROVED')
);

-- -----------------------------------------------------------------------------
-- basket: composition snapshots (ETF creation, redemption and holdings; index constituents)
-- -----------------------------------------------------------------------------
create table basket.basket (
  basket_id          uuid primary key default gen_random_uuid(),
  owner_type         text not null check (owner_type in ('ETF', 'INDEX')),
  etf_instrument_id  uuid references core.etf (instrument_id),
  index_id           uuid references core.reference_index (index_id),
  owner_key          uuid generated always as (coalesce(etf_instrument_id, index_id)) stored,
  basket_type        text not null check (basket_type in ('CREATION', 'REDEMPTION', 'PORTFOLIO_HOLDINGS', 'BENCHMARK')),
  business_date      date not null,
  version_no         integer not null default 1 check (version_no >= 1),
  status             text not null default 'DRAFT' check (status in ('DRAFT', 'PUBLISHED', 'SUPERSEDED')),
  received_at        timestamptz not null default now(),   -- operator receipt, taken at the edge
  published_at       timestamptz,                          -- publication time stated by the source
  recorded_at        timestamptz not null default now(),
  superseded_at      timestamptz,
  cash_amount        numeric(24, 6),
  cash_currency      ref.currency_code,
  creation_unit_size numeric(18, 4) check (creation_unit_size > 0),
  declared_line_count integer check (declared_line_count >= 0),
  source_system      text not null,
  source_reference   text,
  fulfilment_id      uuid,    -- foreign key to the obligation fulfilment record once that context exists
  constraint basket_owner_consistent check (
       (owner_type = 'ETF'   and etf_instrument_id is not null and index_id is null)
    or (owner_type = 'INDEX' and index_id is not null and etf_instrument_id is null)),
  constraint basket_type_matches_owner check ((owner_type = 'INDEX') = (basket_type = 'BENCHMARK')),
  constraint basket_cash_pair check ((cash_amount is null) = (cash_currency is null)),
  constraint basket_superseded_consistent check ((status = 'SUPERSEDED') = (superseded_at is not null)),
  unique (owner_key, basket_type, business_date, version_no)
);
create unique index basket_one_current_version
  on basket.basket (owner_key, basket_type, business_date) where superseded_at is null;

alter table core.typed_ref
  add constraint typed_ref_basket_fk foreign key (basket_id) references basket.basket (basket_id);

-- Header rows: only the publication state may change. Published headers are never deleted.
create function basket.guard_basket() returns trigger
language plpgsql as $$
begin
  if tg_op = 'DELETE' then
    if old.status <> 'DRAFT' then
      raise exception 'published baskets cannot be deleted' using errcode = '55000';
    end if;
    return old;
  end if;
  -- owner_key is a generated column. Generated columns are not yet computed in BEFORE
  -- triggers, so it must be excluded from the comparison.
  if (to_jsonb(new) - array['status', 'superseded_at', 'published_at', 'owner_key']::text[])
     is distinct from
     (to_jsonb(old) - array['status', 'superseded_at', 'published_at', 'owner_key']::text[]) then
    raise exception 'basket headers are immutable except for publication state' using errcode = '55000';
  end if;
  return new;
end $$;
create trigger basket_guard
  before update or delete on basket.basket
  for each row execute function basket.guard_basket();

-- Lines are partitioned by business date, which also keeps daily loads and archiving cheap.
create table basket.basket_component (
  basket_id         uuid not null references basket.basket (basket_id),
  business_date     date not null,
  line_no           integer not null check (line_no >= 1),
  typed_ref_id      uuid not null references core.typed_ref,
  quantity          numeric(28, 8),
  weight            numeric(12, 10) check (weight >= 0),
  direction         text not null default 'LONG' check (direction in ('LONG', 'SHORT')),
  component_currency ref.currency_code,
  eligibility_basis text references ref.eligibility_basis,
  primary key (business_date, basket_id, line_no),
  check (quantity is not null or weight is not null)
) partition by range (business_date);

-- Safety net. Create real partitions ahead of time, because a default partition
-- holding rows for a range blocks creating that range later.
create table basket.basket_component_default partition of basket.basket_component default;

create function basket.ensure_month_partition(p_month date) returns text
language plpgsql as $$
declare
  v_start date := date_trunc('month', p_month)::date;
  v_end   date := (date_trunc('month', p_month) + interval '1 month')::date;
  v_name  text := format('basket_component_p%s', to_char(v_start, 'YYYYMM'));
begin
  execute format(
    'create table if not exists basket.%I partition of basket.basket_component for values from (%L) to (%L)',
    v_name, v_start, v_end);
  return v_name;
end $$;

create index basket_component_ref_idx on basket.basket_component (typed_ref_id);

-- Lines are frozen once the parent header leaves DRAFT.
create function basket.guard_basket_component() returns trigger
language plpgsql as $$
declare
  v_status text;
begin
  select status into v_status from basket.basket
  where basket_id = case when tg_op = 'DELETE' then old.basket_id else new.basket_id end;
  if v_status is distinct from 'DRAFT' then
    raise exception 'basket lines can only change while the basket is DRAFT' using errcode = '55000';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
create trigger basket_component_guard
  before insert or update or delete on basket.basket_component
  for each row execute function basket.guard_basket_component();

create view basket.v_basket_totals as
select b.basket_id, b.owner_key, b.basket_type, b.business_date, b.version_no,
       b.declared_line_count,
       count(c.line_no) as line_count,
       sum(c.weight)    as weight_sum
from basket.basket b
left join basket.basket_component c on c.basket_id = b.basket_id and c.business_date = b.business_date
group by b.basket_id;

-- -----------------------------------------------------------------------------
-- Bitemporal append-only enforcement on every versioned table
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'core.reference_index_version', 'core.instrument_version', 'core.instrument_identifier',
    'core.listing_version', 'core.listing_status', 'core.contract_specification_version',
    'core.derivative_terms_version', 'core.underlying_link', 'core.etf_version'
  ] loop
    execute format(
      'create trigger %I before update or delete on %s for each row execute function core.enforce_bitemporal_append_only()',
      replace(t, '.', '_') || '_append_only', t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- As-of access
-- -----------------------------------------------------------------------------
-- All approved instrument versions valid on p_valid_on, as known at p_known_at.
create function core.instrument_as_of(p_valid_on date, p_known_at timestamptz default now())
returns setof core.instrument_version
language sql stable as $$
  select * from core.instrument_version
  where approval_status = 'APPROVED'
    and valid_range @> p_valid_on
    and recorded_range @> p_known_at
$$;

-- Resolve an identifier as at a business date and a knowledge time.
-- instrument_version_id is null when the instrument exists but has no approved version for that date.
create function core.resolve_identifier(
  p_scheme text, p_value text, p_valid_on date, p_known_at timestamptz default now())
returns table (instrument_id uuid, instrument_version_id uuid)
language sql stable as $$
  select i.instrument_id, v.instrument_version_id
  from core.instrument_identifier i
  left join core.instrument_version v
    on  v.instrument_id = i.instrument_id
    and v.approval_status = 'APPROVED'
    and v.valid_range @> p_valid_on
    and v.recorded_range @> p_known_at
  where i.scheme = p_scheme
    and i.id_value = p_value
    and i.valid_range @> p_valid_on
    and i.recorded_range @> p_known_at
$$;

create view core.v_instrument_current as
select i.instrument_id, i.instrument_class, v.instrument_version_id, v.full_name, v.fisn, v.cfi_code,
       v.denomination_currency, v.issuer_lei, v.governing_framework, v.lifecycle_status
from core.instrument i
join core.instrument_as_of(current_date) v on v.instrument_id = i.instrument_id;

-- -----------------------------------------------------------------------------
-- ISO 20022 traceability (indicative auth.017 element paths, verify before relying on them)
-- -----------------------------------------------------------------------------
comment on column core.instrument_version.cfi_code              is 'iso20022Path: FinInstrmGnlAttrbts/ClssfctnTp';
comment on column core.instrument_version.fisn                  is 'iso20022Path: FinInstrmGnlAttrbts/ShrtNm';
comment on column core.instrument_version.full_name             is 'iso20022Path: FinInstrmGnlAttrbts/FullNm';
comment on column core.instrument_version.denomination_currency is 'iso20022Path: FinInstrmGnlAttrbts/NtnlCcy';
comment on column core.instrument_version.issuer_lei            is 'iso20022Path: Issr';
comment on column core.instrument_version.ext                   is 'Extension block. Keys are namespaced by owner and never reuse ISO 20022 names.';
comment on column core.instrument_identifier.id_value           is 'iso20022Path (scheme ISIN): FinInstrmGnlAttrbts/Id';
comment on column core.listing.mic                              is 'iso20022Path: TradgVnRltdAttrbts/Id';
comment on column core.derivative_terms_version.expiry_date     is 'iso20022Path: DerivInstrmAttrbts/XpryDt';
comment on column core.derivative_terms_version.price_multiplier is 'iso20022Path: DerivInstrmAttrbts/PricMltplr';
comment on column core.derivative_terms_version.option_type     is 'iso20022Path: DerivInstrmAttrbts/OptnTp';
comment on column core.derivative_terms_version.strike_price    is 'iso20022Path: DerivInstrmAttrbts/StrkPric';
comment on column core.derivative_terms_version.exercise_style  is 'iso20022Path: DerivInstrmAttrbts/OptnExrcStyle';
comment on column core.derivative_terms_version.delivery_type   is 'iso20022Path: DerivInstrmAttrbts/DlvryTp';
