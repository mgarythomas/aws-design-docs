-- ==========================================
-- DOMAIN: VENUE DATA
-- ==========================================
CREATE TABLE venue (
    mic VARCHAR(4) PRIMARY KEY,
    operating_mic VARCHAR(4) REFERENCES venue(mic), -- Self-referencing hierarchy
    name VARCHAR(100) NOT NULL,
    country_code VARCHAR(2) NOT NULL,
    city VARCHAR(50),
    website VARCHAR(255),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'MODIFIED', 'INACTIVE')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- DOMAIN: INDUSTRY CLASSIFICATION
-- ==========================================
CREATE TABLE industry_classification (
    classification_system VARCHAR(10) NOT NULL, -- e.g., ANZSIC, GICS, NAICS
    code VARCHAR(20) NOT NULL,
    name VARCHAR(150) NOT NULL,
    hierarchy_level VARCHAR(50), -- e.g., Division, Class
    parent_code VARCHAR(20),
    PRIMARY KEY (classification_system, code)
);

-- ==========================================
-- DOMAIN: ISSUER AGGREGATE ROOT
-- ==========================================
CREATE TABLE issuer (
    lei VARCHAR(20) PRIMARY KEY CHECK (lei ~ '^[0-9A-Z]{20}$'),
    legal_name VARCHAR(255) NOT NULL,
    jurisdiction VARCHAR(2) NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Mapping Table: Issuers to Industry Classifications (Many-to-Many)
CREATE TABLE issuer_classification (
    issuer_lei VARCHAR(20) REFERENCES issuer(lei) ON DELETE CASCADE,
    classification_system VARCHAR(10),
    classification_code VARCHAR(20),
    is_primary BOOLEAN DEFAULT false,
    PRIMARY KEY (issuer_lei, classification_system, classification_code),
    FOREIGN KEY (classification_system, classification_code) 
        REFERENCES industry_classification(classification_system, code)
);

-- ==========================================
-- DOMAIN: INSTRUMENT AGGREGATE ROOT
-- ==========================================
CREATE TABLE instrument (
    figi VARCHAR(12) PRIMARY KEY CHECK (figi ~ '^[0-9A-Z]{12}$'),
    issuer_lei VARCHAR(20) NOT NULL REFERENCES issuer(lei), -- DDD Reference by Identity
    isin VARCHAR(12) UNIQUE CHECK (isin ~ '^[A-Z]{2}[A-Z0-9]{9}[0-9]$'),
    ticker VARCHAR(20) NOT NULL,
    composite_ticker VARCHAR(30),
    mic VARCHAR(4) NOT NULL REFERENCES venue(mic),
    asset_class VARCHAR(20) NOT NULL CHECK (asset_class IN ('EQUITY', 'DERIVATIVE', 'FIXED_INCOME')),
    cfi_code VARCHAR(6) CHECK (cfi_code ~ '^[A-Z]{6}$'),
    currency VARCHAR(3) NOT NULL,
    contract_specs JSONB, -- Flexible payload for derivatives (strike price, multipliers, expiries)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexing JSONB for fast derivative queries (e.g., finding all options expiring on a certain date)
CREATE INDEX idx_instrument_contract_specs ON instrument USING GIN (contract_specs);
CREATE INDEX idx_instrument_ticker ON instrument(ticker);
CREATE INDEX idx_instrument_issuer ON instrument(issuer_lei);