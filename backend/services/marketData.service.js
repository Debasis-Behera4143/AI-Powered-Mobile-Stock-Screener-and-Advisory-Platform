const axios = require("axios");

async function fetchCompanyOverview(symbol) {
  const apiKey = process.env.ALPHA_VANTAGE_API_KEY;

  const url = `https://www.alphavantage.co/query?function=OVERVIEW&symbol=${symbol}&apikey=${apiKey}`;

  const response = await axios.get(url);

  if (!response.data || response.data.Note) {
    throw new Error("Market API error or rate limit reached");
  }

  return response.data;
}

module.exports = { fetchCompanyOverview };
