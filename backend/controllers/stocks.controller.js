const pool = require("../database");
const DataFreshnessService = require("../services/dataFreshness.service");
const finnhubService = require("../services/finnhub.service");
const responseFormatter = require("../utils/responseFormatter");
const logger = require("../utils/logger");

const ALLOWED_SORT_FIELDS = new Set([
  "market_cap_cr",
  "pe_ratio",
  "ltp",
  "change_pct",
  "volume",
  "return_1m",
  "return_3m",
  "return_1y",
  "return_3y",
  "return_5y",
  "rsi",
]);

const COMPANY_SYMBOLS = {
  "reliance": "RELIANCE",
  "hdfc": "HDFCBANK",
  "hdfc bank": "HDFCBANK",
  "bharti airtel": "BHARTIARTL",
  "tata consultancy": "TCS",
  "tata consultancy systems": "TCS",
  "icici": "ICICIBANK",
  "icici bank": "ICICIBANK",
  "state india": "SBIN",
  "state bank india": "SBIN",
  "infosys": "INFY",
  "wipro": "WIPRO",
  "hcl technologies": "HCLTECH",
  "tech mahindra": "TECHM",
  "axis": "AXISBANK",
  "axis bank": "AXISBANK",
  "kotak mahindra": "KOTAKBANK",
  "hindustan unilever": "HINDUNILVR",
  "itc": "ITC",
  "larsen toubro": "LT",
  "bajaj finance": "BAJFINANCE",
  "asian paints": "ASIANPAINT",
  "maruti suzuki": "MARUTI",
  "titan": "TITAN",
  "sun pharmaceutical": "SUNPHARMA",
  "tata motors": "TATAMOTORS",
  "tata steel": "TATASTEEL",
  "ntpc": "NTPC",
  "power grid corporation": "POWERGRID",
  "mahindra mahindra": "M&M",
  "ultratech cement": "ULTRACEMCO",
  "nestle india": "NESTLEIND",
  "oil natural gas": "ONGC",
};

async function getStocks(req, res) {
  try {
    const search = (req.query.search || "").trim();
    const minMarketCap = parseNumeric(req.query.min_market_cap_cr);
    const maxMarketCap = parseNumeric(req.query.max_market_cap_cr);
    const minPe = parseNumeric(req.query.min_pe_ratio);
    const maxPe = parseNumeric(req.query.max_pe_ratio);
    const limit = clamp(parseInt(req.query.limit, 10) || 100, 1, 500);
    const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
    const sort = ALLOWED_SORT_FIELDS.has(req.query.sort) ? req.query.sort : "market_cap_cr";
    const order = (req.query.order || "desc").toLowerCase() === "asc" ? "ASC" : "DESC";
    const liveRequested = req.query.live !== "false";
    const liveEnabled = process.env.USE_LIVE_MARKET_DATA === "true" && liveRequested;
    const liveLimit = clamp(
      parseInt(req.query.live_limit || process.env.LIVE_QUOTE_BATCH_LIMIT || "50", 10),
      0,
      100
    );

    const where = [];
    const params = [];

    if (search) {
      params.push(`%${search}%`);
      where.push(`name ILIKE $${params.length}`);
    }

    if (minMarketCap !== null) {
      params.push(minMarketCap);
      where.push(`market_cap_cr >= $${params.length}`);
    }

    if (maxMarketCap !== null) {
      params.push(maxMarketCap);
      where.push(`market_cap_cr <= $${params.length}`);
    }

    if (minPe !== null) {
      params.push(minPe);
      where.push(`pe_ratio >= $${params.length}`);
    }

    if (maxPe !== null) {
      params.push(maxPe);
      where.push(`pe_ratio <= $${params.length}`);
    }

    let sql = "SELECT * FROM dhan_stocks";
    if (where.length > 0) {
      sql += ` WHERE ${where.join(" AND ")}`;
    }

    params.push(limit);
    params.push(offset);
    sql += ` ORDER BY ${sort} ${order} NULLS LAST LIMIT $${params.length - 1} OFFSET $${params.length}`;

    const [stocksResult, freshnessResult] = await Promise.all([
      pool.query(sql, params),
      pool.query("SELECT MAX(updated_at) AS last_updated FROM dhan_stocks"),
    ]);

    const stocks = liveEnabled
      ? await enrichWithLiveQuotes(stocksResult.rows, liveLimit)
      : withSheetPriceFields(stocksResult.rows);
    const lastUpdated = freshnessResult.rows[0]?.last_updated || null;

    const metadata = {
      ...DataFreshnessService.augmentBatchResponse(
        stocks,
        lastUpdated,
        liveEnabled ? "DHAN_CSV_PLUS_LIVE_QUOTES" : "DHAN_CSV"
      ).metadata,
      live_market_data: {
        requested: liveRequested,
        enabled: liveEnabled,
        provider: "FINNHUB",
        enriched_count: stocks.filter((stock) => stock.is_real_data).length,
        limit: liveLimit,
      },
      query_params: {
        search,
        filters: { minMarketCap, maxMarketCap, minPe, maxPe },
        sort,
        order,
        limit,
        offset,
      },
    };

    res.json(responseFormatter.list(stocks, metadata));
  } catch (error) {
    logger.error(logger.LOG_CATEGORIES.API, "Get stocks error", { error: error.message });
    res.status(500).json(
      responseFormatter.error("Failed to retrieve stock data", "STOCKS_FETCH_ERROR", {
        detail: error.message,
      })
    );
  }
}

function withSheetPriceFields(stocks) {
  return stocks.map((stock) => ({
    ...stock,
    symbol: resolveMarketSymbol(stock),
    current_price: stock.ltp,
    currentPrice: stock.ltp,
    price: stock.ltp,
    change_percent: stock.change_pct,
    changePercent: stock.change_pct,
    data_source: "DHAN_CSV",
    is_real_data: false,
  }));
}

async function enrichWithLiveQuotes(stocks, liveLimit) {
  const baseRows = withSheetPriceFields(stocks);
  if (liveLimit <= 0) return baseRows;

  const quoteTargets = baseRows.filter((stock) => stock.symbol).slice(0, liveLimit);
  const quotes = await finnhubService.getQuotes(quoteTargets.map((stock) => stock.symbol));
  const bySymbol = new Map(quotes.map((quote) => [stripExchangeSuffix(quote.symbol), quote]));

  return baseRows.map((stock) => {
    const quote = bySymbol.get(stripExchangeSuffix(stock.symbol));
    if (!quote || quote.current_price <= 0) return stock;

    return {
      ...stock,
      symbol: stripExchangeSuffix(quote.symbol),
      market_symbol: quote.symbol,
      ltp: quote.current_price,
      current_price: quote.current_price,
      currentPrice: quote.current_price,
      price: quote.current_price,
      previous_close: quote.previous_close,
      previousClose: quote.previous_close,
      change: quote.change,
      change_percent: quote.change_percent,
      changePercent: quote.change_percent,
      change_pct: quote.change_percent,
      open: quote.open ?? stock.open,
      high: quote.high,
      low: quote.low,
      volume: quote.volume || stock.volume,
      timestamp: quote.timestamp,
      data_source: quote.data_source,
      is_real_data: quote.is_real_data,
      is_delayed: quote.is_delayed,
      delay_minutes: quote.delay_minutes,
      fallback_reason: quote.fallback_reason,
    };
  });
}

function resolveMarketSymbol(stock) {
  const normalizedName = normalizeName(stock.name);
  const known = COMPANY_SYMBOLS[normalizedName];
  if (known) return known;

  const slug = extractCompanySlug(stock.screener_url);
  const normalizedSlug = normalizeName(slug.replace(/-/g, " "));
  const slugKnown = COMPANY_SYMBOLS[normalizedSlug];
  if (slugKnown) return slugKnown;

  return deriveSymbolFromSlug(slug) || deriveSymbolFromName(stock.name);
}

function normalizeName(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/\b(limited|ltd|company|co|industries|industry|services|service)\b/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function extractCompanySlug(url) {
  const match = /\/company\/([^/?#]+)/i.exec(String(url || ""));
  return match ? match[1].toLowerCase() : "";
}

function deriveSymbolFromSlug(slug) {
  if (!slug) return "";
  const cleaned = slug
    .replace(/-ltd$/, "")
    .replace(/-limited$/, "")
    .replace(/-india$/, "");
  const first = cleaned.split("-").filter(Boolean)[0];
  return first ? first.toUpperCase() : "";
}

function deriveSymbolFromName(name) {
  const words = String(name || "")
    .replace(/&/g, "and")
    .split(/\s+/)
    .map((word) => word.replace(/[^A-Za-z0-9]/g, ""))
    .filter(Boolean);

  if (words.length === 0) return "";
  return words
    .slice(0, 3)
    .map((word) => word[0])
    .join("")
    .toUpperCase();
}

function stripExchangeSuffix(symbol) {
  return String(symbol || "").toUpperCase().replace(/\.(NS|BO)$/i, "");
}

function parseNumeric(value) {
  if (value === undefined || value === null || value === "") {
    return null;
  }

  const cleaned = String(value).trim().replace(/,/g, "").replace(/%/g, "");
  if (cleaned === "" || cleaned === "-") {
    return null;
  }

  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : null;
}

function clamp(value, min, max) {
  if (!Number.isFinite(value)) {
    return min;
  }

  return Math.min(Math.max(value, min), max);
}

module.exports = {
  getStocks,
  enrichWithLiveQuotes,
  withSheetPriceFields,
};
