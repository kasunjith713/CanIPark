-- CanIPark SQLite Schema
-- Version: 1.0
-- Description: Database schema for parking sign rules, jurisdictions, and scan history.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- =============================================================================
-- JURISDICTIONS
-- Australian states and territories
-- =============================================================================

CREATE TABLE IF NOT EXISTS jurisdictions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL UNIQUE,          -- e.g. "NSW", "VIC", "QLD"
    name        TEXT NOT NULL,                 -- e.g. "New South Wales"
    timezone    TEXT NOT NULL,                 -- e.g. "Australia/Sydney"
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO jurisdictions (code, name, timezone) VALUES
    ('NSW', 'New South Wales',              'Australia/Sydney'),
    ('VIC', 'Victoria',                     'Australia/Melbourne'),
    ('QLD', 'Queensland',                   'Australia/Brisbane'),
    ('WA',  'Western Australia',            'Australia/Perth'),
    ('SA',  'South Australia',              'Australia/Adelaide'),
    ('TAS', 'Tasmania',                     'Australia/Hobart'),
    ('ACT', 'Australian Capital Territory', 'Australia/Sydney'),
    ('NT',  'Northern Territory',           'Australia/Darwin');

-- =============================================================================
-- SIGN TYPES
-- Master list of recognised parking sign categories
-- =============================================================================

CREATE TABLE IF NOT EXISTS sign_types (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    category_key    TEXT NOT NULL UNIQUE,      -- matches SignCategory raw value
    display_name    TEXT NOT NULL,
    precedence      INTEGER NOT NULL,          -- lower = more restrictive
    description     TEXT,
    is_prohibitive  INTEGER NOT NULL DEFAULT 0,  -- 1 = cannot park at all
    can_have_duration INTEGER NOT NULL DEFAULT 0, -- 1 = may include time limit
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO sign_types (category_key, display_name, precedence, description, is_prohibitive, can_have_duration) VALUES
    ('noStopping',   'No Stopping',        0,  'No vehicle may stop at all, even briefly.',                       1, 0),
    ('clearway',     'Clearway',           1,  'No stopping or parking. Vehicles may be towed.',                  1, 0),
    ('noParking',    'No Parking',         2,  'No parking. May stop briefly (up to 2 min) for passengers.',      1, 0),
    ('busZone',      'Bus Zone',           3,  'Reserved for buses only.',                                        1, 0),
    ('taxiZone',     'Taxi Zone',          4,  'Reserved for taxis picking up or setting down passengers.',        1, 0),
    ('truckZone',    'Truck Zone',         5,  'Reserved for trucks for loading and unloading.',                   1, 0),
    ('worksZone',    'Works Zone',         6,  'Reserved for works and construction vehicles.',                    1, 0),
    ('mailZone',     'Mail Zone',          7,  'Reserved for Australia Post vehicles.',                            1, 0),
    ('loadingZone',  'Loading Zone',       8,  'Only for actively loading or unloading goods.',                    1, 1),
    ('permitZone',   'Permit Zone',        9,  'Permit holders only.',                                            1, 0),
    ('accessible',   'Accessible Parking', 9,  'Reserved for disability permit holders.',                          1, 1),
    ('evCharging',   'EV Charging Only',   9,  'Reserved for electric vehicles while charging.',                   1, 1),
    ('timedParking', 'Timed Parking',      10, 'Parking allowed with a time limit.',                               0, 1),
    ('unrestricted', 'Unrestricted',       99, 'No parking restrictions apply.',                                   0, 0),
    ('unknown',      'Unknown',            100,'Sign could not be classified.',                                    0, 0);

-- =============================================================================
-- RESTRICTION RULES
-- Default rules for each sign type, optionally per jurisdiction
-- =============================================================================

CREATE TABLE IF NOT EXISTS restriction_rules (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    sign_type_id        INTEGER NOT NULL REFERENCES sign_types(id) ON DELETE CASCADE,
    jurisdiction_id     INTEGER REFERENCES jurisdictions(id) ON DELETE SET NULL,
    can_park            TEXT NOT NULL CHECK (can_park IN ('yes', 'no', 'uncertain')),
    brief_stop_allowed  INTEGER NOT NULL DEFAULT 0,    -- 1 = up to 2 min allowed
    max_brief_stop_min  INTEGER,                       -- max minutes for brief stop
    tow_risk            INTEGER NOT NULL DEFAULT 0,    -- 1 = vehicle may be towed
    default_fine_min    REAL,                           -- minimum typical fine ($)
    default_fine_max    REAL,                           -- maximum typical fine ($)
    notes               TEXT,
    created_at          TEXT NOT NULL DEFAULT (datetime('now'))
);

-- National default rules (jurisdiction_id IS NULL = applies everywhere)
INSERT OR IGNORE INTO restriction_rules (sign_type_id, jurisdiction_id, can_park, brief_stop_allowed, max_brief_stop_min, tow_risk, default_fine_min, default_fine_max, notes) VALUES
    (1,  NULL, 'no',  0, NULL, 0, 280, 500,  'No stopping at all. Cannot even pause momentarily.'),
    (2,  NULL, 'no',  0, NULL, 1, 350, 600,  'Clearway: vehicles will be towed.'),
    (3,  NULL, 'no',  1, 2,    0, 130, 280,  'No parking, but may stop up to 2 minutes for passengers.'),
    (4,  NULL, 'no',  0, NULL, 0, 280, 500,  'Bus zone: only buses may stop.'),
    (5,  NULL, 'no',  0, NULL, 0, 280, 500,  'Taxi zone: only taxis may stop.'),
    (6,  NULL, 'no',  0, NULL, 0, 130, 280,  'Truck zone: only trucks for loading/unloading.'),
    (7,  NULL, 'no',  0, NULL, 0, 130, 280,  'Works zone: construction vehicles only.'),
    (8,  NULL, 'no',  0, NULL, 0, 130, 280,  'Mail zone: Australia Post vehicles only.'),
    (9,  NULL, 'no',  0, NULL, 0, 130, 280,  'Loading zone: active loading/unloading only.'),
    (10, NULL, 'no',  0, NULL, 0, 130, 280,  'Permit zone: valid permit required.'),
    (11, NULL, 'no',  0, NULL, 0, 500, 1000, 'Accessible parking: disability permit required.'),
    (12, NULL, 'no',  0, NULL, 0, 130, 280,  'EV charging: electric vehicles while charging only.'),
    (13, NULL, 'yes', 0, NULL, 0, 80,  180,  'Timed parking: observe time limit and payment.'),
    (14, NULL, 'yes', 0, NULL, 0, NULL, NULL, 'Unrestricted: park freely.'),
    (15, NULL, 'uncertain', 0, NULL, 0, NULL, NULL, 'Unknown sign type.');

-- =============================================================================
-- TIME WINDOWS
-- Reusable time window definitions that can be linked to restrictions
-- =============================================================================

CREATE TABLE IF NOT EXISTS time_windows (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    name                    TEXT,                         -- optional label, e.g. "Weekday business hours"
    start_hour              INTEGER NOT NULL CHECK (start_hour >= 0 AND start_hour <= 23),
    start_minute            INTEGER NOT NULL DEFAULT 0 CHECK (start_minute >= 0 AND start_minute <= 59),
    end_hour                INTEGER NOT NULL CHECK (end_hour >= 0 AND end_hour <= 23),
    end_minute              INTEGER NOT NULL DEFAULT 0 CHECK (end_minute >= 0 AND end_minute <= 59),
    days_of_week            TEXT NOT NULL DEFAULT '1,2,3,4,5,6,7',  -- comma-separated weekday numbers (1=Sun)
    school_days_only        INTEGER NOT NULL DEFAULT 0,
    public_holiday_behavior TEXT NOT NULL DEFAULT 'unspecified'
        CHECK (public_holiday_behavior IN ('applies', 'doesNotApply', 'publicHolidayOnly', 'unspecified')),
    created_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Common time windows
INSERT OR IGNORE INTO time_windows (id, name, start_hour, start_minute, end_hour, end_minute, days_of_week, school_days_only, public_holiday_behavior) VALUES
    (1, 'Weekday business hours',      8,  0,  18, 0,  '2,3,4,5,6', 0, 'unspecified'),
    (2, 'Weekday morning peak',        7,  0,  9,  0,  '2,3,4,5,6', 0, 'unspecified'),
    (3, 'Weekday afternoon peak',      16, 0,  18, 0,  '2,3,4,5,6', 0, 'unspecified'),
    (4, 'Saturday morning',            8,  0,  12, 0,  '7',         0, 'unspecified'),
    (5, 'Saturday all day',            8,  0,  18, 0,  '7',         0, 'unspecified'),
    (6, 'All day every day',           0,  0,  23, 59, '1,2,3,4,5,6,7', 0, 'unspecified'),
    (7, 'Weekday excl public holiday', 8,  0,  18, 0,  '2,3,4,5,6', 0, 'doesNotApply'),
    (8, 'School day morning',          8,  0,  9,  30, '2,3,4,5,6', 1, 'doesNotApply'),
    (9, 'School day afternoon',        14, 30, 16, 0,  '2,3,4,5,6', 1, 'doesNotApply'),
    (10,'Clearway morning weekday',    6,  0,  10, 0,  '2,3,4,5,6', 0, 'doesNotApply'),
    (11,'Clearway afternoon weekday',  15, 0,  19, 0,  '2,3,4,5,6', 0, 'doesNotApply');

-- =============================================================================
-- PUBLIC HOLIDAYS
-- Public holiday dates by jurisdiction and year
-- =============================================================================

CREATE TABLE IF NOT EXISTS public_holidays (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    jurisdiction_id INTEGER REFERENCES jurisdictions(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    holiday_date    TEXT NOT NULL,             -- ISO 8601 date: YYYY-MM-DD
    is_national     INTEGER NOT NULL DEFAULT 0,
    is_substitute   INTEGER NOT NULL DEFAULT 0,
    year            INTEGER NOT NULL,
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Create index for fast lookups by date
CREATE INDEX IF NOT EXISTS idx_public_holidays_date ON public_holidays(holiday_date);
CREATE INDEX IF NOT EXISTS idx_public_holidays_jurisdiction ON public_holidays(jurisdiction_id, year);

-- 2026 National public holidays (seed data)
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year) VALUES
    (NULL, 'New Year''s Day',                    '2026-01-01', 1, 0, 2026),
    (NULL, 'Australia Day',                      '2026-01-26', 1, 0, 2026),
    (NULL, 'Good Friday',                        '2026-04-03', 1, 0, 2026),
    (NULL, 'Saturday before Easter Sunday',      '2026-04-04', 1, 0, 2026),
    (NULL, 'Easter Monday',                      '2026-04-06', 1, 0, 2026),
    (NULL, 'Anzac Day',                          '2026-04-25', 1, 0, 2026),
    (NULL, 'Christmas Day',                      '2026-12-25', 1, 0, 2026),
    (NULL, 'Boxing Day',                         '2026-12-26', 1, 0, 2026);

-- 2026 State-specific public holidays (selected)
-- NSW
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Queen''s Birthday', '2026-06-08', 0, 0, 2026 FROM jurisdictions WHERE code = 'NSW';

-- VIC
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Queen''s Birthday', '2026-06-08', 0, 0, 2026 FROM jurisdictions WHERE code = 'VIC';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Melbourne Cup Day', '2026-11-03', 0, 0, 2026 FROM jurisdictions WHERE code = 'VIC';

-- QLD
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Queen''s Birthday', '2026-10-26', 0, 0, 2026 FROM jurisdictions WHERE code = 'QLD';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Royal Queensland Show', '2026-08-12', 0, 0, 2026 FROM jurisdictions WHERE code = 'QLD';

-- WA
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Western Australia Day', '2026-06-01', 0, 0, 2026 FROM jurisdictions WHERE code = 'WA';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Queen''s Birthday', '2026-09-28', 0, 0, 2026 FROM jurisdictions WHERE code = 'WA';

-- SA
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Adelaide Cup', '2026-03-09', 0, 0, 2026 FROM jurisdictions WHERE code = 'SA';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Queen''s Birthday', '2026-06-08', 0, 0, 2026 FROM jurisdictions WHERE code = 'SA';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Proclamation Day', '2026-12-28', 0, 1, 2026 FROM jurisdictions WHERE code = 'SA';

-- TAS
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Royal Hobart Regatta', '2026-02-09', 0, 0, 2026 FROM jurisdictions WHERE code = 'TAS';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Queen''s Birthday', '2026-06-08', 0, 0, 2026 FROM jurisdictions WHERE code = 'TAS';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Recreation Day', '2026-11-02', 0, 0, 2026 FROM jurisdictions WHERE code = 'TAS';

-- ACT
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Canberra Day', '2026-03-09', 0, 0, 2026 FROM jurisdictions WHERE code = 'ACT';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Reconciliation Day', '2026-05-27', 0, 0, 2026 FROM jurisdictions WHERE code = 'ACT';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Queen''s Birthday', '2026-06-08', 0, 0, 2026 FROM jurisdictions WHERE code = 'ACT';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Family & Community Day', '2026-09-28', 0, 0, 2026 FROM jurisdictions WHERE code = 'ACT';

-- NT
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'May Day', '2026-05-04', 0, 0, 2026 FROM jurisdictions WHERE code = 'NT';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Queen''s Birthday', '2026-06-08', 0, 0, 2026 FROM jurisdictions WHERE code = 'NT';
INSERT OR IGNORE INTO public_holidays (jurisdiction_id, name, holiday_date, is_national, is_substitute, year)
SELECT id, 'Picnic Day', '2026-08-03', 0, 0, 2026 FROM jurisdictions WHERE code = 'NT';

-- =============================================================================
-- SCAN HISTORY
-- Persistent record of user scans (mirrors ScanHistoryStore but in SQLite)
-- =============================================================================

CREATE TABLE IF NOT EXISTS scan_history (
    id                  TEXT PRIMARY KEY,          -- UUID string
    verdict             TEXT NOT NULL CHECK (verdict IN ('canPark', 'cannotPark', 'uncertain')),
    confidence          TEXT NOT NULL CHECK (confidence IN ('high', 'medium', 'low')),
    time_limit          TEXT,
    max_stay            TEXT,
    payment_status      TEXT,
    warnings            TEXT,                      -- JSON array of strings
    detected_signs      TEXT,                      -- JSON array of DetectedSign objects
    reasoning_chain     TEXT,                      -- JSON array of strings
    scan_date           TEXT NOT NULL,             -- ISO 8601 datetime
    location_desc       TEXT,
    latitude            REAL,
    longitude           REAL,
    jurisdiction_id     INTEGER REFERENCES jurisdictions(id) ON DELETE SET NULL,
    raw_ocr_text        TEXT,
    thumbnail_path      TEXT,                      -- relative path to thumbnail JPEG
    created_at          TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_scan_history_date ON scan_history(scan_date);
CREATE INDEX IF NOT EXISTS idx_scan_history_verdict ON scan_history(verdict);

-- =============================================================================
-- OCR CORRECTIONS
-- Table of known OCR misreads and their corrections
-- =============================================================================

CREATE TABLE IF NOT EXISTS ocr_corrections (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern     TEXT NOT NULL UNIQUE,          -- regex pattern to match
    replacement TEXT NOT NULL,                 -- corrected text
    notes       TEXT,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO ocr_corrections (pattern, replacement, notes) VALUES
    ('(?i)\bN0\b',        'NO',       'Zero misread as O in NO'),
    ('(?i)\bST0PPING\b',  'STOPPING', 'Zero misread as O in STOPPING'),
    ('(?i)\bPARKlNG\b',   'PARKING',  'Lowercase L misread as I in PARKING'),
    ('(?i)\bZ0NE\b',      'ZONE',     'Zero misread as O in ZONE'),
    ('(?i)\bL0ADING\b',   'LOADING',  'Zero misread as O in LOADING'),
    ('(?i)\bCLEARWAY\b',  'CLEARWAY', 'Identity mapping for validation'),
    ('(?i)\bMETER\b',     'METER',    'Identity mapping for validation');

-- =============================================================================
-- SCHEMA VERSION
-- =============================================================================

CREATE TABLE IF NOT EXISTS schema_version (
    version     INTEGER PRIMARY KEY,
    applied_at  TEXT NOT NULL DEFAULT (datetime('now')),
    description TEXT
);

INSERT OR IGNORE INTO schema_version (version, description) VALUES
    (1, 'Initial schema: jurisdictions, sign_types, restriction_rules, time_windows, public_holidays, scan_history, ocr_corrections');
