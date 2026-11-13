-- TABANG — starter Supabase schema
-- Companion to docs/backend/TABANG_Backend_Guide.xlsx and BACKEND_GUIDE.md
--
-- REVIEW BEFORE RUNNING. This is a starter, not a production migration.
-- Recommended next step: split into versioned migrations
--   supabase migration new tabang_core
-- and run against a clean project first.
--
-- Design notes
-- * auth.users is the credential store; profiles is the application identity.
-- * Public screens read projection tables, never base tables with PII.
-- * Multi-row workflows are SECURITY DEFINER RPCs with explicit role/state checks.
-- * Use text + lower() unique indexes instead of citext to avoid extension
--   search-path surprises on a fresh project.
-- * All timestamps are timestamptz in UTC. Display in Asia/Manila.

create extension if not exists pgcrypto;

-- ============================================================ enums
do $$ begin create type public.user_role as enum ('user','donor','recipient','staff','admin'); exception when duplicate_object then null; end $$;
do $$ begin create type public.account_status as enum ('unverified','verified','warned','suspended'); exception when duplicate_object then null; end $$;
do $$ begin create type public.blood_type as enum ('O_NEG','O_POS','A_NEG','A_POS','B_NEG','B_POS','AB_NEG','AB_POS'); exception when duplicate_object then null; end $$;
do $$ begin create type public.blood_component as enum ('WHOLE_BLOOD','PACKED_RBC','PLATELETS','PLASMA'); exception when duplicate_object then null; end $$;
do $$ begin create type public.unit_status as enum ('available','reserved','quarantined','dispatched','expired'); exception when duplicate_object then null; end $$;
do $$ begin create type public.request_urgency as enum ('routine','urgent','critical'); exception when duplicate_object then null; end $$;
do $$ begin create type public.request_status as enum ('pending_review','open','matched','fulfilled','rejected','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.request_source as enum ('blood_bank','donor_network'); exception when duplicate_object then null; end $$;
do $$ begin create type public.response_status as enum ('pending','selected','declined','withdrawn'); exception when duplicate_object then null; end $$;
do $$ begin create type public.report_status as enum ('open','resolved','dismissed'); exception when duplicate_object then null; end $$;
do $$ begin create type public.moderation_flag as enum ('clean','flagged','inappropriate','spam'); exception when duplicate_object then null; end $$;
do $$ begin create type public.donor_application_status as enum ('pending','documents_requested','verified','rejected'); exception when duplicate_object then null; end $$;
do $$ begin create type public.drive_approval as enum ('pending','approved','rejected','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.content_category as enum ('explore','tips','eligibility','drives','stories'); exception when duplicate_object then null; end $$;
do $$ begin create type public.activity_kind as enum ('donation','donation_window','profile','avatar','verification','warning','suspension','application','report','request_submitted','request_verified','request_rejected','request_reopened','drive_update','inventory','readiness_targets'); exception when duplicate_object then null; end $$;
do $$ begin create type public.thread_kind as enum ('direct','chapter','group'); exception when duplicate_object then null; end $$;
do $$ begin create type public.notification_kind as enum ('request','response','message','warning','drive','application','system'); exception when duplicate_object then null; end $$;
do $$ begin create type public.document_kind as enum ('doctors_form','transfusion_slip','patient_id','typing_result'); exception when duplicate_object then null; end $$;
do $$ begin create type public.eligibility_blocker as enum ('none','cooldown','underage','overage','underweight','weight_missing','suspended','unverified','unavailable','away','no_blood_type','restricted'); exception when duplicate_object then null; end $$;
do $$ begin create type public.facility_kind as enum ('chapter','hospital'); exception when duplicate_object then null; end $$;

-- ============================================================ reference data
create table if not exists public.barangays (
  name text primary key,
  province text not null default 'Davao del Sur',
  is_city boolean not null default false,
  sort_order smallint not null default 0
);

create table if not exists public.blood_types (
  code public.blood_type primary key,
  label text not null unique,
  sort_order smallint not null default 0
);

create table if not exists public.blood_components (
  code public.blood_component primary key,
  label text not null,
  short_code text not null unique,
  shelf_life_days integer not null check (shelf_life_days > 0),
  cooldown_days integer not null check (cooldown_days > 0),
  sort_order smallint not null default 0
);

create table if not exists public.facilities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  kind public.facility_kind not null default 'hospital',
  barangay text not null references public.barangays(name) on delete restrict,
  address text,
  lat numeric(9,6),
  lng numeric(9,6),
  is_active boolean not null default true
);

create table if not exists public.document_requirements (
  kind public.document_kind primary key,
  label text not null,
  is_required boolean not null default false,
  sort_order smallint not null default 0
);

create table if not exists public.donor_requirements (
  code text primary key,
  label text not null,
  sort_order smallint not null default 0,
  is_active boolean not null default true
);

create table if not exists public.donor_screening_questions (
  id uuid primary key default gen_random_uuid(),
  question text not null unique,
  sort_order smallint not null default 0,
  is_active boolean not null default true,
  answer_persisted boolean not null default false
);

create table if not exists public.role_capabilities (
  role public.user_role not null,
  capability text not null,
  allowed boolean not null default false,
  primary key (role, capability)
);

create table if not exists public.tab_activity_rules (
  tab text not null,
  activity_kind public.activity_kind not null,
  personal_only boolean not null default false,
  primary key (tab, activity_kind)
);

-- ============================================================ profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  legacy_id text unique,
  full_name text not null default '',
  alias text not null,
  email text not null,
  phone text not null default '',
  barangay text not null default 'Zone 1' references public.barangays(name) on delete restrict,
  role public.user_role not null default 'user',
  status public.account_status not null default 'unverified',
  warning_count smallint not null default 0 check (warning_count between 0 and 3),
  suspension_reason text,
  blood_type public.blood_type,
  birth_date date,
  weight_kg numeric(5,2) check (weight_kg between 20 and 300),
  last_donation_date date,
  last_donation_component public.blood_component,
  total_donations integer not null default 0 check (total_donations >= 0),
  is_available boolean not null default true,
  last_active_at timestamptz,
  blood_card_verified boolean not null default false,
  share_barangay boolean not null default true,
  notify_requests boolean not null default true,
  notify_chat boolean not null default true,
  notify_news boolean not null default true,
  onboarding_completed boolean not null default false,
  photo_path text,
  allowed_components public.blood_component[],
  public_handle text not null,
  is_system boolean not null default false,
  must_change_password boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index if not exists profiles_alias_lower_uidx on public.profiles (lower(alias));
create unique index if not exists profiles_email_lower_uidx on public.profiles (lower(email));
create unique index if not exists profiles_public_handle_uidx on public.profiles (public_handle);
create index if not exists profiles_role_idx on public.profiles (role) where deleted_at is null;
create index if not exists profiles_barangay_idx on public.profiles (barangay) where deleted_at is null;

-- ============================================================ donor directory projection
create table if not exists public.donor_directory (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  public_handle text not null,
  blood_type public.blood_type,
  barangay text,
  account_status public.account_status not null,
  blood_card_verified boolean not null default false,
  is_available boolean not null default true,
  last_donation_date date,
  last_donation_component public.blood_component,
  total_donations integer not null default 0,
  last_active_at timestamptz,
  is_eligible boolean not null default false,
  eligibility_blocker public.eligibility_blocker not null default 'none',
  eligible_from date,
  days_remaining integer not null default 0 check (days_remaining >= 0),
  eligibility_reason text,
  updated_at timestamptz not null default now()
);
create unique index if not exists donor_directory_handle_uidx on public.donor_directory (public_handle);
create index if not exists donor_directory_barangay_idx on public.donor_directory (barangay);
create index if not exists donor_directory_eligible_idx on public.donor_directory (is_eligible);

-- ============================================================ inventory
create table if not exists public.blood_units (
  barcode text primary key,
  blood_type public.blood_type not null references public.blood_types(code) on delete restrict,
  component public.blood_component not null references public.blood_components(code) on delete restrict,
  storage_bay text not null default 'Unassigned',
  status public.unit_status not null default 'available',
  collected_on date not null default current_date,
  expires_on timestamptz not null,
  reserved_by uuid references public.profiles(id) on delete set null,
  reservation_note text,
  reserved_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  row_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_on > collected_on::timestamptz)
);
create index if not exists blood_units_status_idx on public.blood_units (status);
create index if not exists blood_units_type_component_idx on public.blood_units (blood_type, component);
create index if not exists blood_units_reserved_by_idx on public.blood_units (reserved_by);

create table if not exists public.blood_units_public (
  barcode text primary key references public.blood_units(barcode) on delete cascade,
  blood_type public.blood_type not null,
  component public.blood_component not null,
  storage_bay text not null,
  status public.unit_status not null,
  collected_on date not null,
  expires_on timestamptz not null,
  is_reserved boolean not null default false,
  effective_status public.unit_status not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_removals (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  barcode text not null,
  unit_snapshot jsonb not null default '{}'::jsonb,
  removed_by uuid not null references public.profiles(id) on delete restrict,
  removed_at timestamptz not null default now(),
  restored boolean not null default false,
  restored_at timestamptz,
  restored_by uuid references public.profiles(id) on delete set null,
  new_barcode text
);
create index if not exists inventory_removals_barcode_idx on public.inventory_removals (barcode);

-- ============================================================ requests
create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  requester_id uuid not null references public.profiles(id) on delete restrict,
  patient_alias text not null,
  blood_type public.blood_type not null references public.blood_types(code) on delete restrict,
  component public.blood_component not null references public.blood_components(code) on delete restrict,
  units_needed smallint not null default 1 check (units_needed between 1 and 20),
  hospital text not null,
  barangay text not null,
  urgency public.request_urgency not null,
  status public.request_status not null default 'pending_review',
  units_fulfilled smallint not null default 0 check (units_fulfilled >= 0),
  source public.request_source not null default 'donor_network',
  note text,
  scheduled_for timestamptz,
  post_to_donor_network boolean not null default true,
  review_note text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  fulfilled_at timestamptz,
  cancelled_at timestamptz,
  deleted_at timestamptz,
  check (units_fulfilled <= units_needed)
);
create index if not exists requests_requester_idx on public.requests (requester_id);
create index if not exists requests_status_idx on public.requests (status);
create index if not exists requests_public_board_idx on public.requests (status, urgency, created_at) where deleted_at is null;
create index if not exists requests_slot_idx on public.requests (scheduled_for) where scheduled_for is not null;

create table if not exists public.request_public (
  id uuid primary key references public.requests(id) on delete cascade,
  legacy_id text,
  patient_alias text not null,
  blood_type public.blood_type not null,
  component public.blood_component not null,
  units_needed smallint not null,
  units_fulfilled smallint not null default 0,
  hospital text not null,
  barangay text not null,
  urgency public.request_urgency not null,
  status public.request_status not null,
  source public.request_source not null,
  scheduled_for timestamptz,
  post_to_donor_network boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists request_public_status_idx on public.request_public (status);

create table if not exists public.request_documents (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.requests(id) on delete cascade,
  kind public.document_kind not null references public.document_requirements(kind) on delete restrict,
  file_name text not null,
  storage_path text not null unique,
  preview_asset text,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 1 and 8388608),
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (request_id, kind)
);
create index if not exists request_documents_request_idx on public.request_documents (request_id);

create table if not exists public.request_units (
  request_id uuid not null references public.requests(id) on delete cascade,
  barcode text not null references public.blood_units(barcode) on delete restrict,
  held_at timestamptz not null default now(),
  released_at timestamptz,
  released_by uuid references public.profiles(id) on delete set null,
  primary key (request_id, barcode)
);
create unique index if not exists request_units_active_barcode_uidx on public.request_units (barcode) where released_at is null;

create table if not exists public.request_responses (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  request_id uuid not null references public.requests(id) on delete cascade,
  donor_id uuid not null references public.profiles(id) on delete restrict,
  donor_handle_snapshot text not null,
  message text,
  status public.response_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (request_id, donor_id)
);
create index if not exists request_responses_request_idx on public.request_responses (request_id);
create index if not exists request_responses_donor_idx on public.request_responses (donor_id, status);

create table if not exists public.request_status_history (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.requests(id) on delete cascade,
  from_status public.request_status,
  to_status public.request_status not null,
  actor_id uuid references public.profiles(id) on delete set null,
  reason text,
  created_at timestamptz not null default now()
);
create index if not exists request_status_history_request_idx on public.request_status_history (request_id, created_at);

-- ============================================================ donors
create table if not exists public.account_warnings (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  level smallint not null check (level between 1 and 3),
  message text not null,
  issued_by uuid not null references public.profiles(id) on delete restrict,
  issued_by_alias_snapshot text not null default '',
  issued_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null
);
create index if not exists account_warnings_user_idx on public.account_warnings (user_id, issued_at);

create table if not exists public.donor_applications (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  user_id uuid not null references public.profiles(id) on delete cascade,
  submitted_at timestamptz not null default now(),
  status public.donor_application_status not null default 'pending',
  has_existing_card boolean not null default false,
  card_number text,
  preferred_visit date,
  note text,
  requested_documents text[] not null default '{}',
  staff_note text,
  decided_by uuid references public.profiles(id) on delete set null,
  decided_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists donor_applications_user_idx on public.donor_applications (user_id, submitted_at desc);
create unique index if not exists donor_applications_one_open_uidx
  on public.donor_applications (user_id)
  where status in ('pending','documents_requested');

create table if not exists public.donations (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  donor_id uuid not null references public.profiles(id) on delete restrict,
  component public.blood_component not null,
  donated_at timestamptz not null default now(),
  request_id uuid references public.requests(id) on delete set null,
  recorded_by uuid not null references public.profiles(id) on delete restrict,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists donations_donor_idx on public.donations (donor_id, donated_at desc);
create index if not exists donations_month_idx on public.donations (donated_at);

-- ============================================================ drives and content
create table if not exists public.blood_drives (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  title text not null,
  venue text not null,
  barangay text not null references public.barangays(name) on delete restrict,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  expected_donors integer not null check (expected_donors > 0),
  is_open_for_registration boolean not null default true,
  photo_path text,
  lat numeric(9,6),
  lng numeric(9,6),
  approval public.drive_approval not null default 'pending',
  proposed_by uuid references public.profiles(id) on delete set null,
  reviewed_by uuid references public.profiles(id) on delete set null,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index if not exists blood_drives_approval_idx on public.blood_drives (approval, starts_at);

create table if not exists public.drive_interests (
  drive_id uuid not null references public.blood_drives(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (drive_id, user_id)
);

create table if not exists public.content_items (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  title text not null,
  subtitle text not null default '',
  body text not null,
  tag text not null default '',
  category public.content_category not null,
  image_path text,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================ messaging
create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  pair_key text unique,
  kind public.thread_kind not null default 'direct',
  group_name text,
  identity_revealed boolean not null default false,
  identity_reveal_requested_by uuid references public.profiles(id) on delete set null,
  is_muted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (kind <> 'group' or group_name is not null)
);

create table if not exists public.chat_thread_members (
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  alias_snapshot text not null default '',
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key (thread_id, user_id)
);
create index if not exists chat_thread_members_user_idx on public.chat_thread_members (user_id);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  sender_alias_snapshot text not null,
  text text not null check (length(btrim(text)) between 1 and 4000),
  sent_as_chapter boolean not null default false,
  flag public.moderation_flag not null default 'clean',
  flag_reason text,
  sent_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists chat_messages_thread_idx on public.chat_messages (thread_id, sent_at);

create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  lifted_at timestamptz,
  check (blocker_id <> blocked_id)
);
create unique index if not exists user_blocks_active_uidx
  on public.user_blocks (blocker_id, blocked_id) where lifted_at is null;

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid not null references public.profiles(id) on delete restrict,
  reporter_alias_snapshot text not null default '',
  reported_alias_snapshot text not null default '',
  reason text not null,
  details text,
  thread_id uuid references public.chat_threads(id) on delete set null,
  status public.report_status not null default 'open',
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists user_reports_status_idx on public.user_reports (status, created_at);

-- ============================================================ chapter settings
create table if not exists public.chapter_settings (
  id smallint primary key default 1 check (id = 1),
  chapter_name text not null,
  chapter_subtitle text not null,
  chapter_account_id uuid references public.profiles(id) on delete set null,
  staff_room_thread_id uuid references public.chat_threads(id) on delete set null,
  warning_suspension_reason text not null,
  min_age integer not null default 18 check (min_age > 0),
  max_age integer not null default 65 check (max_age > min_age),
  min_weight_kg numeric(5,2) not null default 50 check (min_weight_kg > 0),
  away_after_days integer not null default 30 check (away_after_days > 0),
  default_cooldown_days integer not null default 84 check (default_cooldown_days > 0),
  blood_bank_weekday_hours smallint[] not null default '{8,9,10,11,13,14,15}',
  blood_bank_saturday_hours smallint[] not null default '{8,9,10,11}',
  updated_at timestamptz not null default now()
);

-- ============================================================ activity, dots, metrics, notifications
create table if not exists public.activity_events (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  kind public.activity_kind not null,
  actor_id uuid references public.profiles(id) on delete set null,
  subject_id uuid references public.profiles(id) on delete set null,
  actor_alias_snapshot text not null default '',
  subject_alias_snapshot text,
  summary text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists activity_events_created_idx on public.activity_events (created_at desc);
create index if not exists activity_events_subject_idx on public.activity_events (subject_id, created_at desc);
create index if not exists activity_events_kind_idx on public.activity_events (kind, created_at desc);

create table if not exists public.profile_tab_seen (
  user_id uuid not null references public.profiles(id) on delete cascade,
  tab text not null,
  last_seen_at timestamptz not null default now(),
  primary key (user_id, tab)
);

create table if not exists public.readiness_targets (
  id smallint primary key default 1 check (id = 1),
  unit_target integer not null default 32 check (unit_target > 0),
  donor_target integer not null default 20 check (donor_target > 0),
  request_pressure_cap integer not null default 16 check (request_pressure_cap > 0),
  community_target integer not null default 60 check (community_target > 0),
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.readiness_targets (id) values (1) on conflict (id) do nothing;

create table if not exists public.chapter_metrics (
  id smallint primary key default 1 check (id = 1),
  donations_today integer not null default 0,
  donations_this_month integer not null default 0,
  registered_users integer not null default 0,
  active_donors integer not null default 0,
  active_drives integer not null default 0,
  top_barangay text not null default '—',
  units_available integer not null default 0,
  open_requests integer not null default 0,
  readiness_score numeric(5,2) not null default 0 check (readiness_score between 0 and 100),
  updated_at timestamptz not null default now()
);
insert into public.chapter_metrics (id) values (1) on conflict (id) do nothing;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind public.notification_kind not null,
  title text not null,
  body text not null,
  entity_table text,
  entity_id uuid,
  read_at timestamptz,
  push_sent_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);

create table if not exists public.moderation_keywords (
  id uuid primary key default gen_random_uuid(),
  flag public.moderation_flag not null check (flag in ('flagged','inappropriate','spam')),
  keyword text not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists moderation_keywords_flag_lower_uidx on public.moderation_keywords (flag, lower(keyword));

-- ============================================================ reference seed
insert into public.barangays (name, sort_order) values
  ('Aplaya',1),('Balabag',2),('Binaton',3),('Cogon',4),('Colorado',5),
  ('Dawis',6),('Dulangan',7),('Goma',8),('Igpit',9),('Kapatagan',10),
  ('Kiagot',11),('Lungag',12),('Mahayahay',13),('Matti',14),('Ruparan',15),
  ('San Agustin',16),('San Jose',17),('San Miguel',18),('San Roque',19),
  ('Sinawilan',20),('Soong',21),('Tiguman',22),('Tres De Mayo',23),
  ('Zone 1',24),('Zone 2',25),('Zone 3',26)
on conflict (name) do nothing;

insert into public.blood_types (code, label, sort_order) values
  ('O_NEG','O−',1),('O_POS','O+',2),('A_NEG','A−',3),('A_POS','A+',4),
  ('B_NEG','B−',5),('B_POS','B+',6),('AB_NEG','AB−',7),('AB_POS','AB+',8)
on conflict (code) do nothing;

insert into public.blood_components (code, label, short_code, shelf_life_days, cooldown_days, sort_order) values
  ('WHOLE_BLOOD','Whole blood','WB',42,84,1),
  ('PACKED_RBC','Packed red blood cells','RBC',42,84,2),
  ('PLATELETS','Platelets (apheresis)','PLT',5,14,3),
  ('PLASMA','Fresh frozen plasma','FFP',365,28,4)
on conflict (code) do nothing;

insert into public.facilities (name, kind, barangay, address, lat, lng) values
  ('Philippine Red Cross - Davao del Sur Chapter','chapter','Zone 1','Quezon Avenue, Digos City',6.757051,125.352800),
  ('Digos Provincial Hospital','hospital','Zone 2','Malvar Street, Digos City',6.743810,125.361265),
  ('Digos Doctors Hospital','hospital','Zone 3','MacArthur Highway, Digos City',6.764423,125.355069)
on conflict (name) do nothing;

insert into public.document_requirements (kind, label, is_required, sort_order) values
  ('doctors_form','Doctor''s request form',true,1),
  ('transfusion_slip','Blood transfusion slip',true,2),
  ('patient_id','Valid hospital patient ID',true,3),
  ('typing_result','Blood typing / cross-match result',false,4)
on conflict (kind) do nothing;

insert into public.donor_requirements (code, label, sort_order) values
  ('valid_id','Valid government or school ID',1),
  ('prc_card','PRC blood donor card, if you have one',2),
  ('medications','List of current medications',3),
  ('interview','Chapter interview and physical examination',4),
  ('screening','Blood typing and infection screening',5)
on conflict (code) do nothing;

insert into public.donor_screening_questions (question, sort_order) values
  ('Fever, cough or an infection in the last 7 days',1),
  ('Alcohol in the last 24 hours',2),
  ('Aspirin or pain relievers in the last 3 days',3),
  ('Medication or a vaccine in the last 4 weeks',4),
  ('Tattoo, piercing or acupuncture in the last 12 months',5),
  ('Surgery or dental extraction in the last 12 months',6),
  ('Pregnant or breastfeeding (female donors)',7),
  ('Hepatitis B/C, HIV or a positive screening test',8),
  ('Cancer, heart disease or a bleeding disorder',9),
  ('Travel outside the Philippines in the last 12 months',10)
on conflict (question) do nothing;

insert into public.role_capabilities (role, capability, allowed) values
  ('admin','request_blood',true),('admin','register_as_donor',false),('admin','verify_donors',true),
  ('admin','manage_inventory',true),('admin','fulfill_requests',true),('admin','moderate',true),
  ('admin','add_staff',true),('admin','manage_staff',true),
  ('staff','request_blood',false),('staff','register_as_donor',false),('staff','verify_donors',true),
  ('staff','manage_inventory',true),('staff','fulfill_requests',true),('staff','moderate',true),
  ('staff','add_staff',false),('staff','manage_staff',false),
  ('donor','request_blood',true),('donor','register_as_donor',false),('donor','verify_donors',false),
  ('donor','manage_inventory',false),('donor','fulfill_requests',false),('donor','moderate',false),
  ('donor','add_staff',false),('donor','manage_staff',false),
  ('recipient','request_blood',true),('recipient','register_as_donor',true),('recipient','verify_donors',false),
  ('recipient','manage_inventory',false),('recipient','fulfill_requests',false),('recipient','moderate',false),
  ('recipient','add_staff',false),('recipient','manage_staff',false),
  ('user','request_blood',true),('user','register_as_donor',true),('user','verify_donors',false),
  ('user','manage_inventory',false),('user','fulfill_requests',false),('user','moderate',false),
  ('user','add_staff',false),('user','manage_staff',false)
on conflict (role, capability) do update set allowed = excluded.allowed;

insert into public.tab_activity_rules (tab, activity_kind, personal_only) values
  ('home','donation',false),('home','inventory',false),('home','request_verified',false),
  ('find_donor','verification',false),('find_donor','request_verified',false),
  ('requests','request_submitted',false),('requests','request_verified',false),('requests','request_rejected',false),
  ('bloodbank','inventory',false),
  ('donor_hub','application',true),('donor_hub','verification',true),('donor_hub','warning',true),
  ('donor_hub','suspension',true),('donor_hub','donation',true),('donor_hub','donation_window',true),
  ('overview','donation',false),
  ('operations','request_submitted',false),('operations','request_verified',false),('operations','request_rejected',false),('operations','inventory',false),
  ('users','application',false),('users','verification',false),('users','warning',false),('users','suspension',false),('users','profile',false),('users','avatar',false),
  ('moderation','report',false)
on conflict (tab, activity_kind) do update set personal_only = excluded.personal_only;

insert into public.chapter_settings (
  id, chapter_name, chapter_subtitle, warning_suspension_reason,
  min_age, max_age, min_weight_kg, away_after_days, default_cooldown_days,
  blood_bank_weekday_hours, blood_bank_saturday_hours
) values (
  1,
  'Philippine Red Cross - Davao del Sur Chapter',
  'Official chapter account · Quezon Avenue, Digos City',
  'Three moderation warnings on record.',
  18, 65, 50, 30, 84,
  '{8,9,10,11,13,14,15}',
  '{8,9,10,11}'
)
on conflict (id) do nothing;

-- chapter_settings is seeded after the chapter account and staff room exist.
-- See the commented seed block near the end of this file.

-- ============================================================ shared helpers
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.bump_row_version()
returns trigger language plpgsql as $$
begin
  new.row_version = old.row_version + 1;
  return new;
end;
$$;

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('staff','admin')
      and status <> 'suspended'
      and deleted_at is null
  );
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and status <> 'suspended'
      and deleted_at is null
  );
$$;

create or replace function public.can_message(p_other uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select not exists (
    select 1 from public.user_blocks
    where lifted_at is null
      and ((blocker_id = auth.uid() and blocked_id = p_other)
        or (blocker_id = p_other and blocked_id = auth.uid()))
  );
$$;

create or replace function public.can_donate_component(
  p_donor public.blood_type,
  p_recipient public.blood_type,
  p_component public.blood_component
)
returns boolean
language sql immutable
as $$
  select case
    when p_component = 'plasma' then
      case
        when p_donor in ('AB_NEG','AB_POS') then true
        when p_donor in ('A_NEG','A_POS') then p_recipient in ('A_NEG','A_POS','O_NEG','O_POS')
        when p_donor in ('B_NEG','B_POS') then p_recipient in ('B_NEG','B_POS','O_NEG','O_POS')
        else p_recipient in ('O_NEG','O_POS')
      end
    else
      case p_recipient
        when 'O_NEG' then p_donor = 'O_NEG'
        when 'O_POS' then p_donor in ('O_NEG','O_POS')
        when 'A_NEG' then p_donor in ('O_NEG','A_NEG')
        when 'A_POS' then p_donor in ('O_NEG','O_POS','A_NEG','A_POS')
        when 'B_NEG' then p_donor in ('O_NEG','B_NEG')
        when 'B_POS' then p_donor in ('O_NEG','O_POS','B_NEG','B_POS')
        when 'AB_NEG' then p_donor in ('O_NEG','A_NEG','B_NEG','AB_NEG')
        when 'AB_POS' then true
      end
  end;
$$;

-- ============================================================ profile creation
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  fallback text := split_part(new.email, '@', 1) || '-' || right(new.id::text, 4);
begin
  insert into public.profiles (
    id, email, full_name, alias, phone, barangay, role, status, public_handle
  ) values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', fallback),
    coalesce(new.raw_user_meta_data->>'alias', fallback),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'barangay', 'Zone 1'),
    'user',
    'unverified',
    'Donor #' || upper(substr(replace(new.id::text, '-', ''), 1, 8))
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ============================================================ projections
create or replace function public.refresh_donor_directory(p_user uuid default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  delete from public.donor_directory d
  where d.user_id = coalesce(p_user, d.user_id)
    and not exists (
      select 1 from public.profiles p
      where p.id = d.user_id
        and p.role = 'donor'
        and p.deleted_at is null
    );

  insert into public.donor_directory (
    user_id, public_handle, blood_type, barangay, account_status,
    blood_card_verified, is_available, last_donation_date,
    last_donation_component, total_donations, last_active_at,
    is_eligible, eligibility_blocker, eligible_from, days_remaining,
    eligibility_reason, updated_at
  )
  select
    p.id,
    p.public_handle,
    p.blood_type,
    case when p.share_barangay then p.barangay else null end,
    p.status,
    p.blood_card_verified,
    p.is_available,
    p.last_donation_date,
    p.last_donation_component,
    p.total_donations,
    p.last_active_at,
    (
      p.role = 'donor'
      and p.deleted_at is null
      and p.status = 'verified'
      and p.blood_card_verified
      and p.blood_type is not null
      and p.weight_kg is not null and p.weight_kg >= 50
      and p.is_available
      and (p.last_active_at is null or p.last_active_at > now() - interval '30 days')
      and (p.last_donation_date is null or p.last_donation_date + interval '84 days' <= current_date)
    ),
    (
      case
        when p.status = 'suspended' then 'suspended'
        when p.status = 'unverified' then 'unverified'
        when p.blood_type is null then 'no_blood_type'
        when p.birth_date is not null and p.birth_date > current_date - interval '18 years' then 'underage'
        when p.birth_date is not null and p.birth_date < current_date - interval '65 years' then 'overage'
        when p.weight_kg is null then 'weight_missing'
        when p.weight_kg < 50 then 'underweight'
        when not p.is_available then 'unavailable'
        when p.last_active_at is not null and p.last_active_at <= now() - interval '30 days' then 'away'
        when p.last_donation_date is not null and p.last_donation_date + interval '84 days' > current_date then 'cooldown'
        else 'none'
      end
    )::public.eligibility_blocker,
    case
      when p.last_donation_date is not null
      then (p.last_donation_date + interval '84 days')::date
      else null
    end,
    case
      when p.last_donation_date is not null
        and p.last_donation_date + interval '84 days' > current_date
      then (p.last_donation_date + interval '84 days' - current_date)::integer
      else 0
    end,
    case
      when p.role <> 'donor' then 'Not a donor'
      when p.status = 'suspended' then 'Account suspended'
      when p.status = 'unverified' then 'Blood card not verified'
      when p.blood_type is null then 'Blood type not recorded'
      when p.weight_kg is null then 'Weight not recorded'
      when p.weight_kg < 50 then 'Below minimum weight'
      when not p.is_available then 'Marked unavailable'
      when p.last_active_at is not null and p.last_active_at <= now() - interval '30 days' then 'Away - no app activity for 30+ days'
      when p.last_donation_date is not null and p.last_donation_date + interval '84 days' > current_date then 'Within donation cooldown'
      else 'Eligible'
    end,
    now()
  from public.profiles p
  where p.role = 'donor'
    and p.deleted_at is null
    and (p_user is null or p.id = p_user)
  on conflict (user_id) do update set
    public_handle = excluded.public_handle,
    blood_type = excluded.blood_type,
    barangay = excluded.barangay,
    account_status = excluded.account_status,
    blood_card_verified = excluded.blood_card_verified,
    is_available = excluded.is_available,
    last_donation_date = excluded.last_donation_date,
    last_donation_component = excluded.last_donation_component,
    total_donations = excluded.total_donations,
    last_active_at = excluded.last_active_at,
    is_eligible = excluded.is_eligible,
    eligibility_blocker = excluded.eligibility_blocker,
    eligible_from = excluded.eligible_from,
    days_remaining = excluded.days_remaining,
    eligibility_reason = excluded.eligibility_reason,
    updated_at = now();
end;
$$;

create or replace function public.refresh_request_public(p_request uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.request_public (
    id, legacy_id, patient_alias, blood_type, component, units_needed,
    units_fulfilled, hospital, barangay, urgency, status, source,
    scheduled_for, post_to_donor_network, created_at, updated_at
  )
  select id, legacy_id, patient_alias, blood_type, component, units_needed,
         units_fulfilled, hospital, barangay, urgency, status, source,
         scheduled_for, post_to_donor_network, created_at, updated_at
  from public.requests
  where id = p_request and deleted_at is null
  on conflict (id) do update set
    legacy_id = excluded.legacy_id,
    patient_alias = excluded.patient_alias,
    blood_type = excluded.blood_type,
    component = excluded.component,
    units_needed = excluded.units_needed,
    units_fulfilled = excluded.units_fulfilled,
    hospital = excluded.hospital,
    barangay = excluded.barangay,
    urgency = excluded.urgency,
    status = excluded.status,
    source = excluded.source,
    scheduled_for = excluded.scheduled_for,
    post_to_donor_network = excluded.post_to_donor_network,
    updated_at = excluded.updated_at;

  delete from public.request_public p
  where p.id = p_request
    and not exists (
      select 1 from public.requests r
      where r.id = p_request and r.deleted_at is null
    );
end;
$$;

create or replace function public.refresh_unit_public(p_barcode text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.blood_units_public (
    barcode, blood_type, component, storage_bay, status, collected_on,
    expires_on, is_reserved, effective_status, updated_at
  )
  select
    barcode, blood_type, component, storage_bay, status, collected_on,
    expires_on,
    reserved_by is not null,
    case
      when expires_on <= now() and status in ('available','reserved','quarantined')
      then 'expired'::public.unit_status
      else status
    end,
    now()
  from public.blood_units
  where barcode = p_barcode
  on conflict (barcode) do update set
    blood_type = excluded.blood_type,
    component = excluded.component,
    storage_bay = excluded.storage_bay,
    status = excluded.status,
    collected_on = excluded.collected_on,
    expires_on = excluded.expires_on,
    is_reserved = excluded.is_reserved,
    effective_status = excluded.effective_status,
    updated_at = now();

  delete from public.blood_units_public u
  where u.barcode = p_barcode
    and not exists (select 1 from public.blood_units b where b.barcode = p_barcode);
end;
$$;

create or replace function public.refresh_chapter_metrics()
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_units integer;
  v_donors integer;
  v_open integer;
  v_users integer;
  v_drives integer;
  v_top text;
  v_score numeric(5,2);
  t public.readiness_targets;
begin
  select * into t from public.readiness_targets where id = 1;

  select count(*) into v_units from public.blood_units_public where effective_status = 'available';
  select count(*) into v_donors from public.donor_directory where is_eligible;
  select count(*) into v_open from public.requests where status in ('pending_review','open','matched') and deleted_at is null;
  select count(*) into v_users from public.profiles where deleted_at is null;
  select count(*) into v_drives from public.blood_drives where approval = 'approved' and ends_at > now();
  select coalesce((
    select barangay from public.donor_directory
    where barangay is not null
    group by barangay order by count(*) desc limit 1
  ), '—') into v_top;

  v_score := least(100, round((
    least(v_units::numeric / greatest(t.unit_target, 1), 1) * 25 +
    least(v_donors::numeric / greatest(t.donor_target, 1), 1) * 25 +
    greatest(0, 1 - v_open::numeric / greatest(t.request_pressure_cap, 1)) * 25 +
    least(v_users::numeric / greatest(t.community_target, 1), 1) * 25
  )::numeric, 2));

  insert into public.chapter_metrics (
    id, donations_today, donations_this_month, registered_users,
    active_donors, active_drives, top_barangay, units_available,
    open_requests, readiness_score, updated_at
  ) values (
    1,
    (select count(*) from public.donations where donated_at::date = current_date),
    (select count(*) from public.donations where date_trunc('month', donated_at) = date_trunc('month', now())),
    v_users, v_donors, v_drives, v_top, v_units, v_open, v_score, now()
  )
  on conflict (id) do update set
    donations_today = excluded.donations_today,
    donations_this_month = excluded.donations_this_month,
    registered_users = excluded.registered_users,
    active_donors = excluded.active_donors,
    active_drives = excluded.active_drives,
    top_barangay = excluded.top_barangay,
    units_available = excluded.units_available,
    open_requests = excluded.open_requests,
    readiness_score = excluded.readiness_score,
    updated_at = now();
end;
$$;

-- ============================================================ updated_at triggers
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','blood_units','requests','request_responses','donor_applications',
    'blood_drives','content_items','chat_threads','readiness_targets','chapter_settings'
  ] loop
    execute format('drop trigger if exists %I on public.%I', 'set_updated_at_' || t, t);
    execute format('create trigger %I before update on public.%I for each row execute function public.touch_updated_at()', 'set_updated_at_' || t, t);
  end loop;
end $$;

drop trigger if exists bump_units_version on public.blood_units;
create trigger bump_units_version before update on public.blood_units
for each row execute function public.bump_row_version();

-- ============================================================ projection triggers
create or replace function public.trg_refresh_donor_directory()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.refresh_donor_directory(new.id);
  return new;
end;
$$;
drop trigger if exists refresh_donor_directory on public.profiles;
create trigger refresh_donor_directory after insert or update on public.profiles
for each row execute function public.trg_refresh_donor_directory();

create or replace function public.trg_refresh_request_public()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.refresh_request_public(new.id);
  return new;
end;
$$;
drop trigger if exists refresh_request_public on public.requests;
create trigger refresh_request_public after insert or update on public.requests
for each row execute function public.trg_refresh_request_public();

create or replace function public.trg_refresh_unit_public()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'DELETE' then
    delete from public.blood_units_public where barcode = old.barcode;
    return old;
  end if;
  perform public.refresh_unit_public(new.barcode);
  return new;
end;
$$;
drop trigger if exists refresh_unit_public on public.blood_units;
create trigger refresh_unit_public after insert or update or delete on public.blood_units
for each row execute function public.trg_refresh_unit_public();

-- A recorded donation is the source of truth for totals and cooldown.
create or replace function public.trg_apply_donation()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.profiles
  set total_donations = total_donations + 1,
      last_donation_date = new.donated_at::date,
      last_donation_component = new.component,
      updated_at = now()
  where id = new.donor_id;

  perform public.refresh_donor_directory(new.donor_id);
  return new;
end;
$$;
drop trigger if exists apply_donation on public.donations;
create trigger apply_donation after insert on public.donations
for each row execute function public.trg_apply_donation();

-- Fill alias snapshots even when a caller omits them.
create or replace function public.trg_enrich_activity_aliases()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.actor_alias_snapshot = '' and new.actor_id is not null then
    select coalesce(alias, '') into new.actor_alias_snapshot from public.profiles where id = new.actor_id;
  end if;
  if (new.subject_alias_snapshot is null or new.subject_alias_snapshot = '') and new.subject_id is not null then
    select coalesce(alias, '') into new.subject_alias_snapshot from public.profiles where id = new.subject_id;
  end if;
  return new;
end;
$$;
drop trigger if exists enrich_activity_aliases on public.activity_events;
create trigger enrich_activity_aliases before insert on public.activity_events
for each row execute function public.trg_enrich_activity_aliases();

create or replace function public.trg_enrich_thread_member()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.alias_snapshot = '' then
    select coalesce(alias, '') into new.alias_snapshot from public.profiles where id = new.user_id;
  end if;
  return new;
end;
$$;
drop trigger if exists enrich_thread_member on public.chat_thread_members;
create trigger enrich_thread_member before insert on public.chat_thread_members
for each row execute function public.trg_enrich_thread_member();

create or replace function public.trg_enrich_report_aliases()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.reporter_alias_snapshot = '' then
    select coalesce(alias, '') into new.reporter_alias_snapshot from public.profiles where id = new.reporter_id;
  end if;
  if new.reported_alias_snapshot = '' then
    select coalesce(alias, '') into new.reported_alias_snapshot from public.profiles where id = new.reported_user_id;
  end if;
  return new;
end;
$$;
drop trigger if exists enrich_report_aliases on public.user_reports;
create trigger enrich_report_aliases before insert on public.user_reports
for each row execute function public.trg_enrich_report_aliases();

-- Lightweight metrics refresh. For a busy deployment, replace these triggers
-- with a pg_cron job every 15–30 seconds.
create or replace function public.trg_refresh_metrics()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.refresh_chapter_metrics();
  return null;
end;
$$;
do $$
declare t text;
begin
  foreach t in array array['profiles','blood_units','requests','donations','blood_drives','donor_directory'] loop
    execute format('drop trigger if exists refresh_metrics_%I on public.%I', t, t);
    execute format('create trigger refresh_metrics_%I after insert or update or delete on public.%I for each statement execute function public.trg_refresh_metrics()', t, t);
  end loop;
end $$;

-- ============================================================ message flagging
create or replace function public.classify_message(p_text text)
returns table (flag public.moderation_flag, reason text)
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  k record;
begin
  for k in select * from public.moderation_keywords order by length(keyword) desc loop
    if position(lower(k.keyword) in lower(p_text)) > 0 then
      return query select k.flag, k.keyword;
      return;
    end if;
  end loop;
  return query select 'clean'::public.moderation_flag, null::text;
end;
$$;

-- ============================================================ core RPCs
create or replace function public.update_own_profile(
  p_full_name text default null,
  p_phone text default null,
  p_share_barangay boolean default null,
  p_notify_requests boolean default null,
  p_notify_chat boolean default null,
  p_notify_news boolean default null,
  p_photo_path text default null
)
returns public.profiles
language plpgsql security definer set search_path = public, pg_temp as $$
declare p public.profiles;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  update public.profiles
  set full_name = coalesce(nullif(btrim(p_full_name), ''), full_name),
      phone = coalesce(p_phone, phone),
      share_barangay = coalesce(p_share_barangay, share_barangay),
      notify_requests = coalesce(p_notify_requests, notify_requests),
      notify_chat = coalesce(p_notify_chat, notify_chat),
      notify_news = coalesce(p_notify_news, notify_news),
      photo_path = coalesce(p_photo_path, photo_path)
  where id = auth.uid()
  returning * into p;

  if p.id is null then raise exception 'profile_not_found'; end if;

  insert into public.activity_events (kind, actor_id, subject_id, summary)
  values ('profile', auth.uid(), auth.uid(), 'Updated their profile');

  return p;
end;
$$;

create or replace function public.reserve_unit(p_barcode text, p_note text default null)
returns public.blood_units
language plpgsql security definer set search_path = public, pg_temp as $$
declare u public.blood_units;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  update public.blood_units
  set status = 'reserved',
      reserved_by = auth.uid(),
      reservation_note = nullif(btrim(coalesce(p_note,'')), ''),
      reserved_at = now()
  where barcode = p_barcode
    and status = 'available'
    and reserved_by is null
    and expires_on > now()
  returning * into u;

  if u.barcode is null then
    raise exception 'unit_unavailable';
  end if;
  return u;
end;
$$;

create or replace function public.release_unit(p_barcode text)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare u public.blood_units;
begin
  select * into u from public.blood_units where barcode = p_barcode for update;
  if u.barcode is null then raise exception 'unit_not_found'; end if;
  if u.reserved_by is null then return false; end if;
  if u.reserved_by <> auth.uid() and not public.is_staff() then
    raise exception 'not_allowed';
  end if;
  if u.expires_on <= now() then raise exception 'unit_expired'; end if;

  update public.blood_units
  set status = 'available', reserved_by = null, reservation_note = null, reserved_at = null
  where barcode = p_barcode;
  return true;
end;
$$;

create or replace function public.verify_request(
  p_request_id uuid,
  p_unit_ids text[] default '{}'
)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  r public.requests;
  b text;
  u public.blood_units;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;

  select * into r from public.requests where id = p_request_id for update;
  if r.id is null then raise exception 'request_not_found'; end if;
  if r.status <> 'pending_review' then raise exception 'not_pending_review'; end if;

  if (
    select count(distinct d.kind)
    from public.request_documents d
    where d.request_id = p_request_id
      and d.kind in ('doctors_form','transfusion_slip','patient_id')
  ) < 3 then
    raise exception 'required_documents_missing';
  end if;

  foreach b in array coalesce(p_unit_ids, '{}') loop
    select * into u from public.blood_units where barcode = b for update;
    if u.barcode is null then raise exception 'unit_not_found:%', b; end if;
    if u.status <> 'available' or u.reserved_by is not null or u.expires_on <= now() then
      raise exception 'unit_unavailable:%', b;
    end if;
    update public.blood_units
    set status = 'reserved', reserved_by = r.requester_id, reserved_at = now(),
        reservation_note = 'Blood-bank hold for ' || r.legacy_id
    where barcode = b;
    insert into public.request_units (request_id, barcode) values (p_request_id, b)
    on conflict do nothing;
  end loop;

  update public.requests
  set status = 'open', reviewed_by = auth.uid(), verified_at = now(),
      review_note = null, updated_at = now()
  where id = p_request_id;

  insert into public.request_status_history (request_id, from_status, to_status, actor_id)
  values (p_request_id, 'pending_review', 'open', auth.uid());

  insert into public.activity_events (kind, actor_id, subject_id, summary, metadata)
  values ('request_verified', auth.uid(), r.requester_id,
          'Verified request ' || coalesce(r.legacy_id, r.id::text),
          jsonb_build_object('request_id', p_request_id, 'units', p_unit_ids));

  return true;
end;
$$;

create or replace function public.reject_request(p_request_id uuid, p_reason text)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare r public.requests;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  if btrim(coalesce(p_reason,'')) = '' then raise exception 'reason_required'; end if;

  select * into r from public.requests where id = p_request_id for update;
  if r.id is null then raise exception 'request_not_found'; end if;
  if r.status not in ('pending_review','open','matched') then raise exception 'cannot_reject'; end if;

  update public.request_units
  set released_at = now(), released_by = auth.uid()
  where request_id = p_request_id and released_at is null;

  update public.blood_units u
  set status = 'available', reserved_by = null, reservation_note = null, reserved_at = null
  where u.barcode in (select barcode from public.request_units where request_id = p_request_id and released_at = now());

  update public.request_responses
  set status = 'declined', updated_at = now()
  where request_id = p_request_id and status = 'pending';

  update public.requests
  set status = 'rejected', reviewed_by = auth.uid(), review_note = btrim(p_reason),
      updated_at = now()
  where id = p_request_id;

  insert into public.request_status_history (request_id, from_status, to_status, actor_id, reason)
  values (p_request_id, r.status, 'rejected', auth.uid(), btrim(p_reason));

  insert into public.activity_events (kind, actor_id, subject_id, summary, metadata)
  values ('request_rejected', auth.uid(), r.requester_id,
          'Rejected request ' || coalesce(r.legacy_id, r.id::text) || ': ' || btrim(p_reason),
          jsonb_build_object('request_id', p_request_id));

  return true;
end;
$$;

create or replace function public.mark_request_fulfilled(p_request_id uuid)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  r public.requests;
  d uuid;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;

  select * into r from public.requests where id = p_request_id for update;
  if r.id is null then raise exception 'request_not_found'; end if;
  if r.status = 'fulfilled' then return false; end if;
  if r.status not in ('open','matched') then raise exception 'cannot_fulfil'; end if;
  if r.source = 'donor_network' and r.status <> 'matched' then raise exception 'not_matched'; end if;

  if r.source = 'donor_network' then
    select donor_id into d from public.request_responses
    where request_id = p_request_id and status = 'selected'
    limit 1;
  end if;

  update public.requests
  set status = 'fulfilled', units_fulfilled = units_needed, fulfilled_at = now(), updated_at = now()
  where id = p_request_id;

  if d is not null then
    insert into public.donations (donor_id, component, donated_at, request_id, recorded_by)
    values (d, r.component, now(), p_request_id, auth.uid());
  end if;

  insert into public.request_status_history (request_id, from_status, to_status, actor_id)
  values (p_request_id, r.status, 'fulfilled', auth.uid());

  insert into public.activity_events (kind, actor_id, subject_id, summary, metadata)
  values ('request_verified', auth.uid(), r.requester_id,
          'Marked request ' || coalesce(r.legacy_id, r.id::text) || ' fulfilled',
          jsonb_build_object('request_id', p_request_id));

  return true;
end;
$$;

create or replace function public.warn_user(p_user_id uuid, p_reason text)
returns public.account_warnings
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  p public.profiles;
  w public.account_warnings;
  next_level smallint;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  select * into p from public.profiles where id = p_user_id for update;
  if p.id is null then raise exception 'user_not_found'; end if;
  if p.status = 'suspended' then raise exception 'already_suspended'; end if;

  next_level := least(3, p.warning_count + 1)::smallint;

  insert into public.account_warnings (user_id, level, message, issued_by, issued_by_alias_snapshot)
  values (p_user_id, next_level,
          coalesce(nullif(btrim(p_reason), ''),
                   'A chapter moderator flagged activity on your account.'),
          auth.uid(),
          (select alias from public.profiles where id = auth.uid()))
  returning * into w;

  update public.profiles
  set warning_count = next_level,
      status = case when next_level >= 3 then 'suspended'::public.account_status else 'warned'::public.account_status end,
      suspension_reason = case when next_level >= 3 then 'Three moderation warnings on record.' else null end,
      updated_at = now()
  where id = p_user_id;

  insert into public.activity_events (kind, actor_id, subject_id, summary, metadata)
  values ('warning', auth.uid(), p_user_id,
          'Issued warning ' || next_level || ' to ' || p.alias,
          jsonb_build_object('warning_id', w.id, 'level', next_level));

  insert into public.notifications (user_id, kind, title, body, entity_table, entity_id)
  values (p_user_id, 'warning', 'Account warning',
          coalesce(nullif(btrim(p_reason), ''), 'Please review the community rules.'),
          'account_warnings', w.id);

  return w;
end;
$$;

create or replace function public.mark_thread_read(p_thread_id uuid)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.chat_thread_members
  set last_read_at = now()
  where thread_id = p_thread_id and user_id = auth.uid();
  return found;
end;
$$;

create or replace function public.acknowledge_warnings()
returns integer
language plpgsql security definer set search_path = public, pg_temp as $$
declare n integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.account_warnings
  set acknowledged_at = now()
  where user_id = auth.uid() and acknowledged_at is null;
  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function public.set_readiness_targets(
  p_unit integer,
  p_donor integer,
  p_request_cap integer,
  p_community integer
)
returns boolean
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if least(p_unit, p_donor, p_request_cap, p_community) <= 0 then
    raise exception 'targets_must_be_positive';
  end if;

  update public.readiness_targets
  set unit_target = p_unit, donor_target = p_donor,
      request_pressure_cap = p_request_cap, community_target = p_community,
      updated_by = auth.uid(), updated_at = now()
  where id = 1;

  insert into public.activity_events (kind, actor_id, summary)
  values ('readiness_targets', auth.uid(),
          format('Updated readiness targets: %s units, %s donors, request cap %s, %s accounts',
                 p_unit, p_donor, p_request_cap, p_community));

  perform public.refresh_chapter_metrics();
  return true;
end;
$$;

-- ============================================================ derived views
create or replace view public.blood_type_stats
with (security_invoker = true) as
select
  bt.code as blood_type,
  coalesce(d.donated, 0)::integer as donated,
  coalesce(r.requested, 0)::integer as requested,
  (coalesce(d.donated, 0) - coalesce(r.requested, 0))::integer as balance
from public.blood_types bt
left join (
  select p.blood_type, count(*)::integer as donated
  from public.donations dn
  join public.profiles p on p.id = dn.donor_id
  group by p.blood_type
) d on d.blood_type = bt.code
left join (
  select blood_type, sum(units_needed)::integer as requested
  from public.requests
  where status <> 'cancelled' and deleted_at is null
  group by blood_type
) r on r.blood_type = bt.code;

create or replace view public.barangay_stats
with (security_invoker = true) as
select
  b.name as barangay,
  coalesce(d.donation_count, 0)::integer as donation_count,
  coalesce(c.donor_count, 0)::integer as donor_count
from public.barangays b
left join (
  select p.barangay, count(*)::integer as donation_count
  from public.donations dn
  join public.profiles p on p.id = dn.donor_id
  group by p.barangay
) d on d.barangay = b.name
left join (
  select barangay, count(*)::integer as donor_count
  from public.donor_directory
  where barangay is not null
  group by barangay
) c on c.barangay = b.name
where coalesce(c.donor_count, 0) > 0;

create or replace view public.donor_counts_by_barangay
with (security_invoker = true) as
select barangay, count(*)::integer as donor_count
from public.donor_directory
where is_eligible and barangay is not null
group by barangay;

create or replace view public.open_requests_by_barangay
with (security_invoker = true) as
select barangay, count(*)::integer as request_count
from public.requests
where status in ('open','matched') and deleted_at is null
group by barangay;

create or replace view public.pending_applications_by_barangay
with (security_invoker = true) as
select p.barangay, count(*)::integer as application_count
from public.donor_applications a
join public.profiles p on p.id = a.user_id
where a.status in ('pending','documents_requested')
group by p.barangay;

create or replace view public.thread_unread_counts
with (security_invoker = true) as
select
  m.thread_id,
  m.user_id,
  count(msg.id)::integer as unread_count,
  (count(msg.id) > 0) as has_unread
from public.chat_thread_members m
left join public.chat_messages msg
  on msg.thread_id = m.thread_id
 and msg.deleted_at is null
 and msg.sender_id is not null
 and msg.sender_id <> m.user_id
 and (m.last_read_at is null or msg.sent_at > m.last_read_at)
group by m.thread_id, m.user_id;

create or replace view public.thread_last_message
with (security_invoker = true) as
select distinct on (thread_id)
  thread_id,
  id as message_id,
  sender_id,
  sender_alias_snapshot,
  text,
  sent_at,
  flag
from public.chat_messages
where deleted_at is null
order by thread_id, sent_at desc;

create or replace view public.thread_moderation_summary
with (security_invoker = true) as
select
  thread_id,
  count(*) filter (where flag <> 'clean')::integer as flagged_count,
  bool_or(flag <> 'clean') as has_flagged_messages
from public.chat_messages
where deleted_at is null
group by thread_id;

create or replace view public.expiring_soon
with (security_invoker = true) as
select *
from public.blood_units_public
where effective_status = 'available'
  and expires_on > now()
  and expires_on <= now() + interval '7 days';

create or replace view public.critical_shortage_types
with (security_invoker = true) as
select bt.code as blood_type
from public.blood_types bt
where not exists (
  select 1 from public.blood_units_public u
  where u.blood_type = bt.code and u.effective_status = 'available'
);

-- ============================================================ RLS
alter table public.profiles enable row level security;
alter table public.donor_directory enable row level security;
alter table public.blood_units enable row level security;
alter table public.blood_units_public enable row level security;
alter table public.inventory_removals enable row level security;
alter table public.requests enable row level security;
alter table public.request_public enable row level security;
alter table public.request_documents enable row level security;
alter table public.request_units enable row level security;
alter table public.request_responses enable row level security;
alter table public.request_status_history enable row level security;
alter table public.account_warnings enable row level security;
alter table public.donor_applications enable row level security;
alter table public.donations enable row level security;
alter table public.blood_drives enable row level security;
alter table public.drive_interests enable row level security;
alter table public.content_items enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_thread_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.user_blocks enable row level security;
alter table public.user_reports enable row level security;
alter table public.activity_events enable row level security;
alter table public.profile_tab_seen enable row level security;
alter table public.readiness_targets enable row level security;
alter table public.chapter_metrics enable row level security;
alter table public.notifications enable row level security;
alter table public.moderation_keywords enable row level security;
alter table public.barangays enable row level security;
alter table public.facilities enable row level security;
alter table public.blood_types enable row level security;
alter table public.blood_components enable row level security;
alter table public.document_requirements enable row level security;
alter table public.donor_requirements enable row level security;
alter table public.donor_screening_questions enable row level security;
alter table public.chapter_settings enable row level security;
alter table public.role_capabilities enable row level security;
alter table public.tab_activity_rules enable row level security;

-- profiles: own row or staff. Direct updates are not allowed; use update_own_profile.
create policy profiles_select_own on public.profiles for select using (id = auth.uid() or public.is_staff());

-- public projections
create policy donor_directory_read on public.donor_directory for select using (auth.uid() is not null);
create policy blood_units_public_read on public.blood_units_public for select using (auth.uid() is not null);
create policy request_public_read on public.request_public for select using (auth.uid() is not null);

-- inventory
create policy blood_units_select_own on public.blood_units for select using (reserved_by = auth.uid() or public.is_staff());
create policy inventory_removals_staff on public.inventory_removals for select using (public.is_staff());

-- requests: own or staff; writes via RPC
create policy requests_select_own on public.requests for select using (requester_id = auth.uid() or public.is_staff());
create policy request_documents_select on public.request_documents for select using (
  public.is_staff() or exists (
    select 1 from public.requests r where r.id = request_id and r.requester_id = auth.uid()
  )
);
create policy request_documents_insert_own on public.request_documents for insert with check (
  uploaded_by = auth.uid() and exists (
    select 1 from public.requests r where r.id = request_id and r.requester_id = auth.uid()
  )
);
create policy request_units_select on public.request_units for select using (
  public.is_staff() or exists (
    select 1 from public.requests r where r.id = request_id and r.requester_id = auth.uid()
  )
);
create policy request_responses_select on public.request_responses for select using (
  donor_id = auth.uid()
  or public.is_staff()
  or exists (select 1 from public.requests r where r.id = request_id and r.requester_id = auth.uid())
);
create policy request_status_history_select on public.request_status_history for select using (
  public.is_staff() or exists (
    select 1 from public.requests r where r.id = request_id and r.requester_id = auth.uid()
  )
);

-- donors
create policy account_warnings_select on public.account_warnings for select using (user_id = auth.uid() or public.is_staff());
create policy donor_applications_select on public.donor_applications for select using (user_id = auth.uid() or public.is_staff());
create policy donations_select on public.donations for select using (donor_id = auth.uid() or public.is_staff());

-- drives and content
create policy blood_drives_select on public.blood_drives for select using (approval = 'approved' or public.is_staff());
create policy drive_interests_select on public.drive_interests for select using (user_id = auth.uid() or public.is_staff());
create policy drive_interests_write on public.drive_interests for insert with check (user_id = auth.uid());
create policy drive_interests_delete on public.drive_interests for delete using (user_id = auth.uid());
create policy content_items_select on public.content_items for select using (is_published or public.is_staff());

-- messaging
create policy chat_threads_select on public.chat_threads for select using (
  public.is_staff() or exists (
    select 1 from public.chat_thread_members m where m.thread_id = id and m.user_id = auth.uid()
  )
);
create policy chat_thread_members_select on public.chat_thread_members for select using (
  user_id = auth.uid() or public.is_staff()
);
create policy chat_messages_select on public.chat_messages for select using (
  public.is_staff() or exists (
    select 1 from public.chat_thread_members m where m.thread_id = thread_id and m.user_id = auth.uid()
  )
);
create policy user_blocks_select on public.user_blocks for select using (blocker_id = auth.uid() or public.is_staff());
create policy user_reports_select on public.user_reports for select using (reporter_id = auth.uid() or public.is_staff());

-- activity / dots / metrics
create policy activity_events_select on public.activity_events for select using (
  public.is_staff() or actor_id = auth.uid() or subject_id = auth.uid()
);
create policy profile_tab_seen_own on public.profile_tab_seen for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy readiness_targets_read on public.readiness_targets for select using (auth.uid() is not null);
create policy chapter_metrics_staff on public.chapter_metrics for select using (public.is_staff());
create policy notifications_own on public.notifications for select using (user_id = auth.uid());
create policy notifications_read on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy moderation_keywords_staff on public.moderation_keywords for all using (public.is_staff()) with check (public.is_staff());

-- reference and configuration data
create policy barangays_read on public.barangays for select using (auth.uid() is not null);
create policy facilities_read on public.facilities for select using (auth.uid() is not null);
create policy blood_types_read on public.blood_types for select using (auth.uid() is not null);
create policy blood_components_read on public.blood_components for select using (auth.uid() is not null);
create policy document_requirements_read on public.document_requirements for select using (auth.uid() is not null);
create policy donor_requirements_read on public.donor_requirements for select using (auth.uid() is not null);
create policy donor_screening_questions_staff on public.donor_screening_questions for select using (public.is_staff());
create policy chapter_settings_read on public.chapter_settings for select using (auth.uid() is not null);
create policy chapter_settings_admin_write on public.chapter_settings for update using (public.is_admin()) with check (public.is_admin());
create policy role_capabilities_read on public.role_capabilities for select using (auth.uid() is not null);
create policy tab_activity_rules_read on public.tab_activity_rules for select using (auth.uid() is not null);

-- ============================================================ storage
insert into storage.buckets (id, name, public)
values ('request-documents', 'request-documents', false)
on conflict (id) do nothing;

create policy request_documents_upload on storage.objects for insert
with check (
  bucket_id = 'request-documents'
  and auth.uid() is not null
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy request_documents_read on storage.objects for select
using (
  bucket_id = 'request-documents'
  and (
    public.is_staff()
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);

create policy request_documents_delete on storage.objects for delete
using (bucket_id = 'request-documents' and public.is_staff());

-- ============================================================ realtime
alter publication supabase_realtime add table
  public.profiles,
  public.donor_directory,
  public.blood_units,
  public.blood_units_public,
  public.requests,
  public.request_public,
  public.request_documents,
  public.request_responses,
  public.request_units,
  public.blood_drives,
  public.drive_interests,
  public.chat_threads,
  public.chat_thread_members,
  public.chat_messages,
  public.user_blocks,
  public.user_reports,
  public.account_warnings,
  public.donor_applications,
  public.activity_events,
  public.readiness_targets,
  public.chapter_metrics,
  public.notifications,
  public.content_items,
  public.chapter_settings,
  public.barangays,
  public.facilities,
  public.blood_components,
  public.role_capabilities,
  public.tab_activity_rules;

alter table public.requests replica identity full;
alter table public.chat_messages replica identity full;

-- ============================================================ chapter identity seed
-- profiles.id references auth.users, so the organization account must be a real
-- auth user. Create it with a random password (never shared) and disable
-- interactive login, then:
--   insert into public.profiles (id, legacy_id, full_name, alias, email, phone,
--     barangay, role, status, public_handle, is_system)
--   values ('<uuid>', 'USR-CHAPTER', 'Philippine Red Cross - Davao del Sur Chapter',
--     'Philippine Red Cross - Davao del Sur Chapter', 'bloodservices@tabang.app',
--     '+63 82 000 0000', 'Zone 1', 'staff', 'verified', 'Chapter', true);
--   insert into public.chat_threads (legacy_id, kind, group_name)
--   values ('STAFF-ROOM', 'group', 'Staff room');
--   -- add staff/admin rows to chat_thread_members, then:
--   update public.chapter_settings
--   set chapter_account_id = '<uuid>',
--       staff_room_thread_id = (select id from public.chat_threads where legacy_id = 'STAFF-ROOM')
--   where id = 1;

-- ============================================================ TODO before production
-- 1. Replace direct profile UPDATE with update_own_profile RPC that whitelists
--    fields and prevents role/status/total_donations/blood_card_verified edits.
-- 2. Add submit_request, respond_to_request, select_donor_response,
--    submit_donor_application, decide_donor_application, propose_drive,
--    decide_drive, block_user, submit_report, resolve_report, send_message,
--    request/accept/decline identity reveal.
-- 3. Add request transition trigger validating every from->to state.
-- 4. Add component-specific eligibility (84/84/14/28 days) and plasma
--    compatibility to the projection/job.
-- 5. Add storage cleanup job and document MIME validation.
-- 6. Add tests in a Supabase branch: two concurrent holds, two concurrent
--    selections, reject-while-response, fulfilled twice, expired bag.
-- 7. Split this file into versioned migrations and run on a clean project.
-- 8. Never put the service_role key in Flutter, web JS or a public repo.
-- 9. Enforce direct-thread/group/chapter member cardinality in get_or_create_thread.
-- 10. Add the one-active-commitment check to select_donor_response.
-- 11. Add the derived views/RLS review for per-role column exposure.
-- 12. Seed the chapter account + staff room + chapter_settings foreign keys.