-- AI STOCK SCREENER DATABASE SCHEMA
-- PostgreSQL Schema Definition
-- 
-- HOW TO USE THIS FILE:
-- 1. Connect to PostgreSQL: psql -U postgres
-- 2. Create database: CREATE DATABASE stock_screener;
-- 3. Connect to it: \c stock_screener
-- 4. Run this file: \i schema.sql

-- ============================================
-- TABLE: symbols
-- Stores stock ticker symbols and company info
-- ============================================

DROP TABLE IF EXISTS fundamentals CASCADE;
DROP TABLE IF EXISTS symbols CASCADE;

CREATE TABLE symbols (
  id SERIAL PRIMARY KEY,
  ticker VARCHAR(20) UNIQUE NOT NULL,
  exchange VARCHAR(50),
  company_name VARCHAR(255),
  sector VARCHAR(100),
  industry VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster ticker lookups
CREATE INDEX idx_symbols_ticker ON symbols(ticker);

-- Index for sector filtering
CREATE INDEX idx_symbols_sector ON symbols(sector);

-- ============================================
-- TABLE: fundamentals
-- Stores financial metrics for each stock
-- ============================================

CREATE TABLE fundamentals (
  id SERIAL PRIMARY KEY,
  symbol_id INTEGER NOT NULL REFERENCES symbols(id) ON DELETE CASCADE,
  
  -- Valuation metrics
  pe_ratio DECIMAL(10, 2),           -- Price-to-Earnings ratio
  market_cap BIGINT,                 -- Market capitalization in smallest currency unit
  eps DECIMAL(10, 2),                -- Earnings Per Share
  
  -- Financial health metrics
  debt_to_equity DECIMAL(10, 2),     -- Debt-to-Equity ratio
  
  -- Ownership metrics (India-specific)
  promoter_holding DECIMAL(5, 2),    -- Promoter holding percentage
  
  -- Metadata
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Ensure one fundamental record per symbol
  UNIQUE(symbol_id)
);

-- Index for faster joins
CREATE INDEX idx_fundamentals_symbol_id ON fundamentals(symbol_id);

-- Indexes for common filter operations
CREATE INDEX idx_fundamentals_pe_ratio ON fundamentals(pe_ratio);
CREATE INDEX idx_fundamentals_market_cap ON fundamentals(market_cap);

-- ============================================
-- SAMPLE DATA
-- Insert some example stocks for testing
-- ============================================

-- Insert TCS (Tata Consultancy Services)
INSERT INTO symbols (ticker, exchange, company_name, sector, industry)
VALUES ('TCS', 'NSE', 'Tata Consultancy Services', 'Technology', 'IT Services & Consulting');

INSERT INTO fundamentals (symbol_id, pe_ratio, market_cap, eps, debt_to_equity, promoter_holding)
VALUES (
  (SELECT id FROM symbols WHERE ticker = 'TCS'),
  28.5,
  1200000000000,  -- 12 lakh crores
  120.5,
  0.15,
  72.3
);

-- Insert Reliance
INSERT INTO symbols (ticker, exchange, company_name, sector, industry)
VALUES ('RELIANCE', 'NSE', 'Reliance Industries Limited', 'Energy', 'Oil & Gas');

INSERT INTO fundamentals (symbol_id, pe_ratio, market_cap, eps, debt_to_equity, promoter_holding)
VALUES (
  (SELECT id FROM symbols WHERE ticker = 'RELIANCE'),
  25.3,
  1800000000000,  -- 18 lakh crores
  95.7,
  0.45,
  50.4
);

-- Insert Infosys
INSERT INTO symbols (ticker, exchange, company_name, sector, industry)
VALUES ('INFY', 'NSE', 'Infosys Limited', 'Technology', 'IT Services & Consulting');

INSERT INTO fundamentals (symbol_id, pe_ratio, market_cap, eps, debt_to_equity, promoter_holding)
VALUES (
  (SELECT id FROM symbols WHERE ticker = 'INFY'),
  26.8,
  650000000000,  -- 6.5 lakh crores
  65.2,
  0.08,
  15.2
);

-- Insert HDFC Bank
INSERT INTO symbols (ticker, exchange, company_name, sector, industry)
VALUES ('HDFCBANK', 'NSE', 'HDFC Bank Limited', 'Finance', 'Banking');

INSERT INTO fundamentals (symbol_id, pe_ratio, market_cap, eps, debt_to_equity, promoter_holding)
VALUES (
  (SELECT id FROM symbols WHERE ticker = 'HDFCBANK'),
  18.5,
  850000000000,  -- 8.5 lakh crores
  82.3,
  8.5,  -- Banks have high debt-to-equity
  26.1
);

-- Insert Wipro
INSERT INTO symbols (ticker, exchange, company_name, sector, industry)
VALUES ('WIPRO', 'NSE', 'Wipro Limited', 'Technology', 'IT Services & Consulting');

INSERT INTO fundamentals (symbol_id, pe_ratio, market_cap, eps, debt_to_equity, promoter_holding)
VALUES (
  (SELECT id FROM symbols WHERE ticker = 'WIPRO'),
  22.4,
  320000000000,  -- 3.2 lakh crores
  28.5,
  0.12,
  73.5
);

-- ============================================
-- VERIFICATION QUERIES
-- Run these to verify the setup
-- ============================================

-- Count symbols
SELECT COUNT(*) as total_symbols FROM symbols;

-- Count fundamentals
SELECT COUNT(*) as total_fundamentals FROM fundamentals;

-- View all stocks with fundamentals
SELECT 
  s.ticker,
  s.company_name,
  s.sector,
  f.pe_ratio,
  f.market_cap,
  f.eps
FROM symbols s
LEFT JOIN fundamentals f ON s.id = f.symbol_id
ORDER BY s.ticker;

-- Test query: Stocks with PE < 25
SELECT 
  s.ticker,
  s.company_name,
  f.pe_ratio,
  f.market_cap
FROM symbols s
INNER JOIN fundamentals f ON s.id = f.symbol_id
WHERE f.pe_ratio < 25
ORDER BY f.pe_ratio;

-- Test query: Technology sector stocks
SELECT 
  s.ticker,
  s.company_name,
  s.sector,
  f.pe_ratio
FROM symbols s
INNER JOIN fundamentals f ON s.id = f.symbol_id
WHERE s.sector LIKE '%Technology%'
ORDER BY f.pe_ratio;
